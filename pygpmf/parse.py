
import ffmpeg, logging, numpy, struct

from pygpmf.t import *
from pygpmf.helpers import ceil4, KLMReader
from pygpmf.endec import GPMFData
from gpxpy.gpx import GPXTrackSegment, GPXTrackPoint, GPX, GPXTrack

logger = logging.getLogger(__name__)



def gpmf2gpx(gpmf_blob:bytes) -> GPXTrack:
    """ Convert GPMF data to GPX Track """

    
    gpmf = gpmf_blob
    d = KLMReader.read_all(gpmf, unfold_keys=["DEVC", "STRM"])
    strm_klvs = {}
    # Group all single KLV items into same block.
    for path_id, klm in d:
        if path_id not in strm_klvs:
            strm_klvs[path_id] = {}
        strm_klvs[path_id][klm.key] = klm
    

    def merge_segments(segments:list[GPXTrackSegment]) -> GPXTrackSegment:
        merged = GPXTrackSegment()
        for segment in segments:
            merged.points.extend(segment.points)
        return merged

    gpmfdata = [GPMFData(klv) for klv in strm_klvs.values()]
    track = GPXTrack()
    gpx_segments = [gpmfgpx.gpx_segment for gpmfgpx in gpmfdata if gpmfgpx.strm_type == "GPS9"]
    if len(gpx_segments) == 0:
        logger.warning("No GPS9 data found in GPMF stream.")
        gpx_segments = [gpmfgpx.gpx_segment for gpmfgpx in gpmfdata if gpmfgpx.strm_type == "GPS5"]
    if len(gpx_segments) == 0:
        logger.warning("No GPS5 data found in GPMF stream.")
        exit(1)

    segment = merge_segments(gpx_segments)
    track.segments.append(segment)

    return track


def find_gpmf_stream(fname):
    """ Find the reference to the GPMF Stream in the video file """
    probe = ffmpeg.probe(fname)

    for s in probe["streams"]:
        logger.debug(f"Stream: {s['index']} - {s['codec_tag_string']}")
        if s["codec_tag_string"] == "gpmd":
            logger.debug(f"gpmd stream: {s}")
            return s


def extract_gpmf_stream(videofile, stream:str):
    """ Extract the GPMF Stream from the video file """

    stream_index = stream["index"]
    logger.debug(f"Extracting GPMF Stream {stream_index} from {videofile}")
    return ffmpeg.input(videofile).output("pipe:", format="rawvideo", map="0:%i" % stream_index, codec="copy").run(capture_stdout=True, capture_stderr=True)[0]


def write_gpx(gpxtrack:GPXTrack, output_file):
    """ Write GPX segments to a file """

    gpx = GPX()
    gpx.tracks.append(gpxtrack)

    with open(output_file, 'w') as f:
        f.write(gpx.to_xml())
    logger.info(f"GPX data written to {output_file}")
