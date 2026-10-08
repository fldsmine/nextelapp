import 'dart:convert';

class GameHistory {
  final int rolledDice;
  final int selectedDice;
  final double betAmount;
  final double resultAmount;
  final bool isWin;
  final DateTime timestamp;

  GameHistory({
    required this.rolledDice,
    required this.selectedDice,
    required this.betAmount,
    required this.resultAmount,
    required this.isWin,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'rolledDice': rolledDice,
      'selectedDice': selectedDice,
      'betAmount': betAmount,
      'resultAmount': resultAmount,
      'isWin': isWin,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory GameHistory.fromMap(Map<String, dynamic> map) {
    return GameHistory(
      rolledDice: map['rolledDice'],
      selectedDice: map['selectedDice'],
      betAmount: map['betAmount'],
      resultAmount: map['resultAmount'],
      isWin: map['isWin'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  static String encode(List<GameHistory> list) =>
      json.encode(list.map((e) => e.toMap()).toList());

  static List<GameHistory> decode(String data) =>
      (json.decode(data) as List)
          .map((e) => GameHistory.fromMap(e))
          .toList();
}