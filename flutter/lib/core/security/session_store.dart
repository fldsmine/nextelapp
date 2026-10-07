import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores bearer tokens and retryable logout tokens in encrypted Android
/// storage. Remember-Me=false sessions exist only in memory for this process.
class SessionStore {
  SessionStore({
    FlutterSecureStorage? secureStorage,
    required SharedPreferences preferences,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _preferences = preferences;

  static const String _tokenKey = 'session.api_token.v1';
  static const String _logoutQueueKey = 'session.pending_logout_tokens.v1';
  static const String _rememberKey = 'session.remember_me';
  static const String _biometricKey = 'xbg_biometric_enabled';

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _preferences;
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

  Future<void> queueLogoutToken(String token) async {
    if (token.trim().isEmpty) return;
    final queue = (await pendingLogoutTokens()).toSet()..add(token);
    await _secureStorage.write(
      key: _logoutQueueKey,
      value: jsonEncode(queue.toList()),
    );
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
  }
}
