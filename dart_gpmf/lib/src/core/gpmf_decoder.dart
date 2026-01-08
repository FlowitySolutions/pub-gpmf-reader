import 'dart:typed_data';
import '../models/klv_types.dart';
import '../models/gps_data.dart';
import 'klv_parser.dart';

/// Decoder for GPMF GPS telemetry data.
///
/// Handles both GPS5 (older format) and GPS9 (newer format) data streams,
/// extracting coordinates, timestamps, speed, and precision information.
class GpmfDecoder {
  final Map<String, dynamic> _data;

  GpmfDecoder(this._data);

  /// Create decoder from raw GPMF bytes.
  factory GpmfDecoder.fromBytes(Uint8List bytes) {
    final parsed = KlvParser.parseToMap(bytes);
    return GpmfDecoder(parsed);
  }

  /// Detect GPS format present in the data.
  GPSFormat get gpsFormat {
    final streams = _findStreams();
    for (final stream in streams) {
      if (stream.containsKey('GPS9')) return GPSFormat.gps9;
      if (stream.containsKey('GPS5')) return GPSFormat.gps5;
    }
    return GPSFormat.unknown;
  }

  /// Extract device ID from GPMF data.
  String get deviceId {
    final devc = _data['DEVC'];
    if (devc is Map && devc['DVID'] is KLVItem) {
      return (devc['DVID'] as KLVItem).readUint32().toString();
    }
    return 'unknown';
  }

  /// Extract device name from GPMF data.
  String get deviceName {
    final devc = _data['DEVC'];
    if (devc is Map && devc['DVNM'] is KLVItem) {
      return (devc['DVNM'] as KLVItem).readString();
    }
    return 'GoPro';
  }

  /// Decode all GPS data points from the GPMF stream.
  List<GPSData> decodeGPS() {
    switch (gpsFormat) {
      case GPSFormat.gps5:
        return _decodeGPS5();
      case GPSFormat.gps9:
        return _decodeGPS9();
      case GPSFormat.unknown:
        return [];
    }
  }

  /// Decode as a complete GPS track.
  GPSTrack decodeTrack() {
    return GPSTrack(
      deviceId: deviceId,
      deviceName: deviceName,
      format: gpsFormat,
      points: decodeGPS(),
    );
  }

  /// Find all STRM (stream) containers in the data.
  List<Map<String, dynamic>> _findStreams() {
    final devc = _data['DEVC'];
    if (devc == null) return [];

    final streams = <Map<String, dynamic>>[];

    void extractStreams(dynamic data) {
      if (data is Map<String, dynamic>) {
        if (data.containsKey('STRM')) {
          final strm = data['STRM'];
          if (strm is Map<String, dynamic>) {
            streams.add(strm);
          } else if (strm is List) {
            for (final s in strm) {
              if (s is Map<String, dynamic>) streams.add(s);
            }
          }
        }
      }
    }

    if (devc is List) {
      for (final d in devc) {
        extractStreams(d);
      }
    } else {
      extractStreams(devc);
    }

    return streams;
  }

  /// Find stream containing GPS data.
  Map<String, dynamic>? _findGPSStream() {
    final streams = _findStreams();
    for (final stream in streams) {
      if (stream.containsKey('GPS9') || stream.containsKey('GPS5')) {
        return stream;
      }
    }
    return null;
  }

  /// Decode GPS5 format data.
  /// GPS5 contains: latitude, longitude, altitude, speed2d, speed3d
  /// All as int32 values that need scaling.
  List<GPSData> _decodeGPS5() {
    final stream = _findGPSStream();
    if (stream == null) return [];

    final gps5Item = stream['GPS5'];
    if (gps5Item is! KLVItem) return [];

    // Get scale factors (SCAL)
    final scalItem = stream['SCAL'];
    final scales = scalItem is KLVItem
        ? _readScales(scalItem)
        : [1, 1, 1, 1, 1];

    // Get timestamp (GPSU)
    final gpsuItem = stream['GPSU'];
    final baseTime = gpsuItem is KLVItem
        ? _parseGPSU(gpsuItem)
        : DateTime.now();

    // Get precision (GPSP) - single value for entire block
    final gpspItem = stream['GPSP'];
    final precision = gpspItem is KLVItem ? gpspItem.readUint16() : 9999;

    // Get fix type (GPSF)
    final gpsfItem = stream['GPSF'];
    final fix = gpsfItem is KLVItem ? gpsfItem.readUint32() : 0;

    // Get units string
    final unitItem = stream['UNIT'];
    final units = unitItem is KLVItem
        ? unitItem.readString()
        : 'deg,deg,m,m/s,m/s';

    // Parse GPS5 data: 5 int32 values per sample
    final rawValues = gps5Item.readInt32Array();
    final sampleCount = rawValues.length ~/ 5;

    final points = <GPSData>[];

    for (var i = 0; i < sampleCount; i++) {
      final offset = i * 5;

      // Apply scale factors
      final lat = rawValues[offset] / scales[0];
      final lon = rawValues[offset + 1] / scales[1];
      final alt = rawValues[offset + 2] / scales[2];
      final speed2d = rawValues[offset + 3] / scales[3];
      final speed3d = rawValues[offset + 4] / scales[4];

      // GPS5 samples at 18 Hz, so each sample is ~55.5ms apart
      final timestamp = baseTime.add(Duration(milliseconds: (i * 1000 ~/ 18)));

      points.add(
        GPSData(
          description: 'GPS5',
          timestamp: timestamp,
          precision: precision,
          fix: fix,
          latitude: lat,
          longitude: lon,
          altitude: alt,
          speed2d: speed2d,
          speed3d: speed3d,
          units: units,
          npoints: sampleCount,
        ),
      );
    }

    return points;
  }

  /// Decode GPS9 format data.
  /// GPS9 contains embedded timestamps and per-sample precision/fix.
  List<GPSData> _decodeGPS9() {
    final stream = _findGPSStream();
    if (stream == null) return [];

    final gps9Item = stream['GPS9'];
    if (gps9Item is! KLVItem) return [];

    // Get scale factors
    final scalItem = stream['SCAL'];
    final scales = scalItem is KLVItem
        ? _readScales(scalItem)
        : [1, 1, 1, 1, 1, 1, 1, 1, 1];

    // Get units string
    final unitItem = stream['UNIT'];
    final units = unitItem is KLVItem
        ? unitItem.readString()
        : 'deg,deg,m,m/s,m/s';

    // Parse GPS9 data
    // Structure: lat, lon, alt, speed2d, speed3d, days, seconds, dop, fix
    // Types vary - need to handle based on SCAL count
    final bd = gps9Item.byteData;
    final sampleSize = gps9Item.length.size;
    final sampleCount = gps9Item.length.repeat;

    final points = <GPSData>[];

    for (var i = 0; i < sampleCount; i++) {
      final baseOffset = i * sampleSize;

      // GPS9 layout (typical 36 bytes per sample):
      // int32 lat, int32 lon, int32 alt, int16 speed2d, int16 speed3d,
      // uint16 days, uint32 seconds, uint16 dop, uint8 fix

      final lat = bd.getInt32(baseOffset, Endian.big) / scales[0];
      final lon = bd.getInt32(baseOffset + 4, Endian.big) / scales[1];
      final alt = bd.getInt32(baseOffset + 8, Endian.big) / scales[2];
      final speed2d = bd.getInt16(baseOffset + 12, Endian.big) / scales[3];
      final speed3d = bd.getInt16(baseOffset + 14, Endian.big) / scales[4];

      // Days since 2000-01-01, seconds of day
      final days = bd.getUint16(baseOffset + 16, Endian.big);
      final secs = bd.getUint32(baseOffset + 18, Endian.big);

      final dop = bd.getUint16(baseOffset + 22, Endian.big);
      final fix = bd.getUint8(baseOffset + 24);

      // Convert days/seconds to DateTime
      final epoch2000 = DateTime.utc(2000, 1, 1);
      final timestamp = epoch2000
          .add(Duration(days: days))
          .add(Duration(milliseconds: (secs * 1000 / scales[6]).round()));

      points.add(
        GPSData(
          description: 'GPS9',
          timestamp: timestamp,
          precision: dop,
          fix: fix,
          latitude: lat,
          longitude: lon,
          altitude: alt,
          speed2d: speed2d,
          speed3d: speed3d,
          units: units,
          npoints: sampleCount,
        ),
      );
    }

    return points;
  }

  /// Read SCAL (scale factors) array.
  List<double> _readScales(KLVItem scalItem) {
    switch (scalItem.length.type) {
      case 'l':
        return scalItem.readInt32Array().map((v) => v.toDouble()).toList();
      case 's':
        return scalItem.readInt16Array().map((v) => v.toDouble()).toList();
      case 'f':
        return scalItem.readFloat32Array();
      case 'd':
        return scalItem.readFloat64Array();
      default:
        return [1.0];
    }
  }

  /// Parse GPSU timestamp string (format: yymmddhhmmss.sss).
  DateTime _parseGPSU(KLVItem gpsuItem) {
    try {
      final str = gpsuItem.readString();
      // Format: yymmddhhmmss.sss or YYMMDDHHmmss.sss
      if (str.length >= 12) {
        final year = 2000 + int.parse(str.substring(0, 2));
        final month = int.parse(str.substring(2, 4));
        final day = int.parse(str.substring(4, 6));
        final hour = int.parse(str.substring(6, 8));
        final minute = int.parse(str.substring(8, 10));
        final second = int.parse(str.substring(10, 12));

        var millis = 0;
        if (str.length > 13 && str[12] == '.') {
          final fracStr = str.substring(13).padRight(3, '0').substring(0, 3);
          millis = int.tryParse(fracStr) ?? 0;
        }

        return DateTime.utc(year, month, day, hour, minute, second, millis);
      }
    } catch (_) {
      // Fall through to default
    }
    return DateTime.now().toUtc();
  }
}
