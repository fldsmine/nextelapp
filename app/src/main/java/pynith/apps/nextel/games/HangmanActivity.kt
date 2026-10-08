package pynith.apps.nextel.games

import android.graphics.Color
import android.os.Bundle
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.button.MaterialButton
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import pynith.apps.nextel.R
import pynith.apps.nextel.games.hangman.HangmanScores
import pynith.apps.nextel.games.hangman.HangmanView
import pynith.apps.nextel.games.hangman.HangmanWords
import pynith.apps.nextel.views.BaseActivity
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The Flutter module's Hangman: 5 lives, one hint per word, 6 wrong guesses
 * lose a life, every solved word scores a point. Runs end when the words run
 * out; scores are kept on the scores screen.
 */
class HangmanActivity : BaseActivity() {

    private val words = HangmanWords()
    private lateinit var scores: HangmanScores

    private lateinit var hangmanView: HangmanView
    private lateinit var hiddenWordText: TextView
    private lateinit var livesText: TextView
    private lateinit var wordCounterText: TextView
    private lateinit var hintButton: MaterialButton
    private lateinit var keyboard: LinearLayout

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

        findViewById<MaterialToolbar>(R.id.hangmanToolbar).setNavigationOnClickListener {
            confirmExit()
        }

        scores = HangmanScores(this)

        hangmanView = findViewById(R.id.hangmanView)
        hiddenWordText = findViewById(R.id.hiddenWordText)
        livesText = findViewById(R.id.livesText)
        wordCounterText = findViewById(R.id.wordCounterText)
        hintButton = findViewById(R.id.hintButton)
        keyboard = findViewById(R.id.keyboard)

        hintButton.setOnClickListener { useHint() }
        findViewById<MaterialButton>(R.id.scoresButton).setOnClickListener {
            startActivity(android.content.Intent(this, ScoresActivity::class.java))
        }

        buildKeyboard()
        newGame()
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
            finishRun("You played every word!")
            return
        }

        word = next
        revealed = BooleanArray(word.length)
        usedLetters = BooleanArray(26)
        hangState = 0
        hintAvailable = true
        wordFinished = false

        hangmanView.state = 0
        hintButton.isEnabled = true
        render()
    }

    private fun buildKeyboard() {
        keyboard.removeAllViews()
        val rows = listOf(
            'A'..'G', 'H'..'N', 'O'..'U', 'V'..'Z'
        )
        for (row in rows) {
            val rowLayout = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            }
            for (letter in row) {
                val button = layoutInflater.inflate(
                    R.layout.item_letter_key, rowLayout, false
                ) as MaterialButton
                button.text = letter.toString()
                button.setOnClickListener { pressLetter(letter - 'A') }
                rowLayout.addView(button, LinearLayout.LayoutParams(0, dp(46), 1f))
            }
            keyboard.addView(rowLayout)
        }
    }

    private fun pressLetter(index: Int) {
        if (wordFinished || usedLetters[index]) return
        usedLetters[index] = true

        var hit = false
        for (i in word.indices) {
            if (word[i] - 'a' == index && !revealed[i]) {
                revealed[i] = true
                hit = true
            }
        }

        if (!hit) {
            hangState += 1
            hangmanView.state = hangState
            SoundFx.click()
        } else {
            SoundFx.pawnMove()
        }

        render()

        when {
            revealed.all { it } -> solvedWord()
            hangState == 6 -> failedWord()
        }
    }

    /** Reveals one random unrevealed letter (once per word). */
    private fun useHint() {
        if (!hintAvailable || wordFinished) return
        val candidates = word.indices.filter { !revealed[it] }
        if (candidates.isEmpty()) return
        hintAvailable = false
        hintButton.isEnabled = false
        pressLetter(word[candidates.random()] - 'a')
    }

    private fun solvedWord() {
        wordFinished = true
        wordCount += 1
        render()
        SoundFx.win()
        MaterialAlertDialogBuilder(this)
            .setTitle("Well done!")
            .setMessage("The word was \"$word\".")
            .setCancelable(false)
            .setPositiveButton("Next word") { _, _ -> nextWord() }
            .show()
    }

    private fun failedWord() {
        wordFinished = true
        lives -= 1
        render()
        SoundFx.lose()

        if (lives <= 0) {
            finishRun("Out of lives!")
        } else {
            MaterialAlertDialogBuilder(this)
                .setTitle("Wrong guess!")
                .setMessage("The word was \"$word\". $lives ${if (lives == 1) "life" else "lives"} left.")
                .setCancelable(false)
                .setPositiveButton("Next word") { _, _ -> nextWord() }
                .show()
        }
    }

    private fun finishRun(reason: String) {
        if (wordCount > 0) {
            scores.add(wordCount, SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date()))
        }
        MaterialAlertDialogBuilder(this)
            .setTitle("Game Over!")
            .setMessage("$reason Your score is $wordCount.")
            .setCancelable(false)
            .setPositiveButton("Play again") { _, _ -> newGame() }
            .setNegativeButton("Exit") { _, _ -> finish() }
            .show()
    }

    private fun render() {
        val display = StringBuilder()
        for (i in word.indices) {
            display.append(if (revealed[i]) word[i].uppercaseChar() else '_')
            if (i != word.length - 1) display.append(' ')
        }
        hiddenWordText.text = display.toString()

        livesText.text = "♥ $lives"
        wordCounterText.text = wordCount.toString()

        // Refresh the keyboard key states.
        for (rowIndex in 0 until keyboard.childCount) {
            val row = keyboard.getChildAt(rowIndex) as LinearLayout
            for (keyIndex in 0 until row.childCount) {
                val key = row.getChildAt(keyIndex) as MaterialButton
                val letterIndex = key.text.toString()[0] - 'A'
                key.isEnabled = !usedLetters[letterIndex]
                key.alpha = if (usedLetters[letterIndex]) 0.35f else 1f
            }
        }
    }

    private fun indexOfLetter(index: Int): Int = word.indices.firstOrNull { word[it] - 'a' == index } ?: 0

    private fun confirmExit() {
        if (wordFinished && lives <= 0) {
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

    override fun onDestroy() {
        SoundFx.release()
        super.onDestroy()
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}
