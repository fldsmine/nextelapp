package pynith.apps.nextel.games.dice

/** Result of settling one bet according to the original Flutter Dice rules. */
data class DiceSettlement(
    val balance: Double,
    val resultAmount: Double,
    val isWin: Boolean
)

/** Pure rules shared by the Dice controller and local JVM tests. */
object DiceRules {

    /** The Flutter controller accepted any positive stake up to the full balance. */
    fun canRoll(betAmount: Double, balance: Double): Boolean =
        betAmount > 0.0 && betAmount <= balance

    /** A matching face adds 5× the stake without first deducting the stake. */
    fun settle(balance: Double, betAmount: Double, selectedDice: Int, rolledDice: Int): DiceSettlement {
        require(selectedDice in 1..6) { "Selected die must be between 1 and 6." }
        require(rolledDice in 1..6) { "Rolled die must be between 1 and 6." }

        return if (rolledDice == selectedDice) {
            val winnings = betAmount * WIN_MULTIPLIER
            DiceSettlement(balance + winnings, winnings, true)
        } else {
            DiceSettlement(balance - betAmount, -betAmount, false)
        }
    }

    fun nextBet(
        strategy: BetStrategyType,
        baseBet: Double,
        currentBet: Double,
        isWin: Boolean,
        multiplier: Double = DEFAULT_MULTIPLIER
    ): Double = when (strategy) {
        BetStrategyType.MANUAL -> currentBet
        BetStrategyType.FIXED -> baseBet
        BetStrategyType.MARTINGALE -> if (isWin) baseBet else currentBet * multiplier
    }

    const val WIN_MULTIPLIER = 5.0
    const val DEFAULT_MULTIPLIER = 2.0
}
