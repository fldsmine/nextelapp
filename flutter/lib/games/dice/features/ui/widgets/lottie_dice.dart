import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieDice extends StatelessWidget {
  final bool isRolling;
  final bool isFirstRoll;
  final int finalValue;

  const LottieDice({
    super.key,
    required this.isRolling,
    required this.finalValue,
    required this.isFirstRoll,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
	  transitionBuilder: (child, animation) =>
		FadeTransition(opacity: animation, child: child),
      child: _buildChild(),
    );
  }

  Widget _buildChild() {
    // 1. First state (before any roll)
    if (isFirstRoll) {
      return Image.asset(
        'assets/images/dice/draw.gif',
        key: const ValueKey("first_roll"),
        height: 140,
      );
    }

    // 2. Rolling state
    if (isRolling) {
      return Lottie.asset(
        'assets/lottie/dice_roll.json',
        key: const ValueKey("rolling"),
        height: 140,
      );
    }

    // 3. Final dice face
    return Image.asset(
      'assets/images/dice_$finalValue.png',
      key: ValueKey(finalValue),
      height: 140,
    );
  }
}
