package pynith.apps.nextel.games.hangman

import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HangmanWordsTest {

    @Test
    fun wordsAreNotRepeatedUntilResetAndThenCanBeDrawnAgain() {
        val words = HangmanWords(listOf("apple", "banana", "cherry"), Random(42))

        val firstRun = List(3) { words.getWord()!! }
        assertEquals(3, firstRun.toSet().size)
        assertNull(words.getWord())

        words.reset()
        assertTrue(words.getWord()!! in listOf("apple", "banana", "cherry"))
    }

    @Test
    fun parserPreservesWordsAndAcceptsCrLf() {
        assertEquals(listOf("apple", "banana", "cherry"), HangmanWords.parseWordList("apple\r\nbanana\r\ncherry"))
    }
}
