import 'package:flutter/material.dart';
import './glass_card.dart';

class BalanceCard extends StatelessWidget {
  final double balance;

  const BalanceCard({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
	return GlassCard(
	  padding: const EdgeInsets.only(left:30,top:2,right:30,bottom:2),
	  borderRadius: BorderRadius.circular(8),
	  color: Colors.black.withOpacity(0.2),
	  border: Border.all(color: Colors.white, width: 1),
      child: Column(
        children: [
          const Text("WALLET BALANCE",
              style: TextStyle(color: Colors.white54)),

          const SizedBox(height: 5),

          Text(
            "₦${balance.toStringAsFixed(2)}",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent,
            ),
          ),
        ],
      ),
    );
  }
}