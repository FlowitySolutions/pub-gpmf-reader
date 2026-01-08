/// Pure Dart library for parsing GoPro GPMF telemetry and converting to GPX.
///
/// This library parses GoPro's GPMF (GoPro Metadata Format) binary telemetry
/// data and converts GPS coordinates to standard GPX format.
///
/// Example usage:
/// ```dart
/// import 'package:dart_gpmf/dart_gpmf.dart';
///
/// final gpmfBytes = await getGpmfDataFromGoPro(); // Your GoPro integration
/// final track = GpmfParser.parse(gpmfBytes);
/// final gpxString = GpxBuilder.build(track);
/// ```
library dart_gpmf;

// Models
export 'src/models/klv_types.dart';
export 'src/models/gps_data.dart';

// Core parsing
export 'src/core/klv_parser.dart';
export 'src/core/gpmf_decoder.dart';

// GPX output
export 'src/gpx/gpx_builder.dart';

// High-level API
export 'src/gpmf_parser.dart';
