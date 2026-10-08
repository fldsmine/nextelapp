package pynith.apps.nextel

import android.Manifest
import android.app.AlarmManager
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
import android.provider.Settings
import android.util.Base64
import android.webkit.CookieManager
import android.webkit.WebStorage
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
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
 * Keystore-backed migration of the old app session, strong-biometric prompts,
 * media-store actions, background update/logout work and APK installation.
 * Product screens and flow orchestration live in Flutter.
 */
class MainActivity : FlutterFragmentActivity() {
    private lateinit var channel: MethodChannel
    private var pendingCanvasBytes: ByteArray? = null
    private var pendingCanvasResult: MethodChannel.Result? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null
    private var strongBiometricPrompt: BiometricPrompt? = null
    private var pendingStrongBiometricResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        clearLegacyPlaintextCredentials()
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(::handleMethodCall)
        runCatching { UpdateCheckScheduler.schedule(applicationContext) }
        runCatching {
            if (PendingLogoutStore.read(applicationContext)?.isNotEmpty() == true) {
                PendingLogoutScheduler.schedule(applicationContext)
            }
        }
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
            "writeLegacyAppSetting" -> writeLegacyAppSetting(call, result)
            "notificationPermissionGranted" -> result.success(hasNotificationPermission())
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "setDailyReminder" -> setDailyReminder(call, result)
            "restoreDailyReminders" -> restoreDailyReminders(result)
            "readBackgroundUpdateState" -> result.success(BackgroundUpdateStore.read(this))
            "canAuthenticateWithStrongBiometrics" ->
                result.success(canAuthenticateWithStrongBiometrics())
            "authenticateWithStrongBiometrics" -> authenticateWithStrongBiometrics(call, result)
            "queueLogoutRevocation" -> queueLogoutRevocation(call, result)
            "removeQueuedLogoutRevocation" -> removeQueuedLogoutRevocation(call, result)
            "canInstallApks" -> result.success(canInstallApks())
            "updateDownloadDirectory" -> result.success(updateDownloadDirectory())
            "requestInstallApkPermission" -> requestInstallApkPermission(result)
            "installApk" -> installApk(call, result)
            "shareText" -> shareText(call, result)
            "openPlayStoreListing" -> openPlayStoreListing(result)
            "saveCanvasImage" -> saveCanvasImage(call, result)
            "shareCanvasImage" -> shareCanvasImage(call, result)
            else -> result.notImplemented()
        }
    }

    private fun canAuthenticateWithStrongBiometrics(): Boolean = runCatching {
        BiometricManager.from(this).canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG,
        ) == BiometricManager.BIOMETRIC_SUCCESS
    }.getOrDefault(false)

    private fun authenticateWithStrongBiometrics(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        if (pendingStrongBiometricResult != null) {
            result.error("biometric_prompt_in_progress", "A biometric prompt is already open.", null)
            return
        }
        if (!canAuthenticateWithStrongBiometrics()) {
            result.success(false)
            return
        }

        val title = call.argument<String>("title")?.takeIf(String::isNotBlank)
            ?: "Biometric authentication"
        val subtitle = call.argument<String>("subtitle")?.takeIf(String::isNotBlank)
        val negativeButtonText = call.argument<String>("negativeButtonText")
            ?.takeIf(String::isNotBlank) ?: "Cancel"
        pendingStrongBiometricResult = result

        try {
            val prompt = BiometricPrompt(
                this,
                ContextCompat.getMainExecutor(this),
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(
                        authenticationResult: BiometricPrompt.AuthenticationResult,
                    ) {
                        finishStrongBiometricPrompt(true)
                    }

                    override fun onAuthenticationError(
                        errorCode: Int,
                        errString: CharSequence,
                    ) {
                        finishStrongBiometricPrompt(false)
                    }
                },
            )
            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle(title)
                .setNegativeButtonText(negativeButtonText)
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .apply { if (subtitle != null) setSubtitle(subtitle) }
                .build()
            strongBiometricPrompt = prompt
            prompt.authenticate(promptInfo)
        } catch (exception: Exception) {
            pendingStrongBiometricResult = null
            strongBiometricPrompt = null
            result.error("biometric_prompt_failed", exception.message, null)
        }
    }

    private fun finishStrongBiometricPrompt(authenticated: Boolean) {
        val result = pendingStrongBiometricResult ?: return
        pendingStrongBiometricResult = null
        strongBiometricPrompt = null
        result.success(authenticated)
    }

    override fun onDestroy() {
        val pendingResult = pendingStrongBiometricResult
        pendingStrongBiometricResult = null
        strongBiometricPrompt?.cancelAuthentication()
        strongBiometricPrompt = null
        runCatching { pendingResult?.success(false) }
        super.onDestroy()
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

    /** Writes only the legacy settings keys still consumed by Android-side integrations. */
    private fun writeLegacyAppSetting(call: MethodCall, result: MethodChannel.Result) {
        val key = call.argument<String>("key")
        if (key == null) {
            result.error("invalid_setting", "A setting key is required.", null)
            return
        }
        val value = call.argument<Any>("value")
        val editor = getSharedPreferences(LEGACY_APP_PREFS, Context.MODE_PRIVATE).edit()
        when (key) {
            "notifications_enabled", "sound", "vibration", "xbg_biometric_enabled" -> {
                val booleanValue = value as? Boolean
                if (booleanValue == null) {
                    result.error("invalid_setting", "A boolean setting value is required.", null)
                    return
                }
                editor.putBoolean(key, booleanValue)
            }
            "fontScale" -> {
                val scale = (value as? Number)?.toFloat()
                if (scale == null || !scale.isFinite()) {
                    result.error("invalid_setting", "A numeric font scale is required.", null)
                    return
                }
                editor.putFloat(key, scale)
            }
            "theme", "fontFamily" -> {
                val text = value as? String
                if (text == null) {
                    result.error("invalid_setting", "A text setting value is required.", null)
                    return
                }
                editor.putString(key, text)
            }
            else -> {
                result.error("invalid_setting", "This setting cannot be written from Flutter.", null)
                return
            }
        }
        editor.apply()
        result.success(true)
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingNotificationPermissionResult != null) {
            result.success(false)
            return
        }
        pendingNotificationPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATION_PERMISSION,
        )
    }

    private fun setDailyReminder(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled")
        if (enabled == null) {
            result.error("invalid_setting", "A reminder state is required.", null)
            return
        }
        val preferences = getSharedPreferences(LEGACY_APP_PREFS, Context.MODE_PRIVATE)
        if (!enabled) {
            preferences.edit().putBoolean("daily_reminder", false).apply()
            DailyReminderScheduler.cancelAll(this)
            result.success(true)
            return
        }
        if (!hasNotificationPermission()) {
            result.success(false)
            return
        }
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !alarmManager.canScheduleExactAlarms()
        ) {
            requestExactAlarmAccess()
            result.success(false)
            return
        }
        val scheduled = DailyReminderScheduler.scheduleAll(this)
        if (scheduled) {
            preferences.edit().putBoolean("daily_reminder", true).apply()
        } else {
            DailyReminderScheduler.cancelAll(this)
        }
        result.success(scheduled)
    }

    private fun restoreDailyReminders(result: MethodChannel.Result) {
        if (!DailyReminderScheduler.isEnabled(this)) {
            result.success(true)
            return
        }
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val canScheduleExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager.canScheduleExactAlarms()
        val hasNotificationPermission = Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            == PackageManager.PERMISSION_GRANTED
        result.success(
            canScheduleExact && hasNotificationPermission &&
                DailyReminderScheduler.scheduleAll(this)
        )
    }

    private fun queueLogoutRevocation(call: MethodCall, result: MethodChannel.Result) {
        val token = call.argument<String>("token")?.takeIf(String::isNotBlank)
        if (token == null) {
            result.error("invalid_logout_token", "A logout token is required.", null)
            return
        }
        if (!PendingLogoutStore.enqueue(applicationContext, token)) {
            result.error("logout_queue_unavailable", "Could not save the logout retry.", null)
            return
        }
        runCatching { PendingLogoutScheduler.schedule(applicationContext) }
        result.success(true)
    }

    private fun removeQueuedLogoutRevocation(call: MethodCall, result: MethodChannel.Result) {
        val token = call.argument<String>("token")?.takeIf(String::isNotBlank)
        if (token == null) {
            result.error("invalid_logout_token", "A logout token is required.", null)
            return
        }
        result.success(PendingLogoutStore.remove(applicationContext, token))
    }

    private fun updateDownloadDirectory(): String =
        File(filesDir, "updates").absolutePath

    private fun canInstallApks(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()

    private fun requestInstallApkPermission(result: MethodChannel.Result) {
        if (canInstallApks()) {
            result.success(true)
            return
        }
        try {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.success(false)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    private fun installApk(call: MethodCall, result: MethodChannel.Result) {
        val rawPath = call.argument<String>("filePath")
        if (rawPath.isNullOrBlank()) {
            result.error("invalid_apk", "An update file is required.", null)
            return
        }

        val updatesDirectory = runCatching { File(filesDir, "updates").canonicalFile }
            .getOrNull()
        val apkFile = runCatching { File(rawPath).canonicalFile }.getOrNull()
        if (updatesDirectory == null || apkFile == null ||
            apkFile.parentFile?.path != updatesDirectory.path ||
            !apkFile.isFile || apkFile.length() <= 0L ||
            !apkFile.name.endsWith(".apk", ignoreCase = true)
        ) {
            result.error("invalid_apk", "The update file is missing or invalid.", null)
            return
        }
        if (!canInstallApks()) {
            result.success(false)
            return
        }

        try {
            val apkUri = FileProvider.getUriForFile(
                this,
                "$packageName.provider",
                apkFile,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.error("installer_unavailable", "No package installer is available.", null)
        } catch (_: Exception) {
            result.error("install_failed", "The update could not be opened.", null)
        }
    }

    private fun requestExactAlarmAccess() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val request = Intent(
            Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
            Uri.parse("package:$packageName"),
        )
        try {
            startActivity(request)
        } catch (_: ActivityNotFoundException) {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:$packageName")),
            )
        }
    }

    private fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            == PackageManager.PERMISSION_GRANTED

    private fun shareText(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text")?.takeIf(String::isNotBlank)
        if (text == null) {
            result.error("invalid_share_text", "Share text is required.", null)
            return
        }
        val subject = call.argument<String>("subject")?.takeIf(String::isNotBlank)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            if (subject != null) putExtra(Intent.EXTRA_SUBJECT, subject)
        }
        val opened = runCatching {
            startActivity(Intent.createChooser(intent, "Share Nextel"))
        }.isSuccess
        result.success(opened)
    }

    private fun openPlayStoreListing(result: MethodChannel.Result) {
        val packageId = packageName
        val marketIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("market://details?id=$packageId"),
        )
        val webIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("https://play.google.com/store/apps/details?id=$packageId"),
        )
        val opened = runCatching { startActivity(marketIntent) }.isSuccess ||
            runCatching { startActivity(webIntent) }.isSuccess
        result.success(opened)
    }

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
        if (requestCode == REQUEST_NOTIFICATION_PERMISSION) {
            val result = pendingNotificationPermissionResult
            pendingNotificationPermissionResult = null
            result?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            return
        }
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
        const val REQUEST_NOTIFICATION_PERMISSION = 7315
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
