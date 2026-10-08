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
    private val appContext = context.applicationContext
    private val preferences = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val flutterPreferences = appContext.getSharedPreferences(
        FLUTTER_PREFERENCES_NAME,
        Context.MODE_PRIVATE
    )

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
        betAmount = value
        notifyChanged()
    }

    fun canRoll(): Boolean = DiceRules.canRoll(betAmount, balance)

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

        // The Flutter controller changed out of the first-roll state even if
        // the entered stake was invalid; an invalid roll otherwise did nothing.
        isFirstRoll = false
        notifyChanged()
        if (!canRoll()) return

        isWin = false
        isRolling = true
        notifyChanged()

        var ticks = 0
        val step = object : Runnable {
            override fun run() {
                ticks += 1
                rolledDice = Random.nextInt(1, 7)
                notifyChanged()
                if (ticks < SHUFFLE_TICKS) {
                    handler.postDelayed(this, SHUFFLE_INTERVAL)
                } else {
                    settle(Random.nextInt(1, 7))
                }
            }
        }
        handler.postDelayed(step, SHUFFLE_INTERVAL)
    }

    private fun settle(result: Int) {
        val settlement = DiceRules.settle(balance, betAmount, selectedDice, result)
        balance = settlement.balance
        isWin = settlement.isWin
        rolledDice = result
        isRolling = false

        addHistory(result, settlement.resultAmount, settlement.isWin)
        saveHistory()
        notifyChanged()
        listener?.onRollSettled(this, settlement.isWin)
    }

    // ------------------------------------------------------------------
    // Auto play
    // ------------------------------------------------------------------

    fun startAutoPlay() {
        if (isAutoPlaying || isRolling) return

        isFirstRoll = false
        notifyChanged()
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

        // An invalid stake makes the source controller's roll a no-op, but
        // the auto-play loop still waits 500 ms and applies its strategy.
        if (isRolling) {
            handler.postDelayed({ playNextRound() }, SHUFFLE_INTERVAL + 50)
            return
        }

        val willRoll = canRoll()
        if (willRoll) rollOnce()

        val roundDelay = if (willRoll) {
            SHUFFLE_TICKS * SHUFFLE_INTERVAL + AUTO_PLAY_PAUSE
        } else {
            AUTO_PLAY_PAUSE
        }
        handler.postDelayed({
            applyStrategy()

            if (balance <= 0 || currentBet > balance) {
                stopAutoPlay()
            } else if (isAutoPlaying) {
                playNextRound()
            }
        }, roundDelay)
    }

    fun stopAutoPlay() {
        if (!isAutoPlaying) return
        isAutoPlaying = false
        notifyChanged()
        listener?.onAutoPlayFinished(this)
    }

    private fun applyStrategy() {
        currentBet = DiceRules.nextBet(
            strategy = strategyType,
            baseBet = baseBet,
            currentBet = currentBet,
            isWin = isWin,
            multiplier = multiplier
        )
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
        val nativeRaw = preferences.getString(KEY_HISTORY, null)
        val flutterRaw = flutterPreferences.getString(FLUTTER_HISTORY_KEY, null)
        val raw = nativeRaw ?: flutterRaw ?: return
        try {
            val array = JSONArray(raw)
            for (index in 0 until array.length()) {
                val entry = array.getJSONObject(index)
                history += DiceHistoryEntry(
                    rolledDice = entry.optInt("rolledDice", entry.optInt("rolled")),
                    selectedDice = entry.optInt("selectedDice", entry.optInt("selected")),
                    betAmount = entry.optDouble("betAmount", entry.optDouble("bet")),
                    resultAmount = entry.optDouble("resultAmount", entry.optDouble("result")),
                    isWin = entry.optBoolean("isWin", entry.optBoolean("win")),
                    timestamp = when {
                        entry.has("timestamp") -> parseTimestamp(entry.optString("timestamp"))
                        else -> entry.optLong("at")
                    }
                )
            }
        } catch (_: Exception) {
            history.clear()
        }

        // Preserve data created by either the earlier Kotlin port or the
        // Flutter SharedPreferences plugin, then write the source JSON shape
        // the next time a roll is settled.
        if (nativeRaw == null && history.isNotEmpty()) saveHistory()
    }

    private fun parseTimestamp(value: String): Long {
        val dateTime = value.substringBefore('.')
        val zone = if (value.endsWith("Z")) "UTC" else null
        val base = try {
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).apply {
                isLenient = false
                if (zone != null) timeZone = java.util.TimeZone.getTimeZone(zone)
            }.parse(dateTime)?.time ?: 0L
        } catch (_: Exception) {
            0L
        }
        val fraction = value.substringAfter('.', "").takeWhile(Char::isDigit)
        val millis = fraction.take(3).padEnd(3, '0').toIntOrNull() ?: 0
        return base + millis
    }

    private fun saveHistory() {
        val array = JSONArray()
        for (entry in history) {
            array.put(
                JSONObject()
                    .put("rolledDice", entry.rolledDice)
                    .put("selectedDice", entry.selectedDice)
                    .put("betAmount", entry.betAmount)
                    .put("resultAmount", entry.resultAmount)
                    .put("isWin", entry.isWin)
                    .put("timestamp", isoTimestamp(entry.timestamp))
            )
        }
        preferences.edit().putString(KEY_HISTORY, array.toString()).apply()
    }

    private fun isoTimestamp(timestamp: Long): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = java.util.TimeZone.getTimeZone("UTC")
        }.format(Date(timestamp))

    private fun notifyChanged() {
        listener?.onGameChanged(this)
    }

    fun formatMoney(amount: Double): String =
        "₦" + String.format(Locale.US, "%.2f", amount)

    fun release() {
        handler.removeCallbacksAndMessages(null)
        isAutoPlaying = false
    }

    companion object {
        const val START_BALANCE = 500_000.0
        const val DEFAULT_BET = 100.0
        // These values exist in the source constants/help copy, but the
        // Flutter controller only enforced a positive stake up to balance.
        const val MIN_BET = 10
        const val MAX_BET = 100_000
        const val WIN_MULTIPLIER = DiceRules.WIN_MULTIPLIER
        const val HISTORY_LIMIT = 100

        private const val SHUFFLE_TICKS = 10
        private const val SHUFFLE_INTERVAL = 80L
        private const val AUTO_PLAY_PAUSE = 500L
        private const val PREFS_NAME = "dice_game"
        private const val KEY_HISTORY = "game_history"
        private const val FLUTTER_PREFERENCES_NAME = "FlutterSharedPreferences"
        private const val FLUTTER_HISTORY_KEY = "flutter.game_history"

        fun formatDate(timestamp: Long): String =
            SimpleDateFormat("d MMM yyyy", Locale.US).format(Date(timestamp))
    }
}
