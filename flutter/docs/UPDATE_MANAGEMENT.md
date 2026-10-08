# Update management

The Flutter app now owns the update prompt and release-notes experience. Android remains responsible for the package-install permission and opening the package installer.

## Endpoint and cadence

`UpdateRepository` calls the existing `GET <updateApiBaseUrl>/app-upgrade` endpoint with the Kotlin contract:

- `platform=android`
- `current_version=<native version name>`
- `current_build=<native version code>`

It reads the standard `data` envelope and these fields: `update_available`, `update_required`, and `latest.version_name`, `build_number`, `minimum_supported_build`, `force_update`, `title`, `release_notes`, `server_download_url`, `play_store_url`, and `published_at`.

The splash starts a daily-cadence check in parallel with session restoration. It waits up to one second for the update result before continuing; a slower request can finish and cache the result for the next launch. Optional prompts are limited to once per build per 24 hours. A cached mandatory update is surfaced at each cold launch. Settings also provides an explicit check that bypasses the daily interval.

An update is mandatory when `update_required` or `force_update` is true, or the installed build is below `minimum_supported_build`. Release notes are displayed as a list. Only HTTPS store/download links without embedded credentials are opened.

## APK download and install

APK downloads use app-private storage under `files/updates/`; the FileProvider exposes only that directory. The native `installApk` bridge canonicalizes and validates the requested path, checks that it is a non-empty `.apk` directly inside the update directory, then gives Android's installer a temporary read grant. Android 8+ users are sent to the per-app "install unknown apps" permission screen and returned to the Flutter update page to continue. Store/browser fallback remains available when the API supplies a valid HTTPS link.

No legacy public-storage permission is requested for updater downloads. Android Package Installer remains responsible for package identity/signature validation. We have not verified download, unknown-app permission, or install/upgrade behavior on a device.

## Remaining gap

The legacy Kotlin application schedules a network-constrained periodic WorkManager job and can check while the app is not running. The Flutter app does **not** yet schedule a periodic/background update worker: it checks at cold launch (daily cadence) and when the user selects **Settings → Check for updates**. WorkManager scheduling, background delivery/resume behavior, and installer/device tests remain follow-up work.
