package pynith.apps.nextel.games

import android.media.AudioManager
import android.media.ToneGenerator

/**
 * Tiny asset-free sound effects for the games (the Flutter module played
 * bundled audio files that are not part of the repository). Uses short DTMF
 * style tones and fails silently on devices that cannot provide them.
 */
object SoundFx {

    private var tone: ToneGenerator? = null

    /** Tone volume (0..100). */
    private const val VOLUME = 80

    @Synchronized
    private fun play(toneType: Int, durationMs: Int) {
        try {
            if (tone == null) {
                tone = ToneGenerator(AudioManager.STREAM_MUSIC, VOLUME)
            }
            tone?.startTone(toneType, durationMs)
        } catch (_: Exception) {
            tone = null
        }
    }

    fun click() = play(ToneGenerator.TONE_PROP_BEEP, 40)

    fun diceRoll() = play(ToneGenerator.TONE_CDMA_PIP, 120)

    fun pawnMove() = play(ToneGenerator.TONE_PROP_BEEP2, 45)

    fun capture() {
        play(ToneGenerator.TONE_CDMA_ABBR_ALERT, 200)
    }

    fun win() {
        play(ToneGenerator.TONE_PROP_ACK, 250)
    }

    fun lose() {
        play(ToneGenerator.TONE_PROP_NACK, 250)
    }

    @Synchronized
    fun release() {
        try {
            tone?.release()
        } catch (_: Exception) {
            // Already gone.
        }
        tone = null
    }
}
