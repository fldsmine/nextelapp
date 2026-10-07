package pynith.apps.nextel.helper

import android.net.Uri
import android.webkit.CookieManager
import pynith.apps.nextel.BuildConfig

/**
 * Installs the `app_gate` entry cookie required by the configured web origin.
 * Its value is supplied via the protected `NEXTEL_APP_GATE_COOKIE` build
 * input, not embedded in source. This covers WebView navigations, page
 * subresources and the native API client ([NextelApi]) alike.
 *
 * The cookie is stored in the shared WebView cookie store
 * (android.webkit.CookieManager) rather than injected as a request header, so
 * the WebView attaches it automatically to every applicable request, and
 * [WebCookieJar] reads the same store for API requests.
 */
object AppGateCookie {

    private const val NAME = "app_gate"

    /**
     * Idempotently writes the gate cookie and persists it.
     *
     * Must run before the first request/navigation to the web domain.
     * [pynith.apps.nextel.App.onCreate] guarantees this for every entry point
     * of the process (activities, services, workers). The logout paths
     * ([LogoutCoordinator] and [WebSessionHandoff]) re-run it after they wipe
     * the cookie store, so the gate cookie also survives a logout.
     */
    fun ensureInstalled() {
        val cookieManager = CookieManager.getInstance()

        // Cookies are accepted by default; make it explicit so no WebView
        // provider or future setting can silently drop them.
        cookieManager.setAcceptCookie(true)

        val webBase = Uri.parse(BuildConfig.WEB_BASE_URL)
        val host = webBase.host ?: return
        val scheme = webBase.scheme?.takeIf { it.isNotBlank() } ?: "https"
        val value = BuildConfig.APP_GATE_COOKIE.trim()

        // The cookie is provided only by protected build configuration. If it
        // is omitted, leave any cookie already present in the WebView store
        // untouched instead of replacing it with an empty or source default.
        if (value.isBlank()) return

        // Domain cookie for the web host and its subdomains, every path,
        // secure transports only.
        cookieManager.setCookie(
            "$scheme://$host/",
            "$NAME=$value; Domain=$host; Path=/; Secure"
        )

        // setCookie() has already updated the in-memory store that the next
        // request reads from; flush() persists it so the cookie also survives
        // a process restart. flush() exists since API 21 and minSdk is 23,
        // so no Build.VERSION guard is required.
        cookieManager.flush()
    }
}
