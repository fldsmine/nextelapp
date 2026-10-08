import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/games/dice/features/data/game_history.dart';

void main() {
  group('Dice history persistence', () {
    test('round-trips the uploaded Flutter record format', () {
      final timestamp = DateTime.utc(2026, 10, 8, 9, 15);
      final history = GameHistory(
        rolledDice: 5,
        selectedDice: 5,
        betAmount: 200,
        resultAmount: 1000,
        isWin: true,
        timestamp: timestamp,
      );

      final decoded = GameHistory.decode(GameHistory.encode([history]));

      expect(decoded, hasLength(1));
      expect(decoded.single.rolledDice, 5);
      expect(decoded.single.selectedDice, 5);
      expect(decoded.single.betAmount, 200);
      expect(decoded.single.resultAmount, 1000);
      expect(decoded.single.isWin, isTrue);
      expect(decoded.single.timestamp, timestamp);
    });

    test('reads the legacy native Dice preference keys', () {
      final decoded = GameHistory.decode(
        '[{"rolled":6,"selected":2,"bet":50,"result":-50,'
        '"win":false,"at":1791450900000}]',
      );

      expect(decoded, hasLength(1));
      expect(decoded.single.rolledDice, 6);
      expect(decoded.single.selectedDice, 2);
      expect(decoded.single.betAmount, 50);
      expect(decoded.single.resultAmount, -50);
      expect(decoded.single.isWin, isFalse);
      expect(
        decoded.single.timestamp,
        DateTime.fromMillisecondsSinceEpoch(1791450900000),
      );
    });

    test('rejects a non-list payload instead of losing it silently', () {
      expect(() => GameHistory.decode('{"rolled":1}'), throwsFormatException);
    });
  });
}
