import logging
import struct, numpy
from datetime import datetime, timedelta
from flowitygpmf.t import KLVItem, KLVLength, TYPE_CONV
from flowitygpmf.src.helpers import ceil4
from typing import Any, Callable, Dict, NamedTuple
from gpxpy.gpx import GPXTrackPoint, GPXTrackSegment
from xml.etree import ElementTree as ET


class GPSData(NamedTuple):
  description:str
  timestamp:datetime
  precision:int
  fix:int
  latitude:float
  longitude:float
  altitude:float
  speed_2d:float
  speed_3d:float
  units:str
  npoints:int

FIX_TYPE = {
    0: "none",
    2: "2d",
    3: "3d"
}

class GPMFData:

  def __init__(self, strm:dict[str, KLVItem]):
    self._strm = strm.copy()
    if (logging.getLogger().isEnabledFor(logging.DEBUG)):
      self._log_header()

  def _log_header(self):
    logging.debug(f"GPMFData {self.strm_type} with keys: {list(self._strm.keys())}")
    for klv in self._strm.values():
      logging.debug(f"  {klv.key} - {klv.length} - {klv.value[:16].decode('utf-8', 'replace')} ...")

  @staticmethod
  def get_embedded_video_metadata(gpmfstreams:list['GPMFData']) -> Dict[str, Any]:
    DVID = None
    DVNM = None

    for dat in gpmfstreams:
      strm = dat._strm
      if not (DVID or DVNM):
        if "DVNM" in strm: # Assume DVID aswell
          DVID = int.from_bytes(strm["DVID"].value, "big")
          DVNM = strm["DVNM"].value.decode("latin-1")
          break

    return {
      "Device ID": DVID,
      "Device Name": DVNM
    }
  
  def __str__(self):
    
      s = f"\nGPMF -:{self.strm_type}:- ::::::::::::::::::::::::::::::"
      gpx_segment = self.gpx_segment
      s += f"{gpx_segment}"
      for p in gpx_segment.points:
        s += f"\n{p.name} - {p.latitude}, {p.longitude} - {p.time} - {p.comment}"
      s += "\nGPMF END :::::::::::::::::::::::::::::::::"

      return s

  @property
  def gpx_segment(self) -> GPXTrackSegment:
    """ Get the GPX track segment from the GPMF data. """
    return self.strm_type_decoders.get(self.strm_type, self.decoder_unknown)()

  @property
  def strm_type(self):
    if "GPS9" in self._strm:
        return "GPS9"
    elif "GPS5" in self._strm:
        return "GPS5"
    return "UNKNOWN"
  
  @property
  def strm_type_decoders(self):
     return {
        "GPS9": self.decode_gps9,
        "GPS5": self.decode_gps5,
     }

  def decode_from_type(self, item:KLVItem):
    if (item.length.type == "U"):
       return item.value.decode("latin-1")

    dtype, stype = TYPE_CONV[item.length.type]
    dtype = numpy.dtype(">" + stype)
    a = numpy.frombuffer(item.value, dtype=dtype)
    type_size = dtype.itemsize
    dim1 = item.length.size // type_size
    if a.size == 1:
        a = a[0]
    # elif dim1 > 1 and item.length.repeat > 1:
    #     a = a.reshape(item.length.repeat, dim1)
    return a


  def decode_gps9(self) -> GPXTrackSegment:
    """ Decode GPS9 stream type. """
    # ['STMP', 'TSMP', 'STNM', 'UNIT', 'TYPE', 'SCAL', 'GPSA', 'GPS9']
    STMP = self._strm.get("STMP")
    STMP = int(self.decode_from_type(STMP))

    TSMP = self._strm.get("TSMP")
    TSMP = int(self.decode_from_type(TSMP))

    STNM = self._strm.get("STNM")
    STNM = STNM.value.decode("latin-1")[:STNM.length.size]

    UNIT = self._strm.get("UNIT")
    UNIT = UNIT.value.decode("latin-1")[:UNIT.length.size]

    TYPE = self._strm.get("TYPE")
    TYPE = TYPE.value.decode("latin-1")[:TYPE.length.size]

    GPSA = self._strm.get("GPSA")
    GPSA = struct.unpack(">cccc", GPSA.value[:4])
    GPSA = (b"".join(GPSA)).decode()

    SCAL = self._strm.get("SCAL")
    SCAL = numpy.frombuffer(SCAL.value, ">i")

    GPS9 = self._strm.get("GPS9")
    typing = TYPE.replace("l", "I")
    typing = typing.replace("S", "H")
    samples = []
    for r in range(GPS9.length.repeat):
      samples.append([dv for dv in struct.unpack(f">{typing}", GPS9.value[r*GPS9.length.size:(r+1)*GPS9.length.size])])
    GPS9 = numpy.array(samples)
    GPS9 = GPS9 * 1.0 / SCAL




    gpx_segment = GPXTrackSegment()
    for i, gpsdp in enumerate(GPS9):

      days_since_2000 = gpsdp[5]
      seconds_of_day = gpsdp[6]
      gps_time = datetime.strptime("2000", "%Y") + timedelta(days=days_since_2000) + timedelta(seconds=seconds_of_day)
      gpx_point = self._build_gpx_point(
        STNM, UNIT, GPSA, i,
        lat=gpsdp[0],
        lng=gpsdp[1],
        elv=gpsdp[2],
        dop=gpsdp[7],  # GPSD Position Dilution of Precision
        vel2d=gpsdp[3],
        vel3d=gpsdp[4],  # GPS9 does not provide 3D velocity
        fix=gpsdp[8],  # GPS9 fix type
        gps_time=gps_time.replace(tzinfo=None)
      )

      gpx_segment.points.append(gpx_point)
    return gpx_segment


  def decode_gps5(self) -> GPXTrackSegment:
    """ Decode GPS5 stream type. """

    # Empty GPS5 stream, return an empty segment
    if ("EMPT" in list(self._strm.keys())):
      return GPXTrackSegment()

    STMP = self._strm.get("STMP")
    STMP = int(self.decode_from_type(STMP))

    TSMP = self._strm.get("TSMP")
    TSMP = int(self.decode_from_type(TSMP))

    STNM = self._strm.get("STNM")
    STNM = STNM.value.decode("latin-1")[:STNM.length.size]

    UNIT = self._strm.get("UNIT")
    UNIT = UNIT.value.decode("latin-1")[:UNIT.length.size]

    GPSU = self._strm.get("GPSU")
    GPSU = self.decode_from_type(GPSU)
    GPSU = f"20{GPSU}"
    GPSU = datetime.strptime(GPSU, "%Y%m%d%H%M%S.%f")

    GPSP = self._strm.get("GPSP")
    GPSP = (self.decode_from_type(GPSP)[0]) / 100.0  # GPSP is in cm, convert to m

    GPSF = self._strm.get("GPSF")
    GPSF = int(self.decode_from_type(GPSF))

    GPSA = self._strm.get("GPSA")
    GPSA = struct.unpack(">cccc", GPSA.value[:4])
    GPSA = (b"".join(GPSA)).decode()

    SCAL = self._strm.get("SCAL")
    SCAL = numpy.frombuffer(SCAL.value, ">i")

    GPS5 = self._strm.get("GPS5")
    _GPS5 = numpy.frombuffer(GPS5.value, ">i4")
    _GPS5 = _GPS5.reshape(GPS5.length.repeat, GPS5.length.size//4)

    G5SCALED = _GPS5 / SCAL

    gpx_segment = GPXTrackSegment()
    SAMPLE_TIME = timedelta(seconds=1.0 / 18.) # GPS5 18 HZ
    for i, gpsdp in enumerate(G5SCALED):
      pos_time = GPSU + (SAMPLE_TIME* i)
      gpx_segment.points.append(
         self._build_gpx_point(
            STNM, UNIT, GPSA, i,
            lat=gpsdp[0],
            lng=gpsdp[1],
            elv=gpsdp[2],
            dop=GPSP,  # GPSP is in cm,
            vel2d=gpsdp[3],
            vel3d=gpsdp[4],
            fix=GPSF,
            gps_time=pos_time.replace(tzinfo=None)
         )
      )

    return gpx_segment
  
  def decoder_unknown(self):
    """ Handle unknown stream types. """
    return ("???", list(self._strm.keys()))

  def _build_gpx_point(self, name:str, unit:str, gps_a:str, block_sample_idx:int, lat:float, lng:float, elv:float, dop:float, vel2d:float, vel3d:float, fix, gps_time):

    if lat>90 or lat<-90:
      logging.warning(f"Invalid latitude {lat} at sample {block_sample_idx} in block {name}, setting to 0.0")
      lat = 0.0
    if lng>180 or lng<-180:
      logging.warning(f"Invalid longitude {lng} at sample {block_sample_idx} in block {name}, setting to 0.0")
      lng = 0.0

    gpx_point = GPXTrackPoint(
      latitude=lat,
      longitude=lng,
      elevation=elv,
      time=gps_time,
      comment=f"unit<{unit}> gpsa<{gps_a}>",
      position_dilution=dop,  # GPSD Position Dilution of Precision
      name=f"{name}"
    )
    gpx_point.type_of_gpx_fix = FIX_TYPE[int(fix)]

    speed_2d = ET.Element("speed_2d")
    speed2d_value = ET.SubElement(speed_2d, "value")
    speed2d_value.text = f"{vel2d:.3f}"
    speed2d_unit = ET.SubElement(speed_2d, "unit")
    speed2d_unit.text = "m/s"

    speed_3d = ET.Element("speed_3d")
    speed3d_value = ET.SubElement(speed_3d, "value")
    speed3d_value.text = f"{vel3d:.3f}"
    speed3d_unit = ET.SubElement(speed_3d, "unit")
    speed3d_unit.text = "m/s"
    gpx_point.extensions.extend([speed_2d, speed_3d])
    return gpx_point