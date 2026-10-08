package pynith.apps.nextel.games

import android.content.res.ColorStateList
import android.os.Bundle
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import com.google.android.material.button.MaterialButton
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import pynith.apps.nextel.R
import pynith.apps.nextel.games.hangman.HangmanScores
import pynith.apps.nextel.games.hangman.HangmanWords
import pynith.apps.nextel.views.BaseActivity
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.min

/** Original five-life Hangman run, rendered with its bundled word and drawing assets. */
class HangmanActivity : BaseActivity() {

    private lateinit var words: HangmanWords
    private lateinit var scores: HangmanScores

    private lateinit var hangmanDrawing: ImageView
    private lateinit var hiddenWordText: TextView
    private lateinit var livesText: TextView
    private lateinit var wordCounterText: TextView
    private lateinit var hintButton: ImageButton
    private lateinit var keyboard: LinearLayout
    private val letterButtons = mutableListOf<MaterialButton>()

    private var word: String = ""
    private var revealed = BooleanArray(0)
    private var usedLetters = BooleanArray(26)
    private var hangState = 0
    private var lives = 5
    private var wordCount = 0
    private var hintAvailable = true
    private var wordFinished = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_hangman)

        words = HangmanWords.from(this)
        scores = HangmanScores(this)

        findViewById<ImageButton>(R.id.exitButton).setOnClickListener { confirmExit() }
        hangmanDrawing = findViewById(R.id.hangmanDrawing)
        hiddenWordText = findViewById(R.id.hiddenWordText)
        livesText = findViewById(R.id.livesText)
        wordCounterText = findViewById(R.id.wordCounterText)
        hintButton = findViewById(R.id.hintButton)
        keyboard = findViewById(R.id.keyboard)

        hintButton.setOnClickListener { useHint() }
        buildKeyboard()
        newGame()

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            // Flutter PopScope(canPop: false) blocks system back; use the
            // on-screen arrow for the source's confirmation dialog.
            override fun handleOnBackPressed() = Unit
        })
    }

    private fun newGame() {
        words.reset()
        lives = 5
        wordCount = 0
        nextWord()
    }

    private fun nextWord() {
        val next = words.getWord()
        if (next == null) {
            finishRun()
            return
        }

        word = next
        revealed = BooleanArray(word.length)
        usedLetters = BooleanArray(26)
        hangState = 0
        hintAvailable = true
        wordFinished = false
        render()
    }

    private fun buildKeyboard() {
        keyboard.removeAllViews()
        letterButtons.clear()

        val rows = listOf('A'..'G', 'H'..'N', 'O'..'U', 'V'..'Z')
        rows.forEachIndexed { rowIndex, letters ->
            val rowLayout = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            }

            letters.forEach { letter ->
                val index = letter - 'A'
                val button = MaterialButton(this).apply {
                    text = letter.toString()
                    textSize = 26f
                    setTextColor(getColor(R.color.nextel_white))
                    backgroundTintList = ColorStateList.valueOf(WORD_BUTTON_COLOR)
                    cornerRadius = dp(10)
                    elevation = dp(3).toFloat()
                    insetTop = 0
                    insetBottom = 0
                    setPadding(dp(4), 0, dp(4), 0)
                    setOnClickListener { pressLetter(index) }
                }
                letterButtons += button
                rowLayout.addView(
                    button,
                    LinearLayout.LayoutParams(0, dp(KEY_HEIGHT), 1f).apply {
                        setMargins(dp(3), dp(4), dp(3), dp(4))
                    }
                )
            }

            if (rowIndex == rows.lastIndex) {
                val scoresButton = MaterialButton(this).apply {
                    text = "Scores"
                    textSize = 14f
                    icon = getDrawable(R.drawable.ic_game_eye)
                    iconSize = dp(15)
                    iconGravity = MaterialButton.ICON_GRAVITY_TEXT_START
                    setTextColor(getColor(R.color.nextel_white))
                    backgroundTintList = ColorStateList.valueOf(WORD_BUTTON_COLOR)
                    cornerRadius = dp(10)
                    insetTop = 0
                    insetBottom = 0
                    setOnClickListener {
                        startActivity(android.content.Intent(this@HangmanActivity, ScoresActivity::class.java))
                    }
                }
                rowLayout.addView(
                    scoresButton,
                    LinearLayout.LayoutParams(0, dp(KEY_HEIGHT), 2f).apply {
                        setMargins(dp(3), dp(4), dp(3), dp(4))
                    }
                )
            }

            keyboard.addView(rowLayout)
        }
    }

    private fun pressLetter(index: Int) {
        if (wordFinished || index !in usedLetters.indices || usedLetters[index]) return
        usedLetters[index] = true

        var hit = false
        for (i in word.indices) {
            if (word[i] - 'a' == index && !revealed[i]) {
                revealed[i] = true
                hit = true
            }
        }

        if (!hit) hangState += 1
        render()

        when {
            revealed.all { it } -> solvedWord()
            hangState == MAX_WRONG_GUESSES -> failedWord()
        }
    }

    /** Reveals one random unrevealed letter, once per word. */
    private fun useHint() {
        if (!hintAvailable || wordFinished) return
        val candidates = word.indices.filter { !revealed[it] }
        if (candidates.isEmpty()) return
        hintAvailable = false
        render()
        pressLetter(word[candidates.random()] - 'a')
    }

    private fun solvedWord() {
        wordFinished = true
        render()
        MaterialAlertDialogBuilder(this)
            .setTitle(word)
            .setCancelable(false)
            .setPositiveButton("Next word") { _, _ ->
                wordCount += 1
                nextWord()
            }
            .show()
    }

    private fun failedWord() {
        wordFinished = true
        lives -= 1
        render()

        if (lives <= 0) {
            finishRun()
        } else {
            MaterialAlertDialogBuilder(this)
                .setTitle(word)
                .setCancelable(false)
                .setPositiveButton("Next word") { _, _ -> nextWord() }
                .show()
        }
    }

    private fun finishRun() {
        if (wordCount > 0) {
            val date = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(Date())
            scores.add(wordCount, date)
        }
        MaterialAlertDialogBuilder(this)
            .setTitle("Game Over!")
            .setMessage("Your score is $wordCount")
            .setCancelable(false)
            .setPositiveButton("Play again") { _, _ -> newGame() }
            .setNegativeButton("Exit") { _, _ -> finish() }
            .show()
    }

    private fun render() {
        val display = buildString {
            for (i in word.indices) append(if (revealed[i]) word[i].uppercaseChar() else '_')
        }
        hiddenWordText.text = display
        val availableWidth = resources.displayMetrics.widthPixels - dp(70)
        val scaledSize = (availableWidth / resources.displayMetrics.density / (word.length * 0.74f))
            .coerceAtMost(57f)
            .coerceAtLeast(18f)
        hiddenWordText.textSize = min(57f, scaledSize)

        livesText.text = if (lives == 1) "I" else lives.toString()
        wordCounterText.text = if (wordCount == 1) "I" else wordCount.toString()
        hintButton.isEnabled = hintAvailable && !wordFinished

        hangmanDrawing.setImageResource(HANGMAN_DRAWINGS[hangState.coerceIn(0, MAX_WRONG_GUESSES)])
        letterButtons.forEachIndexed { index, button ->
            button.backgroundTintList = ColorStateList.valueOf(
                if (usedLetters[index]) WORD_BUTTON_USED_COLOR else WORD_BUTTON_COLOR
            )
            // The Flutter keys remain opaque and colored after use; the click
            // handler ignores repeats rather than dimming/disabling the key.
            button.isClickable = !usedLetters[index] && !wordFinished
        }
    }

    private fun confirmExit() {
        MaterialAlertDialogBuilder(this)
            .setTitle("Exit Game")
            .setMessage("Are you sure you want to exit the current game?")
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Proceed") { _, _ -> finish() }
            .show()
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    companion object {
        private const val KEY_HEIGHT = 46
        private const val MAX_WRONG_GUESSES = 6
        private const val WORD_BUTTON_COLOR = 0xFF1089FF.toInt()
        private const val WORD_BUTTON_USED_COLOR = 0xFF9D9797.toInt()
        private val HANGMAN_DRAWINGS = intArrayOf(
            R.drawable.hangman_0,
            R.drawable.hangman_1,
            R.drawable.hangman_2,
            R.drawable.hangman_3,
            R.drawable.hangman_4,
            R.drawable.hangman_5,
            R.drawable.hangman_6
        )
    }
}
