package pynith.apps.nextel.games.ludo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LudoGameTest {

    @Test
    fun diceRollUsesInjectedSourceAndBoundsIt() {
        assertEquals(6, LudoGame { 6 }.rollDice())
        assertEquals(1, LudoGame { 0 }.rollDice())
        assertEquals(6, LudoGame { 9 }.rollDice())
    }

    @Test
    fun yardPawnsNeedSixAndAllAreMovableOnSix() {
        val game = LudoGame { 6 }

        assertTrue(game.movablePawns(LudoPlayerType.GREEN, 1).isEmpty())
        assertEquals(listOf(0, 1, 2, 3), game.movablePawns(LudoPlayerType.GREEN, 6))
    }

    @Test
    fun tappingYardPawnAndSourceSinglePawnAutoMoveKeepTheirDistinctPaths() {
        val tapped = LudoGame { 6 }
        tapped.rollDice()
        tapped.awaitPick()
        val tappedMove = tapped.applyMove(LudoPlayerType.GREEN, 1, 6)

        assertEquals(0, tappedMove.landingStep)
        assertEquals(listOf(0), tappedMove.pathSteps)

        val singleAuto = LudoGame { 6 }
        singleAuto.rollDice()
        singleAuto.awaitPick()
        val automaticMove = singleAuto.applyMove(
            LudoPlayerType.GREEN,
            1,
            6,
            singlePawnAutoMove = true
        )

        // The original provider's one-legal-pawn auto path advances to roll - 1.
        assertEquals(5, automaticMove.landingStep)
        assertEquals(listOf(0, 1, 2, 3, 4, 5), automaticMove.pathSteps)
    }

    @Test
    fun pawnsMustReachTheFinalCellExactly() {
        val game = LudoGame { 2 }
        game.steps[LudoPlayerType.RED.ordinal][0] = 54

        assertTrue(game.movablePawns(LudoPlayerType.RED, 2).contains(0))
        assertFalse(game.movablePawns(LudoPlayerType.RED, 3).contains(0))

        game.awaitPick()
        val result = game.applyMove(LudoPlayerType.RED, 0, 2)

        assertEquals(LudoGame.FINAL_STEP, result.landingStep)
        assertTrue(game.hasFinished(LudoPlayerType.RED).not())
    }

    @Test
    fun capturesOpponentsOnUnsafeCellsButNotOnSafeStartCells() {
        val capture = LudoGame { 1 }
        capture.steps[LudoPlayerType.GREEN.ordinal][0] = 0 // (2, 6), not safe
        capture.steps[LudoPlayerType.RED.ordinal][0] = 14 // (2, 6)
        capture.awaitPick()

        val captured = capture.applyMove(LudoPlayerType.GREEN, 0, 1)

        assertEquals(listOf(LudoPlayerType.RED to 0), captured.captures)
        assertEquals(-1, capture.step(LudoPlayerType.RED, 0))
        assertTrue(captured.extraTurn)

        val safe = LudoGame { 6 }
        safe.steps[LudoPlayerType.RED.ordinal][0] = 13 // (1, 6), a safe cell
        safe.awaitPick()

        val safeLanding = safe.applyMove(LudoPlayerType.GREEN, 0, 6)

        assertEquals(0, safeLanding.landingStep)
        assertTrue(safeLanding.captures.isEmpty())
        assertEquals(13, safe.step(LudoPlayerType.RED, 0))
    }

    @Test
    fun reachingFinalSquareRegistersThirdWinnerAndFinishes() {
        val game = LudoGame { 1 }
        game.winners.addAll(listOf(LudoPlayerType.GREEN, LudoPlayerType.YELLOW))
        game.steps[LudoPlayerType.BLUE.ordinal].fill(LudoGame.FINAL_STEP)
        game.steps[LudoPlayerType.BLUE.ordinal][3] = LudoGame.FINAL_STEP - 1
        game.awaitPick()

        val result = game.applyMove(LudoPlayerType.BLUE, 3, 1)

        assertEquals(LudoGame.FINAL_STEP, result.landingStep)
        assertTrue(game.isFinished)
        assertEquals(listOf(LudoPlayerType.GREEN, LudoPlayerType.YELLOW, LudoPlayerType.BLUE), game.winners)
        assertFalse(result.extraTurn)
    }

    @Test
    fun passTurnSkipsAlreadyFinishedPlayers() {
        val game = LudoGame()
        game.winners.addAll(listOf(LudoPlayerType.YELLOW, LudoPlayerType.BLUE))

        game.passTurn()

        assertEquals(LudoPlayerType.RED, game.currentTurn)
        assertEquals(LudoGameState.THROW_DICE, game.gameState)
    }
}
