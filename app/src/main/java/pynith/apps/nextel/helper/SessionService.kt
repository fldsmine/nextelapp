package pynith.apps.nextel.helper

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONArray
import pynith.apps.nextel.model.CONData
import java.io.ByteArrayOutputStream
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

private object VolatileSession {
    @Volatile
    var token: String? = null
}

/** Stores Sanctum tokens encrypted with an Android Keystore AES-GCM key. */
class SessionService(context: Context) {
    private val appContext = context.applicationContext
    private val prefs: SharedPreferences =
        appContext.getSharedPreferences(CONData.APP_PREFS_EXT, Context.MODE_PRIVATE)

    init {
        migrateLegacyToken()
        expireUnrememberedSession()
        // Remove legacy plaintext login credentials; biometric sign-in must
        // unlock the encrypted token, never replay a stored password.
        prefs.edit()
            .remove(LEGACY_TOKEN_KEY)
            .remove(LEGACY_EXPIRY_KEY)
            .remove(LEGACY_PROVIDER_KEY)
            .remove(LEGACY_USERNAME_KEY)
            .remove(LEGACY_PASSWORD_KEY)
            .apply()
        appContext.getSharedPreferences(CONData.APP_USER_EXT, Context.MODE_PRIVATE)
            .edit()
            .remove("user_data")
            .apply()
    }

    /** Save the active device token encrypted; an unremembered token is revoked after process restart. */
    fun saveSession(token: String, rememberMe: Boolean = true) {
        require(token.isNotBlank()) { "API token cannot be empty." }
        val previousToken = getToken()

        val encryptedToken = encrypt(token)
        prefs.edit()
            .putString(ENCRYPTED_TOKEN_KEY, encryptedToken)
            .putBoolean(REMEMBER_SESSION_KEY, rememberMe)
            .remove(LEGACY_TOKEN_KEY)
            .remove(LEGACY_EXPIRY_KEY)
            .remove(LEGACY_PROVIDER_KEY)
            .apply()
        VolatileSession.token = token
        if (!previousToken.isNullOrBlank() && previousToken != token) {
            try {
                queueLogoutToken(previousToken)
            } catch (_: Exception) {
                // Replacing the active session must still succeed if retry queuing fails.
            }
        }
    }

    fun shouldRememberSession(): Boolean = prefs.getBoolean(REMEMBER_SESSION_KEY, true)

    fun setRememberSession(remember: Boolean) {
        prefs.edit().putBoolean(REMEMBER_SESSION_KEY, remember).apply()
    }

    /** A saved token is only a local hint; the API validates it on each app start. */
    fun isLoggedIn(): Boolean = !getToken().isNullOrBlank()

    fun getToken(): String? {
        VolatileSession.token?.let { return it }
        if (!prefs.getBoolean(REMEMBER_SESSION_KEY, true)) return null

        val encrypted = prefs.getString(ENCRYPTED_TOKEN_KEY, null) ?: return null
        return try {
            decrypt(encrypted).also { VolatileSession.token = it }
        } catch (_: Exception) {
            // Keystore keys can be invalidated (for example after a device reset).
            prefs.edit().remove(ENCRYPTED_TOKEN_KEY).putBoolean(REMEMBER_SESSION_KEY, false).apply()
            null
        }
    }

    fun clearSession() {
        VolatileSession.token = null
        prefs.edit()
            .remove(ENCRYPTED_TOKEN_KEY)
            .remove(LEGACY_TOKEN_KEY)
            .remove(LEGACY_EXPIRY_KEY)
            .remove(LEGACY_PROVIDER_KEY)
            .remove(LEGACY_USERNAME_KEY)
            .remove(LEGACY_PASSWORD_KEY)
            .apply()
    }

    /** Queue a token before clearing it so an offline logout can be retried later. */
    fun queueLogoutToken(token: String) {
        if (token.isBlank()) return
        synchronized(logoutQueueLock) {
            val tokens = readQueuedLogoutTokens().toMutableSet()
            tokens.add(token)
            prefs.edit().putString(ENCRYPTED_LOGOUT_QUEUE_KEY, encrypt(JSONArray(tokens.toList()).toString())).apply()
        }
    }

    fun queuedLogoutTokens(): List<String> = synchronized(logoutQueueLock) {
        readQueuedLogoutTokens()
    }

    fun removeQueuedLogoutToken(token: String) {
        synchronized(logoutQueueLock) {
            val remaining = readQueuedLogoutTokens().filterNot { it == token }
            if (remaining.isEmpty()) {
                prefs.edit().remove(ENCRYPTED_LOGOUT_QUEUE_KEY).apply()
            } else {
                prefs.edit().putString(ENCRYPTED_LOGOUT_QUEUE_KEY, encrypt(JSONArray(remaining).toString())).apply()
            }
        }
    }

    private fun readQueuedLogoutTokens(): List<String> {
        val encrypted = prefs.getString(ENCRYPTED_LOGOUT_QUEUE_KEY, null) ?: return emptyList()
        return try {
            val array = JSONArray(decrypt(encrypted))
            (0 until array.length()).mapNotNull { index ->
                array.optString(index).takeIf(String::isNotBlank)
            }
        } catch (_: Exception) {
            prefs.edit().remove(ENCRYPTED_LOGOUT_QUEUE_KEY).apply()
            emptyList()
        }
    }

    private fun expireUnrememberedSession() {
        if (VolatileSession.token != null || prefs.getBoolean(REMEMBER_SESSION_KEY, true)) return
        val encrypted = prefs.getString(ENCRYPTED_TOKEN_KEY, null) ?: return
        val token = try {
            decrypt(encrypted)
        } catch (_: Exception) {
            prefs.edit().remove(ENCRYPTED_TOKEN_KEY).apply()
            return
        }

        try {
            queueLogoutToken(token)
            prefs.edit().remove(ENCRYPTED_TOKEN_KEY).apply()
        } catch (_: Exception) {
            // Keep the encrypted token so a later startup can retry revocation.
        }
    }

    private fun migrateLegacyToken() {
        if (prefs.contains(ENCRYPTED_TOKEN_KEY)) return
        val legacyToken = prefs.getString(LEGACY_TOKEN_KEY, null)
        if (legacyToken.isNullOrBlank()) return

        val legacyExpiry = prefs.getLong(LEGACY_EXPIRY_KEY, 0L)
        val stillInDate = legacyExpiry == 0L || System.currentTimeMillis() < legacyExpiry
        try {
            if (stillInDate) {
                prefs.edit()
                    .putString(ENCRYPTED_TOKEN_KEY, encrypt(legacyToken))
                    .putBoolean(REMEMBER_SESSION_KEY, true)
                    .apply()
            } else {
                // Old local expiry did not necessarily revoke the Sanctum token server-side.
                queueLogoutToken(legacyToken)
            }
        } catch (_: Exception) {
            // A failed migration must not leave the old bearer token in plaintext.
        } finally {
            prefs.edit()
                .remove(LEGACY_TOKEN_KEY)
                .remove(LEGACY_EXPIRY_KEY)
                .remove(LEGACY_PROVIDER_KEY)
                .apply()
        }
    }

    private fun encrypt(plainText: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val encrypted = cipher.doFinal(plainText.toByteArray(Charsets.UTF_8))
        val payload = ByteArrayOutputStream().apply {
            write(cipher.iv)
            write(encrypted)
        }.toByteArray()
        return Base64.encodeToString(payload, Base64.NO_WRAP)
    }

    private fun decrypt(payload: String): String {
        val bytes = Base64.decode(payload, Base64.NO_WRAP)
        require(bytes.size > GCM_IV_LENGTH) { "Invalid encrypted session data." }
        val iv = bytes.copyOfRange(0, GCM_IV_LENGTH)
        val encrypted = bytes.copyOfRange(GCM_IV_LENGTH, bytes.size)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv))
        return String(cipher.doFinal(encrypted), Charsets.UTF_8)
    }

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEY_STORE).apply { load(null) }
        val existing = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
        if (existing != null) return existing

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEY_STORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .setKeySize(256)
                .build()
        )
        return generator.generateKey()
    }

    private companion object {
        val logoutQueueLock = Any()
        const val KEY_ALIAS = "nextel.api.session.v1"
        const val ANDROID_KEY_STORE = "AndroidKeyStore"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val GCM_IV_LENGTH = 12
        const val GCM_TAG_LENGTH_BITS = 128

        const val ENCRYPTED_TOKEN_KEY = "nextel.encrypted_api_token"
        const val ENCRYPTED_LOGOUT_QUEUE_KEY = "nextel.encrypted_logout_queue"
        const val REMEMBER_SESSION_KEY = "nextel.remember_api_session"

        const val LEGACY_TOKEN_KEY = "xbg_auth_token_keys"
        const val LEGACY_EXPIRY_KEY = "xbg_session_expiry"
        const val LEGACY_PROVIDER_KEY = "xbg_auth_provider"
        const val LEGACY_USERNAME_KEY = "xbg_auth_username"
        const val LEGACY_PASSWORD_KEY = "xbg_auth_password"
    }
}
