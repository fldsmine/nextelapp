package pynith.apps.nextel.games

import android.graphics.Color
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import android.widget.ArrayAdapter
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.Spinner
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import com.bumptech.glide.Glide
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.android.material.button.MaterialButton
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.textfield.TextInputEditText
import com.airbnb.lottie.LottieAnimationView
import pynith.apps.nextel.R
import pynith.apps.nextel.games.dice.BetStrategyType
import pynith.apps.nextel.games.dice.DiceGame
import pynith.apps.nextel.games.widget.ConfettiView
import pynith.apps.nextel.views.BaseActivity
import java.util.Locale

/** Native Android rendering of the original Flutter betting Dice screen. */
class DiceActivity : BaseActivity(), DiceGame.Listener {

    private lateinit var game: DiceGame

    private lateinit var firstRollDice: ImageView
    private lateinit var rollingDice: LottieAnimationView
    private lateinit var finalDice: ImageView
    private lateinit var balanceText: TextView
    private lateinit var strategySpinner: Spinner
    private lateinit var betInput: TextInputEditText
    private lateinit var playButton: TextView
    private lateinit var playProgress: ProgressBar
    private lateinit var autoPlayButton: MaterialButton
    private lateinit var winRateText: TextView
    private lateinit var profitText: TextView
    private lateinit var wlText: TextView
    private lateinit var historyRow: LinearLayout
    private lateinit var noHistoryText: TextView
    private lateinit var confettiView: ConfettiView

    private val selectorDice = mutableListOf<ImageView>()
    private var activeDiceView: View? = null
    private var syncingBet = false
    private var wasRolling = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_dice)
        SoundFx.initialize(applicationContext)

        game = DiceGame(this)
        game.listener = this

        findViewById<MaterialToolbar>(R.id.diceToolbar).apply {
            setNavigationOnClickListener { confirmExit() }
            inflateMenu(R.menu.menu_dice)
            setOnMenuItemClickListener { item ->
                when (item.itemId) {
                    R.id.action_help -> {
                        showHelp()
                        true
                    }
                    // The source screen's settings icon is intentionally a no-op.
                    R.id.action_settings -> true
                    else -> false
                }
            }
        }

        firstRollDice = findViewById(R.id.firstRollDice)
        rollingDice = findViewById(R.id.rollingDice)
        finalDice = findViewById(R.id.finalDice)
        balanceText = findViewById(R.id.balanceText)
        strategySpinner = findViewById(R.id.strategySpinner)
        betInput = findViewById(R.id.betInput)
        playButton = findViewById(R.id.playButton)
        playProgress = findViewById(R.id.playProgress)
        autoPlayButton = findViewById(R.id.autoPlayButton)
        winRateText = findViewById(R.id.winRateText)
        profitText = findViewById(R.id.profitText)
        wlText = findViewById(R.id.wlText)
        historyRow = findViewById(R.id.historyRow)
        noHistoryText = findViewById(R.id.noHistoryText)
        confettiView = findViewById(R.id.confettiView)

        Glide.with(this).asGif().load(R.raw.dice_draw).into(firstRollDice)

        findViewById<MaterialButton>(R.id.fundWalletButton).setOnClickListener {
            // The matching Flutter button did not have an action.
        }

        setupSelectors()
        setupStrategySpinner()
        setupBetInput()

        playButton.setOnClickListener { play() }
        autoPlayButton.setOnClickListener { toggleAutoPlay() }

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            // The original Dice screen uses PopScope(canPop: false); only its
            // in-screen arrow opens the exit confirmation.
            override fun handleOnBackPressed() = Unit
        })

        render(game)
    }

    private fun setupSelectors() {
        val ids = listOf(R.id.dice1, R.id.dice2, R.id.dice3, R.id.dice4, R.id.dice5, R.id.dice6)
        ids.forEachIndexed { index, id ->
            val value = index + 1
            val dice = findViewById<ImageView>(id)
            dice.setImageResource(DICE_FACES[index])
            dice.setOnClickListener {
                if (!game.isRolling) {
                    SoundFx.click()
                    game.selectDice(value)
                }
            }
            selectorDice += dice
        }
    }

    private fun setupStrategySpinner() {
        val labels = BetStrategyType.entries.map { it.label }
        val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_item, labels).apply {
            setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        }
        strategySpinner.adapter = adapter
        strategySpinner.onItemSelectedListener = object : android.widget.AdapterView.OnItemSelectedListener {
            override fun onItemSelected(
                parent: android.widget.AdapterView<*>,
                view: View?,
                position: Int,
                id: Long
            ) {
                game.setStrategy(BetStrategyType.entries[position])
            }

            override fun onNothingSelected(parent: android.widget.AdapterView<*>) = Unit
        }
    }

    private fun setupBetInput() {
        betInput.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit

            override fun afterTextChanged(s: Editable?) {
                if (syncingBet) return
                val value = s?.toString()?.toDoubleOrNull() ?: 0.0
                game.setBet(value)
            }
        })
    }

    private fun play() {
        if (game.isRolling) return
        // Invalid/non-positive stakes are silently ignored by the source
        // controller after it leaves the first-roll animation state.
        game.rollOnce()
    }

    private fun toggleAutoPlay() {
        if (game.isAutoPlaying) {
            game.stopAutoPlay()
        } else {
            game.startAutoPlay()
        }
    }

    // ------------------------------------------------------------------
    // DiceGame.Listener
    // ------------------------------------------------------------------

    override fun onGameChanged(game: DiceGame) {
        if (isFinishing || isDestroyed) return
        if (!wasRolling && game.isRolling) SoundFx.diceRoll()
        if (wasRolling && !game.isRolling) SoundFx.diceStop()
        wasRolling = game.isRolling
        render(game)
    }

    override fun onRollSettled(game: DiceGame, win: Boolean) {
        if (isFinishing || isDestroyed) return
        render(game)

        // The source plays result sounds for manual and automatic rolls, but
        // only manual wins open the celebration dialog and confetti.
        if (win) SoundFx.win() else SoundFx.lose()
        if (game.isAutoPlaying) return
        if (win) {
            confettiView.burst()
            showWinDialog(game.betAmount * DiceGame.WIN_MULTIPLIER)
        }
    }

    override fun onAutoPlayFinished(game: DiceGame) {
        if (isFinishing || isDestroyed) return
        render(game)
    }

    // ------------------------------------------------------------------
    // Rendering
    // ------------------------------------------------------------------

    private fun render(game: DiceGame) {
        balanceText.text = game.formatMoney(game.balance)

        playButton.text = if (game.isRolling) "" else "PLAY NOW"
        playProgress.visibility = if (game.isRolling) View.VISIBLE else View.GONE
        playButton.isEnabled = !game.isRolling

        autoPlayButton.text = if (game.isAutoPlaying) "STOP AUTO" else "AUTO PLAY"
        autoPlayButton.isEnabled = true

        renderDice(game)

        selectorDice.forEachIndexed { index, dice ->
            dice.isSelected = game.selectedDice == index + 1
            dice.contentDescription = "Select dice ${index + 1}"
        }

        // Keep the bet field in sync when auto-play changes the stake.
        val betText = game.betAmount.toString()
        if (betInput.text?.toString() != betText) {
            syncingBet = true
            betInput.setText(betText)
            betInput.setSelection(betInput.text?.length ?: 0)
            syncingBet = false
        }

        renderStats(game)
        renderHistory(game)
    }

    private fun renderDice(game: DiceGame) {
        val target = when {
            game.isFirstRoll -> firstRollDice
            game.isRolling -> rollingDice
            else -> finalDice.apply {
                setImageResource(DICE_FACES[(game.rolledDice - 1).coerceIn(0, 5)])
            }
        }

        if (game.isRolling && !rollingDice.isAnimating) rollingDice.playAnimation()
        if (!game.isRolling && rollingDice.isAnimating) rollingDice.cancelAnimation()
        showDiceState(target)
    }

    private fun showDiceState(target: View) {
        if (activeDiceView === target) {
            target.visibility = View.VISIBLE
            return
        }

        val previous = activeDiceView
        target.animate().cancel()
        target.alpha = 0f
        target.visibility = View.VISIBLE
        target.animate().alpha(1f).setDuration(DICE_SWITCH_DURATION).start()

        if (previous != null) {
            previous.animate().cancel()
            previous.animate().alpha(0f).setDuration(DICE_SWITCH_DURATION).withEndAction {
                if (activeDiceView !== previous) {
                    previous.visibility = View.GONE
                    previous.alpha = 1f
                }
            }.start()
        }
        activeDiceView = target
    }

    private fun renderStats(game: DiceGame) {
        winRateText.text = String.format(Locale.US, "%.1f%%", game.winRatePercent)
        profitText.text = "₦" + String.format(Locale.US, "%.0f", game.profit)
        wlText.text = "${game.winCount}/${game.lossCount}"
    }

    private fun renderHistory(game: DiceGame) {
        historyRow.removeAllViews()
        noHistoryText.visibility = if (game.history.isEmpty()) View.VISIBLE else View.GONE

        // Source keeps the full rolling history (up to its 100-entry cap).
        for (entry in game.history) {
            val chip = layoutInflater
                .inflate(R.layout.item_dice_history, historyRow, false) as LinearLayout
            chip.findViewById<ImageView>(R.id.historyDice)
                .setImageResource(DICE_FACES[(entry.rolledDice - 1).coerceIn(0, 5)])
            chip.findViewById<TextView>(R.id.historyBet).text = "₦${entry.betAmount}"
            val resultView = chip.findViewById<TextView>(R.id.historyResult)
            resultView.text = if (entry.isWin) "WIN" else "LOSE"
            resultView.setTextColor(
                if (entry.isWin) Color.parseColor("#69F0AE") else Color.parseColor("#FF8A80")
            )
            chip.setBackgroundResource(if (entry.isWin) R.drawable.bg_history_win else R.drawable.bg_history_lose)
            historyRow.addView(chip)
        }
    }

    private fun showWinDialog(amount: Double) {
        MaterialAlertDialogBuilder(this)
            .setTitle("🎉 YOU WIN!")
            .setMessage(game.formatMoney(amount))
            .setPositiveButton("CONTINUE") { dialog, _ -> dialog.dismiss() }
            .setCancelable(false)
            .show()
    }

    private fun showHelp() {
        val helpText = "1. Select your dice (D4, D6, D8, D10, D12, D20).\n" +
            "2. Enter your bet amount.\n" +
            "3. Press the Play button to roll the dice.\n" +
            "4. If you roll a 1, you lose your bet. If you roll a 6, you win 5x your bet!\n\n" +
            "This is your developer section.\n\n" +
            "You can place debug info, logs, API responses,\n" +
            "or any internal tools here.\n\n" +
            "Example:\n" +
            "- App Version: 1.0.0\n" +
            "- Environment: Development\n" +
            "- API Status: Connected\n\n" +
            "Add anything useful for debugging or testing."

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(22), dp(18), dp(22), dp(28))
            setBackgroundColor(Color.parseColor("#141A27"))
        }
        content.addView(TextView(this).apply {
            text = "HOW TO PLAY"
            textSize = 18f
            setTextColor(Color.WHITE)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            gravity = Gravity.START
        })
        content.addView(TextView(this).apply {
            text = helpText
            textSize = 15f
            setTextColor(Color.WHITE)
            setPadding(0, dp(12), 0, 0)
        })

        BottomSheetDialog(this).apply {
            setContentView(content)
            show()
        }
    }

    private fun confirmExit() {
        MaterialAlertDialogBuilder(this)
            .setTitle("Exit Game")
            .setMessage("Are you sure you want to exit the current game?")
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Proceed") { _, _ ->
                game.release()
                finish()
            }
            .show()
    }

    override fun onDestroy() {
        game.release()
        rollingDice.cancelAnimation()
        SoundFx.release()
        super.onDestroy()
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    companion object {
        private const val DICE_SWITCH_DURATION = 250L
        private val DICE_FACES = intArrayOf(
            R.drawable.game_dice_1,
            R.drawable.game_dice_2,
            R.drawable.game_dice_3,
            R.drawable.game_dice_4,
            R.drawable.game_dice_5,
            R.drawable.game_dice_6
        )
    }
}
