import 'package:flutter/material.dart';
import '../../logic/game_controller.dart';

class HistoryPanel extends StatelessWidget {
  final List history;

  const HistoryPanel({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: history.isEmpty
          ? const Center(child: Text("No history yet"))
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];

                return Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: item.isWin
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/dice_${item.rolledDice}.png',
                        height: 20,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "₦${item.betAmount}",
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.isWin ? "WIN" : "LOSE",
                        style: TextStyle(
                          color: item.isWin
                              ? Colors.greenAccent
                              : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}