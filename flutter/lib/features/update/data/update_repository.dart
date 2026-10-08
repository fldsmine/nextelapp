import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/config/app_config.dart';
import '../domain/app_update_info.dart';

/// Queries the legacy-compatible upgrade endpoint and caches the latest result.
class UpdateRepository {
  UpdateRepository({
    required AppConfig config,
    required SharedPreferences preferences,
    Dio? dio,
    DateTime Function()? clock,
  })  : _config = config,
        _preferences = preferences,
        _clock = clock ?? DateTime.now,
        _dio = dio ?? _createDio(config);

  static const checkInterval = Duration(hours: 24);
  static const _lastCheckKey = 'flutter_update_last_successful_check';
  static const _updateInfoKey = 'flutter_update_cached_info';
  static const _lastPromptedBuildKey = 'flutter_update_last_prompted_build';
  static const _lastPromptedAtKey = 'flutter_update_last_prompted_at';

  final AppConfig _config;
  final SharedPreferences _preferences;
  final DateTime Function() _clock;
  final Dio _dio;
  Future<AppUpdateInfo?>? _inFlightCheck;

  /// Performs a daily launch check. A cached mandatory update is returned on
  /// every call so a force-upgrade screen can be shown whenever the app opens.
  /// Optional updates are returned only on a fresh daily check, avoiding a
  /// prompt on every app launch.
  Future<AppUpdateInfo?> checkForStartup() async {
    final cached = await readCachedUpdate();
    if (cached?.isMandatory == true) return cached;

    final now = _clock().millisecondsSinceEpoch;
    final lastCheck = _preferences.getInt(_lastCheckKey) ?? 0;
    final elapsed = now - lastCheck;
    if (lastCheck > 0 && elapsed < checkInterval.inMilliseconds) {
      if (cached != null && _optionalPromptIsDue(cached, now)) return cached;
      return null;
    }

    return checkNow();
  }

  /// Records that an optional prompt was actually presented to the user.
  Future<void> markPrompted(AppUpdateInfo update) async {
    if (update.isMandatory) return;
    await _preferences.setInt(_lastPromptedBuildKey, update.buildNumber);
    await _preferences.setInt(
      _lastPromptedAtKey,
      _clock().millisecondsSinceEpoch,
    );
  }

  bool _optionalPromptIsDue(AppUpdateInfo update, int now) {
    final lastBuild =
        _preferences.getInt(_lastPromptedBuildKey) ?? -1;
    final lastPromptedAt = _preferences.getInt(_lastPromptedAtKey) ?? 0;
    return lastBuild != update.buildNumber ||
        lastPromptedAt <= 0 ||
        now - lastPromptedAt >= checkInterval.inMilliseconds;
  }

  /// Ignores the daily interval and is used by the explicit Settings action.
  Future<AppUpdateInfo?> checkNow() {
    return _inFlightCheck ??= _runCheckAndClearInFlight();
  }

  Future<AppUpdateInfo?> _runCheckAndClearInFlight() async {
    try {
      return await _fetchAndPersist();
    } finally {
      _inFlightCheck = null;
    }
  }

  Future<AppUpdateInfo?> readCachedUpdate() async {
    final raw = _preferences.getString(_updateInfoKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Invalid update cache.');
      final info = AppUpdateInfo.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
        currentBuild: _config.versionCode,
      );
      if (info.buildNumber <= _config.versionCode) {
        await _clearCachedUpdate();
        return null;
      }
      return info;
    } catch (_) {
      await _clearCachedUpdate();
      return null;
    }
  }

  Future<AppUpdateInfo?> _fetchAndPersist() async {
    final response = await _dio.get<Object?>(
      'app-upgrade',
      queryParameters: {
        'platform': 'android',
        'current_version': _config.versionName,
        'current_build': _config.versionCode.toString(),
      },
    );
    final info = AppUpdateInfo.fromApiResponse(
      response.data,
      currentBuild: _config.versionCode,
    );

    await _preferences.setInt(
      _lastCheckKey,
      _clock().millisecondsSinceEpoch,
    );
    if (info == null) {
      await _clearCachedUpdate();
    } else {
      await _preferences.setString(_updateInfoKey, jsonEncode(info.toJson()));
    }
    return info;
  }

  Future<void> _clearCachedUpdate() async {
    await _preferences.remove(_updateInfoKey);
    await _preferences.remove(_lastPromptedBuildKey);
    await _preferences.remove(_lastPromptedAtKey);
  }

  static Dio _createDio(AppConfig config) {
    final uri = Uri.tryParse(config.updateApiBaseUrl.trim());
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        config.updateApiBaseUrl,
        'updateApiBaseUrl',
        'Must be an HTTPS URL without embedded credentials.',
      );
    }
    final baseUrl = uri.replace(query: null, fragment: null).toString();
    return Dio(
      BaseOptions(
        baseUrl: '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/',
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
        headers: const {'accept': 'application/json'},
      ),
    );
  }
}
