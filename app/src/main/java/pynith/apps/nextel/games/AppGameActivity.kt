package pynith.apps.nextel.games

import android.content.Intent
import android.os.Bundle
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.Toast
import com.google.android.material.appbar.MaterialToolbar
import pynith.apps.nextel.R
import pynith.apps.nextel.games.widget.FeatureMiddleCardView
import pynith.apps.nextel.games.widget.FeaturedCardSliverView
import pynith.apps.nextel.games.widget.FeaturedCardView
import pynith.apps.nextel.games.widget.SmallFeatureCardView
import pynith.apps.nextel.views.BaseActivity

/**
 * Games hub (the Flutter module's AppGameScreen): featured Ludo, the dice
 * betting game and Hangman are playable; the remaining cards are teasers.
 */
class AppGameActivity : BaseActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_games)

        findViewById<MaterialToolbar>(R.id.gamesToolbar).setNavigationOnClickListener {
            onBackPressedDispatcher.onBackPressed()
        }

        // Featured Ludo game — fully playable.
        findViewById<FrameLayout>(R.id.featuredContainer).addView(
            FeaturedCardSliverView(
                context = this,
                imageRes = R.drawable.ludo,
                title = "Featured Ludo Game",
                subtitle = "Classic four-player Ludo on one device.",
                onClick = { openGame(LudoActivity::class.java) }
            )
        )

        // Quick games row.
        val smallRow = findViewById<LinearLayout>(R.id.smallRow)
        smallRow.addView(
            SmallFeatureCardView(this, "Dice Rolling", R.drawable.ads_card2, "NEW") {
                openGame(DiceActivity::class.java)
            },
            rowParams()
        )
        smallRow.addView(
            SmallFeatureCardView(this, "Newbie Task", R.drawable.ads_card3, "HOT") {
                showToast("Newbie Task game coming soon.")
            },
            rowParams()
        )
        smallRow.addView(
            SmallFeatureCardView(this, "Voucher Claim", R.drawable.ads_card4, "") {
                showToast("Voucher Claim game coming soon.")
            },
            rowParams()
        )

        // Board & word games row.
        val middleRow = findViewById<LinearLayout>(R.id.middleRow)
        middleRow.addView(
            FeatureMiddleCardView(this, "Ludo Games", R.drawable.ludo) {
                openGame(LudoActivity::class.java)
            }
        )
        middleRow.addView(
            FeatureMiddleCardView(this, "Hangman Words", R.drawable.hangman) {
                openGame(HangmanActivity::class.java)
            }
        )

        // Coming soon feature.
        findViewById<FrameLayout>(R.id.featuredBottomContainer).addView(
            FeaturedCardView(
                context = this,
                imageRes = R.drawable.hangman,
                title = "Featured Hangman",
                subtitle = "Guess the word before the gallows fill up.",
                onClick = { openGame(HangmanActivity::class.java) }
            )
        )
    }

    private fun openGame(activityClass: Class<*>) {
        startActivity(Intent(this, activityClass))
        overridePendingTransition(R.anim.anim_pull_in_right, R.anim.fade_out)
    }

    private fun rowParams(): LinearLayout.LayoutParams {
        return LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            marginEnd = dp(14)
        }
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun showToast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }
}
