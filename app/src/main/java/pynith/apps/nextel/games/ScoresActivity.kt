package pynith.apps.nextel.games

import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.airbnb.lottie.LottieAnimationView
import pynith.apps.nextel.R
import pynith.apps.nextel.games.hangman.HangmanScore
import pynith.apps.nextel.games.hangman.HangmanScores
import pynith.apps.nextel.views.BaseActivity
import java.util.concurrent.Executors

/** Top-ten Hangman runs, preceded by the original short loading-animation state. */
class ScoresActivity : BaseActivity() {

    private val worker = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_scores)

        findViewById<ImageButton>(R.id.scoresHomeButton).setOnClickListener { finish() }
        findViewById<ImageButton>(R.id.emptyScoresHomeButton).setOnClickListener { finish() }

        val appContext = applicationContext
        worker.execute {
            val scores = HangmanScores(appContext).sortedForDisplay().take(10)
            runOnUiThread {
                if (isFinishing || isDestroyed) return@runOnUiThread
                showScores(scores)
            }
        }
    }

    private fun showScores(scores: List<HangmanScore>) {
        val content = findViewById<LinearLayout>(R.id.scoresContent)
        val emptyState = findViewById<FrameLayout>(R.id.scoresEmptyState)
        val loading = findViewById<FrameLayout>(R.id.scoresLoading)
        val loadingAnimation = findViewById<LottieAnimationView>(R.id.scoresLoadingAnimation)
        val list = findViewById<LinearLayout>(R.id.scoresList)

        loadingAnimation.cancelAnimation()
        loading.visibility = View.GONE

        if (scores.isEmpty()) {
            content.visibility = View.GONE
            emptyState.visibility = View.VISIBLE
            return
        }

        emptyState.visibility = View.GONE
        content.visibility = View.VISIBLE
        list.removeAllViews()
        val medals = arrayOf("🥇", "🥈", "🥉")
        scores.forEachIndexed { index, score ->
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(0, 0, 0, dp(8))
            }

            row.addView(
                TextView(this).apply {
                    text = if (index < medals.size) "${medals[index]}${index + 1}" else "${index + 1}"
                    setTextColor(Color.WHITE)
                    textSize = 27f
                    gravity = Gravity.CENTER
                    typeface = android.graphics.Typeface.create("sans-serif-light", android.graphics.Typeface.NORMAL)
                },
                LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            )
            row.addView(
                TextView(this).apply {
                    text = formatScoreDate(score.date)
                    setTextColor(Color.WHITE)
                    textSize = 27f
                    gravity = Gravity.CENTER
                    typeface = android.graphics.Typeface.create("sans-serif-light", android.graphics.Typeface.NORMAL)
                },
                LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 2f)
            )
            row.addView(
                TextView(this).apply {
                    text = score.score.toString()
                    setTextColor(ContextCompat.getColor(this@ScoresActivity, R.color.nextel_white))
                    textSize = 27f
                    gravity = Gravity.CENTER
                    typeface = android.graphics.Typeface.create("sans-serif-light", android.graphics.Typeface.NORMAL)
                },
                LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            )
            list.addView(row)
        }
    }

    /** Matches the source date_format pattern `[yy, '-', M, '-', d]`. */
    private fun formatScoreDate(raw: String): String {
        val date = raw.substringBefore('T').substringBefore(' ')
        val parts = date.split('-')
        if (parts.size != 3) return raw
        val year = parts[0].toIntOrNull() ?: return raw
        val month = parts[1].toIntOrNull() ?: return raw
        val day = parts[2].toIntOrNull() ?: return raw
        return String.format(java.util.Locale.US, "%02d-%d-%d", year % 100, month, day)
    }

    override fun onDestroy() {
        worker.shutdownNow()
        super.onDestroy()
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}
