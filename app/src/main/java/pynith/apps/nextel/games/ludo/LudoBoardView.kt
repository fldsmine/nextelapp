package pynith.apps.nextel.games.ludo

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.Context
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
import kotlin.math.sin

/**
 * Draws the Ludo board (Flutter module geometry): ring, colored start and
 * home-column cells, star safe cells, yards, center triangles, pawns, the
 * current-turn indicator and winner crowns. Pawns that may be picked get a
 * pulsing highlight ring; moves are animated cell by cell.
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

    private val boardPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val cellPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val cellBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1.5f
        color = Color.parseColor("#C9D4CE")
    }
    private val starPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        color = Color.parseColor("#8FA39A")
    }
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
    private val crownPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
    }
    private val cellRect = RectF()
    private val centerPath = Path()

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

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        cell = min(w, h) / 15f
        originX = (w - cell * 15f) / 2f
        originY = (h - cell * 15f) / 2f
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
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            setDuration(duration)
            interpolator = LinearInterpolator()
            addUpdateListener { animation ->
                val state = anim ?: return@addUpdateListener
                val fraction = animation.animatedValue as Float
                val segments = (state.points.size - 1).coerceAtLeast(1)
                val position = fraction * segments
                val index = position.toInt().coerceAtMost(segments - 1)
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

        drawBoard(canvas, g)
        drawPawns(canvas, g)

        // Pulsing highlight on pickable pawns.
        if (highlighted.isNotEmpty()) {
            val phase = ((System.currentTimeMillis() - pulseStart) % 900) / 900f
            val pulse = 0.5f + 0.5f * sin((phase * 2 * Math.PI).toFloat())
            highlightPaint.strokeWidth = cell * (0.06f + 0.05f * pulse)
            for (pawnIndex in highlighted) {
                val (x, y) = pawnPixelPosition(g.currentTurn, pawnIndex)
                canvas.drawCircle(x, y, cell * (0.42f + 0.06f * pulse), highlightPaint)
            }
        }

        // The animated pawn rides on top.
        anim?.let { state ->
            drawPawn(canvas, state.x, state.y, state.type.color, cell * 0.36f)
        }

        drawTurnIndicator(canvas, g)
        drawCrowns(canvas, g)
    }

    private fun drawBoard(canvas: Canvas, g: LudoGame) {
        boardPaint.color = Color.WHITE
        canvas.drawRoundRect(
            originX + cell * 0.1f, originY + cell * 0.1f,
            originX + cell * 14.9f, originY + cell * 14.9f,
            cell * 0.8f, cell * 0.8f, boardPaint
        )

        // Ring cells with start-cell colors and star markers.
        val startOwners = mapOf(
            LudoBoard.cell(1, 6) to LudoPlayerType.GREEN,
            LudoBoard.cell(8, 1) to LudoPlayerType.YELLOW,
            LudoBoard.cell(13, 8) to LudoPlayerType.BLUE,
            LudoBoard.cell(6, 13) to LudoPlayerType.RED
        )
        for (cellXy in LudoBoard.ring) {
            val key = LudoBoard.cell(cellXy[0], cellXy[1])
            cellRect.set(
                originX + cellXy[0] * cell, originY + cellXy[1] * cell,
                originX + (cellXy[0] + 1) * cell, originY + (cellXy[1] + 1) * cell
            )
            cellPaint.color = startOwners[key]?.color ?: Color.WHITE
            canvas.drawRect(cellRect, cellPaint)
            canvas.drawRect(cellRect, cellBorderPaint)

            if (key in LudoBoard.safeCells && key !in startOwners) {
                val (cx, cy) = centerOf(cellXy[0].toFloat(), cellXy[1].toFloat())
                starPaint.textSize = cell * 0.5f
                canvas.drawText(STAR, cx, cy + cell * 0.18f, starPaint)
            }
        }

        // Colored home columns (each player's last 6 path cells).
        for (type in LudoPlayerType.entries) {
            val path = LudoBoard.path(type)
            for (step in 51..LudoGame.FINAL_STEP) {
                val homeCell = path[step]
                cellRect.set(
                    originX + homeCell[0] * cell, originY + homeCell[1] * cell,
                    originX + (homeCell[0] + 1) * cell, originY + (homeCell[1] + 1) * cell
                )
                cellPaint.color = type.color
                canvas.drawRect(cellRect, cellPaint)
                canvas.drawRect(cellRect, cellBorderPaint)
            }
        }

        drawCenterTriangles(canvas)
        for (type in LudoPlayerType.entries) {
            drawYard(canvas, type, g)
        }
    }

    private fun drawCenterTriangles(canvas: Canvas) {
        val left = originX + 6 * cell
        val top = originY + 6 * cell
        val right = originX + 9 * cell
        val bottom = originY + 9 * cell
        val midX = originX + 7.5f * cell
        val midY = originY + 7.5f * cell

        // Green enters from the left, yellow from the top,
        // blue from the right, red from the bottom (module geometry).
        drawTriangle(canvas, left, top, left, bottom, midX, midY, LudoPlayerType.GREEN.color)
        drawTriangle(canvas, left, top, right, top, midX, midY, LudoPlayerType.YELLOW.color)
        drawTriangle(canvas, right, top, right, bottom, midX, midY, LudoPlayerType.BLUE.color)
        drawTriangle(canvas, left, bottom, right, bottom, midX, midY, LudoPlayerType.RED.color)
    }

    private fun drawTriangle(
        canvas: Canvas,
        x1: Float, y1: Float,
        x2: Float, y2: Float,
        x3: Float, y3: Float,
        color: Int
    ) {
        centerPath.reset()
        centerPath.moveTo(x1, y1)
        centerPath.lineTo(x2, y2)
        centerPath.lineTo(x3, y3)
        centerPath.close()
        cellPaint.color = color
        canvas.drawPath(centerPath, cellPaint)
        canvas.drawPath(centerPath, cellBorderPaint)
    }

    private fun drawYard(canvas: Canvas, type: LudoPlayerType, g: LudoGame) {
        // Yard corners from the module's home slots: green TL, yellow TR,
        // blue BR, red BL.
        val (startX, startY) = when (type) {
            LudoPlayerType.GREEN -> 0 to 0
            LudoPlayerType.YELLOW -> 9 to 0
            LudoPlayerType.BLUE -> 9 to 9
            LudoPlayerType.RED -> 0 to 9
        }
        val inset = cell * 0.35f
        val left = originX + startX * cell + inset
        val top = originY + startY * cell + inset
        val right = originX + (startX + 6) * cell - inset
        val bottom = originY + (startY + 6) * cell - inset
        val radius = cell * 1.4f

        cellPaint.color = type.color
        canvas.drawRoundRect(left, top, right, bottom, radius, radius, cellPaint)

        // Bright outline on the active player's yard.
        if (g.currentTurn == type && !g.isFinished) {
            highlightPaint.strokeWidth = cell * 0.14f
            canvas.drawRoundRect(left, top, right, bottom, radius, radius, highlightPaint)
        }

        boardPaint.color = Color.WHITE
        canvas.drawRoundRect(
            left + cell * 0.85f, top + cell * 0.85f,
            right - cell * 0.85f, bottom - cell * 0.85f,
            radius * 0.7f, radius * 0.7f, boardPaint
        )

        for (slot in LudoBoard.yard(type)) {
            val (cx, cy) = centerOf(slot[0], slot[1])
            pawnPaint.color = type.color
            canvas.drawCircle(cx, cy, cell * 0.34f, pawnPaint)
            pawnPaint.color = Color.WHITE
            canvas.drawCircle(cx, cy, cell * 0.22f, pawnPaint)
        }
    }

    private fun drawPawns(canvas: Canvas, g: LudoGame) {
        data class Placed(val type: LudoPlayerType, val index: Int, val x: Float, val y: Float)

        val placed = mutableListOf<Placed>()
        for (type in LudoPlayerType.entries) {
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

    /** "Your turn!" + stage text pinned to the current player's corner. */
    private fun drawTurnIndicator(canvas: Canvas, g: LudoGame) {
        if (g.isFinished) return
        val type = g.currentTurn
        val boxLeft: Float
        val boxTop: Float
        when (type) {
            LudoPlayerType.GREEN -> { boxLeft = originX + cell; boxTop = originY + cell }
            LudoPlayerType.YELLOW -> { boxLeft = originX + 9 * cell; boxTop = originY + cell }
            LudoPlayerType.BLUE -> { boxLeft = originX + 9 * cell; boxTop = originY + 9 * cell }
            LudoPlayerType.RED -> { boxLeft = originX + cell; boxTop = originY + 9 * cell }
        }
        val cx = boxLeft + 2.5f * cell
        val cy = boxTop + 2.5f * cell

        val stageText = when (g.gameState) {
            LudoGameState.THROW_DICE -> "Roll the dice"
            LudoGameState.PICK_PAWN -> "Pick a pawn"
            LudoGameState.MOVING -> "Pawn is moving…"
            LudoGameState.FINISH -> "Game is over"
        }

        indicatorPaint.color = type.color
        indicatorPaint.textSize = cell * 0.62f
        indicatorPaint.isFakeBoldText = true
        indicatorPaint.color = 0xCC000000.toInt()
        canvas.drawText("${type.label}'s turn!", cx, cy, indicatorPaint)
        indicatorPaint.color = type.color
        canvas.drawText(stageText, cx, cy + cell * 0.75f, indicatorPaint)
    }

    /** 1st / 2nd / 3rd crowns on the winners' yards. */
    private fun drawCrowns(canvas: Canvas, g: LudoGame) {
        for ((rank, type) in g.winners.withIndex()) {
            val (startX, startY) = when (type) {
                LudoPlayerType.GREEN -> 0 to 0
                LudoPlayerType.YELLOW -> 9 to 0
                LudoPlayerType.BLUE -> 9 to 9
                LudoPlayerType.RED -> 0 to 9
            }
            val cx = originX + (startX + 3) * cell
            val cy = originY + (startY + 1.2f) * cell

            crownPaint.color = when (rank) {
                0 -> Color.parseColor("#FFC107") // 1st gold
                1 -> Color.parseColor("#CFD8DC") // 2nd silver
                else -> Color.parseColor("#D7A86E") // 3rd bronze
            }
            crownPaint.textSize = cell * 0.55f
            crownPaint.isFakeBoldText = true
            canvas.drawText("${CROWNS[rank]} ${RANK_LABELS[rank]}", cx, cy, crownPaint)
        }
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

    companion object {
        const val STAR = "★"
        val CROWNS = arrayOf("🥇", "🥈", "🥉")
        val RANK_LABELS = arrayOf("1st", "2nd", "3rd")
    }
}
