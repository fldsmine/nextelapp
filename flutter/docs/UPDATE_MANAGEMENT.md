# Update management

The Flutter app owns update state, prompting and release notes. Android retains the network-constrained WorkManager task for checks while the app is inactive, plus the package-install permission and installer handoff.

## Endpoint and cadence

`UpdateRepository` calls the existing `GET <updateApiBaseUrl>/app-upgrade` endpoint with the Kotlin contract:

- `platform=android`
- `current_version=<native version name>`
- `current_build=<native version code>`

It reads the standard `data` envelope and these fields: `update_available`, `update_required`, and `latest.version_name`, `build_number`, `minimum_supported_build`, `force_update`, `title`, `release_notes`, `server_download_url`, `play_store_url`, and `published_at`.

The splash starts a daily-cadence check in parallel with session restoration. It waits up to one second for the update result before continuing; a slower request can finish and cache the result for the next launch. Android WorkManager also schedules a 24-hour periodic check constrained to a connected network. The worker uses a separate durable preference store exposed through the native bridge; Flutter imports new results at startup or when the app resumes and surfaces them through the existing update screen. Optional prompts are limited to once per build per 24 hours. Cached mandatory updates are surfaced whenever the app starts or returns to the foreground. Settings also provides an explicit check that bypasses the daily interval.

An update is mandatory when `update_required` or `force_update` is true, or the installed build is below `minimum_supported_build`. Release notes are displayed as a list. Only HTTPS store/download links without embedded credentials are opened.

## APK download and install

APK downloads use app-private storage under `files/updates/`; the FileProvider exposes only that directory. The native `installApk` bridge canonicalizes and validates the requested path, checks that it is a non-empty `.apk` directly inside the update directory, then gives Android's installer a temporary read grant. Android 8+ users are sent to the per-app "install unknown apps" permission screen and returned to the Flutter update page to continue. Store/browser fallback remains available when the API supplies a valid HTTPS link.

No legacy public-storage permission is requested for updater downloads. Android Package Installer remains responsible for package identity/signature validation. We have not verified download, unknown-app permission, or install/upgrade behavior on a device.

## WorkManager and remaining verification

The Flutter Android module now schedules a unique 24-hour periodic WorkManager job with a connected-network constraint. Transient failures return `Result.retry()`; the feed's contract-mismatch responses (HTTP 404/405) are not retried. Worker results are stored separately from Flutter plugin preferences and transferred through a narrow MethodChannel method, avoiding reliance on the plugin's private storage format. No notification is emitted while the app is closed; the pending update is presented on the next app start/resume, matching the previous foreground-prompt behavior.

WorkManager timing, reboot/upgrade persistence, foreground handoff, unknown-app permission, and installer behavior still need Android device verification. This environment has no Android/Flutter toolchains, so those checks and the Dart test suite could not be executed here.
