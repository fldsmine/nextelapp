package pynith.apps.nextel.games

import android.content.Intent
import android.os.Bundle
import android.widget.FrameLayout
import android.widget.LinearLayout
import com.google.android.material.appbar.MaterialToolbar
import pynith.apps.nextel.R
import pynith.apps.nextel.games.widget.FeatureMiddleCardView
import pynith.apps.nextel.games.widget.FeaturedCardSliverView
import pynith.apps.nextel.games.widget.FeaturedCardView
import pynith.apps.nextel.games.widget.SmallFeatureCardView
import pynith.apps.nextel.views.BaseActivity

/** Native hub that follows the original Flutter card order, copy, and actions. */
class AppGameActivity : BaseActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_games)

        findViewById<MaterialToolbar>(R.id.gamesToolbar).setNavigationOnClickListener {
            onBackPressedDispatcher.onBackPressed()
        }

        // The first featured card opens Ludo.
        findViewById<FrameLayout>(R.id.featuredContainer).addView(
            FeaturedCardView(
                context = this,
                imageRes = R.drawable.ludo,
                title = "🔥 Featured Feature",
                subtitle = "This is a feature coming soon",
                onClick = { openGame(LudoActivity::class.java) }
            )
        )

        val smallRow = findViewById<LinearLayout>(R.id.smallRow)
        smallRow.addView(
            SmallFeatureCardView(this, "Feature March", R.drawable.ads_card2, "NEW") {
                openGame(DiceActivity::class.java)
            },
            rowParams()
        )
        smallRow.addView(
            SmallFeatureCardView(this, "Newbie Task", R.drawable.ads_card3, "HOT") { },
            rowParams()
        )
        smallRow.addView(
            SmallFeatureCardView(this, "Voucher Claim", R.drawable.ads_card4, "") { },
            rowParams()
        )

        val middleRow = findViewById<LinearLayout>(R.id.middleRow)
        middleRow.addView(
            FeatureMiddleCardView(this, "Feature March", R.drawable.ludo, "NEW") { }
        )
        middleRow.addView(
            FeatureMiddleCardView(this, "Feature Tournament", R.drawable.hangman, "HOT") { }
        )

        // Hangman is launched from the final featured card; the middle card is
        // intentionally only a teaser, as in the source screen.
        findViewById<FrameLayout>(R.id.featuredBottomContainer).addView(
            FeaturedCardSliverView(
                context = this,
                imageRes = R.drawable.hangman,
                title = "Featured Feature",
                subtitle = "This is a feature coming soon",
                onClick = { openGame(HangmanActivity::class.java) }
            )
        )
    }

    private fun openGame(activityClass: Class<*>) {
        startActivity(Intent(this, activityClass))
        overridePendingTransition(R.anim.anim_pull_in_right, R.anim.fade_out)
    }

    private fun rowParams(): LinearLayout.LayoutParams =
        LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            marginEnd = dp(14)
        }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}
