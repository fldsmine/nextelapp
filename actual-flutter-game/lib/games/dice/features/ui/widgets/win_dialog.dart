import 'package:flutter/material.dart';

class WinDialog extends StatelessWidget {
  final double amount;

  const WinDialog({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black87,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "🎉 YOU WIN!",
              style: TextStyle(fontSize: 22, color: Colors.greenAccent),
            ),
            const SizedBox(height: 10),
            Text(
              "₦${amount.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CONTINUE"),
            )
          ],
        ),
      ),
    );
  }
}