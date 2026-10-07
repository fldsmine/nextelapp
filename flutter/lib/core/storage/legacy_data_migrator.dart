import 'package:shared_preferences/shared_preferences.dart';

import '../security/native_platform_bridge.dart';
import '../security/session_store.dart';

/// One-time, retryable import from the original app's named SharedPreferences
/// and Android Keystore. Source data is only cleared after Flutter has saved it.
class LegacyDataMigrator {
  LegacyDataMigrator({
    required NativePlatformBridge nativeBridge,
    required SessionStore sessionStore,
    required SharedPreferences preferences,
  })  : _nativeBridge = nativeBridge,
        _sessionStore = sessionStore,
        _preferences = preferences;

  static const String _completionKey = 'migration.legacy_native.v1.complete';
  static const String _diceHistoryKey = 'games.dice.history.v1';
  static const String _hangmanScoresKey = 'games.hangman.scores.v1';

  final NativePlatformBridge _nativeBridge;
  final SessionStore _sessionStore;
  final SharedPreferences _preferences;

  Future<bool> migrate() async {
    if (_preferences.getBool(_completionKey) ?? false) return true;

    final legacy = await _nativeBridge.readLegacyData();
    if (legacy == null) return false;

    try {
      await _copySettings(legacy['settings']);
      await _copyJsonPreference(_diceHistoryKey, legacy['diceHistory']);
      await _copyJsonPreference(_hangmanScoresKey, legacy['hangmanScores']);

      final session = _asStringMap(legacy['session']);
      final remember = session['rememberMe'] is bool
          ? session['rememberMe']! as bool
          : true;
      await _sessionStore.setRememberMe(remember);
      final token = session['token'];
      if (token is String && token.isNotEmpty && await _sessionStore.readToken() == null) {
        await _sessionStore.saveToken(token, remember: remember);
      }

      final pending = session['pendingLogoutTokens'];
      if (pending is List) {
        for (final candidate in pending.whereType<String>()) {
          await _sessionStore.queueLogoutToken(candidate);
        }
      }

      if (session['safeToComplete'] != true) return false;
      final nativeCleared = await _nativeBridge.completeLegacyImport();
      if (!nativeCleared) return false;
      await _preferences.setBool(_completionKey, true);
      return true;
    } catch (_) {
      // Keep the native copy intact and retry on the next launch.
      return false;
    }
  }

  Future<void> _copySettings(Object? rawSettings) async {
    final settings = _asStringMap(rawSettings);
    for (final entry in settings.entries) {
      if (_preferences.containsKey(entry.key)) continue;
      final value = entry.value;
      switch (value) {
        case bool value:
          await _preferences.setBool(entry.key, value);
        case int value:
          await _preferences.setInt(entry.key, value);
        case double value:
          await _preferences.setDouble(entry.key, value);
        case String value:
          await _preferences.setString(entry.key, value);
        case List<String> value:
          await _preferences.setStringList(entry.key, value);
        default:
          break;
      }
    }
  }

  Future<void> _copyJsonPreference(String key, Object? raw) async {
    if (raw is! String || raw.isEmpty || _preferences.containsKey(key)) return;
    await _preferences.setString(key, raw);
  }

  Map<String, Object?> _asStringMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
}
