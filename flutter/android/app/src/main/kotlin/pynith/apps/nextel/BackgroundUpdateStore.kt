package pynith.apps.nextel

import android.content.Context

/** Durable handoff from WorkManager to Flutter without depending on plugin internals. */
internal object BackgroundUpdateStore {
    private const val PREFERENCES_NAME = "flutter_background_update"
    private const val KEY_CHECKED_AT = "checked_at"
    private const val KEY_UPDATE_INFO = "update_info_json"

    fun save(context: Context, checkedAt: Long, updateInfoJson: String?): Boolean =
        preferences(context).edit()
            .putLong(KEY_CHECKED_AT, checkedAt)
            .putString(KEY_UPDATE_INFO, updateInfoJson)
            .commit()

    fun read(context: Context): Map<String, Any?> {
        val preferences = preferences(context)
        return mapOf(
            "checkedAt" to preferences.getLong(KEY_CHECKED_AT, 0L),
            "updateInfoJson" to preferences.getString(KEY_UPDATE_INFO, null),
        )
    }

    private fun preferences(context: Context) =
        context.applicationContext.getSharedPreferences(
            PREFERENCES_NAME,
            Context.MODE_PRIVATE,
        )
}
