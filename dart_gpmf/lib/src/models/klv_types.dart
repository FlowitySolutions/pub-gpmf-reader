import 'dart:typed_data';

/// Type conversion map for GPMF binary types.
/// Maps single-character type codes to Dart type information.
class TypeConversion {
  final String dartType;
  final int byteSize;

  const TypeConversion(this.dartType, this.byteSize);

  /// GPMF type conversion table
  /// Maps GPMF type characters to (Dart type name, byte size)
  static const Map<String, TypeConversion> typeConv = {
    'd': TypeConversion('float64', 8), // 8-byte double
    'f': TypeConversion('float32', 4), // 4-byte float
    'b': TypeConversion('int8', 1), // signed byte
    'B': TypeConversion('uint8', 1), // unsigned byte
    's': TypeConversion('int16', 2), // 2-byte signed
    'S': TypeConversion('uint16', 2), // 2-byte unsigned
    'l': TypeConversion('int32', 4), // 4-byte signed
    'L': TypeConversion('uint32', 4), // 4-byte unsigned
    'j': TypeConversion('int64', 8), // 8-byte signed
    'J': TypeConversion('uint64', 8), // 8-byte unsigned
    'c': TypeConversion('char', 1), // ASCII character
    'U': TypeConversion('utc', 16), // UTC date/time string
    '?': TypeConversion('complex', 4), // Complex/nested structure
    '\x00': TypeConversion('nested', 0), // Nested container (DEVC, STRM)
  };

  /// Get conversion info for a type character, returns null if unknown
  static TypeConversion? forType(String typeChar) => typeConv[typeChar];
}

/// Represents the length/type information in a KLV header.
/// Contains type character, element size, and repeat count.
class KLVLength {
  /// Single character type code ('d', 'f', 'l', etc.)
  final String type;

  /// Size of each element in bytes
  final int size;

  /// Number of elements (repeat count)
  final int repeat;

  const KLVLength({
    required this.type,
    required this.size,
    required this.repeat,
  });

  /// Total payload size (before 4-byte alignment)
  int get rawSize => size * repeat;

  /// Whether this is a nested container type (null type byte)
  bool get isNested => type == '\x00' || type.isEmpty;

  @override
  String toString() => 'KLVLength(type: "$type", size: $size, repeat: $repeat)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KLVLength &&
          type == other.type &&
          size == other.size &&
          repeat == other.repeat;

  @override
  int get hashCode => Object.hash(type, size, repeat);
}

/// Represents a single KLV (Key-Length-Value) item from GPMF data.
class KLVItem {
  /// FourCC code (e.g., "GPS5", "SCAL", "DEVC")
  final String key;

  /// Length/type information
  final KLVLength length;

  /// Raw binary payload
  final Uint8List value;

  /// Original 4-byte FourCC as bytes
  final Uint8List fourcc;

  const KLVItem({
    required this.key,
    required this.length,
    required this.value,
    required this.fourcc,
  });

  /// Whether this is a nested container (DEVC, STRM, etc.)
  bool get isContainer => length.isNested;

  /// Payload size after 4-byte alignment
  int get alignedSize => ceil4(length.rawSize);

  /// Total item size including 8-byte header
  int get totalSize => 8 + alignedSize;

  @override
  String toString() =>
      'KLVItem(key: "$key", length: $length, valueSize: ${value.length})';
}

/// Find the closest greater or equal multiple of 4.
/// Critical for GPMF binary parsing as all payloads are 4-byte aligned.
int ceil4(int x) {
  if (x <= 0) return 0;
  return (((x - 1) >> 2) + 1) << 2;
}
