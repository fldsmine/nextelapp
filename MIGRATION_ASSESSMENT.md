# Nextel Android → Flutter Migration Assessment

**Scope:** repository inspection plus incremental implementation notes. Flutter migration work is in progress on `arena/9171df30-nextelapp`; this document is a roadmap, not a claim of release verification. Native Kotlin screens remain in the repository until Flutter parity is verified.

## 1. Existing application architecture

- The source product is a native Android app using Kotlin and some Java, XML layouts, View/Data Binding, AndroidX, and Material Components. It is **not** Jetpack Compose. A Flutter project now lives under `flutter/` alongside the retained Android implementation.
- App identity is `pynith.apps.nextel` / **Nextel**. Android config is min SDK 23, target SDK 34, compile SDK 36, version `3.5.alpha` / code 4, with debug and release build types and no product flavors.
- The original native user journey was: animated splash → login/register/verification/reset → bearer-token validation → `web-session` API handoff → authenticated Laravel/Livewire dashboard in Android `WebView`.
- The repository does **not** contain the Laravel backend or the Livewire dashboard source. The dashboard, profile, and VAS/feature pages are remote web pages; native reconstruction of those pages cannot be derived from this checkout. The parity-preserving default is to keep that dashboard in a Flutter WebView and migrate the Android-owned screens and bridge behavior.
- There is a central OkHttp JSON client and helper/service classes, but no consistent ViewModel/repository/domain layering. UI and state live mostly in Activities; the three games have separate rule/controller classes.

## 2. Screen and flow checklist

### Incremental migration status (2026-10-08)

| Area | Flutter status | Verification status |
|---|---|---|
| Auth and account recovery | Implemented | Analyzer, tests, Android build and device flow remain pending. |
| Dashboard WebView and native bridge | Implemented | Web session, upload/canvas and device behavior remain pending. |
| Support tickets | Implemented | API contract and device flow remain pending. |
| Coupon verification | Implemented | API response fields and device flow remain pending. |
| App settings | Implemented (source-level) | Code reviewed; analyzer, tests, Android build and device behavior remain pending. |
| About and FAQ | Implemented (source-level) | Local copy and navigation implemented; analyzer, tests, Android build and device behavior remain pending. |
| Games, update management and other native integrations | Not yet migrated | See the feature checklist below. |


| Android screen / entry → destinations | Behavior, data, validation and states to preserve | Flutter target |
|---|---|---|
| Splash → Login | Branded animated logo; startup update scheduling. | Flutter splash/launch state; preserve app icon and animation feel. |
| Login → Register, Reset, Verification, Suspended, Dashboard | `POST login` with email-or-username and untrimmed password; required-field checks; loading, field/API errors, 401/403 handling. Saved tokens are checked with `GET user`; verified users call `POST web-session`. Remember Me and optional biometric shortcut. | Flutter form + auth controller/repository; keep the API contract and route transitions. |
| Register → Verification or Dashboard | Loads `GET countries`; defaults to Nigeria; searchable country picker; formats phone with country dial code. Required full name, username 3–30 `[A-Za-z0-9_-]`, valid email, phone ≤20 chars, password ≥8, accepted Terms/Privacy; optional referral code. `POST register`; loading, country-empty/error and server field errors. | Flutter form + country picker; preserve server-driven country list and validation. |
| Email verification → Dashboard / Login | Requires a six-digit code; `POST email/verify`; `POST email/resend`; token-expiration handling; loading and server errors. | Flutter verification page/controller. |
| Password reset → Login | Valid email; request code using `POST password/forgot`; reset with email + six-digit code + password ≥8 using `POST password/reset`; clears session after success. | Flutter reset flow/controller. |
| Suspended account → Support / Login | Shows server message; support may receive a short-lived support token. | Flutter status screen and support navigation. |
| Dashboard (`HomeActivity`) → profile, VAS, native settings/support/coupon, logout | Remote `/dashboard`, `/dashboard/profile`, `/dashboard/vas`; progress, offline/error retry and WebView back stack. Trusted-origin navigation only; external HTTP(S), `mailto:`, and `tel:` open externally. JavaScript bridge handles menu/profile/settings/support/coupon/logout and canvas save/share. Web upload permits image selection and camera capture. | Flutter `webview_flutter` page plus narrowly scoped platform/JS bridge. Keep remote web UI; validate all bridge calls and trusted origins. |
| Support → ticket list → conversation → reply | `GET support-tickets`; `POST support-tickets` (subject ≥4 chars, message ≥5, category general/account/payments/technical); `GET support-tickets/{id}`; `POST support-tickets/{id}/messages` (nonempty reply). Account header, empty list, progress, field errors, and expired-token retry/redirect. | Flutter feature with typed models, repository and explicit loading/empty/error states. |
| Coupon search → result | Public `GET coupons/verify?code=...`; code required and ≥3 chars. Displays validity, product/batch, agent/redeemer, and localized dates; supports not-found/server error. | Flutter form/results feature; preserve conditional fields and response model. |
| App settings | Persistent notification enable, sound/vibration, reminder, 3 themes (Light/Dark/Blue), 5 font families and font size; strong-biometric opt-in; support/coupon/logout; account deletion directs to support. | Flutter settings/state; use native biometric capability through an appropriate Flutter equivalent. |
| Games hub → Dice / Hangman / Ludo / Scores | Dice is a local demo bankroll game (₦500,000 start; ₦10–₦100,000 bet; matching face pays 5×; manual/Martingale/Fixed auto-play up to 10 rolls; last 100 rolls persisted). Hangman uses bundled words, 5 lives, one hint per word, and keeps score history (top 25 stored, top 10 displayed). Ludo is four-player pass-and-play with animated board, captures/safe cells, extra turns, exact finish, and first-three-winners end rule. | Flutter game hub/screens; put pure rules in testable Dart domain classes and preserve existing local histories. |
| About / FAQ / Terms / Privacy | About and FAQ are local native layouts; Terms and Privacy load remote web pages. About links to external support/social endpoints. | Flutter information screens; retain remote legal content URLs unless backend supplies a stable native source. |
| Update page / background checker | WorkManager checks update feed; optional/mandatory update UI, notes, APK download/progress/cancel/install prompt or external store/browser fallback. Uses unknown-app install permission and FileProvider. | Flutter update flow where possible; keep the Android package-install/native background parts isolated if Flutter packages do not preserve behavior. |
| Store / Notice / legacy Settings | Store shows “coming soon” data; Notice is a simple layout; a separate PreferenceFragment settings screen exists. These Activities are declared but no active entry point was found for them. | Investigate actual reachability before treating these as active flows; do not invent behavior. |

### Feature disposition checklist

| Feature | Assessment status | Notes |
|---|---|---|
| Splash, login, registration, email verification, password reset, suspended-account handling | **Migrate** | Preserve API validations, field errors, navigation, loading and session transitions. |
| Support tickets and coupon verification | **Migrate** | Native flows are implemented in this repository and have explicit API contracts. |
| Settings, themes/fonts, game hub, Dice, Hangman, Ludo, scores, About and FAQ | **Migrate** | Retain preference/history behavior and bundled visual assets. |
| Laravel/Livewire dashboard and legal pages | **Needs Flutter equivalent** | `webview_flutter` is the parity path because server-rendered frontend source is absent. |
| API networking and serialization | **Needs Flutter equivalent** | Dio + typed models/errors; keep endpoint contracts. |
| Existing secure session, named SharedPreferences and WebView cookies | **Requires native Android integration** | One-time bridge/import is needed to avoid losing installed users' sessions/preferences. |
| Biometric unlock | **Needs Flutter equivalent** | Use platform biometric auth and secure token access; never migrate plaintext password storage. |
| WebView image picker/camera and canvas save/share | **Needs Flutter equivalent** | Use Flutter media/share APIs where supported; retain a small Android bridge for chooser/MediaStore gaps. |
| Exact reminders, notification delivery, update checks and retryable logout | **Requires native Android integration** | Verify plugin parity for exact alarms/WorkManager; preserve scheduling and retry semantics. |
| APK download and package installation | **Requires native Android integration** | Android's unknown-app install permission and package installer remain platform-owned. |
| Existing Room/SQLite schema migration | **Not applicable** | No Room, SQLite or app database exists. Migrate preference-backed data instead. |
| Firebase/social-login integration | **Not applicable (verify stale config)** | No Firebase SDK/plugin or active social sign-in flow is configured in this app. |
| Store, Notice, legacy `SettingsActivity`, duplicate `WebTimeline`, QR helper | **Requires investigation** | Declared or present, but no active entry point/call site was found for several of these. |

## 3. API, auth, persistence and device-function inventory

- **API contract:** OkHttp sends JSON, `Accept: application/json`, optional Bearer token, parses `{success,message,data,errors}`, field errors and `Retry-After`. Endpoints found: `login`, `user`, `register`, `countries`, `email/verify`, `email/resend`, `password/forgot`, `password/reset`, `web-session`, `logout`, `support-tickets` (+ ticket/messages), `coupons/verify`. Update feed is separately queried at `/api/v1/app-upgrade`.
- **Web session:** `web-session` returns a same-origin redirect and `Set-Cookie` values. The app installs an `app_gate` cookie, validates the destination host, writes cookies into Android `CookieManager`, and shares that store with WebView and the OkHttp `WebCookieJar`. Logout clears cookies/WebStorage and queues token revocation when offline.
- **Persistence:** no Room, SQLite, DataStore, or app database is present. Tokens and queued logout tokens use AES-GCM with Android Keystore; settings use named `SharedPreferences`; Dice history and Hangman scores use their own `SharedPreferences`; WebView cookies/DOM storage are separate. Canvas images, camera temp files and downloaded APKs use app/external storage or MediaStore.
- **Permissions/native behavior:** Internet/network, legacy storage (limited to old Android versions), notification posting, exact alarms, unknown-package install, and biometric permission. Camera/gallery are launched through Android intents. App has no declared app-link/deep-link filters beyond launcher.
- **Notifications/background:** daily reminders are scheduled for 08:00, 15:00 and 19:07 in `Africa/Lagos`; update checks and pending logout retries use WorkManager. APK installation, exact-alarm scheduling, shared WebView cookies, and Keystore migration are the main candidates for a small Kotlin/platform-channel layer.

## 4. Dependency mapping (based on actual use)

| Android component/dependency | Observed use | Flutter direction |
|---|---|---|
| Android Activities, XML, Material Components, custom views | Auth, support, coupon, settings, games and information UI | Feature-based Flutter pages/widgets; reproduce the green/cream brand palette, separate dark/yellow auth treatment, and supplied font families. |
| OkHttp + custom `NextelApi` | JSON API, cookies, update/APK network I/O | Dio + repository/data-source boundary and typed API errors; coordinate cookies with the native WebView cookie store. |
| Android WebView + `JavascriptInterface` | Livewire dashboard, media picker, canvas, logout/navigation bridge | `webview_flutter` with a restricted JavaScript channel and explicit URL allowlist; retain a small Android bridge where required. |
| Android Keystore + SharedPreferences | Encrypted token/queued revocation, preferences and game history | `flutter_secure_storage` for secrets, `shared_preferences` for non-sensitive settings; a one-time Kotlin importer is needed to preserve existing Android namespaces/Keystore-encrypted data. |
| WorkManager / AlarmManager / NotificationCompat | Update checks, logout retry, reminders | Evaluate `workmanager` and `flutter_local_notifications`; keep native exact-alarm/update/install hooks if the selected plugins cannot match the existing behavior. |
| AndroidX Biometric | Strong-biometric enable/login | `local_auth`, preserving the requirement for a remembered secure session. |
| Gson / hand-written JSON models | Drawer profile and coupon response parsing | Dart model classes; add `json_serializable` only if it materially reduces model boilerplate. |
| Glide | Drawer profile image | Flutter image provider/cache only if that UI remains; avoid an image package if not needed. |
| RecyclerView / custom game board views | Country list, support cards, games | Flutter scrollable/list widgets and `CustomPainter` for the board/dice/canvas. |
| Material, fonts and image resources | Existing visual language and artwork | Reuse needed raster artwork and the five bundled font families as Flutter assets; regenerate/adapt launcher assets. |
| uCrop, RxJava/RxAndroid, SwipeRefreshLayout, Firebase | No call sites/dependency use found for uCrop/RxJava/SwipeRefresh; no Firebase SDK/plugin configured. `google-services.json` is present. | Do not add Flutter replacements without a real call site; verify whether these files/dependencies are stale before removing them. ZXing QR helper also appears unreferenced. |

## 5. Recommended Flutter shape

Use feature-first folders with `flutter_riverpod` for state, `go_router` for auth/dashboard/settings/game navigation, Dio repositories for the Laravel API, `flutter_secure_storage` plus a first-run native data importer, and `webview_flutter` for the existing Livewire surface. Keep domain logic (validation, coupon mapping, game rules and update state) out of widgets and cover it with Dart unit tests. Preserve the application ID, assets/fonts and stored user data. Keep native Kotlin limited to Android-specific migration/bridging that packages cannot safely reproduce (legacy Keystore/preferences import, shared `CookieManager`, exact alarms and APK installation if needed).

## 6. Risks, assumptions and items to verify before release

1. **Dashboard source is absent.** Flutter can preserve the hosted Livewire UI, but pixel-level/native recreation of it requires the separate Laravel/frontend repository and backend contract.
2. **Existing-install continuity is required.** Flutter's preference file is not the Android app's current named preferences. A one-time bridge must migrate settings, game histories, and the encrypted session without invalidating existing users or web cookies.
3. **Credential handling needs security review.** Login currently writes username/password to ordinary SharedPreferences for biometric sign-in even though the token is encrypted. The Flutter version should not retain a plaintext password; biometric unlock should gate a secure token instead.
4. **Release signing configuration conflicts with README.** `app/build.gradle` contains fallback signing credentials while README says credentials are never stored. Remove defaults and require protected local/CI secrets before release.
5. **Environment config disagrees.** The Gradle debug URL defaults differ from README's emulator URL; update feed host is hard-coded separately from the configurable API base. Confirm intended dev/staging/production endpoints before moving them to `--dart-define`/CI configuration.
6. **Reminder implementation needs behavior review.** No notification-channel creation or boot receiver was found; exact reminders appear one-shot rather than self-rescheduling, and `cancelAll()` cancels all WorkManager jobs, including unrelated update/logout work. Preserve intended reminders while correcting these side effects.
7. **The `app_gate` cookie is statically embedded in the client.** Do not copy its value into Dart or expose it in documentation; confirm its purpose and rotation/security model with the backend owner.
8. **Some Android entries look legacy/unreachable.** `WebTimeline`, `SettingsActivity`, `StoreActivity`, `NoticeActivity`, the unused Firebase config, and several assets/dependencies require reachability/use checks.

## 7. Baseline verification

The Android source still has only generated example tests; Flutter now has unit tests for auth validation, API failures, bridge parsing, Support, Coupon, settings models and About/FAQ content. This environment has no Flutter, Dart, Java, or Android SDK on `PATH`, so Flutter analysis/tests/builds (and Android Gradle builds) cannot currently be run. Install/configure Flutter + Android toolchains before claiming a verified migration.
