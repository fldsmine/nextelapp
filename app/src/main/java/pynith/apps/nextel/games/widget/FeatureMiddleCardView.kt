package pynith.apps.nextel.games.widget

import android.content.Context
import android.view.LayoutInflater
import android.view.MotionEvent
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.view.ViewCompat
import pynith.apps.nextel.R

class FeatureMiddleCardView(
    context: Context,
    title: String,
    imageRes: Int,
    onClick: () -> Unit
) : LinearLayout(context) {

    init {
        val view = LayoutInflater.from(context)
            .inflate(R.layout.card_feature_middle, this, true)

        val rootView = view.findViewById<LinearLayout>(R.id.rootView)
        val image = view.findViewById<ImageView>(R.id.image)
        val titleView = view.findViewById<TextView>(R.id.titleView)

        val width = resources.displayMetrics.widthPixels / 2 - 10
        rootView.layoutParams = LayoutParams(width, LayoutParams.WRAP_CONTENT)

        image.setImageResource(imageRes)
        titleView.text = title

        setupTouchAnimation()
        setOnClickListener { onClick() }
    }
    private fun setupTouchAnimation() {
        setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    animateScale(0.96f)
                }
                MotionEvent.ACTION_UP -> {
                    animateScale(1.0f)
                    performClick()
                }
                MotionEvent.ACTION_CANCEL -> {
                    animateScale(1.0f)
                }
            }
            true
        }
    }

    private fun animateScale(scale: Float) {
        ViewCompat.animate(this)
            .scaleX(scale)
            .scaleY(scale)
            .setDuration(80)
            .start()
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}