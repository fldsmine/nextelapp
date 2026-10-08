import 'dart:convert';

class GameHistory {
  const GameHistory({
    required this.rolledDice,
    required this.selectedDice,
    required this.betAmount,
    required this.resultAmount,
    required this.isWin,
    required this.timestamp,
  });

  final int rolledDice;
  final int selectedDice;
  final double betAmount;
  final double resultAmount;
  final bool isWin;
  final DateTime timestamp;

  Map<String, dynamic> toMap() => {
        'rolledDice': rolledDice,
        'selectedDice': selectedDice,
        'betAmount': betAmount,
        'resultAmount': resultAmount,
        'isWin': isWin,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Accepts the uploaded Flutter schema and the older Android JSON keys so
  /// histories copied by LegacyDataMigrator remain visible in Dice.
  factory GameHistory.fromMap(Map<String, dynamic> map) => GameHistory(
        rolledDice: _asInt(map['rolledDice'] ?? map['rolled']),
        selectedDice: _asInt(map['selectedDice'] ?? map['selected']),
        betAmount: _asDouble(map['betAmount'] ?? map['bet']),
        resultAmount: _asDouble(map['resultAmount'] ?? map['result']),
        isWin: _asBool(map['isWin'] ?? map['win']),
        timestamp: _asDateTime(map['timestamp'] ?? map['at']),
      );

  static String encode(List<GameHistory> list) =>
      jsonEncode(list.map((entry) => entry.toMap()).toList());

  static List<GameHistory> decode(String data) {
    final decoded = jsonDecode(data);
    if (decoded is! List) {
      throw const FormatException('Dice history must be a JSON list.');
    }
    return decoded
        .whereType<Map>()
        .map((entry) => GameHistory.fromMap(
              entry.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .toList();
  }

  static int _asInt(Object? value) => switch (value) {
        int number => number,
        num number => number.toInt(),
        String text => int.tryParse(text) ?? 0,
        _ => 0,
      };

  static double _asDouble(Object? value) => switch (value) {
        num number => number.toDouble(),
        String text => double.tryParse(text) ?? 0,
        _ => 0,
      };

  static bool _asBool(Object? value) => switch (value) {
        bool boolean => boolean,
        num number => number != 0,
        String text => text.toLowerCase() == 'true' || text == '1',
        _ => false,
      };

  static DateTime _asDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      final numeric = int.tryParse(value);
      if (numeric != null) {
        return DateTime.fromMillisecondsSinceEpoch(numeric);
      }
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
