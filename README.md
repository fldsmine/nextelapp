# Nextel Android app

This is the native Kotlin/Java Android client. Authentication, registration, email verification, password reset, and suspended-account handling run natively against the existing Laravel `/api/v1` API. After authentication, the app exchanges its Sanctum token for Laravel web-session cookies and opens the Livewire dashboard in `HomeActivity`'s WebView. The Laravel/backend source is not modified by the Android client work.

## Build prerequisites

- JDK 21
- Android SDK Platform 36 and Android Gradle Plugin-compatible Build Tools
- Android SDK location provided by `ANDROID_HOME` / `ANDROID_SDK_ROOT`, or an untracked `local.properties` containing `sdk.dir=...`
- Network access to the configured Maven repositories on the first build

From this directory:

```bash
./gradlew :app:assembleDebug
```

For a unit-test task (once tests exist):

```bash
./gradlew :app:testDebugUnitTest
```

## API and WebView URLs

The release build defaults to the production web host and its `/api/v1` API. The current debug defaults are `https://api.n-calls.com` for the web host and its `/api/v1` API (the earlier emulator-host description was stale).

Override debug URLs using Gradle properties or environment variables:

```bash
./gradlew :app:assembleDebug \
  -PnextelDebugWebBaseUrl=https://dev.example.test \
  -PnextelDebugApiBaseUrl=https://dev.example.test/api/v1
```

Equivalent environment variables are `NEXTEL_DEBUG_WEB_BASE_URL` and `NEXTEL_DEBUG_API_BASE_URL`. The web and API deployments must share the Laravel session store and cookie domain so the `web-session` handoff can authenticate the WebView. Cleartext HTTP is allowed only for emulator host `10.0.2.2`; use HTTPS for other development hosts.

Production/release URL overrides are `NEXTEL_WEB_BASE_URL` and `NEXTEL_API_BASE_URL` (or Gradle properties `nextelWebBaseUrl` and `nextelApiBaseUrl`). The Flutter module also keeps the update-feed base URL independently configurable with `NEXTEL_UPDATE_API_BASE_URL` or `-PnextelUpdateApiBaseUrl`; it retains the legacy update host by default. Confirm the production/staging feed host with the backend owner before release rather than assuming it is the main API host.

The native app-gate cookie is supplied to builds through `NEXTEL_APP_GATE_COOKIE` (or Gradle property `nextelAppGateCookie`). It has no source-code fallback; provide it only through a protected local/CI environment. Existing WebView cookies are left intact if this input is omitted. Never add the value to Dart source or a committed configuration file.

## Signed release builds

No signing key or passwords are stored in the repository. Supply these environment variables locally or in a protected build environment:

- `NEXTEL_RELEASE_STORE_FILE`
- `NEXTEL_RELEASE_STORE_PASSWORD`
- `NEXTEL_RELEASE_KEY_ALIAS`
- `NEXTEL_RELEASE_KEY_PASSWORD`

The retained Android client no longer depends on Firebase or social-login SDK configuration. Its authenticated product screens are served by Livewire; Android-specific file picking and canvas saving/sharing remain native. Flutter API tokens are stored with encrypted session storage, and queued logout revocations are mirrored into an AES-GCM/Android-Keystore queue for network-constrained WorkManager retries. When Remember Me is off, a saved token is queued for revocation on process restart. Biometric sign-in uses an Android `BIOMETRIC_STRONG` prompt to validate the remembered encrypted token and does not persist or replay the account password; legacy plaintext username/password preference keys are cleared at startup.

## Flutter migration app

The parallel Flutter application lives in [`flutter/`](flutter/). Its Games route (`/games`) integrates the uploaded `actual-flutter-game/` Dart sources and assets—Dice, Hangman, Ludo and Hangman scores—into the existing GoRouter/Riverpod app. Flutter-side cards/help widgets fill source imports that were not part of the upload. The Dashboard drawer also preserves the account header, native share chooser, Play Store rating flow and the Airdrops placeholder. Legacy Dice history and Hangman score preferences are imported into the Flutter games' persistence formats. Use Flutter 3.32 or newer with Dart 3.8 or newer, then run `cd flutter && flutter pub get && flutter analyze && flutter test` to check the migration. Device/build verification still depends on the relevant Flutter and Android toolchains.
