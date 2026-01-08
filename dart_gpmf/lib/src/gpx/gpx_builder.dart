import 'package:xml/xml.dart';
import '../models/gps_data.dart';

/// Builder for GPX (GPS Exchange Format) XML files.
///
/// Creates GPX 1.1 compliant XML from GPS track data.
class GpxBuilder {
  static const _gpxNamespace = 'http://www.topografix.com/GPX/1/1';
  static const _xsiNamespace = 'http://www.w3.org/2001/XMLSchema-instance';
  static const _schemaLocation =
      'http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd';

  /// Build GPX XML string from a GPS track.
  ///
  /// [track] - The GPS track data to convert
  /// [creator] - Creator application name (default: 'dart_gpmf')
  /// [name] - Optional track name
  /// [description] - Optional track description
  /// [validFixOnly] - If true, only include points with valid GPS fix (default: true)
  static String build(
    GPSTrack track, {
    String creator = 'dart_gpmf',
    String? name,
    String? description,
    bool validFixOnly = true,
  }) {
    final points = validFixOnly ? track.validOnly.points : track.points;

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element(
      'gpx',
      nest: () {
        builder.attribute('version', '1.1');
        builder.attribute('creator', creator);
        builder.attribute('xmlns', _gpxNamespace);
        builder.attribute('xmlns:xsi', _xsiNamespace);
        builder.attribute('xsi:schemaLocation', _schemaLocation);

        // Metadata
        builder.element(
          'metadata',
          nest: () {
            builder.element(
              'name',
              nest: name ?? '${track.deviceName} GPS Track',
            );
            if (description != null) {
              builder.element('desc', nest: description);
            }
            builder.element(
              'time',
              nest: DateTime.now().toUtc().toIso8601String(),
            );
          },
        );

        // Track
        builder.element(
          'trk',
          nest: () {
            builder.element(
              'name',
              nest: name ?? '${track.deviceName} GPS Track',
            );
            builder.element('src', nest: track.deviceName);

            // Track segment
            builder.element(
              'trkseg',
              nest: () {
                for (final point in points) {
                  _buildTrackPoint(builder, point);
                }
              },
            );
          },
        );
      },
    );

    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// Build GPX XML string from multiple GPS tracks.
  static String buildMultiTrack(
    List<GPSTrack> tracks, {
    String creator = 'dart_gpmf',
    String? name,
    String? description,
    bool validFixOnly = true,
  }) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element(
      'gpx',
      nest: () {
        builder.attribute('version', '1.1');
        builder.attribute('creator', creator);
        builder.attribute('xmlns', _gpxNamespace);
        builder.attribute('xmlns:xsi', _xsiNamespace);
        builder.attribute('xsi:schemaLocation', _schemaLocation);

        // Metadata
        builder.element(
          'metadata',
          nest: () {
            builder.element('name', nest: name ?? 'GPS Tracks');
            if (description != null) {
              builder.element('desc', nest: description);
            }
            builder.element(
              'time',
              nest: DateTime.now().toUtc().toIso8601String(),
            );
          },
        );

        // Multiple tracks
        for (var i = 0; i < tracks.length; i++) {
          final track = tracks[i];
          final points = validFixOnly ? track.validOnly.points : track.points;

          builder.element(
            'trk',
            nest: () {
              builder.element(
                'name',
                nest: '${track.deviceName} Track ${i + 1}',
              );
              builder.element('src', nest: track.deviceName);

              builder.element(
                'trkseg',
                nest: () {
                  for (final point in points) {
                    _buildTrackPoint(builder, point);
                  }
                },
              );
            },
          );
        }
      },
    );

    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// Build GPX with only coordinates (no elevation, time, etc.).
  /// Useful for smaller file size or privacy.
  static String buildMinimal(
    GPSTrack track, {
    String creator = 'dart_gpmf',
    bool validFixOnly = true,
  }) {
    final points = validFixOnly ? track.validOnly.points : track.points;

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element(
      'gpx',
      nest: () {
        builder.attribute('version', '1.1');
        builder.attribute('creator', creator);
        builder.attribute('xmlns', _gpxNamespace);

        builder.element(
          'trk',
          nest: () {
            builder.element(
              'trkseg',
              nest: () {
                for (final point in points) {
                  builder.element(
                    'trkpt',
                    nest: () {
                      builder.attribute(
                        'lat',
                        point.latitude.toStringAsFixed(7),
                      );
                      builder.attribute(
                        'lon',
                        point.longitude.toStringAsFixed(7),
                      );
                    },
                  );
                }
              },
            );
          },
        );
      },
    );

    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// Build a single track point element.
  static void _buildTrackPoint(XmlBuilder builder, GPSData point) {
    builder.element(
      'trkpt',
      nest: () {
        builder.attribute('lat', point.latitude.toStringAsFixed(7));
        builder.attribute('lon', point.longitude.toStringAsFixed(7));

        // Elevation
        builder.element('ele', nest: point.altitude.toStringAsFixed(2));

        // Time
        builder.element('time', nest: point.timestamp.toIso8601String());

        // Extensions for additional data
        builder.element(
          'extensions',
          nest: () {
            builder.element('speed', nest: point.speed2d.toStringAsFixed(2));
            builder.element('speed3d', nest: point.speed3d.toStringAsFixed(2));
            builder.element('fix', nest: _fixTypeString(point.fix));
            builder.element('hdop', nest: point.dop.toStringAsFixed(2));
          },
        );
      },
    );
  }

  /// Convert fix type integer to GPX fix string.
  static String _fixTypeString(int fix) {
    switch (fix) {
      case 0:
        return 'none';
      case 2:
        return '2d';
      case 3:
        return '3d';
      default:
        return 'none';
    }
  }
}
