import 'package:flutter/material.dart';

class StatsDashboard extends StatelessWidget {
  final List history;

  const StatsDashboard({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    int wins = history.where((e) => e.isWin).length;
    int losses = history.length - wins;

    double profit = history.fold(
      0,
      (sum, e) => sum + e.resultAmount,
    );

    double winRate =
        history.isEmpty ? 0 : (wins / history.length) * 100;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _stat("Win %", "${winRate.toStringAsFixed(1)}%"),
        _stat("Profit", "₦${profit.toStringAsFixed(0)}"),
        _stat("W/L", "$wins/$losses"),
      ],
    );
  }

  Widget _stat(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white54)),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
