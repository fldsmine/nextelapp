package pynith.apps.nextel.views.auth

import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.text.SpannableString
import android.text.Spanned
import android.text.TextPaint
import android.text.method.LinkMovementMethod
import android.text.style.ClickableSpan
import android.view.View
import android.view.WindowManager
import android.widget.EditText
import android.widget.Toast
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import org.json.JSONArray
import org.json.JSONObject
import pynith.apps.nextel.R
import pynith.apps.nextel.databinding.UserRegistrationBinding
import pynith.apps.nextel.helper.ApiError
import pynith.apps.nextel.helper.ApiResult
import pynith.apps.nextel.helper.CountryAdapter
import pynith.apps.nextel.helper.LogoutCoordinator
import pynith.apps.nextel.helper.NextelApi
import pynith.apps.nextel.helper.SessionService
import pynith.apps.nextel.helper.WebSessionHandoff
import pynith.apps.nextel.model.Country
import pynith.apps.nextel.model.CountryData
import pynith.apps.nextel.views.BaseActivity
import pynith.apps.nextel.views.us.PrivacyActivity
import pynith.apps.nextel.views.us.TermsActivity

class RegisterActivity : BaseActivity() {
    private lateinit var bind: UserRegistrationBinding
    private val api by lazy { NextelApi(this) }
    private var availableCountries: List<Country> = emptyList()
    private var isLoadingCountries = false
    private var selectedCountry: Country = CountryData.countries.first { it.code == "NG" }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        bind = UserRegistrationBinding.inflate(layoutInflater)
        setContentView(bind.root)

        setupDefaultCountry()
        setupCountryPicker()
        setupClicks()
        setupTermsAndConditions()
        loadCountries()
    }

    private fun setupTermsAndConditions() {
        val fullText = "I agree to the Terms & Conditions and Privacy Policy."
        val spannable = SpannableString(fullText)
        val termsStart = fullText.indexOf("Terms & Conditions")
        val termsEnd = termsStart + "Terms & Conditions".length
        val privacyStart = fullText.indexOf("Privacy Policy")
        val privacyEnd = privacyStart + "Privacy Policy".length

        spannable.setSpan(object : ClickableSpan() {
            override fun onClick(widget: View) {
                startActivity(Intent(this@RegisterActivity, TermsActivity::class.java))
            }

            override fun updateDrawState(ds: TextPaint) {
                ds.color = ContextCompat.getColor(this@RegisterActivity, R.color.dark_green)
                ds.isUnderlineText = false
                ds.isFakeBoldText = true
            }
        }, termsStart, termsEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)

        spannable.setSpan(object : ClickableSpan() {
            override fun onClick(widget: View) {
                startActivity(Intent(this@RegisterActivity, PrivacyActivity::class.java))
            }

            override fun updateDrawState(ds: TextPaint) {
                ds.color = ContextCompat.getColor(this@RegisterActivity, R.color.dark_green)
                ds.isUnderlineText = false
                ds.isFakeBoldText = true
            }
        }, privacyStart, privacyEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)

        bind.termsText.text = spannable
        bind.termsText.movementMethod = LinkMovementMethod.getInstance()
        bind.termsText.highlightColor = Color.TRANSPARENT
    }

    private fun setupDefaultCountry() {
        bind.countryInput.setText("${selectedCountry.flag}  ${selectedCountry.name}")
        bind.countryDialCode.text = selectedCountry.dialCode
    }

    private fun setupCountryPicker() {
        bind.countryInput.setOnClickListener { showCountryPicker() }
        bind.countryLayout.setOnClickListener { showCountryPicker() }
    }

    private fun loadCountries() {
        if (isLoadingCountries) return
        isLoadingCountries = true
        bind.countryInput.isEnabled = false
        bind.countryLayout.isEnabled = false
        bind.registerButton.isEnabled = false
        api.get("countries") { result ->
            runOnUiThread {
                if (isFinishing || isDestroyed) return@runOnUiThread
                isLoadingCountries = false
                when (result) {
                    is ApiResult.Success -> {
                        val array = countryArray(result.data.opt("countries"))
                        val dialCodes = CountryData.countries.associateBy { it.code.uppercase() }
                        availableCountries = (0 until array.length()).mapNotNull { index ->
                            val item = array.optJSONObject(index) ?: return@mapNotNull null
                            val code = item.optString("code").uppercase()
                            val name = item.optString("name").trim()
                            if (code.isBlank() || name.isBlank()) return@mapNotNull null
                            val local = dialCodes[code]
                            Country(
                                name = name,
                                code = code,
                                dialCode = local?.dialCode.orEmpty(),
                                flag = item.optString("flag").ifBlank { local?.flag.orEmpty() }
                            )
                        }

                        if (availableCountries.isEmpty()) {
                            bind.countryInput.isEnabled = true
                            bind.countryLayout.isEnabled = true
                            toast("No supported countries are currently available. Tap the country field to retry.")
                            return@runOnUiThread
                        }

                        selectedCountry = availableCountries.firstOrNull { it.code == "NG" }
                            ?: availableCountries.first()
                        bind.countryInput.isEnabled = true
                        bind.countryLayout.isEnabled = true
                        bind.registerButton.isEnabled = true
                        renderSelectedCountry()
                    }

                    is ApiResult.Failure -> {
                        bind.countryInput.isEnabled = true
                        bind.countryLayout.isEnabled = true
                        toast(result.error.displayMessage())
                    }
                }
            }
        }
    }

    private fun countryArray(value: Any?): JSONArray {
        return when (value) {
            is JSONArray -> value
            is JSONObject -> value.optJSONArray("data") ?: JSONArray()
            else -> JSONArray()
        }
    }

    private fun renderSelectedCountry() {
        bind.countryInput.setText("${selectedCountry.flag}  ${selectedCountry.name}")
        bind.countryDialCode.text = selectedCountry.dialCode
    }

    private fun showCountryPicker() {
        if (availableCountries.isEmpty()) {
            loadCountries()
            return
        }

        val dialogView = layoutInflater.inflate(R.layout.dialog_country_picker, null)
        val search = dialogView.findViewById<EditText>(R.id.countrySearch)
        val recyclerView = dialogView.findViewById<RecyclerView>(R.id.countryRecyclerView)
        recyclerView.layoutManager = LinearLayoutManager(this)

        val dialog = MaterialAlertDialogBuilder(this).setView(dialogView).create()
        val adapter = CountryAdapter(availableCountries) { country ->
            selectedCountry = country
            renderSelectedCountry()
            dialog.dismiss()
        }
        recyclerView.adapter = adapter

        search.addTextChangedListener(object : android.text.TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit

            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                val query = s?.toString()?.trim()?.lowercase().orEmpty()
                adapter.updateList(availableCountries.filter {
                    it.name.lowercase().contains(query) ||
                        it.dialCode.contains(query) ||
                        it.code.lowercase().contains(query)
                })
            }

            override fun afterTextChanged(s: android.text.Editable?) = Unit
        })

        dialog.window?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        dialog.show()
        dialog.window?.setLayout(
            (resources.displayMetrics.widthPixels * 0.92).toInt(),
            android.view.ViewGroup.LayoutParams.WRAP_CONTENT
        )
    }

    private fun setupClicks() {
        bind.backButton.setOnClickListener { finish() }
        bind.loginButton.setOnClickListener { finish() }
        bind.registerButton.setOnClickListener { register() }
    }

    private fun register() {
        clearErrors()
        val name = bind.nameInput.text?.toString()?.trim().orEmpty()
        val referralCode = bind.promoInput.text?.toString()?.trim().orEmpty()
        val phoneInput = bind.phoneInput.text?.toString()?.trim().orEmpty()
        val phone = phoneForApi(phoneInput)
        val username = bind.usernameInput.text?.toString()?.trim().orEmpty()
        val email = bind.emailInput.text?.toString()?.trim().orEmpty()
        val password = bind.passwordInput.text?.toString().orEmpty()
        var valid = true

        if (name.isBlank() || name.length > 255) {
            bind.nameInput.error = "Enter your full name"
            valid = false
        }
        if (!Regex("^[A-Za-z0-9_-]{3,30}$").matches(username)) {
            bind.usernameInput.error = "Use 3–30 letters, numbers, underscores or hyphens"
            valid = false
        }
        if (!android.util.Patterns.EMAIL_ADDRESS.matcher(email).matches()) {
            bind.emailInput.error = "Enter a valid email address"
            valid = false
        }
        if (phone.isBlank() || phone.length > 20) {
            bind.phoneInput.error = "Enter a phone number (up to 20 characters)"
            valid = false
        }
        if (password.length < 8) {
            bind.passwordInput.error = "Password must contain at least 8 characters"
            valid = false
        }
        if (!bind.termsCheckbox.isChecked) {
            Toast.makeText(this, "Please accept the Terms & Conditions and Privacy Policy", Toast.LENGTH_LONG).show()
            valid = false
        }
        if (availableCountries.none { it.code == selectedCountry.code }) {
            toast("Please select a supported country.")
            valid = false
        }
        if (!valid) return

        setLoading(true)
        val payload = JSONObject()
            .put("full_name", name)
            .put("username", username)
            .put("email", email)
            .put("phone", phone)
            .put("country", selectedCountry.code)
            .put("password", password)
            .put("agree_terms", true)
        if (referralCode.isNotBlank()) payload.put("referral_code", referralCode)

        api.post("register", payload) { result ->
            runOnUiThread {
                if (isFinishing || isDestroyed) return@runOnUiThread
                setLoading(false)

                when (result) {
                    is ApiResult.Success -> handleRegistrationSuccess(result.data, email)
                    is ApiResult.Failure -> showRegistrationErrors(result.error)
                }
            }
        }
    }

    private fun handleRegistrationSuccess(data: JSONObject, enteredEmail: String) {
        val token = data.optString("token")
        if (token.isBlank()) {
            toast("The server did not return a sign-in token.")
            return
        }

        val registrationSession = SessionService(this)
        try {
            registrationSession.saveSession(
                token,
                registrationSession.shouldRememberSession(),
            )
        } catch (_: Exception) {
            toast("Could not securely save this session. Please try again.")
            return
        }
        LogoutCoordinator.retryQueuedRevocations(this)

        val apiUser = data.optJSONObject("user")
        val user = apiUser?.optJSONObject("data") ?: apiUser ?: JSONObject()
        val userEmail = user.optString("email").ifBlank { enteredEmail }
        val onboarding = user.optJSONObject("onboarding")
        val verified = onboarding?.optBoolean("email_verified")
            ?: !user.optString("email_verified_at").isNullOrBlank()

        if (!verified || data.optBoolean("verification_required", false)) {
            val intent = Intent(this, EmailVerificationActivity::class.java)
                .putExtra(EmailVerificationActivity.EXTRA_EMAIL, userEmail)
            startActivity(intent)
            finish()
        } else {
            WebSessionHandoff.openLivewire(this) { message ->
                if (!isFinishing && !isDestroyed) toast(message)
            }
        }
    }

    private fun phoneForApi(input: String): String {
        val digits = input.filter { it.isDigit() }
        if (digits.isEmpty()) return ""
        if (input.trim().startsWith("+")) return "+$digits"
        if (digits.startsWith("00")) return "+${digits.drop(2)}"

        val dialDigits = selectedCountry.dialCode.filter { it.isDigit() }
        return when {
            dialDigits.isBlank() -> digits
            digits.startsWith(dialDigits) -> "+$digits"
            else -> "+$dialDigits$digits"
        }
    }

    private fun showRegistrationErrors(error: ApiError) {
        var shownFieldError = false
        fun show(field: String, action: (String) -> Unit) {
            error.firstFieldError(field)?.let {
                action(it)
                shownFieldError = true
            }
        }
        show("full_name") { bind.nameInput.error = it }
        show("username") { bind.usernameInput.error = it }
        show("email") { bind.emailInput.error = it }
        show("phone") { bind.phoneInput.error = it }
        show("password") { bind.passwordInput.error = it }
        if (!shownFieldError || error.statusCode == 429) toast(error.displayMessage())
    }

    private fun setLoading(loading: Boolean) {
        bind.progress.visibility = if (loading) View.VISIBLE else View.GONE
        bind.registerButton.isEnabled = !loading && availableCountries.isNotEmpty()
        bind.backButton.isEnabled = !loading
        bind.loginButton.isEnabled = !loading
    }

    private fun clearErrors() {
        bind.nameInput.error = null
        bind.phoneInput.error = null
        bind.usernameInput.error = null
        bind.emailInput.error = null
        bind.passwordInput.error = null
    }

    private fun toast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show()
    }
}
