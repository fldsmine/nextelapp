package pynith.apps.nextel.games

import android.content.Context
import android.media.MediaPlayer
import pynith.apps.nextel.R

/** Bundled game sounds used by the Flutter reference, played natively. */
object SoundFx {

    @Volatile
    private var appContext: Context? = null
    private var player: MediaPlayer? = null

    fun initialize(context: Context) {
        appContext = context.applicationContext
    }

    @Synchronized
    private fun play(resourceId: Int) {
        val context = appContext ?: return
        releasePlayer()

        val next = try {
            MediaPlayer.create(context, resourceId)
        } catch (_: Exception) {
            null
        } ?: return

        player = next
        next.setOnCompletionListener { completed ->
            synchronized(this@SoundFx) {
                if (player === completed) player = null
            }
            completed.release()
        }
        next.setOnErrorListener { failed, _, _ ->
            synchronized(this@SoundFx) {
                if (player === failed) player = null
            }
            failed.release()
            true
        }
        try {
            next.start()
        } catch (_: Exception) {
            if (player === next) player = null
            next.release()
        }
    }

    private fun releasePlayer() {
        player?.let { current ->
            player = null
            try {
                if (current.isPlaying) current.stop()
            } catch (_: Exception) {
                // The player may already have completed or failed.
            }
            try {
                current.release()
            } catch (_: Exception) {
                // Already released.
            }
        }
    }

    fun click() = play(R.raw.click)
    fun diceRoll() = play(R.raw.dice)
    fun diceStop() = play(R.raw.move)
    fun ludoRoll() = play(R.raw.roll_the_dice)
    fun ludoMove() = play(R.raw.move)
    fun capture() = play(R.raw.laugh)
    fun win() = play(R.raw.win)
    fun lose() = play(R.raw.lost)

    /** Kept for any existing call sites; a pawn step uses the original move sound. */
    fun pawnMove() = ludoMove()

    @Synchronized
    fun release() {
        releasePlayer()
        appContext = null
    }
}
