import 'package:flutter/material.dart';

class BetInput extends StatelessWidget {
  final Function(String) onChanged;

  const BetInput({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      decoration: const InputDecoration(
        hintText: "Enter Bet Amount",
        filled: true,
      ),
    );
  }
}
