enum BetStrategyType {
  manual,
  martingale,
  fixed,
}

class BetStrategy {
  final BetStrategyType type;
  final double baseBet;
  final double multiplier;
  final int maxRounds;

  BetStrategy({
    required this.type,
    required this.baseBet,
    this.multiplier = 2.0,
    this.maxRounds = 10,
  });
}
