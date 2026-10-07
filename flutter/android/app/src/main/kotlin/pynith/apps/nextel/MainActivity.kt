package pynith.apps.nextel

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Base64
import android.webkit.CookieManager
import android.webkit.WebStorage
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.io.File
import java.io.FileOutputStream
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Deliberately small Android integration seam for shared WebView cookies,
 * Keystore-backed migration of the old app session, and media-store actions.
 * Product screens and flow orchestration live in Flutter.
 */
class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel
    private lateinit var imageChooserLauncher: ActivityResultLauncher<Intent>
    private var pendingImageChooserResult: MethodChannel.Result? = null
    private var pendingCameraPhotoUri: Uri? = null
    private var pendingCameraPhotoFile: File? = null
    private var pendingCanvasBytes: ByteArray? = null
    private var pendingCanvasResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        imageChooserLauncher = registerForActivityResult(
            ActivityResultContracts.StartActivityForResult()
        ) { activityResult ->
            completeImageChooser(activityResult.resultCode, activityResult.data)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        clearLegacyPlaintextCredentials()
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(::handleMethodCall)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "runtimeConfig" -> result.success(runtimeConfig())
            "ensureAppGateCookie" -> result.success(ensureAppGateCookie())
            "getCookieHeader" -> getCookieHeader(call, result)
            "setCookies" -> setCookies(call, result)
            "flushCookies" -> {
                CookieManager.getInstance().flush()
                result.success(true)
            }
            "clearWebSession" -> clearWebSession(result)
            "readLegacyData" -> readLegacyData(result)
            "completeLegacyImport" -> completeLegacyImport(call, result)
            "saveCanvasImage" -> saveCanvasImage(call, result)
            "shareCanvasImage" -> shareCanvasImage(call, result)
            "chooseWebViewImage" -> chooseWebViewImage(result)
            else -> result.notImplemented()
        }
    }

    private fun runtimeConfig(): Map<String, Any> = mapOf(
        "webBaseUrl" to BuildConfig.WEB_BASE_URL.trimEnd('/'),
        "apiBaseUrl" to BuildConfig.API_BASE_URL.trimEnd('/'),
        "frontBaseUrl" to BuildConfig.FRONTBASE_URL.trimEnd('/'),
        "updateApiBaseUrl" to BuildConfig.UPDATE_API_BASE_URL.trimEnd('/'),
        "versionName" to BuildConfig.VERSION_NAME,
        "versionCode" to BuildConfig.VERSION_CODE,
        "appGateCookieConfigured" to BuildConfig.APP_GATE_COOKIE.isNotBlank()
    )

    /** Remove obsolete password preferences without exposing them to Flutter. */
    private fun clearLegacyPlaintextCredentials() {
        listOf(LEGACY_APP_PREFS, "no_app_users").forEach { preferencesName ->
            getSharedPreferences(preferencesName, Context.MODE_PRIVATE).edit()
                .remove(LEGACY_USERNAME_KEY)
                .remove(LEGACY_PASSWORD_KEY)
                .remove(OLD_USERNAME_KEY)
                .remove(OLD_PASSWORD_KEY)
                .apply()
        }
    }

    /** Installs a build-provided gate cookie without ever returning its value to Dart. */
    private fun ensureAppGateCookie(): Boolean {
        val cookieManager = CookieManager.getInstance().apply { setAcceptCookie(true) }
        val webBase = Uri.parse(BuildConfig.WEB_BASE_URL)
        val host = webBase.host ?: return false
        val url = webBase.toString().trimEnd('/') + "/"
        val existing = cookieManager.getCookie(url).orEmpty()
        if (existing.split(';').any { it.trim().startsWith("$APP_GATE_COOKIE_NAME=") }) {
            return true
        }

        val value = BuildConfig.APP_GATE_COOKIE.trim()
        if (value.isEmpty()) return false
        val scheme = webBase.scheme?.takeIf(String::isNotBlank) ?: "https"
        val cookie = "$APP_GATE_COOKIE_NAME=$value; Domain=$host; Path=/; Secure"
        cookieManager.setCookie("$scheme://$host/", cookie)
        cookieManager.flush()
        return true
    }

    private fun getCookieHeader(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        if (url.isNullOrBlank() || !isTrustedUrl(url)) {
            result.error("untrusted_origin", "Cookie access is limited to configured Nextel origins.", null)
            return
        }
        result.success(CookieManager.getInstance().getCookie(url))
    }

    private fun setCookies(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        val cookies = call.argument<List<String>>("cookies")
        if (url.isNullOrBlank() || !isTrustedUrl(url) || cookies == null) {
            result.error("invalid_cookie_target", "Cookies may only be set for configured Nextel origins.", null)
            return
        }
        if (cookies.any { it.contains('\r') || it.contains('\n') || !it.substringBefore(';').contains('=') }) {
            result.error("invalid_cookie", "The server returned an invalid cookie value.", null)
            return
        }
        if (cookies.isEmpty()) {
            result.success(true)
            return
        }

        val cookieManager = CookieManager.getInstance().apply { setAcceptCookie(true) }
        var remaining = cookies.size
        var allAccepted = true
        cookies.forEach { cookie ->
            cookieManager.setCookie(url, cookie) { accepted ->
                allAccepted = allAccepted && accepted
                remaining -= 1
                if (remaining == 0) {
                    cookieManager.flush()
                    result.success(allAccepted)
                }
            }
        }
    }

    /** Clears Laravel state while preserving/re-installing the native app-gate cookie. */
    private fun clearWebSession(result: MethodChannel.Result) {
        val webBase = Uri.parse(BuildConfig.WEB_BASE_URL)
        val webUrl = webBase.toString().trimEnd('/') + "/"
        val cookieManager = CookieManager.getInstance().apply { setAcceptCookie(true) }
        val previouslyStoredGate = cookieManager.getCookie(webUrl)
            .orEmpty()
            .split(';')
            .map(String::trim)
            .firstOrNull { it.startsWith("$APP_GATE_COOKIE_NAME=") }

        cookieManager.removeAllCookies {
            WebStorage.getInstance().deleteAllData()
            val host = webBase.host
            val configuredValue = BuildConfig.APP_GATE_COOKIE.trim()
            val gateCookie = when {
                configuredValue.isNotEmpty() && !host.isNullOrBlank() ->
                    "$APP_GATE_COOKIE_NAME=$configuredValue; Domain=$host; Path=/; Secure"
                !previouslyStoredGate.isNullOrBlank() && !host.isNullOrBlank() ->
                    "$previouslyStoredGate; Domain=$host; Path=/; Secure"
                else -> null
            }
            if (gateCookie == null) {
                result.success(true)
                return@removeAllCookies
            }
            val scheme = webBase.scheme?.takeIf(String::isNotBlank) ?: "https"
            cookieManager.setCookie("$scheme://${host}/", gateCookie) { accepted ->
                cookieManager.flush()
                result.success(accepted)
            }
        }
    }

    private fun isTrustedUrl(rawUrl: String): Boolean {
        val candidate = runCatching { Uri.parse(rawUrl) }.getOrNull() ?: return false
        if (candidate.userInfo != null || candidate.host.isNullOrBlank()) return false
        if (candidate.scheme !in setOf("https", "http")) return false
        return listOf(BuildConfig.WEB_BASE_URL, BuildConfig.API_BASE_URL).any { base ->
            val baseUri = runCatching { Uri.parse(base) }.getOrNull() ?: return@any false
            candidate.scheme == baseUri.scheme &&
                candidate.host.equals(baseUri.host, ignoreCase = true) &&
                effectivePort(candidate) == effectivePort(baseUri)
        }
    }

    private fun effectivePort(uri: Uri): Int = when {
        uri.port >= 0 -> uri.port
        uri.scheme == "https" -> 443
        uri.scheme == "http" -> 80
        else -> -1
    }

    /** Reads old app preferences without exposing passwords or modifying game/settings data. */
    private fun readLegacyData(result: MethodChannel.Result) {
        val appPrefs = getSharedPreferences(LEGACY_APP_PREFS, Context.MODE_PRIVATE)
        val settings = linkedMapOf<String, Any>()
        LEGACY_SETTING_KEYS.forEach { key ->
            val value = appPrefs.all[key] ?: return@forEach
            val channelValue = when (value) {
                is Float -> value.toDouble()
                is Set<*> -> value.filterIsInstance<String>()
                is Boolean, is Int, is Long, is String -> value
                else -> null
            }
            if (channelValue != null) settings[key] = channelValue
        }

        val legacySession = readLegacySession(appPrefs)
        val diceHistory = getSharedPreferences("dice_game", Context.MODE_PRIVATE)
            .getString("game_history", null)
        val hangmanScores = getSharedPreferences("hangman_scores", Context.MODE_PRIVATE)
            .getString("scores", null)

        result.success(
            mapOf(
                "schemaVersion" to 1,
                "settings" to settings,
                "diceHistory" to diceHistory,
                "hangmanScores" to hangmanScores,
                "session" to legacySession
            )
        )
    }

    private fun readLegacySession(prefs: SharedPreferences): Map<String, Any> {
        val rawRememberValue = prefs.all[REMEMBER_SESSION_KEY] as? Boolean
        val rememberMe = rawRememberValue ?: true
        val pending = linkedSetOf<String>()
        var queueReadable = true
        var tokenReadable = true

        val encryptedQueue = prefs.getString(ENCRYPTED_LOGOUT_QUEUE_KEY, null)
        if (!encryptedQueue.isNullOrBlank()) {
            val queueText = decryptLegacyValue(encryptedQueue)
            if (queueText == null) {
                queueReadable = false
            } else {
                runCatching {
                    val array = JSONArray(queueText)
                    for (index in 0 until array.length()) {
                        array.optString(index).takeIf(String::isNotBlank)?.let(pending::add)
                    }
                }.onFailure { queueReadable = false }
            }
        }

        var activeToken: String? = null
        val encryptedToken = prefs.getString(ENCRYPTED_TOKEN_KEY, null)
        if (!encryptedToken.isNullOrBlank()) {
            val decrypted = decryptLegacyValue(encryptedToken)
            if (decrypted == null) {
                tokenReadable = false
            } else if (rememberMe) {
                activeToken = decrypted.takeIf(String::isNotBlank)
            } else {
                decrypted.takeIf(String::isNotBlank)?.let(pending::add)
            }
        }

        // Support installs that have not yet run the older encrypted-token migration.
        val plaintextLegacyToken = prefs.getString(LEGACY_TOKEN_KEY, null)
        if (!plaintextLegacyToken.isNullOrBlank()) {
            val expiry = when (val storedExpiry = prefs.all[LEGACY_EXPIRY_KEY]) {
                is Long -> storedExpiry
                is Int -> storedExpiry.toLong()
                else -> 0L
            }
            val expired = expiry != 0L && System.currentTimeMillis() >= expiry
            if (!expired && rememberMe && activeToken == null) {
                activeToken = plaintextLegacyToken
            } else {
                pending.add(plaintextLegacyToken)
            }
        }

        return mapOf(
            "rememberMe" to rememberMe,
            "token" to (activeToken ?: ""),
            "pendingLogoutTokens" to pending.toList(),
            "safeToComplete" to (tokenReadable && queueReadable)
        )
    }

    /** Decrypts the old SessionService AES-GCM payload using its existing key only. */
    private fun decryptLegacyValue(encoded: String): String? = runCatching {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val key = keyStore.getKey(LEGACY_KEY_ALIAS, null) as? SecretKey
            ?: throw IllegalStateException("Legacy session key is unavailable.")
        val bytes = Base64.decode(encoded, Base64.NO_WRAP)
        require(bytes.size > LEGACY_GCM_IV_LENGTH) { "Invalid encrypted session data." }
        val iv = bytes.copyOfRange(0, LEGACY_GCM_IV_LENGTH)
        val encrypted = bytes.copyOfRange(LEGACY_GCM_IV_LENGTH, bytes.size)
        val cipher = Cipher.getInstance(LEGACY_TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(LEGACY_GCM_TAG_BITS, iv))
        String(cipher.doFinal(encrypted), Charsets.UTF_8)
    }.getOrNull()

    /** Called only after Flutter has durably copied all readable session material. */
    private fun completeLegacyImport(call: MethodCall, result: MethodChannel.Result) {
        if (call.argument<Boolean>("complete") != true) {
            result.error("migration_not_complete", "Legacy session data was not confirmed as migrated.", null)
            return
        }
        getSharedPreferences(LEGACY_APP_PREFS, Context.MODE_PRIVATE).edit()
            .remove(ENCRYPTED_TOKEN_KEY)
            .remove(ENCRYPTED_LOGOUT_QUEUE_KEY)
            .remove(LEGACY_TOKEN_KEY)
            .remove(LEGACY_EXPIRY_KEY)
            .remove(LEGACY_PROVIDER_KEY)
            .remove(LEGACY_USERNAME_KEY)
            .remove(LEGACY_PASSWORD_KEY)
            .remove(OLD_USERNAME_KEY)
            .remove(OLD_PASSWORD_KEY)
            .apply()
        result.success(true)
    }

    /** Shows the same image gallery + external-camera chooser used by the legacy WebView. */
    private fun chooseWebViewImage(result: MethodChannel.Result) {
        pendingImageChooserResult?.success(null)
        pendingCameraPhotoFile?.delete()
        pendingImageChooserResult = result
        pendingCameraPhotoUri = null
        pendingCameraPhotoFile = null

        val galleryIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
        }
        val cameraIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
        if (cameraIntent.resolveActivity(packageManager) != null) {
            try {
                val picturesDirectory = getExternalFilesDir(Environment.DIRECTORY_PICTURES)
                    ?: throw IllegalStateException("App picture storage is unavailable.")
                val photoFile = File.createTempFile("nextel-web-", ".jpg", picturesDirectory)
                val photoUri = FileProvider.getUriForFile(
                    this,
                    "$packageName.provider",
                    photoFile
                )
                pendingCameraPhotoFile = photoFile
                pendingCameraPhotoUri = photoUri
                cameraIntent.apply {
                    putExtra(MediaStore.EXTRA_OUTPUT, photoUri)
                    clipData = android.content.ClipData.newUri(
                        contentResolver,
                        "Captured image",
                        photoUri
                    )
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                }
            } catch (_: Exception) {
                pendingCameraPhotoFile?.delete()
                pendingCameraPhotoFile = null
                pendingCameraPhotoUri = null
            }
        }

        val chooserIntent = Intent.createChooser(galleryIntent, "Image Chooser").apply {
            pendingCameraPhotoUri?.let {
                putExtra(Intent.EXTRA_INITIAL_INTENTS, arrayOf(cameraIntent))
            }
        }
        try {
            imageChooserLauncher.launch(chooserIntent)
        } catch (_: ActivityNotFoundException) {
            pendingImageChooserResult = null
            pendingCameraPhotoFile?.delete()
            pendingCameraPhotoFile = null
            pendingCameraPhotoUri = null
            result.error("image_chooser_unavailable", "No image picker is available.", null)
        } catch (_: Exception) {
            pendingImageChooserResult = null
            pendingCameraPhotoFile?.delete()
            pendingCameraPhotoFile = null
            pendingCameraPhotoUri = null
            result.error("image_chooser_failed", "Could not open the image picker.", null)
        }
    }

    private fun completeImageChooser(resultCode: Int, data: Intent?) {
        val result = pendingImageChooserResult ?: run {
            pendingCameraPhotoFile?.delete()
            pendingCameraPhotoFile = null
            pendingCameraPhotoUri = null
            return
        }
        val cameraUri = pendingCameraPhotoUri
        val cameraFile = pendingCameraPhotoFile
        pendingImageChooserResult = null
        pendingCameraPhotoUri = null
        pendingCameraPhotoFile = null

        if (resultCode != Activity.RESULT_OK) {
            cameraFile?.delete()
            result.success(null)
            return
        }

        val galleryUri = data?.data
            ?: data?.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
        val selectedUri = galleryUri ?: cameraUri?.takeIf(::hasNonEmptyContent)
        if (selectedUri == null) {
            cameraFile?.delete()
            result.success(null)
            return
        }
        if (selectedUri != cameraUri) cameraFile?.delete()
        result.success(selectedUri.toString())
    }

    private fun hasNonEmptyContent(uri: Uri): Boolean = runCatching {
        contentResolver.openAssetFileDescriptor(uri, "r")?.use { descriptor ->
            descriptor.length > 0 || descriptor.parcelFileDescriptor.statSize > 0
        } ?: false
    }.getOrDefault(false)

    private fun saveCanvasImage(call: MethodCall, result: MethodChannel.Result) {
        val bytes = decodeImage(call.argument<String>("data"), result) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            runCatching { writeCanvasToMediaStore(bytes) }
                .onSuccess { result.success(true) }
                .onFailure { result.error("save_failed", "Could not save the canvas image.", null) }
            return
        }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE)
            == PackageManager.PERMISSION_GRANTED
        ) {
            runCatching { writeCanvasToLegacyPictures(bytes) }
                .onSuccess { result.success(true) }
                .onFailure { result.error("save_failed", "Could not save the canvas image.", null) }
            return
        }

        pendingCanvasBytes = bytes
        pendingCanvasResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
            REQUEST_WRITE_CANVAS_PERMISSION
        )
    }

    private fun shareCanvasImage(call: MethodCall, result: MethodChannel.Result) {
        val bytes = decodeImage(call.argument<String>("data"), result) ?: return
        runCatching {
            val sharedDirectory = File(cacheDir, "shared").apply { mkdirs() }
            val imageFile = File(sharedDirectory, "canvas-${System.currentTimeMillis()}.png")
            FileOutputStream(imageFile).use { it.write(bytes) }
            val uri = FileProvider.getUriForFile(this, "$packageName.provider", imageFile)
            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                clipData = android.content.ClipData.newUri(contentResolver, "Canvas image", uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(shareIntent, "Share Canvas Image"))
        }.onSuccess {
            result.success(true)
        }.onFailure {
            result.error("share_failed", "Could not share the canvas image.", null)
        }
    }

    private fun decodeImage(encoded: String?, result: MethodChannel.Result): ByteArray? {
        if (encoded.isNullOrBlank()) {
            result.error("invalid_image", "No canvas image was provided.", null)
            return null
        }
        return runCatching {
            val payload = encoded.substringAfter(',', encoded)
            Base64.decode(payload, Base64.DEFAULT).also {
                require(it.isNotEmpty() && it.size <= MAX_CANVAS_BYTES) { "Canvas image size is invalid." }
            }
        }.getOrElse {
            result.error("invalid_image", "The canvas image could not be decoded.", null)
            null
        }
    }

    private fun writeCanvasToMediaStore(bytes: ByteArray) {
        val name = "NovaPNL-${System.currentTimeMillis()}.png"
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/NovaPNL")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("MediaStore did not create an image entry.")
        try {
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("MediaStore image stream is unavailable.")
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            throw error
        }
    }

    @Suppress("DEPRECATION")
    private fun writeCanvasToLegacyPictures(bytes: ByteArray) {
        val pictures = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
        if (!pictures.exists() && !pictures.mkdirs()) {
            throw IllegalStateException("Pictures directory is unavailable.")
        }
        val imageFile = File(pictures, "NovaPNL-${System.currentTimeMillis()}.png")
        FileOutputStream(imageFile).use { it.write(bytes) }
        android.media.MediaScannerConnection.scanFile(this, arrayOf(imageFile.absolutePath), arrayOf("image/png"), null)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_WRITE_CANVAS_PERMISSION) return

        val bytes = pendingCanvasBytes
        val result = pendingCanvasResult
        pendingCanvasBytes = null
        pendingCanvasResult = null
        if (bytes == null || result == null) return
        if (grantResults.firstOrNull() != PackageManager.PERMISSION_GRANTED) {
            result.error("permission_denied", "Storage permission is required to save this image.", null)
            return
        }
        runCatching { writeCanvasToLegacyPictures(bytes) }
            .onSuccess { result.success(true) }
            .onFailure { result.error("save_failed", "Could not save the canvas image.", null) }
    }

    private companion object {
        const val CHANNEL_NAME = "pynith.apps.nextel/native"
        const val APP_GATE_COOKIE_NAME = "app_gate"
        const val REQUEST_WRITE_CANVAS_PERMISSION = 7314
        const val MAX_CANVAS_BYTES = 32 * 1024 * 1024

        const val LEGACY_APP_PREFS = "app_prefs"
        const val LEGACY_KEY_ALIAS = "nextel.api.session.v1"
        const val LEGACY_TRANSFORMATION = "AES/GCM/NoPadding"
        const val LEGACY_GCM_IV_LENGTH = 12
        const val LEGACY_GCM_TAG_BITS = 128

        const val ENCRYPTED_TOKEN_KEY = "nextel.encrypted_api_token"
        const val ENCRYPTED_LOGOUT_QUEUE_KEY = "nextel.encrypted_logout_queue"
        const val REMEMBER_SESSION_KEY = "nextel.remember_api_session"
        const val LEGACY_TOKEN_KEY = "xbg_auth_token_keys"
        const val LEGACY_EXPIRY_KEY = "xbg_session_expiry"
        const val LEGACY_PROVIDER_KEY = "xbg_auth_provider"
        const val LEGACY_USERNAME_KEY = "xbg_auth_username"
        const val LEGACY_PASSWORD_KEY = "xbg_auth_password"
        const val OLD_USERNAME_KEY = "xbg_user_id"
        const val OLD_PASSWORD_KEY = "xbg_user_pass"

        val LEGACY_SETTING_KEYS = listOf(
            "daily_reminder",
            "sound",
            "vibration",
            "fontScale",
            "theme",
            "fontFamily",
            "notifications_enabled",
            "xbg_biometric_enabled"
        )
    }
}
