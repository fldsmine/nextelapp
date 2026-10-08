class GameState {
  final double balance;
  final int selectedDice;
  final int rolledDice;
  final double betAmount;
  final bool isRolling;
  final bool isFirstRoll;

  GameState({
    required this.balance,
    required this.selectedDice,
    required this.rolledDice,
    required this.betAmount,
    required this.isRolling,
    required this.isFirstRoll,
  });

  GameState copyWith({
    double? balance,
    int? selectedDice,
    int? rolledDice,
    double? betAmount,
    bool? isRolling,
    bool? isFirstRoll,
  }) {
    return GameState(
      balance: balance ?? this.balance,
      selectedDice: selectedDice ?? this.selectedDice,
      rolledDice: rolledDice ?? this.rolledDice,
      betAmount: betAmount ?? this.betAmount,
      isRolling: isRolling ?? this.isRolling,
      isFirstRoll: isFirstRoll ?? this.isFirstRoll,
    );
  }
}
