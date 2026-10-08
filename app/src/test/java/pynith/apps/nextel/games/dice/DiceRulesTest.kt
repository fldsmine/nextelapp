package pynith.apps.nextel.games.dice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DiceRulesTest {

    @Test
    fun acceptsOnlyPositiveStakesWithinBalance() {
        assertTrue(DiceRules.canRoll(100.0, 500_000.0))
        assertTrue(DiceRules.canRoll(500_000.0, 500_000.0))
        assertFalse(DiceRules.canRoll(0.0, 500_000.0))
        assertFalse(DiceRules.canRoll(-1.0, 500_000.0))
        assertFalse(DiceRules.canRoll(500_001.0, 500_000.0))
    }

    @Test
    fun matchingFaceAddsFiveTimesStakeAndLossDeductsStake() {
        val win = DiceRules.settle(500_000.0, 100.0, selectedDice = 3, rolledDice = 3)
        assertEquals(500_500.0, win.balance, 0.0)
        assertEquals(500.0, win.resultAmount, 0.0)
        assertTrue(win.isWin)

        val loss = DiceRules.settle(500_000.0, 100.0, selectedDice = 3, rolledDice = 5)
        assertEquals(499_900.0, loss.balance, 0.0)
        assertEquals(-100.0, loss.resultAmount, 0.0)
        assertFalse(loss.isWin)
    }

    @Test
    fun strategiesMatchSourceProgression() {
        assertEquals(140.0, DiceRules.nextBet(BetStrategyType.MANUAL, 100.0, 140.0, false), 0.0)
        assertEquals(100.0, DiceRules.nextBet(BetStrategyType.FIXED, 100.0, 140.0, false), 0.0)
        assertEquals(100.0, DiceRules.nextBet(BetStrategyType.MARTINGALE, 100.0, 400.0, true), 0.0)
        assertEquals(800.0, DiceRules.nextBet(BetStrategyType.MARTINGALE, 100.0, 400.0, false), 0.0)
    }
}
