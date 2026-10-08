package pynith.apps.nextel

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

/** Runs the update feed check while the Flutter app is not in the foreground. */
internal class UpdateBackgroundWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        return try {
            when (val outcome = withContext(Dispatchers.IO) { fetchUpdate() }) {
                is FetchOutcome.UpToDate -> {
                    saveResult(null)
                    Result.success()
                }
                is FetchOutcome.Available -> {
                    saveResult(outcome.infoJson)
                    Result.success()
                }
                is FetchOutcome.Unavailable -> {
                    Log.w(TAG, "Update feed is unavailable (HTTP ${outcome.statusCode}).")
                    Result.success()
                }
            }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: Exception) {
            Log.w(TAG, "Background update check failed; WorkManager will retry.", error)
            Result.retry()
        }
    }

    private fun saveResult(updateInfoJson: String?) {
        if (!BackgroundUpdateStore.save(
                applicationContext,
                System.currentTimeMillis(),
                updateInfoJson,
            )
        ) {
            throw IOException("Could not persist the background update result.")
        }
    }

    private fun fetchUpdate(): FetchOutcome {
        val baseUrl = BuildConfig.UPDATE_API_BASE_URL.toHttpUrlOrNull()
            ?.takeIf { it.isHttps }
            ?: throw IOException("Configured update API URL must use HTTPS.")
        val url = baseUrl.newBuilder()
            .addPathSegments("app-upgrade")
            .addQueryParameter("platform", "android")
            .addQueryParameter("current_version", BuildConfig.VERSION_NAME)
            .addQueryParameter("current_build", BuildConfig.VERSION_CODE.toString())
            .build()

        val request = Request.Builder()
            .url(url)
            .header("Accept", "application/json")
            .get()
            .build()

        return httpClient.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                if (response.code in NON_RETRIED_STATUS_CODES) {
                    return FetchOutcome.Unavailable(response.code)
                }
                throw IOException("Update feed returned HTTP ${response.code}.")
            }

            val body = response.body?.string()
                ?: throw IOException("Update feed returned an empty response.")
            val data = JSONObject(body).optJSONObject("data")
                ?: throw IOException("Update response did not contain data.")
            if (!data.optBoolean("update_available", false)) {
                return FetchOutcome.UpToDate
            }

            val latest = data.optJSONObject("latest")
                ?: throw IOException("Update response did not contain release details.")
            val buildNumber = latest.optInt("build_number", 0)
            if (buildNumber <= BuildConfig.VERSION_CODE) {
                return FetchOutcome.UpToDate
            }

            val info = JSONObject()
                .put("current_build", BuildConfig.VERSION_CODE)
                .put("update_required", data.optBoolean("update_required", false))
                .put("version_name", latest.optString("version_name").orEmpty())
                .put("build_number", buildNumber)
                .put("minimum_supported_build", latest.optInt("minimum_supported_build", 0))
                .put("force_update", latest.optBoolean("force_update", false))
                .put(
                    "title",
                    latest.optString("title").takeIf(String::isNotBlank)
                        ?: DEFAULT_TITLE,
                )
                .put("release_notes", latest.optString("release_notes").orEmpty())
                .put("server_download_url", latest.nullableString("server_download_url"))
                .put("play_store_url", latest.nullableString("play_store_url"))
                .put("published_at", latest.nullableString("published_at"))

            FetchOutcome.Available(info.toString())
        }
    }

    private fun JSONObject.nullableString(key: String): String? {
        if (!has(key) || isNull(key)) return null
        return optString(key).trim().takeIf(String::isNotEmpty)
    }

    private sealed class FetchOutcome {
        data object UpToDate : FetchOutcome()
        data class Available(val infoJson: String) : FetchOutcome()
        data class Unavailable(val statusCode: Int) : FetchOutcome()
    }

    companion object {
        private const val TAG = "UpdateBackgroundWorker"
        private const val DEFAULT_TITLE = "A new update is available"
        private val NON_RETRIED_STATUS_CODES = setOf(404, 405)

        private val httpClient = OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS)
            .callTimeout(20, TimeUnit.SECONDS)
            .retryOnConnectionFailure(true)
            .build()
    }
}
