package pynith.apps.nextel.games

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import com.bumptech.glide.Glide
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import pynith.apps.nextel.R
import pynith.apps.nextel.games.ludo.LudoBoardView
import pynith.apps.nextel.games.ludo.LudoGame
import pynith.apps.nextel.games.ludo.LudoGameState
import pynith.apps.nextel.games.ludo.LudoDiceView
import pynith.apps.nextel.views.BaseActivity
import kotlin.random.Random

/** Four-player pass-and-play Ludo from the original Flutter game. */
class LudoActivity : BaseActivity() {

    private val handler = Handler(Looper.getMainLooper())

    private lateinit var game: LudoGame
    private lateinit var boardView: LudoBoardView
    private lateinit var diceView: LudoDiceView
    private lateinit var endGamePanel: LinearLayout
    private lateinit var winnersText: TextView

    private var busy = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_ludo)
        SoundFx.initialize(applicationContext)

        findViewById<MaterialToolbar>(R.id.ludoToolbar).apply {
            setNavigationOnClickListener { confirmExit() }
            inflateMenu(R.menu.menu_ludo)
            setOnMenuItemClickListener { item ->
                // The original screen's search and overflow buttons had no action.
                item.itemId == R.id.action_search || item.itemId == R.id.action_more
            }
        }

        boardView = findViewById(R.id.boardView)
        diceView = findViewById(R.id.diceView)
        endGamePanel = findViewById(R.id.endGamePanel)
        winnersText = findViewById(R.id.winnersText)
        val celebrationImage = findViewById<ImageView>(R.id.celebrationImage)
        Glide.with(this).asGif().load(R.raw.ludo_thankyou).into(celebrationImage)

        boardView.onPawnPicked = { pawnIndex -> pickPawn(pawnIndex) }
        diceView.setOnClickListener { throwDice() }
        newGame()

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            // Flutter PopScope(canPop: false) blocks system back; the in-screen
            // arrow remains the explicit, confirmation-protected exit control.
            override fun handleOnBackPressed() = Unit
        })
    }

    private fun newGame() {
        handler.removeCallbacksAndMessages(null)
        game = LudoGame()
        busy = false
        endGamePanel.visibility = LinearLayout.GONE
        diceView.value = 1
        diceView.rolling = false
        diceView.accentColor = game.currentTurn.color
        diceView.highlight = true
        updateBoard()
        setStatus("Green starts — tap the dice to roll.")
    }

    private fun updateBoard(highlight: Set<Int> = emptySet()) {
        boardView.setState(game, highlight)
    }

    private fun setStatus(message: String) {
        // The source displays this status inside the active yard, not in a
        // separate banner. Keep both interactive surfaces accessible.
        boardView.contentDescription = "Ludo board. $message"
        diceView.contentDescription = "$message Current die face ${diceView.value}."
    }

    // ------------------------------------------------------------------
    // Turn flow
    // ------------------------------------------------------------------

    private fun throwDice() {
        if (busy || game.isFinished || game.gameState != LudoGameState.THROW_DICE) return

        // The source lets a player who has already won tap the dice once to
        // advance to the next non-winning player instead of rolling again.
        if (game.currentTurn in game.winners) {
            SoundFx.ludoRoll()
            game.passTurn()
            afterTurnState()
            return
        }

        busy = true
        SoundFx.ludoRoll()
        diceView.highlight = false
        diceView.rolling = true

        // Flutter keeps the animated GIF visible for one second, then settles.
        handler.postDelayed({
            if (isFinishing || isDestroyed) return@postDelayed
            val roll = game.rollDice()
            diceView.rolling = false
            diceView.value = roll
            resolveRoll(roll)
        }, DICE_REVEAL_DELAY)
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
            handler.postDelayed({
                busy = false
                if (roll != 6) game.passTurn()
                afterTurnState()
            }, TURN_PAUSE)
            return
        }

        if (movable.size == 1) {
            game.awaitPick()
            updateBoard()
            setStatus("${player.label} rolled $roll.")
            val pawn = movable.first()
            handler.postDelayed({
                busy = false
                movePawn(pawn, singlePawnAutoMove = true)
            }, AUTO_MOVE_DELAY)
            return
        }

        // Match the source's auto-selection: if every highlighted pawn shares
        // the same step, choose randomly from indices 1..last (not index 0).
        val steps = movable.map { game.step(player, it) }
        if (steps.distinct().size == 1) {
            game.awaitPick()
            updateBoard()
            setStatus("${player.label} rolled $roll.")
            val pawn = movable[Random.nextInt(1, movable.size)]
            handler.postDelayed({
                busy = false
                movePawn(pawn)
            }, AUTO_MOVE_DELAY)
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

    private fun movePawn(pawnIndex: Int, singlePawnAutoMove: Boolean = false) {
        if (busy) return
        busy = true

        val player = game.currentTurn
        val fromStep = game.step(player, pawnIndex)
        val startPoint = boardView.positionForStep(player, pawnIndex, fromStep)
        val result = game.applyMove(
            player,
            pawnIndex,
            game.diceResult,
            singlePawnAutoMove = singlePawnAutoMove
        )
        val waypoints = result.pathSteps.map { step ->
            boardView.positionForStep(player, pawnIndex, step)
        }

        updateBoard()
        setStatus("${player.label}'s pawn is moving…")

        boardView.animatePawn(
            type = player,
            pawnIndex = pawnIndex,
            startPoint = startPoint,
            waypoints = waypoints,
            onStep = { SoundFx.ludoMove() }
        ) {
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
        winnersText.text = "The Winners is: $ranking"
        endGamePanel.visibility = LinearLayout.VISIBLE
        setStatus("Game over — winners: $ranking")
    }

    private fun confirmExit() {
        MaterialAlertDialogBuilder(this)
            .setTitle("Exit Game")
            .setMessage("Are you sure you want to exit the current game?")
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Proceed") { _, _ -> finish() }
            .show()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        SoundFx.release()
        super.onDestroy()
    }

    companion object {
        private const val DICE_REVEAL_DELAY = 1_000L
        private const val TURN_PAUSE = 900L
        private const val LONG_PAUSE = 1_300L
        private const val AUTO_MOVE_DELAY = 450L
    }
}
