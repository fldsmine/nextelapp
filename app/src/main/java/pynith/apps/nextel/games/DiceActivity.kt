package pynith.apps.nextel.games

import android.graphics.Color
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.widget.ArrayAdapter
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.button.MaterialButton
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.textfield.TextInputEditText
import pynith.apps.nextel.R
import pynith.apps.nextel.games.dice.BetStrategyType
import pynith.apps.nextel.games.dice.DiceGame
import pynith.apps.nextel.games.widget.ConfettiView
import pynith.apps.nextel.games.widget.DiceView
import pynith.apps.nextel.views.BaseActivity

/**
 * The Flutter module's betting dice game: pick a face, stake an amount,
 * roll — a match pays 5x. Includes the auto-play strategies and the
 * persisted roll history with stats.
 */
class DiceActivity : BaseActivity(), DiceGame.Listener {

    private lateinit var game: DiceGame

    private lateinit var bigDice: DiceView
    private lateinit var rollHint: TextView
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

    private val selectorDice = mutableListOf<DiceView>()
    private var syncingBet = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_dice)

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
                    else -> false
                }
            }
        }

        bigDice = findViewById(R.id.bigDice)
        rollHint = findViewById(R.id.rollHintText)
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

        selectorDice.add(findViewById(R.id.dice5))
        selectorDice.add(findViewById(R.id.dice6))

        findViewById<MaterialButton>(R.id.fundWalletButton).setOnClickListener {
            Toast.makeText(this, "Wallet funding is not available in the demo game.", Toast.LENGTH_SHORT).show()
        }

        setupSelectors()
        setupStrategySpinner()
        setupBetInput()

        playButton.setOnClickListener { play() }
        autoPlayButton.setOnClickListener { toggleAutoPlay() }

        render(game)
    }

    private fun setupSelectors() {
        val row = findViewById<LinearLayout>(R.id.diceRow1)
        for (value in 1..4) {
            val dice = DiceView(this).apply {
                accentColor = Color.WHITE
                layoutParams = LinearLayout.LayoutParams(0, dp(46), 1f).apply {
                    marginEnd = dp(10)
                }
                background = getDrawable(R.drawable.bg_dice_selector)
                setOnClickListener {
                    SoundFx.click()
                    game.selectDice(value)
                }
            }
            dice.value = value
            row.addView(dice)
            selectorDice += dice
        }

        for (value in 5..6) {
            val dice = selectorDice.first { it.id == if (value == 5) R.id.dice5 else R.id.dice6 }
            dice.accentColor = Color.WHITE
            dice.value = value
            dice.setOnClickListener {
                SoundFx.click()
                game.selectDice(value)
            }
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
                renderStats(game)
            }
        })
    }

    private fun play() {
        if (game.isRolling || game.isAutoPlaying) return

        if (game.betAmount < DiceGame.MIN_BET) {
            Toast.makeText(this, "Minimum bet is ₦${DiceGame.MIN_BET}.", Toast.LENGTH_SHORT).show()
            return
        }
        if (game.betAmount > DiceGame.MAX_BET) {
            Toast.makeText(this, "Maximum bet is ₦${DiceGame.MAX_BET}.", Toast.LENGTH_SHORT).show()
            return
        }
        if (game.betAmount > game.balance) {
            Toast.makeText(this, "Bet exceeds your wallet balance.", Toast.LENGTH_SHORT).show()
            return
        }

        SoundFx.diceRoll()
        game.rollOnce()
    }

    private fun toggleAutoPlay() {
        if (game.isAutoPlaying) {
            game.stopAutoPlay()
            SoundFx.click()
        } else {
            if (game.betAmount < DiceGame.MIN_BET || game.betAmount > game.balance) {
                Toast.makeText(this, "Set a valid bet before auto play.", Toast.LENGTH_SHORT).show()
                return
            }
            SoundFx.click()
            game.startAutoPlay()
        }
    }

    // ------------------------------------------------------------------
    // DiceGame.Listener
    // ------------------------------------------------------------------

    override fun onGameChanged(game: DiceGame) {
        if (isFinishing || isDestroyed) return
        render(game)
    }

    override fun onRollSettled(game: DiceGame, win: Boolean) {
        if (isFinishing || isDestroyed) return
        render(game)

        // Auto play stays quiet; a manual winning roll celebrates.
        if (game.isAutoPlaying) return
        if (win) {
            SoundFx.win()
            confettiView.burst()
            showWinDialog(game.betAmount * DiceGame.WIN_MULTIPLIER)
        } else {
            SoundFx.lose()
        }
    }

    override fun onAutoPlayFinished(game: DiceGame) {
        if (isFinishing || isDestroyed) return
        render(game)
        Toast.makeText(this, "Auto play finished.", Toast.LENGTH_SHORT).show()
    }

    // ------------------------------------------------------------------
    // Rendering
    // ------------------------------------------------------------------

    private fun render(game: DiceGame) {
        bigDice.value = game.rolledDice
        balanceText.text = game.formatMoney(game.balance)

        playButton.text = if (game.isRolling) "" else "PLAY NOW"
        playProgress.visibility = if (game.isRolling) View.VISIBLE else View.GONE
        playButton.isEnabled = !game.isRolling && !game.isAutoPlaying

        autoPlayButton.text = if (game.isAutoPlaying) "STOP AUTO" else "AUTO PLAY"
        autoPlayButton.isEnabled = !game.isRolling

        rollHint.text = when {
            game.isFirstRoll -> "Pick a face and press PLAY NOW"
            game.isRolling -> "Rolling…"
            game.isWin -> "You matched the dice!"
            else -> "No match — try again!"
        }

        selectorDice.forEachIndexed { index, dice ->
            dice.isSelected = game.selectedDice == index + 1
            dice.highlight = game.selectedDice == index + 1
        }

        // Keep the bet field in sync (auto play changes the stake).
        val betText = if (game.betAmount % 1.0 == 0.0) {
            game.betAmount.toLong().toString()
        } else {
            game.betAmount.toString()
        }
        if (betInput.text?.toString() != betText) {
            syncingBet = true
            betInput.setText(betText)
            betInput.setSelection(betInput.text?.length ?: 0)
            syncingBet = false
        }

        renderStats(game)
        renderHistory(game)
    }

    private fun renderStats(game: DiceGame) {
        winRateText.text = String.format(java.util.Locale.US, "%.1f%%", game.winRatePercent)
        profitText.text = game.formatMoney(game.profit).replace(".00", "")
        wlText.text = "${game.winCount}/${game.lossCount}"
    }

    private fun renderHistory(game: DiceGame) {
        historyRow.removeAllViews()
        noHistoryText.visibility = if (game.history.isEmpty()) View.VISIBLE else View.GONE

        for (entry in game.history.take(30)) {
            val chip = LayoutInflater.from(this)
                .inflate(R.layout.item_dice_history, historyRow, false) as LinearLayout
            chip.findViewById<DiceView>(R.id.historyDice).value = entry.rolledDice
            chip.findViewById<TextView>(R.id.historyBet).text = "₦${entry.betAmount.toLong()}"
            val resultView = chip.findViewById<TextView>(R.id.historyResult)
            resultView.text = if (entry.isWin) "WIN" else "LOSE"
            resultView.setTextColor(if (entry.isWin) Color.parseColor("#69F0AE") else Color.parseColor("#FF8A80"))
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
        MaterialAlertDialogBuilder(this)
            .setTitle("HOW TO PLAY")
            .setMessage(
                "1. Select your dice (1 – 6).\n" +
                        "2. Enter your bet amount (₦10 – ₦100,000).\n" +
                        "3. Press PLAY NOW to roll the dice.\n" +
                        "4. If the dice lands on your number, you win 5× your bet — otherwise the bet is lost.\n\n" +
                        "AUTO PLAY rolls up to 10 rounds using the selected strategy:\n" +
                        "• Manual — keeps your stake.\n" +
                        "• Martingale — doubles after a loss, resets after a win.\n" +
                        "• Fixed — always returns to the base bet."
            )
            .setPositiveButton("Got it", null)
            .show()
    }

    private fun confirmExit() {
        if (!game.isAutoPlaying && !game.isRolling) {
            finish()
            return
        }
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
        SoundFx.release()
        super.onDestroy()
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}
