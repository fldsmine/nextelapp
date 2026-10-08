import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_platform_bridge.dart';

/// Stores bearer tokens and retryable logout tokens in encrypted storage.
/// Remember-Me=false sessions exist only in memory for this process.
class SessionStore {
  SessionStore({
    FlutterSecureStorage? secureStorage,
    required SharedPreferences preferences,
    NativePlatformBridge? nativePlatformBridge,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _preferences = preferences,
        _nativePlatformBridge = nativePlatformBridge;

  static const String _tokenKey = 'session.api_token.v1';
  static const String _logoutQueueKey = 'session.pending_logout_tokens.v1';
  static const String _rememberKey = 'session.remember_me';
  static const String _biometricKey = 'xbg_biometric_enabled';

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _preferences;
  final NativePlatformBridge? _nativePlatformBridge;
  String? _volatileToken;

  bool get rememberMe => _preferences.getBool(_rememberKey) ?? true;
  bool get biometricEnabled => _preferences.getBool(_biometricKey) ?? false;

  Future<void> setRememberMe(bool value) async {
    await _preferences.setBool(_rememberKey, value);
    if (!value) {
      // Match the native flow: keep this process's active token available, but
      // disable biometric sign-in. Startup queues/revokes a remembered token
      // if the user opted out and the process has since been restarted.
      await _preferences.setBool(_biometricKey, false);
    }
  }

  Future<void> expireUnrememberedSession() async {
    if (rememberMe) return;
    final storedToken = await _secureStorage.read(key: _tokenKey);
    if (storedToken == null || storedToken.isEmpty) return;
    await queueLogoutToken(storedToken);
    await _secureStorage.delete(key: _tokenKey);
    _volatileToken = null;
  }

  Future<void> setBiometricEnabled(bool value) async {
    await _preferences.setBool(_biometricKey, value);
  }

  Future<String?> readToken() async {
    final volatileToken = _volatileToken;
    if (volatileToken != null && volatileToken.isNotEmpty) return volatileToken;
    if (!rememberMe) return null;
    return _secureStorage.read(key: _tokenKey);
  }

  Future<void> saveToken(String token, {required bool remember}) async {
    if (token.trim().isEmpty) {
      throw ArgumentError.value(token, 'token', 'Token must not be empty.');
    }
    await _preferences.setBool(_rememberKey, remember);
    if (remember) {
      await _secureStorage.write(key: _tokenKey, value: token);
      _volatileToken = token;
    } else {
      await _secureStorage.delete(key: _tokenKey);
      _volatileToken = token;
      if (biometricEnabled) await setBiometricEnabled(false);
    }
  }

  Future<void> replaceToken(String token, {required bool remember}) async {
    final oldToken = await readToken();
    if (oldToken != null && oldToken.isNotEmpty && oldToken != token) {
      await queueLogoutToken(oldToken);
    }
    await saveToken(token, remember: remember);
  }

  Future<void> clearToken() async {
    _volatileToken = null;
    await _secureStorage.delete(key: _tokenKey);
    await _preferences.setBool(_biometricKey, false);
  }

  Future<List<String>> pendingLogoutTokens() async {
    final raw = await _secureStorage.read(key: _logoutQueueKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.whereType<String>().where((value) => value.isNotEmpty).toSet().toList();
    } on FormatException {
      await _secureStorage.delete(key: _logoutQueueKey);
      return const [];
    }
  }

  /// Rehydrates WorkManager after an app update from a build with only the Dart queue.
  Future<void> synchronizeNativeLogoutQueue() async {
    final bridge = _nativePlatformBridge;
    if (bridge == null) return;
    final List<String> tokens;
    try {
      tokens = await pendingLogoutTokens();
    } catch (_) {
      return;
    }
    for (final token in tokens) {
      try {
        await bridge.queueLogoutRevocation(token);
      } catch (_) {
        // Keep the secure Flutter copy; foreground retry remains available.
      }
    }
  }

  Future<void> queueLogoutToken(String token) async {
    if (token.trim().isEmpty) return;
    final queue = (await pendingLogoutTokens()).toSet()..add(token);
    await _secureStorage.write(
      key: _logoutQueueKey,
      value: jsonEncode(queue.toList()),
    );
    await _mirrorQueuedLogoutToken(token);
  }

  Future<void> removeQueuedLogoutToken(String token) async {
    final queue = (await pendingLogoutTokens())
      ..removeWhere((candidate) => candidate == token);
    if (queue.isEmpty) {
      await _secureStorage.delete(key: _logoutQueueKey);
    } else {
      await _secureStorage.write(
        key: _logoutQueueKey,
        value: jsonEncode(queue),
      );
    }
    await _mirrorRemovedLogoutToken(token);
  }

  Future<void> _mirrorQueuedLogoutToken(String token) async {
    try {
      await _nativePlatformBridge?.queueLogoutRevocation(token);
    } catch (_) {
      // Keep the encrypted Flutter queue for the next foreground retry.
    }
  }

  Future<void> _mirrorRemovedLogoutToken(String token) async {
    try {
      await _nativePlatformBridge?.removeQueuedLogoutRevocation(token);
    } catch (_) {
      // A stale native copy is safe: WorkManager treats an already-revoked token as complete.
    }
  }
}
