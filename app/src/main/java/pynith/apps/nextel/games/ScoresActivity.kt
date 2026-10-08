package pynith.apps.nextel.games

import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.material.appbar.MaterialToolbar
import pynith.apps.nextel.R
import pynith.apps.nextel.games.hangman.HangmanScores
import pynith.apps.nextel.views.BaseActivity

/** Top-10 Hangman runs (the Flutter module's score_screen). */
class ScoresActivity : BaseActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_scores)

        findViewById<MaterialToolbar>(R.id.scoresToolbar).setNavigationOnClickListener {
            finish()
        }

        val list = findViewById<LinearLayout>(R.id.scoresList)
        val scores = HangmanScores(this).all().sortedByDescending { it.score }.take(10)

        if (scores.isEmpty()) {
            val empty = TextView(this).apply {
                text = "No scores yet — play a round of Hangman!"
                setTextColor(Color.parseColor("#B3FFFFFF"))
                textSize = 15f
                gravity = Gravity.CENTER
                setPadding(0, dp(32), 0, dp(32))
            }
            list.addView(empty)
            return
        }

        val medals = arrayOf("🥇", "🥈", "🥉")
        scores.forEachIndexed { index, score ->
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(0, dp(10), 0, dp(10))
            }

            val rank = TextView(this).apply {
                text = if (index < 3) "${medals[index]}" else "${index + 1}."
                setTextColor(Color.WHITE)
                textSize = 18f
                gravity = Gravity.CENTER
            }
            row.addView(rank, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))

            val date = TextView(this).apply {
                text = score.date
                setTextColor(Color.WHITE)
                textSize = 16f
                gravity = Gravity.CENTER
            }
            row.addView(date, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 2f))

            val value = TextView(this).apply {
                text = score.score.toString()
                setTextColor(Color.parseColor("#69F0AE"))
                textSize = 18f
                gravity = Gravity.CENTER
            }
            row.addView(value, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))

            list.addView(row)

            if (index != scores.size - 1) {
                val divider = View(this)
                divider.setBackgroundColor(Color.parseColor("#26FFFFFF"))
                list.addView(
                    divider,
                    LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT, dp(1)
                    )
                )
            }
        }
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}
