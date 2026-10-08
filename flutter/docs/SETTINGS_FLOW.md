# App settings migration contract

Flutter's `/settings` route replaces the active `AppSettingsActivity` entry point. The Kotlin activities and preference fragment remain in the repository until the Flutter app is verified.

## Preferences and appearance

- Preserve the legacy `app_prefs` values: `notifications_enabled` (default `true`), `sound` (`true`), `vibration` (`false`), `daily_reminder` (`false`), `xbg_biometric_enabled` (`false`), `theme` (`Light`), `fontFamily` (`Patrick`), and `fontScale` (`1.0`). The one-time migration imports those keys; Flutter changes are also mirrored through an allowlisted platform-channel method for Android compatibility.
- Theme choices are Light, Dark and Blue. Font families are Poppins, Roboto, Nunito, Patrick and Montserrat. The font-scale setting clamps legacy values to 0.75–2.5 and applies to Flutter text; hosted WebView text remains controlled by the website.
- The app uses the migrated theme extension for Flutter-owned screens so palette changes apply across auth, Dashboard chrome, Support, Coupon, legal and settings pages.

## Device settings

- Settings reads the current Android notification permission and shows an explicit allow-permission action when Android 13+ access is missing. Enabling notifications also requests Android 13+ permission. Sound and vibration remain app preferences and are reflected in the daily reminder's notification channel.
- Daily reminders use Android exact alarms at 08:00, 15:00 and 19:07 in `Africa/Lagos`. A small Flutter-app receiver reschedules each one after delivery and restores them after reboot. Enabling may take the user to Android's exact-alarm access page. Disabling cancels only these reminder alarms/notifications; it does not cancel unrelated WorkManager work.
- Biometric opt-in requires an active token and a successful biometric-only local-auth prompt. The token is stored persistently in encrypted session storage before the setting is enabled; opting in therefore makes the session survive process restart, consistent with the native flow. The Android activity extends `FlutterFragmentActivity` for the plugin's biometric prompt.

## Account actions

- Support opens the existing Flutter Support route with the current token; Coupon opens the public Flutter verification route.
- Logout uses the existing best-effort server revocation queue and clears the local token and WebView session before returning to Login.
- Account deletion is not performed in Settings; the confirmation directs users to Support.

Flutter/Dart/Android tooling is unavailable in this environment. Analyzer, tests, Android build, notification permission/alarm behavior, biometric availability, and on-device settings persistence must be verified before marking this phase production-ready.
