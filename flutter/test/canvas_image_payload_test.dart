import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/features/dashboard/domain/canvas_image_payload.dart';

void main() {
  const onePixelPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j5WQAAAAASUVORK5CYII=';

  test('accepts plain PNG base64 and data URIs', () {
    final plain = CanvasImagePayload.parse(onePixelPng);
    final dataUri = CanvasImagePayload.parse('data:image/png;base64,$onePixelPng');

    expect(base64Decode(plain.base64Data).take(8), [
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ]);
    expect(dataUri.base64Data, onePixelPng);
  });

  test('rejects non-PNG, malformed, and empty payloads', () {
    expect(() => CanvasImagePayload.parse(''), throwsFormatException);
    expect(() => CanvasImagePayload.parse('not base64'), throwsFormatException);
    expect(
      () => CanvasImagePayload.parse('data:image/jpeg;base64,$onePixelPng'),
      throwsFormatException,
    );
    expect(
      () => CanvasImagePayload.parse(base64Encode([1, 2, 3, 4, 5, 6, 7, 8])),
      throwsFormatException,
    );
  });
}
