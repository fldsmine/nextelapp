package pynith.apps.nextel.games.ludo

import kotlin.random.Random

/** Player types in turn order (matches the Flutter module). */
enum class LudoPlayerType(val label: String, val color: Int) {
    GREEN("Green", 0xFF1AAA30.toInt()),
    YELLOW("Yellow", 0xFFFFCD1D.toInt()),
    BLUE("Blue", 0xFF4A5FD1.toInt()),
    RED("Red", 0xFFF84700.toInt());

    fun next(): LudoPlayerType = entries[(ordinal + 1) % entries.size]
}

/** Game stages (matches LudoGameState in the Flutter module). */
enum class LudoGameState { THROW_DICE, PICK_PAWN, MOVING, FINISH }

/** What happened when a pawn move was applied. */
data class LudoMoveResult(
    /** Steps the pawn passes through (excluding its start), for animation. */
    val pathSteps: List<Int>,
    val landingStep: Int,
    /** (type, pawnIndex) pairs captured by this move. */
    val captures: List<Pair<LudoPlayerType, Int>>,
    val extraTurn: Boolean
)

/**
 * Rules engine for the module's Ludo: 4 players take turns on one device
 * (pass-and-play, no computer opponents — as in the Flutter original).
 *
 * Rule set (ported from ludo_provider.dart):
 *  - the source roll expression returns 6 on the boolean branch, and again
 *    when the fallback 1..6 roll is 6 (so 6 occurs 7/12 of the time);
 *  - a 6 is required to move a yard pawn; the source's tapped-pawn and
 *    automatic-move paths both release a yard pawn onto step zero, while its
 *    single-legal-pawn auto-move retains the source's longer yard path;
 *  - pawns must land on the final cell (step 56) exactly;
 *  - landing on a non-safe cell sends EVERY opponent pawn standing there
 *    back to its yard (no blocking pairs) and grants another throw;
 *  - the first three players to bring all four pawns home win; the game
 *    ends when the third player finishes.
 */
class LudoGame(
    private val rollSource: () -> Int = {
        if (Random.nextBoolean()) 6 else Random.nextInt(1, 7)
    }
) {

    /** Pawn steps per player: -1 = yard, 0..56 = path index. */
    val steps = Array(LudoPlayerType.entries.size) { IntArray(4) { -1 } }

    var currentTurn: LudoPlayerType = LudoPlayerType.GREEN
        private set
    var gameState: LudoGameState = LudoGameState.THROW_DICE
        private set
    var diceResult: Int = 1
        private set
    val winners = mutableListOf<LudoPlayerType>()

    val isFinished: Boolean
        get() = gameState == LudoGameState.FINISH

    fun step(type: LudoPlayerType, pawnIndex: Int): Int = steps[type.ordinal][pawnIndex]

    fun hasFinished(type: LudoPlayerType): Boolean =
        steps[type.ordinal].all { it == FINAL_STEP }

    fun homeCount(type: LudoPlayerType): Int =
        steps[type.ordinal].count { it == FINAL_STEP }

    /** Uses the Flutter expression: `nextBool() ? 6 : nextInt(6) + 1`. */
    fun rollDice(): Int {
        diceResult = rollSource().coerceIn(1, 6)
        return diceResult
    }

    /**
     * Pawns the current roll lets [type] move:
     * a yard pawn needs a 6; a board pawn must not overshoot the final cell.
     */
    fun movablePawns(type: LudoPlayerType, roll: Int): List<Int> {
        val result = mutableListOf<Int>()
        for (pawn in 0 until 4) {
            val step = steps[type.ordinal][pawn]
            val canMove = if (step == -1) {
                roll == 6
            } else {
                step + roll <= FINAL_STEP
            }
            if (canMove) result += pawn
        }
        return result
    }

    /** Shared-ring cell a pawn currently occupies, or null (yard/home column). */
    fun ringCell(type: LudoPlayerType, pawnIndex: Int): Long? {
        val step = steps[type.ordinal][pawnIndex]
        if (step < 0 || step > 50) return null
        val cell = LudoBoard.path(type)[step]
        return LudoBoard.cell(cell[0], cell[1])
    }

    /** Opponent pawns standing on the ring cell a pawn would land on. */
    private fun opponentsAtLanding(
        mover: LudoPlayerType,
        landingStep: Int
    ): List<Pair<LudoPlayerType, Int>> {
        val landing = LudoBoard.path(mover)[landingStep]
        val landingKey = LudoBoard.cell(landing[0], landing[1])
        val result = mutableListOf<Pair<LudoPlayerType, Int>>()
        for (type in LudoPlayerType.entries) {
            if (type == mover) continue
            for (pawn in 0 until 4) {
                if (ringCell(type, pawn) == landingKey) result += type to pawn
            }
        }
        return result
    }

    /**
     * Applies a move for [type]'s pawn and reports captures / turn effects.
     *
     * In the source UI, manually tapped yard pawns and the same-step automatic
     * selection use `move(..., 1)`, so they enter at step zero. The separate
     * single-legal-pawn auto-move passes `(step + 1) + roll`; because yard is
     * represented by -1, that source path advances to `roll - 1`. Keep that
     * edge case when [singlePawnAutoMove] is true rather than silently
     * normalizing the original game's behavior.
     */
    fun applyMove(
        type: LudoPlayerType,
        pawnIndex: Int,
        roll: Int,
        singlePawnAutoMove: Boolean = false
    ): LudoMoveResult {
        require(gameState == LudoGameState.PICK_PAWN || gameState == LudoGameState.MOVING) {
            "Cannot move in state $gameState"
        }
        require(pawnIndex in 0 until 4) { "Pawn index out of range." }
        require(roll in 1..6) { "Dice roll must be between 1 and 6." }

        val fromStep = steps[type.ordinal][pawnIndex]
        require(fromStep >= 0 || roll == 6) { "A yard pawn needs a six to move." }
        val landingStep = if (fromStep == -1 && !singlePawnAutoMove) {
            0
        } else {
            fromStep + roll
        }
        require(landingStep <= FINAL_STEP) { "Move would overshoot the finish." }

        val pathSteps = (fromStep + 1..landingStep).toList()

        gameState = LudoGameState.MOVING
        steps[type.ordinal][pawnIndex] = landingStep

        // Capture: every opponent on the landing ring cell (unless it is safe).
        val captures = mutableListOf<Pair<LudoPlayerType, Int>>()
        if (landingStep <= 50) {
            val landing = LudoBoard.path(type)[landingStep]
            val landingKey = LudoBoard.cell(landing[0], landing[1])
            if (landingKey !in LudoBoard.safeCells) {
                for ((capturedType, capturedPawn) in opponentsAtLanding(type, landingStep)) {
                    steps[capturedType.ordinal][capturedPawn] = -1
                    captures += capturedType to capturedPawn
                }
            }
        }

        if (hasFinished(type) && type !in winners) {
            winners += type
        }
        if (winners.size == 3) {
            gameState = LudoGameState.FINISH
        }

        val extraTurn = gameState != LudoGameState.FINISH && (captures.isNotEmpty() || roll == 6)

        return LudoMoveResult(pathSteps, landingStep, captures, extraTurn)
    }

    /** Passes the turn to the next player that has not already won. */
    fun passTurn() {
        if (gameState == LudoGameState.FINISH) return
        var next = currentTurn.next()
        while (next in winners) {
            next = next.next()
        }
        currentTurn = next
        gameState = LudoGameState.THROW_DICE
    }

    /** Keeps the turn with the current player (after a 6 or a capture). */
    fun keepTurn() {
        if (gameState == LudoGameState.FINISH) return
        gameState = LudoGameState.THROW_DICE
    }

    fun awaitPick() {
        check(gameState != LudoGameState.FINISH) { "Game is over" }
        gameState = LudoGameState.PICK_PAWN
    }

    fun reset() {
        for (player in steps.indices) {
            steps[player].fill(-1)
        }
        winners.clear()
        currentTurn = LudoPlayerType.GREEN
        diceResult = 1
        gameState = LudoGameState.THROW_DICE
    }

    companion object {
        const val FINAL_STEP = 56
    }
}
