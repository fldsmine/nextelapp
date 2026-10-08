import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/features/about/domain/about_content.dart';

void main() {
  group('About and FAQ content', () {
    test('preserves all six native FAQ entries', () {
      expect(AboutContent.faqs, hasLength(6));
      for (final entry in AboutContent.faqs) {
        expect(entry.question, isNotEmpty);
        expect(entry.answer, isNotEmpty);
      }
    });

    test('support link is an HTTPS Telegram endpoint', () {
      final uri = Uri.parse(AboutContent.supportLink);

      expect(uri.scheme, 'https');
      expect(uri.host, 't.me');
      expect(uri.path, '/nextelconnect_support01');
    });

    test('about information includes the expected brand and highlights', () {
      expect(AboutContent.tagline, 'Next-Gen Memecoin App');
      expect(AboutContent.description, contains('Nextel Connect'));
      expect(AboutContent.highlights, hasLength(4));
    });
  });
}
