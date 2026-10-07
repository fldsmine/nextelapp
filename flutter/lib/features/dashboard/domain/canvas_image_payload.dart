import 'dart:convert';
import 'dart:typed_data';

class CanvasImagePayload {
  CanvasImagePayload._(this.base64Data);

  static const int maxDecodedBytes = 16 * 1024 * 1024;
  static const List<int> _pngSignature = [
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
  ];

  /// A whitespace-free, validated PNG payload suitable for the native channel.
  final String base64Data;

  factory CanvasImagePayload.parse(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('No canvas image was provided.');
    }

    final input = value.trim();
    var encoded = input;
    if (input.toLowerCase().startsWith('data:')) {
      final comma = input.indexOf(',');
      if (comma < 0) {
        throw const FormatException('The canvas image data URI is invalid.');
      }
      final metadata = input.substring(5, comma).toLowerCase();
      if (!metadata.startsWith('image/png') ||
          !metadata.split(';').any((part) => part.trim() == 'base64')) {
        throw const FormatException('Only PNG canvas images are supported.');
      }
      encoded = input.substring(comma + 1);
    } else if (input.contains(',')) {
      throw const FormatException('The canvas image payload is invalid.');
    }

    final compact = encoded.replaceAll(RegExp(r'\s+'), '');
    final maxEncodedLength = ((maxDecodedBytes + 2) ~/ 3) * 4;
    if (compact.isEmpty || compact.length > maxEncodedLength) {
      throw const FormatException('The canvas image is empty or too large.');
    }

    final Uint8List bytes;
    try {
      bytes = base64Decode(compact);
    } on FormatException {
      throw const FormatException('The canvas image could not be decoded.');
    }
    if (bytes.length < _pngSignature.length || bytes.length > maxDecodedBytes) {
      throw const FormatException('The canvas image is empty or too large.');
    }
    for (var index = 0; index < _pngSignature.length; index++) {
      if (bytes[index] != _pngSignature[index]) {
        throw const FormatException('The canvas image is not a PNG.');
      }
    }
    return CanvasImagePayload._(base64Encode(bytes));
  }
}
