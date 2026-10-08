import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

class ConfettiWidgetCustom extends StatelessWidget {
  final ConfettiController controller;

  const ConfettiWidgetCustom({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: controller,
        blastDirectionality: BlastDirectionality.explosive,
        shouldLoop: false,
        emissionFrequency: 0.05,
        numberOfParticles: 30,
        gravity: 0.3,
      ),
    );
  }
}
