package pynith.apps.nextel.games.widget

import android.content.Context
import android.graphics.Color
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import pynith.apps.nextel.R


class SmallFeatureCardView(
    context: Context,
    title: String,
    imageRes: Int,
    badge: String,
    onClick: () -> Unit
) : LinearLayout(context) {

    init {
        val view = LayoutInflater.from(context)
            .inflate(R.layout.card_small_feature, this, true)

        val rootView = view.findViewById<FrameLayout>(R.id.rootView)
        val image = view.findViewById<ImageView>(R.id.image)
        val titleView = view.findViewById<TextView>(R.id.titleView)
        val badgeView = view.findViewById<TextView>(R.id.badge)

        val width = resources.displayMetrics.widthPixels / 3 + 42

        rootView.layoutParams = LayoutParams(width, LayoutParams.WRAP_CONTENT)
        image.setImageResource(imageRes)

        titleView.text = title
        badgeView.text = badge
        badgeView.setBackgroundColor(
            if (badge === "NEW")
                -65536
            else
                -16776961)

        if(badge.isEmpty()){
            badgeView.visibility = View.GONE
        }


        setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    v.scaleX = 0.96f
                    v.scaleY = 0.96f
                }
                MotionEvent.ACTION_UP -> {
                    v.scaleX = 1f
                    v.scaleY = 1f
                    performClick()
                }
                MotionEvent.ACTION_CANCEL -> {
                    v.scaleX = 1f
                    v.scaleY = 1f
                }
            }
            false
        }

        setOnClickListener { onClick() }
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}