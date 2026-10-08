package pynith.apps.nextel.games.hangman

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** One saved Hangman run. */
data class HangmanScore(val score: Int, val date: String)

/**
 * Persists Hangman high scores (the Flutter module used a SQLite table;
 * SharedPreferences keeps the same data without an extra dependency).
 */
class HangmanScores(context: Context) {

    private val preferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun add(score: Int, date: String) {
        val scores = all().toMutableList()
        scores += HangmanScore(score, date)
        val array = JSONArray()
        scores.sortedByDescending { it.score }
            .take(LIMIT)
            .forEach {
                array.put(JSONObject().put("score", it.score).put("date", it.date))
            }
        preferences.edit().putString(KEY_SCORES, array.toString()).apply()
    }

    fun all(): List<HangmanScore> {
        val raw = preferences.getString(KEY_SCORES, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { index ->
                val entry = array.getJSONObject(index)
                HangmanScore(entry.optInt("score"), entry.optString("date"))
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    companion object {
        private const val PREFS_NAME = "hangman_scores"
        private const val KEY_SCORES = "scores"
        private const val LIMIT = 25
    }
}
