/// GPS data point extracted from GPMF telemetry.
class GPSData {
  /// Description of the data source
  final String description;

  /// UTC timestamp of the GPS reading
  final DateTime timestamp;

  /// GPS precision (DOP - Dilution of Precision) × 100
  final int precision;

  /// GPS fix type: 0=none, 2=2D fix, 3=3D fix
  final int fix;

  /// Latitude in degrees (-90 to 90)
  final double latitude;

  /// Longitude in degrees (-180 to 180)
  final double longitude;

  /// Altitude in meters above sea level
  final double altitude;

  /// 2D ground speed in m/s
  final double speed2d;

  /// 3D speed in m/s (includes vertical component)
  final double speed3d;

  /// Units description string
  final String units;

  /// Number of GPS samples in this batch
  final int npoints;

  const GPSData({
    required this.description,
    required this.timestamp,
    required this.precision,
    required this.fix,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed2d,
    required this.speed3d,
    required this.units,
    required this.npoints,
  });

  /// Whether this GPS reading has a valid fix
  bool get hasValidFix => fix >= 2;

  /// Whether this is a 3D fix (includes altitude)
  bool get has3DFix => fix >= 3;

  /// Precision as actual DOP value (divide by 100)
  double get dop => precision / 100.0;

  /// Create a copy with modified values
  GPSData copyWith({
    String? description,
    DateTime? timestamp,
    int? precision,
    int? fix,
    double? latitude,
    double? longitude,
    double? altitude,
    double? speed2d,
    double? speed3d,
    String? units,
    int? npoints,
  }) {
    return GPSData(
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      precision: precision ?? this.precision,
      fix: fix ?? this.fix,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      speed2d: speed2d ?? this.speed2d,
      speed3d: speed3d ?? this.speed3d,
      units: units ?? this.units,
      npoints: npoints ?? this.npoints,
    );
  }

  @override
  String toString() =>
      'GPSData(lat: $latitude, lon: $longitude, alt: $altitude, '
      'time: $timestamp, fix: $fix, precision: $precision)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GPSData &&
          timestamp == other.timestamp &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          altitude == other.altitude;

  @override
  int get hashCode => Object.hash(timestamp, latitude, longitude, altitude);
}

/// GPS format type detected in GPMF stream
enum GPSFormat {
  /// GPS5: 5 int32 values (lat, lon, alt, speed2d, speed3d) with external timestamp
  gps5,

  /// GPS9: 9 values including embedded timestamp per sample
  gps9,

  /// Unknown or no GPS data found
  unknown,
}

/// A collection of GPS points from a single GPMF stream
class GPSTrack {
  /// Device identifier
  final String deviceId;

  /// Device name
  final String deviceName;

  /// GPS format used in this track
  final GPSFormat format;

  /// All GPS data points
  final List<GPSData> points;

  const GPSTrack({
    required this.deviceId,
    required this.deviceName,
    required this.format,
    required this.points,
  });

  /// Whether the track has any valid GPS points
  bool get hasData => points.isNotEmpty;

  /// Number of points with valid fix
  int get validPointCount => points.where((p) => p.hasValidFix).length;

  /// Filter to only points with valid GPS fix
  GPSTrack get validOnly => GPSTrack(
    deviceId: deviceId,
    deviceName: deviceName,
    format: format,
    points: points.where((p) => p.hasValidFix).toList(),
  );

  @override
  String toString() =>
      'GPSTrack(device: $deviceName, format: $format, points: ${points.length})';
}
