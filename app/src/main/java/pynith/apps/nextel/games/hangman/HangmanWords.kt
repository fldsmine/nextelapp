package pynith.apps.nextel.games.hangman

import android.content.Context
import kotlin.random.Random

/**
 * Random word source for the original Hangman word list. The source Flutter
 * screen loaded `assets/res/hangman_words.txt` and did not repeat a word in a
 * run; the Android port reads the same bundled list from app assets.
 */
class HangmanWords(
    private val words: List<String>,
    private val random: Random = Random.Default
) {
    private val used = mutableSetOf<Int>()

    var wordCounter: Int = 0
        private set

    fun reset() {
        wordCounter = 0
        used.clear()
    }

    /** Next random unused word, or null once the full bundled list is used. */
    fun getWord(): String? {
        wordCounter += 1
        if (wordCounter - 1 == words.size || words.isEmpty()) return null

        while (true) {
            val index = random.nextInt(words.size)
            if (used.add(index)) return words[index]
        }
    }

    companion object {
        private const val WORD_LIST_ASSET = "res/hangman_words.txt"

        fun from(context: Context): HangmanWords {
            val contents = context.assets.open(WORD_LIST_ASSET).bufferedReader().use { it.readText() }
            return HangmanWords(parseWordList(contents))
        }

        /** Mirrors Dart's `split('\n')`, while accepting CRLF asset checkouts. */
        fun parseWordList(contents: String): List<String> =
            contents.split('\n').map { it.removeSuffix("\r") }
    }
}
