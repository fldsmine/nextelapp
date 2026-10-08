package pynith.apps.nextel.games.ludo

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import android.view.animation.LinearInterpolator
import kotlin.math.min
import pynith.apps.nextel.R
import kotlin.math.sin

/**
 * Draws the original bundled Ludo board image with native pawn overlays,
 * turn/winner artwork, ripple highlights, and animated cell-by-cell moves.
 */
class LudoBoardView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    /** Called with the pawn index when a highlighted pawn of the current player is tapped. */
    var onPawnPicked: ((pawnIndex: Int) -> Unit)? = null

    private var game: LudoGame? = null
    private var highlighted: Set<Int> = emptySet()

    private val boardBitmap = BitmapFactory.decodeResource(resources, R.drawable.ludo_board)
    private val crownBitmaps: List<Bitmap> = listOf(
        R.drawable.ludo_crown_1st,
        R.drawable.ludo_crown_2nd,
        R.drawable.ludo_crown_3rd
    ).map { BitmapFactory.decodeResource(resources, it) }
    private val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val boardRect = RectF()
    private val boardClipPath = Path()
    private val pawnPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val pawnBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 3f
        color = Color.WHITE
    }
    private val highlightPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = Color.parseColor("#FFB300")
    }
    private val indicatorPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
    }

    private var cell = 0f
    private var originX = 0f
    private var originY = 0f
    private var pulseStart = 0L

    private class AnimState(
        val type: LudoPlayerType,
        val pawnIndex: Int,
        val points: List<Pair<Float, Float>>,
        var x: Float,
        var y: Float
    )

    private var anim: AnimState? = null
    private var animator: ValueAnimator? = null
    private var suppressAnimEnd = false

    private val pulseAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 900
        repeatCount = ValueAnimator.INFINITE
        interpolator = LinearInterpolator()
        addUpdateListener { invalidate() }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        pulseStart = System.currentTimeMillis()
        if (highlighted.isNotEmpty()) pulseAnimator.start()
    }

    override fun onDetachedFromWindow() {
        pulseAnimator.cancel()
        suppressAnimEnd = true
        animator?.cancel()
        animator = null
        anim = null
        super.onDetachedFromWindow()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val widthMode = MeasureSpec.getMode(widthMeasureSpec)
        val heightMode = MeasureSpec.getMode(heightMeasureSpec)
        val width = MeasureSpec.getSize(widthMeasureSpec)
        val height = MeasureSpec.getSize(heightMeasureSpec)
        val size = when {
            widthMode == MeasureSpec.EXACTLY && heightMode == MeasureSpec.EXACTLY -> min(width, height)
            widthMode == MeasureSpec.EXACTLY -> width
            heightMode == MeasureSpec.EXACTLY -> height
            widthMode != MeasureSpec.UNSPECIFIED && heightMode != MeasureSpec.UNSPECIFIED -> min(width, height)
            widthMode != MeasureSpec.UNSPECIFIED -> width
            heightMode != MeasureSpec.UNSPECIFIED -> height
            else -> dp(300f).toInt()
        }
        setMeasuredDimension(size, size)
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        cell = min(w, h) / 15f
        originX = (w - cell * 15f) / 2f
        originY = (h - cell * 15f) / 2f
        boardRect.set(originX, originY, originX + cell * 15f, originY + cell * 15f)
        boardClipPath.reset()
        boardClipPath.addRoundRect(boardRect, dp(40f), dp(40f), Path.Direction.CW)
    }

    fun setState(game: LudoGame, highlighted: Set<Int>) {
        this.game = game
        if (highlighted != this.highlighted) {
            this.highlighted = highlighted
            if (highlighted.isNotEmpty()) {
                pulseStart = System.currentTimeMillis()
                if (isAttachedToWindow && !pulseAnimator.isStarted) pulseAnimator.start()
            } else {
                pulseAnimator.cancel()
            }
        }
        invalidate()
    }

    private fun centerOf(x: Float, y: Float): Pair<Float, Float> =
        (originX + (x + 0.5f) * cell) to (originY + (y + 0.5f) * cell)

    /** Pixel position of a pawn at a given step (yard slots included). */
    fun positionForStep(type: LudoPlayerType, pawnIndex: Int, step: Int): Pair<Float, Float> {
        return if (step == -1) {
            val slot = LudoBoard.yard(type)[pawnIndex]
            centerOf(slot[0], slot[1])
        } else {
            val pathCell = LudoBoard.path(type)[step.coerceIn(0, LudoGame.FINAL_STEP)]
            centerOf(pathCell[0].toFloat(), pathCell[1].toFloat())
        }
    }

    fun pawnPixelPosition(type: LudoPlayerType, pawnIndex: Int): Pair<Float, Float> {
        val step = game?.step(type, pawnIndex) ?: -1
        return positionForStep(type, pawnIndex, step)
    }

    /**
     * Animates [type]'s pawn from [startPoint] through [waypoints] (pixel
     * centers of each cell it enters) and reports completion.
     */
    fun animatePawn(
        type: LudoPlayerType,
        pawnIndex: Int,
        startPoint: Pair<Float, Float>,
        waypoints: List<Pair<Float, Float>>,
        onStep: () -> Unit = {},
        onDone: () -> Unit
    ) {
        val points = mutableListOf(startPoint)
        points += waypoints

        anim = AnimState(type, pawnIndex, points, startPoint.first, startPoint.second)

        animator?.let {
            suppressAnimEnd = true
            it.cancel()
        }
        suppressAnimEnd = false

        val duration = (points.size * 190L).coerceIn(200L, 2600L)
        var lastSegment = -1
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            setDuration(duration)
            interpolator = LinearInterpolator()
            addUpdateListener { animation ->
                val state = anim ?: return@addUpdateListener
                val fraction = animation.animatedValue as Float
                val segments = (state.points.size - 1).coerceAtLeast(1)
                val position = fraction * segments
                val index = position.toInt().coerceAtMost(segments - 1)
                if (index != lastSegment) {
                    lastSegment = index
                    onStep()
                }
                val local = position - index
                val (x1, y1) = state.points[index]
                val (x2, y2) = state.points[index + 1]
                state.x = x1 + (x2 - x1) * local
                state.y = y1 + (y2 - y1) * local
                invalidate()
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    if (suppressAnimEnd) {
                        suppressAnimEnd = false
                        return
                    }
                    anim = null
                    invalidate()
                    onDone()
                }
            })
            start()
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val g = game ?: return
        if (cell <= 0f) return

        val boardSave = canvas.save()
        canvas.clipPath(boardClipPath)
        drawBoard(canvas)
        drawPawns(canvas, g)
        drawHighlights(canvas, g)

        // The animated pawn rides on top of all stationary pawns.
        anim?.let { state ->
            drawPawn(canvas, state.x, state.y, state.type.color, cell * 0.36f)
        }

        // Match the source Stack order: crowns, then turn text.
        drawCrowns(canvas, g)
        drawTurnIndicator(canvas, g)
        canvas.restoreToCount(boardSave)
    }

    private fun drawBoard(canvas: Canvas) {
        canvas.drawBitmap(boardBitmap, null, boardRect, bitmapPaint)
    }

    private fun drawHighlights(canvas: Canvas, g: LudoGame) {
        if (highlighted.isEmpty()) return
        val phase = ((System.currentTimeMillis() - pulseStart) % 900L) / 900f
        highlightPaint.strokeWidth = cell * 0.055f
        highlightPaint.color = g.currentTurn.color
        val minimumRadius = dp(20f)

        for (wave in 0 until 3) {
            val wavePhase = (phase + wave / 3f) % 1f
            highlightPaint.alpha = (220 * (1f - wavePhase)).toInt().coerceIn(0, 220)
            val radius = minimumRadius + wavePhase * dp(15f)
            for (pawnIndex in highlighted) {
                val (x, y) = pawnPixelPosition(g.currentTurn, pawnIndex)
                canvas.drawCircle(x, y, radius, highlightPaint)
            }
        }
        highlightPaint.alpha = 255
    }

    /** "Your turn!" and the current stage sit in the active player's yard. */
    private fun drawTurnIndicator(canvas: Canvas, g: LudoGame) {
        val (yardX, yardY) = when (g.currentTurn) {
            LudoPlayerType.GREEN -> 0f to 0f
            LudoPlayerType.YELLOW -> 9f to 0f
            LudoPlayerType.BLUE -> 9f to 9f
            LudoPlayerType.RED -> 0f to 9f
        }
        val centerX = originX + (yardX + 3f) * cell
        val centerY = originY + (yardY + 3f) * cell
        val stageText = when (g.gameState) {
            LudoGameState.THROW_DICE -> "Roll the dice"
            LudoGameState.PICK_PAWN -> "Pick a pawn"
            LudoGameState.MOVING -> "Pawn is moving..."
            LudoGameState.FINISH -> "Game is over"
        }

        indicatorPaint.textAlign = Paint.Align.CENTER
        indicatorPaint.typeface = android.graphics.Typeface.DEFAULT_BOLD
        indicatorPaint.isFakeBoldText = true
        indicatorPaint.textSize = dp(12f)
        indicatorPaint.color = g.currentTurn.color
        canvas.drawText("Your turn!", centerX, centerY, indicatorPaint)

        indicatorPaint.typeface = android.graphics.Typeface.DEFAULT
        indicatorPaint.isFakeBoldText = false
        indicatorPaint.textSize = dp(8f)
        indicatorPaint.color = Color.BLACK
        canvas.drawText(stageText, centerX, centerY + dp(12f), indicatorPaint)
    }

    /** Source crown artwork appears in the yards in finishing order. */
    private fun drawCrowns(canvas: Canvas, g: LudoGame) {
        val boardSize = cell * 15f
        for ((rank, type) in g.winners.withIndex()) {
            val image = crownBitmaps.getOrNull(rank) ?: continue
            val x = originX + (if (type == LudoPlayerType.YELLOW || type == LudoPlayerType.BLUE) boardSize * 0.6f else 0f)
            val y = originY + (if (type == LudoPlayerType.BLUE || type == LudoPlayerType.RED) boardSize * 0.6f else 0f)
            val cardSize = boardSize * 0.4f
            val destination = RectF(
                x + cell,
                y + cell,
                x + cardSize - cell,
                y + cardSize - cell
            )
            canvas.drawBitmap(image, null, destination, bitmapPaint)
        }
    }

    private fun drawPawns(canvas: Canvas, g: LudoGame) {
        data class Placed(val type: LudoPlayerType, val index: Int, val x: Float, val y: Float)

        val placed = mutableListOf<Placed>()
        val drawingOrder = LudoPlayerType.entries.filter { it != g.currentTurn } + g.currentTurn
        for (type in drawingOrder) {
            for (pawn in 0 until 4) {
                if (anim != null && anim!!.type == type && anim!!.pawnIndex == pawn) continue
                val (x, y) = pawnPixelPosition(type, pawn)
                placed += Placed(type, pawn, x, y)
            }
        }

        // Fan out pawns sharing the same cell.
        val groups = placed.groupBy { it.x to it.y }
        for (group in groups.values) {
            group.forEachIndexed { positionInGroup, pawn ->
                val offset = (positionInGroup - (group.size - 1) / 2f) * cell * 0.22f
                drawPawn(canvas, pawn.x + offset, pawn.y, pawn.type.color, cell * 0.33f)
            }
        }
    }

    private fun drawPawn(canvas: Canvas, x: Float, y: Float, color: Int, radius: Float) {
        pawnPaint.color = color
        canvas.drawCircle(x, y, radius, pawnPaint)
        pawnBorderPaint.strokeWidth = radius * 0.22f
        canvas.drawCircle(x, y, radius * 0.88f, pawnBorderPaint)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.action != MotionEvent.ACTION_DOWN) return super.onTouchEvent(event)

        var bestPawn = -1
        var bestDistance = Float.MAX_VALUE
        for (pawnIndex in highlighted) {
            val (x, y) = pawnPixelPosition(game?.currentTurn ?: return false, pawnIndex)
            val distance = Math.hypot((event.x - x).toDouble(), (event.y - y).toDouble()).toFloat()
            if (distance < cell * 0.9f && distance < bestDistance) {
                bestDistance = distance
                bestPawn = pawnIndex
            }
        }

        if (bestPawn >= 0) {
            performClick()
            onPawnPicked?.invoke(bestPawn)
            return true
        }
        return false
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }

    private fun dp(value: Float): Float = value * resources.displayMetrics.density
}
