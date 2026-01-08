import 'dart:typed_data';
import '../models/klv_types.dart';

/// Parser for GPMF KLV (Key-Length-Value) binary format.
///
/// GPMF uses an 8-byte header structure:
/// - Bytes 0-3: FourCC key (e.g., "GPS5", "DEVC")
/// - Byte 4: Type character (e.g., 'l' for int32)
/// - Byte 5: Element size in bytes
/// - Bytes 6-7: Repeat count (big-endian uint16)
///
/// All payloads are 4-byte aligned.
class KlvParser {
  final Uint8List _data;
  int _offset = 0;

  KlvParser(this._data);

  /// Current read position
  int get offset => _offset;

  /// Remaining bytes to read
  int get remaining => _data.length - _offset;

  /// Whether there's more data to parse
  bool get hasMore => remaining >= 8;

  /// Reset parser to beginning
  void reset() => _offset = 0;

  /// Parse the next KLV item from the stream.
  /// Returns null if insufficient data remains.
  KLVItem? parseNext() {
    if (remaining < 8) return null;

    // Read 8-byte header
    final fourcc = Uint8List.sublistView(_data, _offset, _offset + 4);
    final key = String.fromCharCodes(fourcc);

    final typeChar = String.fromCharCode(_data[_offset + 4]);
    final size = _data[_offset + 5];

    // Repeat is big-endian uint16
    final repeat = (_data[_offset + 6] << 8) | _data[_offset + 7];

    final length = KLVLength(type: typeChar, size: size, repeat: repeat);

    _offset += 8;

    // Calculate aligned payload size
    final payloadSize = ceil4(length.rawSize);

    // Extract payload (may be less than remaining if truncated)
    final availablePayload = remaining.clamp(0, payloadSize);
    final value = availablePayload > 0
        ? Uint8List.sublistView(_data, _offset, _offset + availablePayload)
        : Uint8List(0);

    _offset += payloadSize;

    return KLVItem(key: key, length: length, value: value, fourcc: fourcc);
  }

  /// Parse all KLV items from current position to end.
  List<KLVItem> parseAll() {
    final items = <KLVItem>[];
    while (hasMore) {
      final item = parseNext();
      if (item == null) break;
      items.add(item);
    }
    return items;
  }

  /// Parse nested KLV items within a container (DEVC, STRM).
  static List<KLVItem> parseNested(Uint8List data) {
    return KlvParser(data).parseAll();
  }

  /// Recursively parse GPMF data into a nested structure.
  /// Returns a map where keys are FourCC codes and values are either
  /// raw KLVItems or lists of nested maps for containers.
  static Map<String, dynamic> parseToMap(Uint8List data) {
    final result = <String, dynamic>{};
    final parser = KlvParser(data);

    while (parser.hasMore) {
      final item = parser.parseNext();
      if (item == null) break;

      if (item.isContainer && item.value.isNotEmpty) {
        // Recursively parse nested container
        final nested = parseToMap(item.value);
        // Handle multiple items with same key (e.g., multiple STRM)
        if (result.containsKey(item.key)) {
          final existing = result[item.key];
          if (existing is List) {
            existing.add(nested);
          } else {
            result[item.key] = [existing, nested];
          }
        } else {
          result[item.key] = nested;
        }
      } else {
        // Store raw item
        if (result.containsKey(item.key)) {
          final existing = result[item.key];
          if (existing is List) {
            existing.add(item);
          } else {
            result[item.key] = [existing, item];
          }
        } else {
          result[item.key] = item;
        }
      }
    }

    return result;
  }
}

/// Extension methods for reading typed values from KLVItem payloads.
extension KLVItemReader on KLVItem {
  /// Get a ByteData view of the payload for typed reads.
  ByteData get byteData => ByteData.sublistView(value);

  /// Read payload as array of int32 values (big-endian).
  List<int> readInt32Array() {
    final count = length.rawSize ~/ 4;
    final bd = byteData;
    return List.generate(count, (i) => bd.getInt32(i * 4, Endian.big));
  }

  /// Read payload as array of uint32 values (big-endian).
  List<int> readUint32Array() {
    final count = length.rawSize ~/ 4;
    final bd = byteData;
    return List.generate(count, (i) => bd.getUint32(i * 4, Endian.big));
  }

  /// Read payload as array of int16 values (big-endian).
  List<int> readInt16Array() {
    final count = length.rawSize ~/ 2;
    final bd = byteData;
    return List.generate(count, (i) => bd.getInt16(i * 2, Endian.big));
  }

  /// Read payload as array of uint16 values (big-endian).
  List<int> readUint16Array() {
    final count = length.rawSize ~/ 2;
    final bd = byteData;
    return List.generate(count, (i) => bd.getUint16(i * 2, Endian.big));
  }

  /// Read payload as array of float32 values (big-endian).
  List<double> readFloat32Array() {
    final count = length.rawSize ~/ 4;
    final bd = byteData;
    return List.generate(count, (i) => bd.getFloat32(i * 4, Endian.big));
  }

  /// Read payload as array of float64 values (big-endian).
  List<double> readFloat64Array() {
    final count = length.rawSize ~/ 8;
    final bd = byteData;
    return List.generate(count, (i) => bd.getFloat64(i * 8, Endian.big));
  }

  /// Read payload as ASCII string.
  String readString() {
    // Trim null bytes and whitespace
    var end = value.length;
    while (end > 0 && (value[end - 1] == 0 || value[end - 1] == 32)) {
      end--;
    }
    return String.fromCharCodes(value.sublist(0, end));
  }

  /// Read single int32 value.
  int readInt32() => byteData.getInt32(0, Endian.big);

  /// Read single uint32 value.
  int readUint32() => byteData.getUint32(0, Endian.big);

  /// Read single uint16 value.
  int readUint16() => byteData.getUint16(0, Endian.big);
}
