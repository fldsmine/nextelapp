# About and FAQ migration contract

Flutter now provides `/about` and `/faq` routes. They replace the local native About and Frequently Asked Questions screens; the native Activities remain in the Android project until Flutter parity is verified.

## About

- Preserve the `Next-Gen Memecoin App` tagline, local About copy, four product highlights, and developer credit from the Android resources. Display the active Android `BuildConfig.VERSION_NAME` (`3.5.alpha`) rather than the stale About resource label (`2.4-beta`).
- The native “Support link” opens `https://t.me/nextelconnect_support01` externally. Flutter uses the existing `url_launcher` dependency and reports an error if no external app can handle it.
- The native “Online chat” action actually opens the authenticated Support screen (despite its label); Flutter follows that behavior by opening the existing Support route with the current session token.

## FAQ

- Preserve the six local question-and-answer entries from `app/src/main/res/values/strings.xml`.
- FAQ is available from the Dashboard drawer and the About page. Its support action opens the authenticated Flutter Support route.
- Terms and Privacy remain on the existing remote legal routes and are exposed in the Dashboard drawer; this migration does not copy or invent legal text.

The content model has unit tests. Flutter analyzer/tests, Android build, navigation, external Telegram launch, and device behavior are still unverified in this environment.
