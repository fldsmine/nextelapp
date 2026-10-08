import 'package:flutter/foundation.dart';

@immutable
class AppConfig {
  const AppConfig({
    required this.webBaseUrl,
    required this.apiBaseUrl,
    required this.frontBaseUrl,
    required this.updateApiBaseUrl,
    required this.versionName,
    required this.versionCode,
    required this.appGateCookieConfigured,
  });

  static const _fallbackWebBaseUrl = 'https://easyportaltopupxyz.com';

  final String webBaseUrl;
  final String apiBaseUrl;
  final String frontBaseUrl;
  final String updateApiBaseUrl;
  final String versionName;
  final int versionCode;
  final bool appGateCookieConfigured;

  factory AppConfig.fromNative(Map<String, Object?>? values) {
    final webBaseUrl = _normalizedUrl(
      values?['webBaseUrl'] as String? ?? _fallbackWebBaseUrl,
    );
    return AppConfig(
      webBaseUrl: webBaseUrl,
      apiBaseUrl: _normalizedUrl(
        values?['apiBaseUrl'] as String? ?? '$webBaseUrl/api/v1',
      ),
      frontBaseUrl: _normalizedUrl(
        values?['frontBaseUrl'] as String? ?? webBaseUrl,
      ),
      updateApiBaseUrl: _normalizedUrl(
        values?['updateApiBaseUrl'] as String? ??
            'https://fakelife.online/api/v1',
      ),
      versionName: values?['versionName'] as String? ?? '3.5.alpha',
      versionCode: _asInt(values?['versionCode']) ?? 4,
      appGateCookieConfigured:
          values?['appGateCookieConfigured'] as bool? ?? false,
    );
  }

  Uri get webOrigin => Uri.parse(webBaseUrl);
  Uri get apiOrigin => Uri.parse(apiBaseUrl);

  Uri get dashboardUri => webOrigin.resolve('/dashboard');

  bool isTrustedWebUri(Uri uri) => _isSameOrigin(webOrigin, uri);

  bool isTrustedApiUri(Uri uri) => _isSameOrigin(apiOrigin, uri);

  bool isTrustedNextelUri(Uri uri) =>
      isTrustedWebUri(uri) || isTrustedApiUri(uri);

  Uri? resolveWebSessionRedirect(String redirect) {
    final base = webOrigin;
    final parsed = Uri.tryParse(redirect.trim());
    final path = parsed?.path ?? '';
    final hasTraversal = parsed?.pathSegments.any(
          (segment) => segment == '..' || segment == '.',
        ) ??
        false;
    final safePath = path.isEmpty ||
            !path.startsWith('/') ||
            path.startsWith('//') ||
            path.contains('\\') ||
            path.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f) ||
            hasTraversal
        ? '/dashboard'
        : path;

    // Only path and query are ever carried over. The redirect authority,
    // username/password, scheme, and fragment are deliberately discarded.
    return base.replace(
      path: safePath,
      query: parsed?.hasQuery == true ? parsed!.query : null,
      fragment: null,
    );
  }

  static String _normalizedUrl(String value) => value.trim().replaceFirst(
        RegExp(r'/+$'),
        '',
      );

  static int? _asInt(Object? value) => switch (value) {
        int number => number,
        num number => number.toInt(),
        String text => int.tryParse(text),
        _ => null,
      };

  static bool _isSameOrigin(Uri base, Uri candidate) {
    if (candidate.userInfo.isNotEmpty ||
        candidate.host.isEmpty ||
        !const {'http', 'https'}.contains(candidate.scheme.toLowerCase())) {
      return false;
    }
    return base.scheme.toLowerCase() == candidate.scheme.toLowerCase() &&
        base.host.toLowerCase() == candidate.host.toLowerCase() &&
        _effectivePort(base) == _effectivePort(candidate);
  }

  static int _effectivePort(Uri uri) {
    if (uri.hasPort) return uri.port;
    return uri.scheme.toLowerCase() == 'https' ? 443 : 80;
  }
}
