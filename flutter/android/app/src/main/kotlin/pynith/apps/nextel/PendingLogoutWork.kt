package pynith.apps.nextel

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.security.KeyStore
import java.util.concurrent.TimeUnit
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** AES-GCM protected queue shared by the Flutter bridge and the background worker. */
internal object PendingLogoutStore {
    private const val PREFERENCES_NAME = "flutter_pending_logout"
    private const val QUEUE_KEY = "encrypted_tokens_v1"
    private const val KEY_ALIAS = "nextel.flutter.logout.queue.v1"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val GCM_IV_LENGTH = 12
    private const val GCM_TAG_BITS = 128

    @Synchronized
    fun enqueue(context: Context, token: String): Boolean = runCatching {
        require(token.isNotBlank())
        val tokens = readTokens(context).toMutableList()
        if (token !in tokens) tokens.add(token)
        writeTokens(context, tokens)
    }.getOrDefault(false)

    @Synchronized
    fun remove(context: Context, token: String): Boolean = runCatching {
        val tokens = readTokens(context).toMutableList()
        tokens.removeAll { it == token }
        writeTokens(context, tokens)
    }.getOrDefault(false)

    /** Returns null rather than dropping an unreadable queue. */
    @Synchronized
    fun read(context: Context): List<String>? = runCatching {
        readTokens(context)
    }.getOrNull()

    private fun readTokens(context: Context): List<String> {
        val encodedQueue = preferences(context).getString(QUEUE_KEY, null)
            ?: return emptyList()
        val array = JSONArray(encodedQueue)
        return buildList {
            for (index in 0 until array.length()) {
                add(decrypt(array.getString(index)))
            }
        }.distinct()
    }

    private fun writeTokens(context: Context, tokens: List<String>): Boolean {
        val editor = preferences(context).edit()
        if (tokens.isEmpty()) {
            editor.remove(QUEUE_KEY)
        } else {
            val encrypted = JSONArray().apply {
                tokens.forEach { put(encrypt(it)) }
            }
            editor.putString(QUEUE_KEY, encrypted.toString())
        }
        return editor.commit()
    }

    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val payload = cipher.iv + encrypted
        return Base64.encodeToString(payload, Base64.NO_WRAP)
    }

    private fun decrypt(value: String): String {
        val payload = Base64.decode(value, Base64.NO_WRAP)
        require(payload.size > GCM_IV_LENGTH) { "Invalid queued token payload." }
        val iv = payload.copyOfRange(0, GCM_IV_LENGTH)
        val encrypted = payload.copyOfRange(GCM_IV_LENGTH, payload.size)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(
            Cipher.DECRYPT_MODE,
            getOrCreateKey(),
            GCMParameterSpec(GCM_TAG_BITS, iv),
        )
        return String(cipher.doFinal(encrypted), Charsets.UTF_8)
    }

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val existing = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
        if (existing != null) return existing

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        return generator.generateKey()
    }

    private fun preferences(context: Context) =
        context.applicationContext.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
}

/** Schedules one network-constrained worker to retry every securely queued revocation. */
internal object PendingLogoutScheduler {
    private const val UNIQUE_WORK_NAME = "flutter_revoke_queued_api_tokens"

    fun schedule(context: Context) {
        val request = OneTimeWorkRequestBuilder<PendingLogoutWorker>()
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build(),
            )
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .build()

        WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
            UNIQUE_WORK_NAME,
            ExistingWorkPolicy.APPEND_OR_REPLACE,
            request,
        )
    }
}

/** Retries logout-token revocation after an offline or interrupted Flutter sign-out. */
internal class PendingLogoutWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val queuedTokens = PendingLogoutStore.read(applicationContext) ?: return@withContext Result.retry()
        if (queuedTokens.isEmpty()) return@withContext Result.success()

        var shouldRetry = false
        for (token in queuedTokens) {
            try {
                val revoked = httpClient.newCall(logoutRequest(token)).execute().use { response ->
                    if (response.code == 401) {
                        true
                    } else if (response.isSuccessful) {
                        val body = response.body?.string().orEmpty()
                        val declaredSuccess = runCatching {
                            JSONObject(body).optBoolean("success", true)
                        }.getOrDefault(true)
                        declaredSuccess
                    } else {
                        false
                    }
                }
                if (revoked) {
                    if (!PendingLogoutStore.remove(applicationContext, token)) {
                        shouldRetry = true
                    }
                } else {
                    shouldRetry = true
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                shouldRetry = true
            }
        }

        if (shouldRetry) Result.retry() else Result.success()
    }

    private fun logoutRequest(token: String): Request {
        val baseUrl = BuildConfig.API_BASE_URL.toHttpUrlOrNull()
            ?.takeIf { it.scheme == "https" || it.scheme == "http" }
            ?: throw IOException("Configured API URL is invalid.")
        val url = baseUrl.newBuilder().addPathSegments("logout").build()
        return Request.Builder()
            .url(url)
            .header("Accept", "application/json")
            .header("Authorization", "Bearer $token")
            .post("{}".toRequestBody(JSON_MEDIA_TYPE))
            .build()
    }

    companion object {
        private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()
        private val httpClient = OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS)
            .callTimeout(20, TimeUnit.SECONDS)
            .retryOnConnectionFailure(true)
            .build()
    }
}
