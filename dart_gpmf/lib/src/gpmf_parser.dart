import 'dart:typed_data';
import 'models/gps_data.dart';
import 'core/gpmf_decoder.dart';
import 'gpx/gpx_builder.dart';

/// High-level API for parsing GPMF data and converting to GPX.
///
/// Example usage:
/// ```dart
/// final gpmfBytes = await getGpmfDataFromGoPro();
/// final gpxString = GpmfParser.toGpx(gpmfBytes);
/// ```
class GpmfParser {
  /// Parse GPMF binary data into a GPS track.
  ///
  /// [data] - Raw GPMF binary bytes from GoPro
  /// Returns a [GPSTrack] containing all decoded GPS points.
  static GPSTrack parse(Uint8List data) {
    final decoder = GpmfDecoder.fromBytes(data);
    return decoder.decodeTrack();
  }

  /// Parse GPMF binary data and convert directly to GPX string.
  ///
  /// [data] - Raw GPMF binary bytes from GoPro
  /// [creator] - Creator application name for GPX metadata
  /// [name] - Optional track name
  /// [validFixOnly] - If true, only include points with valid GPS fix
  /// Returns a GPX 1.1 compliant XML string.
  static String toGpx(
    Uint8List data, {
    String creator = 'dart_gpmf',
    String? name,
    bool validFixOnly = true,
  }) {
    final track = parse(data);
    return GpxBuilder.build(
      track,
      creator: creator,
      name: name,
      validFixOnly: validFixOnly,
    );
  }

  /// Parse GPMF data and convert to minimal GPX (coordinates only).
  ///
  /// [data] - Raw GPMF binary bytes from GoPro
  /// Returns a minimal GPX string with only lat/lon coordinates.
  static String toMinimalGpx(Uint8List data, {bool validFixOnly = true}) {
    final track = parse(data);
    return GpxBuilder.buildMinimal(track, validFixOnly: validFixOnly);
  }

  /// Parse multiple GPMF data chunks into a single multi-track GPX.
  ///
  /// [dataChunks] - List of raw GPMF binary data
  /// [creator] - Creator application name for GPX metadata
  /// [name] - Optional GPX file name
  /// Returns a GPX string with multiple tracks.
  static String multiToGpx(
    List<Uint8List> dataChunks, {
    String creator = 'dart_gpmf',
    String? name,
    bool validFixOnly = true,
  }) {
    final tracks = dataChunks.map((data) => parse(data)).toList();
    return GpxBuilder.buildMultiTrack(
      tracks,
      creator: creator,
      name: name,
      validFixOnly: validFixOnly,
    );
  }

  /// Get GPS format detected in GPMF data without full parsing.
  ///
  /// [data] - Raw GPMF binary bytes
  /// Returns the [GPSFormat] detected (gps5, gps9, or unknown).
  static GPSFormat detectFormat(Uint8List data) {
    final decoder = GpmfDecoder.fromBytes(data);
    return decoder.gpsFormat;
  }

  /// Get device information from GPMF data.
  ///
  /// [data] - Raw GPMF binary bytes
  /// Returns a map with 'deviceId' and 'deviceName'.
  static Map<String, String> getDeviceInfo(Uint8List data) {
    final decoder = GpmfDecoder.fromBytes(data);
    return {'deviceId': decoder.deviceId, 'deviceName': decoder.deviceName};
  }
}
