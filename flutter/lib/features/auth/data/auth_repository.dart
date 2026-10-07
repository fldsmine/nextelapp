import 'dart:async';

import '../../../app/config/app_config.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/nextel_api.dart';
import '../../../core/security/native_platform_bridge.dart';
import '../../../core/security/session_store.dart';
import '../domain/country.dart';
import '../domain/country_calling_codes.dart';
import '../domain/user_account.dart';

class AuthResult {
  const AuthResult({
    required this.user,
    required this.verificationRequired,
    this.message = '',
  });

  final UserAccount user;
  final bool verificationRequired;
  final String message;
}

class WebSessionResult {
  const WebSessionResult({required this.destination});

  final Uri destination;
}

class AuthRepository {
  AuthRepository({
    required NextelApi api,
    required AppConfig config,
    required NativePlatformBridge nativeBridge,
    required SessionStore sessionStore,
  })  : _api = api,
        _config = config,
        _nativeBridge = nativeBridge,
        _sessionStore = sessionStore;

  final NextelApi _api;
  final AppConfig _config;
  final NativePlatformBridge _nativeBridge;
  final SessionStore _sessionStore;

  Future<AuthResult> login({
    required String login,
    required String password,
    required bool rememberMe,
  }) async {
    final response = await _api.post(
      'login',
      body: {'login': login.trim(), 'password': password},
    );
    final data = response.dataMap;
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw ApiFailure(
        statusCode: response.statusCode,
        message: 'The server did not return a sign-in token.',
      );
    }

    await _sessionStore.replaceToken(token, remember: rememberMe);
    final user = UserAccount.fromApi(data['user']);
    return AuthResult(
      user: user,
      verificationRequired: !user.emailVerified ||
          data['verification_required'] == true,
      message: response.message,
    );
  }

  Future<AuthResult> register({
    required String fullName,
    required String username,
    required String email,
    required String phone,
    required Country country,
    required String password,
    required String referralCode,
  }) async {
    final body = <String, Object?>{
      'full_name': fullName.trim(),
      'username': username.trim(),
      'email': email.trim(),
      'phone': phone,
      'country': country.code,
      'password': password,
      'agree_terms': true,
    };
    if (referralCode.trim().isNotEmpty) {
      body['referral_code'] = referralCode.trim();
    }

    final response = await _api.post('register', body: body);
    final data = response.dataMap;
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw ApiFailure(
        statusCode: response.statusCode,
        message: 'The server did not return a sign-in token.',
      );
    }
    await _sessionStore.replaceToken(token, remember: _sessionStore.rememberMe);
    final user = UserAccount.fromApi(data['user']);
    return AuthResult(
      user: user,
      verificationRequired: !user.emailVerified ||
          data['verification_required'] == true,
      message: response.message,
    );
  }

  Future<List<Country>> fetchCountries() async {
    final response = await _api.get('countries');
    final data = response.data;
    Object? rawCountries;
    if (data is List) {
      rawCountries = data;
    } else if (data is Map) {
      final map = data.map((key, value) => MapEntry(key.toString(), value));
      rawCountries = map['countries'];
      if (rawCountries is! List && map['data'] is Map) {
        final nested = (map['data'] as Map)
            .map((key, value) => MapEntry(key.toString(), value));
        rawCountries = nested['countries'] ?? nested['data'];
      } else if (rawCountries is! List && map['data'] is List) {
        rawCountries = map['data'];
      }
    }

    if (rawCountries is! List) return const [];
    final fallbacks = {
      for (final country in localCountryDialCodes) country.code: country,
    };
    return rawCountries
        .whereType<Map>()
        .map(
          (entry) => Country.fromServer(
            entry.map((key, value) => MapEntry(key.toString(), value)),
            dialCodeFallbacks: fallbacks,
          ),
        )
        .where((country) => country.code.isNotEmpty && country.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<UserAccount?> validateStoredSession() async {
    final token = await _sessionStore.readToken();
    if (token == null || token.isEmpty) return null;

    try {
      final response = await _api.get('user', bearerToken: token);
      return UserAccount.fromApi(response.dataMap['user']);
    } on ApiFailure catch (failure) {
      if (failure.statusCode == 401) await handleExpiredSession();
      rethrow;
    }
  }

  Future<void> verifyEmail(String code) async {
    final token = await _requiredToken();
    try {
      await _api.post(
        'email/verify',
        body: {'code': code.trim()},
        bearerToken: token,
      );
    } on ApiFailure catch (failure) {
      if (failure.statusCode == 401) await handleExpiredSession();
      rethrow;
    }
  }

  Future<String> resendVerificationCode() async {
    final token = await _requiredToken();
    try {
      final response = await _api.post(
        'email/resend',
        bearerToken: token,
      );
      return response.message;
    } on ApiFailure catch (failure) {
      if (failure.statusCode == 401) await handleExpiredSession();
      rethrow;
    }
  }

  Future<String> requestPasswordReset(String email) async {
    final response = await _api.post(
      'password/forgot',
      body: {'email': email.trim()},
    );
    return response.message;
  }

  Future<String> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    final response = await _api.post(
      'password/reset',
      body: {
        'email': email.trim(),
        'code': code.trim(),
        'password': password,
      },
    );
    await handleExpiredSession();
    return response.message;
  }

  Future<WebSessionResult> openWebSession() async {
    final token = await _requiredToken();
    final ApiResponse response;
    try {
      response = await _api.post('web-session', bearerToken: token);
    } on ApiFailure catch (failure) {
      if (failure.statusCode == 401) await handleExpiredSession();
      rethrow;
    }

    final redirect = response.dataMap['redirect']?.toString() ?? '';
    final destination = _config.resolveWebSessionRedirect(redirect);
    if (destination == null || response.cookies.isEmpty) {
      throw const ApiFailure(
        statusCode: 0,
        message:
            'Could not establish a secure website session. Please try again.',
      );
    }
    final cookiesWritten = await _nativeBridge.setCookies(
      destination,
      response.cookies,
    );
    if (!cookiesWritten) {
      throw const ApiFailure(
        statusCode: 0,
        message:
            'Unable to save the website session cookies. Please try again.',
      );
    }
    await _nativeBridge.flushCookies();
    return WebSessionResult(destination: destination);
  }

  Future<void> handleSuspended({
    required bool serverRevokedCurrentToken,
  }) async {
    String? oldToken;
    try {
      oldToken = await _sessionStore.readToken();
    } catch (_) {
      // Clearing the local session takes priority over retrying a revoked token.
    }
    if (oldToken != null && oldToken.isNotEmpty) {
      try {
        if (serverRevokedCurrentToken) {
          await _sessionStore.removeQueuedLogoutToken(oldToken);
        } else {
          await _sessionStore.queueLogoutToken(oldToken);
        }
      } catch (_) {
        // A failed retry-queue write must not keep a suspended session active.
      }
    }
    await handleExpiredSession();
  }

  /// Clears both the encrypted API token and Laravel WebView session after a
  /// server-confirmed 401/403 without retaining credentials in page state.
  Future<void> handleExpiredSession() async {
    await _sessionStore.clearToken();
    try {
      await _nativeBridge.clearWebSession();
    } catch (_) {
      // Keep the native screen flow available if WebStorage is temporarily down.
    }
  }

  Future<void> logout() async {
    String? token;
    try {
      token = await _sessionStore.readToken();
    } catch (_) {
      // Continue with local cookie/session cleanup even if storage is unavailable.
    }
    if (token != null && token.isNotEmpty) {
      try {
        await _sessionStore.queueLogoutToken(token);
      } catch (_) {
        // Local sign-out must not depend on the best-effort revoke queue.
      }
    }

    try {
      await _sessionStore.clearToken();
    } finally {
      try {
        await _nativeBridge.clearWebSession();
      } catch (_) {
        // Do not block navigation to Login on a platform-channel failure.
      }
    }

    if (token != null && token.isNotEmpty) {
      unawaited(_revokeQueuedToken(token));
    }
  }

  Future<void> retryQueuedRevocations() async {
    List<String> queued;
    try {
      queued = await _sessionStore.pendingLogoutTokens();
    } catch (_) {
      return;
    }
    for (final token in queued) {
      await _revokeQueuedToken(token);
    }
  }

  Future<void> _revokeQueuedToken(String token) async {
    try {
      await _api.post('logout', bearerToken: token);
      await _sessionStore.removeQueuedLogoutToken(token);
    } on ApiFailure catch (failure) {
      if (failure.statusCode == 401) {
        await _sessionStore.removeQueuedLogoutToken(token);
      }
    } catch (_) {
      // Keep the encrypted queue for a later retry.
    }
  }

  Future<String> _requiredToken() async {
    final token = await _sessionStore.readToken();
    if (token == null || token.isEmpty) {
      throw const ApiFailure(
        statusCode: 401,
        message: 'Please sign in again to continue.',
      );
    }
    return token;
  }
}
