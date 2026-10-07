package pynith.apps.nextel.views.auth

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.ProgressBar
import android.widget.Toast
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import org.json.JSONObject
import pynith.apps.nextel.databinding.ActivityLoginBinding
import pynith.apps.nextel.helper.ApiError
import pynith.apps.nextel.helper.ApiResult
import pynith.apps.nextel.helper.LogoutCoordinator
import pynith.apps.nextel.helper.NextelApi
import pynith.apps.nextel.helper.SessionService
import pynith.apps.nextel.helper.WebSessionHandoff
import pynith.apps.nextel.model.CONData
import pynith.apps.nextel.views.BaseActivity
import java.util.concurrent.Executor

class LoginActivity : BaseActivity() {
    private lateinit var bind: ActivityLoginBinding
    private lateinit var session: SessionService
    private lateinit var prefs: android.content.SharedPreferences
    private val api by lazy { NextelApi(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        bind = ActivityLoginBinding.inflate(layoutInflater)
        setContentView(bind.root)

        session = SessionService(this)
        prefs = getSharedPreferences(CONData.APP_PREFS_EXT, Context.MODE_PRIVATE)
        bind.rememberMe.isChecked = session.shouldRememberSession()
        bind.rememberMe.setOnCheckedChangeListener { _, checked ->
            session.setRememberSession(checked)
            if (!checked && prefs.getBoolean(CONData.BIOMETRIC_ENABLED, false)) {
                // A biometric shortcut needs a persistent token; honor an explicit opt-out.
                prefs.edit().putBoolean(CONData.BIOMETRIC_ENABLED, false).apply()
                updateBiometricButton()
            }
        }

        intent.getStringExtra(EXTRA_PREFILL_LOGIN)?.let { bind.username.setText(it) }
        bind.loginBtn.setOnClickListener { login() }
        bind.tvForgot.setOnClickListener { startActivity(Intent(this, ResetActivity::class.java)) }
        bind.tvCreate.setOnClickListener { startActivity(Intent(this, RegisterActivity::class.java)) }
        bind.biometricBtn.setOnClickListener { showBiometricPrompt() }

        updateBiometricButton()
        if (session.isLoggedIn() && !prefs.getBoolean(CONData.BIOMETRIC_ENABLED, false)) {
            validateStoredSession()
        }
    }

    private fun login() {
        bind.emailLayout.error = null
        bind.passwordLayout.error = null

        val login = bind.username.text?.toString()?.trim().orEmpty()
        // Passwords may legitimately contain leading or trailing spaces.
        val password = bind.password.text?.toString().orEmpty()

        if (login.isBlank()) {
            bind.emailLayout.error = "Email or username is required"
            return
        }
        if (password.isEmpty()) {
            bind.passwordLayout.error = "Password is required"
            return
        }

        setLoading(true)
        val payload = JSONObject()
            .put("login", login)
            .put("password", password)

        api.post("login", payload) { result ->
            runOnUiThread {
                if (isFinishing || isDestroyed) return@runOnUiThread
                setLoading(false)

                when (result) {
                    is ApiResult.Success -> {
                        val token = result.data.optString("token")
                        if (token.isBlank()) {
                            toast("The server did not return a sign-in token.")
                            return@runOnUiThread
                        }

                        try {
                            session.saveSession(token, bind.rememberMe.isChecked)
                        } catch (_: Exception) {
                            toast("Could not securely save this session. Please try again.")
                            return@runOnUiThread
                        }

                        LogoutCoordinator.retryQueuedRevocations(this@LoginActivity)
                        updateBiometricButton()
                        val apiUser = result.data.optJSONObject("user")
                        handleAuthenticatedUser(apiUser?.optJSONObject("data") ?: apiUser ?: JSONObject())
                    }

                    is ApiResult.Failure -> handleLoginError(result.error)
                }
            }
        }
    }

    private fun validateStoredSession() {
        setLoading(true)
        val token = session.getToken() ?: run {
            setLoading(false)
            return
        }

        api.get("user", token) { result ->
            runOnUiThread {
                if (isFinishing || isDestroyed) return@runOnUiThread
                when (result) {
                    is ApiResult.Success -> {
                        val apiUser = result.data.optJSONObject("user")
                        handleAuthenticatedUser(apiUser?.optJSONObject("data") ?: apiUser ?: JSONObject())
                    }
                    is ApiResult.Failure -> {
                        setLoading(false)
                        when {
                            result.error.statusCode == 401 -> {
                                session.clearSession()
                                updateBiometricButton()
                            }
                            result.error.statusCode == 403 -> showSuspended(
                                result.error.message,
                                result.error.data.optString("support_token"),
                                oldTokenAlreadyRevoked = result.error.data.optString("support_token").isNotBlank(),
                            )
                            else -> toast(result.error.displayMessage())
                        }
                    }
                }
            }
        }
    }

    private fun handleAuthenticatedUser(user: JSONObject) {
        val status = user.optString("status").lowercase()
        if (status in setOf("suspended", "banned", "blocked")) {
            setLoading(false)
            showSuspended("This account has been suspended. Please contact support.")
            return
        }

        val onboarding = user.optJSONObject("onboarding")
        val verified = onboarding?.optBoolean("email_verified")
            ?: !user.optString("email_verified_at").isNullOrBlank()
        if (!verified) {
            setLoading(false)
            val intent = Intent(this, EmailVerificationActivity::class.java)
                .putExtra(EmailVerificationActivity.EXTRA_EMAIL, user.optString("email"))
            startActivity(intent)
            finish()
            return
        }

        setLoading(true)
        WebSessionHandoff.openLivewire(
            this,
            onSuspended = { error ->
                if (!isFinishing && !isDestroyed) {
                    setLoading(false)
                    showSuspended(
                        error.message,
                        error.data.optString("support_token"),
                        oldTokenAlreadyRevoked = true,
                    )
                }
            },
        ) { message ->
            if (!isFinishing && !isDestroyed) {
                setLoading(false)
                toast(message)
            }
        }
    }

    private fun handleLoginError(error: ApiError) {
        when (error.statusCode) {
            403 -> showSuspended(error.message, error.data.optString("support_token"))
            else -> {
                val loginError = error.firstFieldError("login")
                val passwordError = error.firstFieldError("password")
                when {
                    loginError != null -> bind.emailLayout.error = loginError
                    passwordError != null -> bind.passwordLayout.error = passwordError
                    else -> toast(error.displayMessage())
                }
            }
        }
    }

    private fun showSuspended(
        message: String,
        supportToken: String? = null,
        oldTokenAlreadyRevoked: Boolean = false,
    ) {
        val oldToken = session.getToken()
        if (!oldToken.isNullOrBlank()) {
            var shouldRetryRevocations = false
            try {
                if (oldTokenAlreadyRevoked) {
                    session.removeQueuedLogoutToken(oldToken)
                } else {
                    session.queueLogoutToken(oldToken)
                    shouldRetryRevocations = true
                }
            } catch (_: Exception) {
                // Local session state must still be cleared when revocation queuing fails.
            }
            if (shouldRetryRevocations) LogoutCoordinator.retryQueuedRevocations(this)
        }
        val intent = Intent(this, AccountSuspendedActivity::class.java)
            .putExtra(AccountSuspendedActivity.EXTRA_MESSAGE, message)
            .putExtra(AccountSuspendedActivity.EXTRA_SUPPORT_TOKEN, supportToken)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        startActivity(intent)
        finish()
    }

    private fun showBiometricPrompt() {
        if (!prefs.getBoolean(CONData.BIOMETRIC_ENABLED, false)) {
            toast("Enable biometric sign-in in App Settings first.")
            return
        }
        if (session.getToken().isNullOrBlank()) {
            toast("Sign in once on this device before using biometrics.")
            return
        }
        if (BiometricManager.from(this).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            != BiometricManager.BIOMETRIC_SUCCESS
        ) {
            toast("Strong biometrics are not available on this device.")
            return
        }

        val executor: Executor = ContextCompat.getMainExecutor(this)
        val prompt = BiometricPrompt(
            this,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    // The biometric prompt unlocks access to the Keystore-backed
                    // session token; never persist or replay the user's password.
                    validateStoredSession()
                }
            }
        )
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Biometric sign-in")
            .setSubtitle("Confirm your identity to continue")
            .setNegativeButtonText("Cancel")
            .build()
        prompt.authenticate(promptInfo)
    }

    private fun updateBiometricButton(loading: Boolean = false) {
        val hasPersistentSession = session.shouldRememberSession() && !session.getToken().isNullOrBlank()
        val biometricPreference = prefs.getBoolean(CONData.BIOMETRIC_ENABLED, false)
        if (biometricPreference && !hasPersistentSession) {
            prefs.edit().putBoolean(CONData.BIOMETRIC_ENABLED, false).apply()
        }
        val available = biometricPreference && hasPersistentSession
        bind.biometricBtn.visibility = if (available) View.VISIBLE else View.GONE
        bind.biometricBtn.isSelected = available
        bind.biometricBtn.isEnabled = available && !loading
        bind.biometricBtn.alpha = if (bind.biometricBtn.isEnabled) 1f else 0.5f
    }

    private fun setLoading(loading: Boolean) {
        bind.progress.visibility = if (loading) ProgressBar.VISIBLE else View.GONE
        bind.loginBtn.isEnabled = !loading
        updateBiometricButton(loading)
        bind.tvForgot.isEnabled = !loading
        bind.tvCreate.isEnabled = !loading
    }

    private fun toast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show()
    }

    companion object {
        const val EXTRA_PREFILL_LOGIN = "pynith.apps.nextel.auth.PREFILL_LOGIN"
    }
}
