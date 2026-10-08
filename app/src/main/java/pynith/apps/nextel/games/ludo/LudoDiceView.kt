package pynith.apps.nextel.games.ludo

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Movie
import android.graphics.Paint
import android.graphics.RectF
import android.os.SystemClock
import android.util.AttributeSet
import android.view.View
import kotlin.math.min
import pynith.apps.nextel.R

/** Source Ludo dice faces/GIF with the source's active-player ripple. */
class LudoDiceView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val faces: List<Bitmap> = listOf(
        R.drawable.ludo_dice_1,
        R.drawable.ludo_dice_2,
        R.drawable.ludo_dice_3,
        R.drawable.ludo_dice_4,
        R.drawable.ludo_dice_5,
        R.drawable.ludo_dice_6
    ).map { BitmapFactory.decodeResource(resources, it) }
    private val rollingMovie: Movie? = try {
        resources.openRawResource(R.raw.ludo_dice_draw).use { Movie.decodeStream(it) }
    } catch (_: Exception) {
        null
    }
    private val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val ripplePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
    }
    private val destination = RectF()
    private var animationStart = SystemClock.uptimeMillis()
    private var pulseStart = SystemClock.uptimeMillis()

    var value: Int = 1
        set(value) {
            field = value.coerceIn(1, 6)
            invalidate()
        }

    var rolling: Boolean = false
        set(value) {
            if (field == value) return
            field = value
            animationStart = SystemClock.uptimeMillis()
            invalidate()
        }

    var highlight: Boolean = false
        set(value) {
            if (field == value) return
            field = value
            pulseStart = SystemClock.uptimeMillis()
            invalidate()
        }

    var accentColor: Int = LudoPlayerType.GREEN.color
        set(value) {
            field = value
            invalidate()
        }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val width = MeasureSpec.getSize(widthMeasureSpec)
        val height = MeasureSpec.getSize(heightMeasureSpec)
        val size = when {
            MeasureSpec.getMode(widthMeasureSpec) == MeasureSpec.EXACTLY &&
                MeasureSpec.getMode(heightMeasureSpec) == MeasureSpec.EXACTLY -> min(width, height)
            MeasureSpec.getMode(widthMeasureSpec) != MeasureSpec.UNSPECIFIED -> width
            MeasureSpec.getMode(heightMeasureSpec) != MeasureSpec.UNSPECIFIED -> height
            else -> dp(50f).toInt()
        }
        setMeasuredDimension(size, size)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val size = min(width, height).toFloat()
        if (size <= 0f) return

        val centerX = width / 2f
        val centerY = height / 2f
        if (highlight) {
            val phase = ((SystemClock.uptimeMillis() - pulseStart) % 900L) / 900f
            ripplePaint.color = accentColor
            ripplePaint.strokeWidth = dp(2f)
            for (ripple in 0 until 3) {
                val ripplePhase = (phase + ripple / 3f) % 1f
                ripplePaint.alpha = (210 * (1f - ripplePhase)).toInt().coerceIn(0, 210)
                canvas.drawCircle(centerX, centerY, dp(20f) + ripplePhase * dp(12f), ripplePaint)
            }
            ripplePaint.alpha = 255
            postInvalidateOnAnimation()
        }

        if (rolling && rollingMovie != null && rollingMovie.width() > 0 && rollingMovie.height() > 0) {
            val duration = rollingMovie.duration().takeIf { it > 0 } ?: 1000
            rollingMovie.setTime(((SystemClock.uptimeMillis() - animationStart) % duration).toInt())
            val scale = size / maxOf(rollingMovie.width(), rollingMovie.height())
            canvas.save()
            canvas.translate(centerX - rollingMovie.width() * scale / 2f, centerY - rollingMovie.height() * scale / 2f)
            canvas.scale(scale, scale)
            rollingMovie.draw(canvas, 0f, 0f)
            canvas.restore()
            postInvalidateOnAnimation()
            return
        }

        val inset = size * 0.04f
        destination.set(inset, inset, width - inset, height - inset)
        canvas.drawBitmap(faces[value - 1], null, destination, bitmapPaint)
    }

    private fun dp(value: Float): Float = value * resources.displayMetrics.density
}
