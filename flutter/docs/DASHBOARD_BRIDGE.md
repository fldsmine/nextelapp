# Remote Dashboard and Android bridge contract

This note records the implementation contract for the Flutter Dashboard, based on the existing Android `HomeActivity`, `WebSessionHandoff`, `WebCookieJar`, `AppGateCookie`, and drawer code. The Flutter Dashboard now embeds the same remote Laravel/Livewire page; it is not a Flutter recreation. Laravel/Livewire source is not present in this repository, and this bridge implementation has not yet been analyzer-, test-, or device-verified because Flutter/Android tooling is unavailable in the current environment.

## 1. Web-session acquisition and redirect validation

1. The native-auth flow keeps the existing bearer token in Android Keystore-backed storage. Flutter reads it from `SessionStore` only when it needs an authenticated request.
2. Send `POST /api/v1/web-session` with the normal JSON envelope headers and `Authorization: Bearer <token>`.
3. Require a successful `{success, message, data}` response, a non-empty `data.redirect`, and at least one `Set-Cookie` response header.
4. Resolve only the redirect's path and query against the configured `WEB_BASE_URL` origin. Discard any redirect authority/host, reject traversal paths, and use `/dashboard` for a missing or invalid path. Never navigate to a server-returned foreign origin.
5. Write the returned cookies to Android's shared `CookieManager` for the validated destination origin, wait for every cookie callback, flush, then load that destination in the WebView.
6. On API `401`, clear the bearer session and Laravel WebView state, restore the configured/preserved `app_gate` cookie, and return to native Login. Preserve `403` suspension handling and its short-lived `support_token`.

`app_gate` is a protected Android build input (`NEXTEL_APP_GATE_COOKIE`), not a Dart constant. The native bridge may report whether it is configured, but never returns its value to Dart or JavaScript.

## 2. Cookies and HTTP client sharing

- `WebCookieJar` is the old OkHttp adapter: it reads applicable cookies from Android `CookieManager` for API requests; it does not save response cookies.
- `AppGateCookie` writes the gate cookie on the configured web origin. Logout removes Laravel cookies and WebStorage, then restores the gate cookie before another request.
- `WebSessionHandoff` writes the `web-session` response cookies for the validated redirect's origin and flushes them.
- Android WebView accepts first-party cookies and explicitly rejects third-party cookies. The Dart HTTP adapter must read/write the same Android cookie store through the narrow native channel; do not create an unrelated Dart-only cookie jar.
- Cookie bridge access is restricted natively to the exact configured API and web origins (scheme, host, effective port). Reject CR/LF in cookie values and never log cookie headers.

## 3. Existing JavaScript bridge

The registered Java object name is `Android`. Its annotated public operations and arguments are:

| Existing JS method | Arguments | Existing native effect | Flutter port action |
|---|---|---|---|
| `showMenu()` | none | Opens the native sliding drawer. | Open the Flutter navigation drawer. |
| `showProfile()` | none | Loads `/dashboard/profile` on the hosted page. | Load the validated same-origin path in the existing WebView controller. |
| `openAppSettings()` | none | Opens native App Settings. | Push Flutter Settings without replacing/recreating the Dashboard WebView. |
| `openSupportTickets()` | none | Opens native Support with the current account token. | Push Flutter Support with the current secure bearer token. |
| `openCouponSearch()` | none | Opens native Coupon Search. | Push Flutter Coupon Search. |
| `logout()` | none | Runs the native retryable logout and clears web state. | Run the same secure token revocation/queue and cookie/WebStorage clearing flow, then route to Login. |
| `handleCanvasImage(base64)` | one base64 image string | Saves a PNG named `NovaPNL-<timestamp>.png` to Pictures/NovaPNL using MediaStore on Android 10+, and legacy external Pictures storage/permission below Android 10. | Decode/size-check and call the native MediaStore/save bridge; show a clear success or failure state. |
| `handleCanvasShare(base64)` | one base64 or data-URI string | Writes a temporary PNG under app cache and launches the Android share chooser. | Decode/size-check and call the native FileProvider/share bridge. |

The UI-only Java helper methods (`saveCanvasImage`, `saveCanvasImageLess`, `shareCanvasImage`, `shareImage`, permission helpers) are not separately exposed as JavaScript methods.

## 4. Origins, navigation, and auth expiry

- The internal origin is the exact configured `WEB_BASE_URL` scheme, host, and port. Same-origin relative paths remain in the WebView. The native drawer currently loads `/dashboard`, `/dashboard/vas`, and `/dashboard/profile`.
- `/mini-app?logged_out=1` is a server-side logout signal: stop the navigation, revoke/queue the bearer token, clear WebView cookies and DOM storage, restore the app-gate cookie, and return to Login.
- `/login` and `/auth/login` are intercepted. If a local token exists, retry `web-session`; otherwise route to native Login.
- Other top-level `http`, `https`, `mailto`, and `tel` URLs are handed to the operating system. Cross-origin subframes and unsupported schemes are blocked. An HTTP URL is not considered trusted merely because its host matches an HTTPS origin.
- The existing dashboard cancels every TLS certificate error. It enables JavaScript and DOM storage, disables file/content access, mixed content, third-party cookies, and multiple windows, and uses the normal WebView cache mode.
- API `401` during `web-session` clears native session and WebView state. A same-origin WebView login redirect is intercepted and asks the API bridge to hand off again; a stale token then follows the `401` path. A `403` carrying `support_token` routes to the suspended-account/support flow.

The Flutter bridge registers one handler, accepts calls only from the exact trusted origin and main frame, validates method names and argument counts, and exposes only the operations above. The compatibility shim is injected main-frame-only with a platform-appropriate exact-origin rule. Even where Android WebView lacks document-start-script support, the handler independently checks origin and main-frame metadata before any native action. The plugin's file-chooser request does not carry frame-origin metadata, so `_showFileChooser` checks the current top-level WebView URL before allowing the native picker; see the verified URI handoff below.

## 5. File upload, camera, and gallery

The source Android `HomeActivity`'s `WebChromeClient.onShowFileChooser` presents an `ACTION_CHOOSER` with an `ACTION_GET_CONTENT` picker restricted to `image/*` plus `MediaStore.ACTION_IMAGE_CAPTURE`. Camera output is a FileProvider URI backed by a temporary file, and the selected gallery or camera URI is returned directly to the original WebView `ValueCallback<Uri[]>`. The camera is launched through an external camera app; the app does not directly access the camera device.

The Flutter app declares `flutter_inappwebview: ^6.2.0-beta.3`. In that release's platform-interface source, [`ShowFileChooserResponse.filePaths`](https://github.com/pichillilorenzo/flutter_inappwebview/blob/7ab5ae6/flutter_inappwebview_platform_interface/lib/src/types/show_file_chooser_response.dart) is documented to accept only valid `file:` URIs. Passing the native picker's `content://` URI through this Dart field violates that API contract. For a trusted top-level URL, `_showFileChooser` now returns `handledByClient: false` with no `filePaths`, invoking the plugin's native Android chooser. Its [`InAppWebViewChromeClient`](https://github.com/pichillilorenzo/flutter_inappwebview/blob/7ab5ae6/flutter_inappwebview_android/android/src/main/java/com/pichillilorenzo/flutter_inappwebview_android/webview/in_app_webview/InAppWebViewChromeClient.java) parses gallery results and passes their `Uri[]` directly to the WebView callback; its camera path uses a plugin-owned FileProvider URI. No content URI is stringified or relayed over the Dart MethodChannel. For an untrusted top-level URL, Flutter returns `handledByClient: true` with no files to cancel the request. WebView file/content access remains disabled.

The URI handoff now follows the declared plugin API and its native default path. Picker filtering/capture behavior, repeated requests, cancellation, and uploads still require device verification against the deployed dashboard; Flutter/Android tests and builds could not run in this environment.

## 6. Canvas image save/share

- Save destination: `Pictures/NovaPNL`; filename prefix `NovaPNL-`; MIME type `image/png`.
- Android 10+ uses MediaStore with scoped storage. Android 6–9 requests `WRITE_EXTERNAL_STORAGE`, writes the PNG in public Pictures, and scans it into the gallery.
- Share writes to an app-cache-only FileProvider location and opens the system `ACTION_SEND` chooser with `image/png` and a read grant. Share file paths must be restricted to the dedicated cache `shared/` directory.
- Flutter accepts PNG base64 or `data:image/png;base64,...`, validates the PNG signature, and rejects empty, malformed, non-PNG, or payloads above 16 MiB before invoking the existing native save/share channel. Native storage retains its separate 32 MiB safety cap. Canvas data is not persisted in logs or preferences.

## 7. Loading, offline, retry, and errors

- On main-frame navigation, show the branded loading/progress layer; dismiss it only after the main page loads.
- On a main-frame network or non-auth HTTP error, show a retry/offline surface. Retry only the last trusted URL, never a URL supplied by untrusted content.
- A main-frame `401`/`403` triggers a fresh authenticated `web-session` handoff; API expiry/suspension responses follow native Login/suspended cleanup. TLS errors are canceled, and subresource errors do not replace the top-level offline state.
- While a trusted main-frame navigation is loading, show the branded loading/progress layer.
- Preserve the current WebView's back stack. Back goes back inside the WebView first; when there is no page history, keep the Android double-back-to-exit behavior.
- Show auth expiry as Login/suspended flows rather than a generic offline page when the response proves the token expired. Keep offline, retryable logout-token revocation, and WebView cookie cleanup independent so cancelling reminders or updates cannot cancel logout retries.

## 8. Verification still required

The remote Dashboard's Laravel behavior cannot be tested from this repository. Before release, verify `web-session` redirects and cookie domain attributes against the backend, confirm all eight JS method call sites and argument shapes with the deployed page, and test picker/camera, canvas save/share, offline retry, auth expiry, and Android back behavior on supported API levels. Do not add extra bridge methods based only on guessed server behavior.
