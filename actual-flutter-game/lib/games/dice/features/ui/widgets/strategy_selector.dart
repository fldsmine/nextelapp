import 'package:flutter/material.dart';
import '../../data/bet_strategy.dart';

class StrategySelector extends StatelessWidget {
  final BetStrategy strategy;
  final Function(BetStrategy) onChanged;

  const StrategySelector({
    super.key,
    required this.strategy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<BetStrategyType>(
      value: strategy.type,
      dropdownColor: Colors.black,
      items: const [
        DropdownMenuItem(
          value: BetStrategyType.manual,
          child: Text("Manual"),
        ),
        DropdownMenuItem(
          value: BetStrategyType.martingale,
          child: Text("Martingale"),
        ),
        DropdownMenuItem(
          value: BetStrategyType.fixed,
          child: Text("Fixed"),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          onChanged(
            BetStrategy(
              type: value,
              baseBet: strategy.baseBet,
              multiplier: strategy.multiplier,
              maxRounds: strategy.maxRounds,
            ),
          );
        }
      },
    );
  }
}