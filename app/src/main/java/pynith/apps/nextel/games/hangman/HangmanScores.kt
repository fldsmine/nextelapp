package pynith.apps.nextel.games.hangman

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** One saved Hangman run. [id] preserves the source SQLite row order for ties. */
data class HangmanScore(val score: Int, val date: String, val id: Int = 0)

/**
 * Stores Hangman run scores in the existing Android preference namespace.
 * If the original Flutter SQLite database is still installed, its rows are
 * imported once before the first preference-backed read.
 */
class HangmanScores(context: Context) {

    private val appContext = context.applicationContext
    private val preferences = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun add(score: Int, date: String) {
        val scores = all().toMutableList()
        val nextId = (scores.maxOfOrNull { it.id } ?: 0) + 1
        scores += HangmanScore(score, date, nextId)
        save(scores)
    }

    fun all(): List<HangmanScore> {
        val raw = preferences.getString(KEY_SCORES, null)
        if (raw != null) {
            val saved = decode(raw)
            if (saved.isNotEmpty() || raw == "[]") return saved
        }

        val imported = readFlutterDatabase()
        if (imported.isNotEmpty()) save(imported)
        return imported
    }

    /**
     * Keep the original `Score.toString()` ordering used by ScoreScreen:
     * score, date, then SQLite id are compared as text, descending.
     */
    fun sortedForDisplay(scores: List<HangmanScore> = all()): List<HangmanScore> =
        scores.sortedByDescending { "${it.score},${it.date},${it.id}" }

    private fun save(scores: List<HangmanScore>) {
        val array = JSONArray()
        scores.forEach { score ->
            array.put(
                JSONObject()
                    .put("score", score.score)
                    .put("date", score.date)
                    .put("id", score.id)
            )
        }
        preferences.edit().putString(KEY_SCORES, array.toString()).apply()
    }

    private fun decode(raw: String): List<HangmanScore> = try {
        val array = JSONArray(raw)
        (0 until array.length()).map { index ->
            val entry = array.getJSONObject(index)
            HangmanScore(
                score = entry.optInt("score"),
                date = entry.optString("date"),
                id = entry.optInt("id", index + 1)
            )
        }
    } catch (_: Exception) {
        emptyList()
    }

    private fun readFlutterDatabase(): List<HangmanScore> {
        val databaseFile: File = appContext.getDatabasePath(FLUTTER_DATABASE_NAME)
        if (!databaseFile.isFile) return emptyList()

        return try {
            SQLiteDatabase.openDatabase(
                databaseFile.absolutePath,
                null,
                SQLiteDatabase.OPEN_READONLY
            ).use { database ->
                database.rawQuery("SELECT id, scoreDate, userScore FROM scores", null).use { cursor ->
                    buildList {
                        val idColumn = cursor.getColumnIndexOrThrow("id")
                        val dateColumn = cursor.getColumnIndexOrThrow("scoreDate")
                        val scoreColumn = cursor.getColumnIndexOrThrow("userScore")
                        while (cursor.moveToNext()) {
                            add(
                                HangmanScore(
                                    score = cursor.getInt(scoreColumn),
                                    date = cursor.getString(dateColumn).orEmpty(),
                                    id = cursor.getInt(idColumn)
                                )
                            )
                        }
                    }
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    companion object {
        private const val PREFS_NAME = "hangman_scores"
        private const val KEY_SCORES = "scores"
        private const val FLUTTER_DATABASE_NAME = "scores_database.db"
    }
}
