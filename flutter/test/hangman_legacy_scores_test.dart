import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/games/utilities/score_db.dart';

void main() {
  group('Legacy Hangman score migration', () {
    test('maps native score/date records into the source SQLite columns', () {
      final rows = decodeLegacyHangmanScores(
        '[{"score":12,"date":"2026-10-08 12:30:00"},'
        '{"score":4,"date":"2026-10-07 09:00:00"}]',
      );

      expect(rows, hasLength(2));
      expect(rows.first, {
        'scoreDate': '2026-10-08 12:30:00',
        'userScore': 12,
      });
      expect(rows.last['userScore'], 4);
    });

    test('also accepts the source SQLite-style field names and IDs', () {
      final rows = decodeLegacyHangmanScores(
        '[{"id":9,"userScore":21,"scoreDate":"2026-10-08"}]',
      );

      expect(rows, [
        {'id': 9, 'scoreDate': '2026-10-08', 'userScore': 21},
      ]);
    });

    test('rejects a non-list score payload', () {
      expect(
        () => decodeLegacyHangmanScores('{"score":2}'),
        throwsFormatException,
      );
    });
  });
}
