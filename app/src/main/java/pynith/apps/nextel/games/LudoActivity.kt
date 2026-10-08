package pynith.apps.nextel.games

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.TextView
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import pynith.apps.nextel.R
import pynith.apps.nextel.games.ludo.LudoBoardView
import pynith.apps.nextel.games.ludo.LudoGame
import pynith.apps.nextel.games.ludo.LudoGameState
import pynith.apps.nextel.games.widget.DiceView
import pynith.apps.nextel.views.BaseActivity
import kotlin.random.Random

/**
 * The Flutter module's Ludo: four players share one device (green starts,
 * then yellow, blue, red). Each player taps the dice on their turn and then
 * taps one of their highlighted pawns. The game ends when three players have
 * brought every pawn home.
 */
class LudoActivity : BaseActivity() {

    private val handler = Handler(Looper.getMainLooper())

    private lateinit var game: LudoGame
    private lateinit var boardView: LudoBoardView
    private lateinit var diceView: DiceView
    private lateinit var statusText: TextView

    private var busy = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_ludo)

        findViewById<MaterialToolbar>(R.id.ludoToolbar).apply {
            setNavigationOnClickListener { confirmExit() }
            inflateMenu(R.menu.menu_ludo)
            setOnMenuItemClickListener { item ->
                when (item.itemId) {
                    R.id.action_restart -> {
                        confirmRestart()
                        true
                    }
                    else -> false
                }
            }
        }

        boardView = findViewById(R.id.boardView)
        diceView = findViewById(R.id.diceView)
        statusText = findViewById(R.id.statusText)

        boardView.onPawnPicked = { pawnIndex -> pickPawn(pawnIndex) }
        diceView.setOnClickListener { throwDice() }

        newGame()
    }

    private fun newGame() {
        handler.removeCallbacksAndMessages(null)
        game = LudoGame()
        busy = false
        diceView.accentColor = game.currentTurn.color
        diceView.highlight = true
        updateBoard()
        setStatus("Green starts — tap the dice to roll.")
    }

    private fun updateBoard(highlight: Set<Int> = emptySet()) {
        boardView.setState(game, highlight)
    }

    private fun setStatus(message: String) {
        statusText.text = message
    }

    // ------------------------------------------------------------------
    // Turn flow
    // ------------------------------------------------------------------

    private fun throwDice() {
        if (busy || game.isFinished) return
        if (game.gameState != LudoGameState.THROW_DICE) return

        busy = true
        SoundFx.diceRoll()
        diceView.highlight = false

        // Shuffle animation, then settle on the roll.
        val roll = game.rollDice()
        var ticks = 0
        val step = object : Runnable {
            override fun run() {
                ticks += 1
                if (ticks >= SHUFFLE_TICKS) {
                    diceView.value = roll
                    handler.postDelayed({ resolveRoll(roll) }, SETTLE_PAUSE)
                } else {
                    diceView.value = (1..6).random()
                    handler.postDelayed(this, SHUFFLE_INTERVAL)
                }
            }
        }
        handler.post(step)
    }

    private fun resolveRoll(roll: Int) {
        if (game.isFinished) {
            busy = false
            return
        }

        diceView.accentColor = game.currentTurn.color
        val player = game.currentTurn
        val movable = game.movablePawns(player, roll)

        if (movable.isEmpty()) {
            updateBoard()
            setStatus(
                if (roll == 6) {
                    "A six, ${player.label} has no possible move — roll again."
                } else {
                    "No possible move with a $roll."
                }
            )
            // A 6 always earns another throw (module rule); otherwise pass on.
            handler.postDelayed({
                busy = false
                if (roll != 6) game.passTurn()
                afterTurnState()
            }, TURN_PAUSE)
            return
        }

        // Single movable pawn: move it automatically.
        if (movable.size == 1) {
            game.awaitPick()
            updateBoard()
            setStatus("${player.label} rolled $roll.")
            handler.postDelayed({ movePawn(movable.first()) }, AUTO_MOVE_DELAY)
            return
        }

        // Module rule: when every movable pawn sits on the same step, one of
        // them is moved automatically.
        val steps = movable.map { game.step(player, it) }
        if (steps.distinct().size == 1) {
            game.awaitPick()
            updateBoard()
            val pawn = movable[Random.nextInt(movable.size)]
            setStatus("${player.label} rolled $roll.")
            handler.postDelayed({ movePawn(pawn) }, AUTO_MOVE_DELAY)
            return
        }

        game.awaitPick()
        updateBoard(movable.toSet())
        setStatus("${player.label} rolled $roll — tap a highlighted pawn.")
        busy = false
    }

    private fun pickPawn(pawnIndex: Int) {
        if (busy || game.isFinished) return
        if (game.gameState != LudoGameState.PICK_PAWN) return
        if (pawnIndex !in game.movablePawns(game.currentTurn, game.diceResult)) return
        movePawn(pawnIndex)
    }

    private fun movePawn(pawnIndex: Int) {
        if (busy) return
        busy = true

        val player = game.currentTurn
        val fromStep = game.step(player, pawnIndex)
        val startPoint = boardView.positionForStep(player, pawnIndex, fromStep)
        val result = game.applyMove(player, pawnIndex, game.diceResult)

        val waypoints = result.pathSteps.map { step ->
            boardView.positionForStep(player, pawnIndex, step)
        }

        updateBoard()
        setStatus("${player.label}'s pawn is moving…")

        boardView.animatePawn(player, pawnIndex, startPoint, waypoints) {
            if (result.captures.isNotEmpty()) {
                SoundFx.capture()
                val names = result.captures.map { it.first.label }.distinct().joinToString()
                setStatus("$names got captured! ${player.label} rolls again.")
            }

            if (game.isFinished) {
                busy = false
                showGameOver()
                return@animatePawn
            }

            val pause = if (result.captures.isNotEmpty()) LONG_PAUSE else TURN_PAUSE
            handler.postDelayed({
                busy = false
                if (result.extraTurn) {
                    game.keepTurn()
                } else {
                    game.passTurn()
                }
                afterTurnState()
            }, pause)
        }
    }

    /** Refreshes dice highlight + status after a turn switch. */
    private fun afterTurnState() {
        if (game.isFinished) {
            showGameOver()
            return
        }
        diceView.accentColor = game.currentTurn.color
        diceView.highlight = game.gameState == LudoGameState.THROW_DICE
        updateBoard()
        setStatus("${game.currentTurn.label}'s turn — tap the dice to roll.")
    }

    private fun showGameOver() {
        updateBoard()
        diceView.highlight = false
        val ranking = game.winners.joinToString(", ") { it.label.uppercase() }
        setStatus("Game over — winners: $ranking")

        MaterialAlertDialogBuilder(this)
            .setTitle("Thank you for playing 😙")
            .setMessage("The winners are: $ranking")
            .setCancelable(false)
            .setPositiveButton("Play again") { _, _ -> newGame() }
            .setNegativeButton("Exit") { _, _ -> finish() }
            .show()
    }

    // ------------------------------------------------------------------
    // Exit / restart
    // ------------------------------------------------------------------

    private fun confirmExit() {
        if (game.isFinished) {
            finish()
            return
        }
        MaterialAlertDialogBuilder(this)
            .setTitle("Exit Game")
            .setMessage("Are you sure you want to exit the current game?")
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Proceed") { _, _ -> finish() }
            .show()
    }

    private fun confirmRestart() {
        if (game.isFinished) {
            newGame()
            return
        }
        MaterialAlertDialogBuilder(this)
            .setTitle("Restart game?")
            .setMessage("The current game will be lost.")
            .setNegativeButton("Keep playing", null)
            .setPositiveButton("Restart") { _, _ -> newGame() }
            .show()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        SoundFx.release()
        super.onDestroy()
    }

    companion object {
        private const val SHUFFLE_TICKS = 12
        private const val SHUFFLE_INTERVAL = 80L
        private const val SETTLE_PAUSE = 250L
        private const val TURN_PAUSE = 900L
        private const val LONG_PAUSE = 1300L
        private const val AUTO_MOVE_DELAY = 450L
    }
}
