package pynith.apps.nextel.games.dice

import android.content.Context
import android.os.Handler
import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.random.Random

/** Auto-play strategies (matches BetStrategyType in the Flutter module). */
enum class BetStrategyType(val label: String) {
    MANUAL("Manual"),
    MARTINGALE("Martingale"),
    FIXED("Fixed")
}

/** One finished roll, for the history panel. */
data class DiceHistoryEntry(
    val rolledDice: Int,
    val selectedDice: Int,
    val betAmount: Double,
    val resultAmount: Double,
    val isWin: Boolean,
    val timestamp: Long
)

/**
 * Controller for the module's betting dice game:
 *  - pick a face (1..6), stake an amount, roll — a match pays 5x the bet,
 *    a miss loses the stake;
 *  - history is persisted (last 100 rolls, newest first);
 *  - auto play runs up to 10 rounds applying the chosen strategy
 *    (Martingale doubles after a loss and resets after a win, Fixed always
 *    returns to the base bet, Manual leaves the stake untouched).
 */
class DiceGame(context: Context) {

    interface Listener {
        fun onGameChanged(game: DiceGame)

        /** Fired exactly once when a roll settles (win or lose). */
        fun onRollSettled(game: DiceGame, win: Boolean)

        fun onAutoPlayFinished(game: DiceGame)
    }

    var listener: Listener? = null

    var balance: Double = START_BALANCE
        private set
    var betAmount: Double = DEFAULT_BET
        private set
    var selectedDice: Int = 1
        private set
    var rolledDice: Int = 1
        private set
    var isRolling: Boolean = false
        private set
    var isFirstRoll: Boolean = true
        private set
    var isWin: Boolean = false
        private set

    var isAutoPlaying: Boolean = false
        private set

    var strategyType: BetStrategyType = BetStrategyType.MANUAL
        private set

    val history = mutableListOf<DiceHistoryEntry>()

    private var baseBet: Double = DEFAULT_BET
    private val multiplier: Double = 2.0
    private val maxRounds: Int = 10
    private var currentBet: Double = DEFAULT_BET
    private var round: Int = 0

    private val handler = Handler(Looper.getMainLooper())
    private val preferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    init {
        loadHistory()
    }

    // ------------------------------------------------------------------
    // User actions
    // ------------------------------------------------------------------

    fun selectDice(value: Int) {
        if (isRolling) return
        selectedDice = value.coerceIn(1, 6)
        notifyChanged()
    }

    fun setBet(value: Double) {
        if (isRolling || isAutoPlaying) return
        betAmount = value.coerceIn(MIN_BET.toDouble(), MAX_BET.toDouble())
        notifyChanged()
    }

    fun setStrategy(type: BetStrategyType) {
        strategyType = type
        currentBet = betAmount
        baseBet = betAmount
        notifyChanged()
    }

    // ------------------------------------------------------------------
    // Single roll
    // ------------------------------------------------------------------

    /**
     * Runs one roll: shuffles the dice [SHUFFLE_TICKS] times (80ms apart,
     * like the module) then settles, applies the payout and reports through
     * [Listener.onGameChanged].
     */
    fun rollOnce() {
        if (isRolling) return
        if (betAmount < MIN_BET || betAmount > MAX_BET || betAmount > balance) return

        isWin = false
        isRolling = true
        isFirstRoll = false
        notifyChanged()

        var ticks = 0
        val step = object : Runnable {
            override fun run() {
                ticks += 1
                if (ticks < SHUFFLE_TICKS) {
                    rolledDice = Random.nextInt(1, 7)
                    notifyChanged()
                    handler.postDelayed(this, SHUFFLE_INTERVAL)
                } else {
                    settle()
                }
            }
        }
        handler.post(step)
    }

    private fun settle() {
        val result = Random.nextInt(1, 7)
        val win = result == selectedDice

        val resultAmount: Double
        if (win) {
            resultAmount = betAmount * WIN_MULTIPLIER
            balance += resultAmount
        } else {
            resultAmount = -betAmount
            balance -= betAmount
        }

        isWin = win
        rolledDice = result
        isRolling = false

        addHistory(result, resultAmount, win)
        saveHistory()
        notifyChanged()
        listener?.onRollSettled(this, win)
    }

    // ------------------------------------------------------------------
    // Auto play
    // ------------------------------------------------------------------

    fun startAutoPlay() {
        if (isAutoPlaying || isRolling) return

        isAutoPlaying = true
        round = 0
        baseBet = betAmount
        currentBet = betAmount
        notifyChanged()

        playNextRound()
    }

    private fun playNextRound() {
        if (!isAutoPlaying || round >= maxRounds) {
            stopAutoPlay()
            return
        }

        round += 1
        betAmount = currentBet
        notifyChanged()

        // Wait for any running roll to finish before starting the next one.
        if (isRolling) {
            handler.postDelayed({ playNextRound() }, SHUFFLE_INTERVAL + 50)
            return
        }

        if (betAmount < MIN_BET || betAmount > MAX_BET || betAmount > balance) {
            stopAutoPlay()
            return
        }

        rollOnce()

        // Continue after the roll animation has surely finished.
        handler.postDelayed({
            if (!isAutoPlaying) return@postDelayed

            applyStrategy()

            if (balance <= 0 || currentBet > balance) {
                stopAutoPlay()
            } else {
                playNextRound()
            }
        }, SHUFFLE_TICKS * SHUFFLE_INTERVAL + 350)
    }

    fun stopAutoPlay() {
        if (!isAutoPlaying) return
        isAutoPlaying = false
        notifyChanged()
        listener?.onAutoPlayFinished(this)
    }

    private fun applyStrategy() {
        when (strategyType) {
            BetStrategyType.MARTINGALE ->
                currentBet = if (isWin) baseBet else currentBet * multiplier
            BetStrategyType.FIXED -> currentBet = baseBet
            BetStrategyType.MANUAL -> Unit
        }
    }

    // ------------------------------------------------------------------
    // Stats & history
    // ------------------------------------------------------------------

    val winCount: Int
        get() = history.count { it.isWin }

    val lossCount: Int
        get() = history.size - winCount

    val winRatePercent: Double
        get() = if (history.isEmpty()) 0.0 else winCount * 100.0 / history.size

    val profit: Double
        get() = history.sumOf { it.resultAmount }

    private fun addHistory(rolled: Int, resultAmount: Double, win: Boolean) {
        history.add(
            0,
            DiceHistoryEntry(
                rolledDice = rolled,
                selectedDice = selectedDice,
                betAmount = betAmount,
                resultAmount = resultAmount,
                isWin = win,
                timestamp = System.currentTimeMillis()
            )
        )
        while (history.size > HISTORY_LIMIT) {
            history.removeAt(history.size - 1)
        }
    }

    private fun loadHistory() {
        val raw = preferences.getString(KEY_HISTORY, null) ?: return
        try {
            val array = JSONArray(raw)
            for (index in 0 until array.length()) {
                val entry = array.getJSONObject(index)
                history += DiceHistoryEntry(
                    rolledDice = entry.optInt("rolled"),
                    selectedDice = entry.optInt("selected"),
                    betAmount = entry.optDouble("bet"),
                    resultAmount = entry.optDouble("result"),
                    isWin = entry.optBoolean("win"),
                    timestamp = entry.optLong("at")
                )
            }
        } catch (_: Exception) {
            history.clear()
        }
    }

    private fun saveHistory() {
        val array = JSONArray()
        for (entry in history) {
            array.put(
                JSONObject()
                    .put("rolled", entry.rolledDice)
                    .put("selected", entry.selectedDice)
                    .put("bet", entry.betAmount)
                    .put("result", entry.resultAmount)
                    .put("win", entry.isWin)
                    .put("at", entry.timestamp)
            )
        }
        preferences.edit().putString(KEY_HISTORY, array.toString()).apply()
    }

    private fun notifyChanged() {
        listener?.onGameChanged(this)
    }

    fun formatMoney(amount: Double): String =
        "₦" + String.format(Locale.US, "%,.2f", amount)

    fun release() {
        handler.removeCallbacksAndMessages(null)
        isAutoPlaying = false
    }

    companion object {
        const val START_BALANCE = 500_000.0
        const val DEFAULT_BET = 100.0
        const val MIN_BET = 10
        const val MAX_BET = 100_000
        const val WIN_MULTIPLIER = 5.0
        const val HISTORY_LIMIT = 100

        private const val SHUFFLE_TICKS = 10
        private const val SHUFFLE_INTERVAL = 80L
        private const val PREFS_NAME = "dice_game"
        private const val KEY_HISTORY = "game_history"

        fun formatDate(timestamp: Long): String =
            SimpleDateFormat("d MMM yyyy", Locale.US).format(Date(timestamp))
    }
}
