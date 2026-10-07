import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/app/config/app_config.dart';

void main() {
  const config = AppConfig(
    webBaseUrl: 'https://nextel.example',
    apiBaseUrl: 'https://nextel.example/api/v1',
    frontBaseUrl: 'https://nextel.example',
    updateApiBaseUrl: 'https://updates.example/api/v1',
    versionName: '3.5.alpha',
    versionCode: 4,
    appGateCookieConfigured: false,
  );

  group('origin validation', () {
    test('accepts only the exact HTTPS origin', () {
      expect(config.isTrustedWebUri(Uri.parse('https://nextel.example/dashboard')),
          isTrue);
      expect(config.isTrustedWebUri(Uri.parse('http://nextel.example/dashboard')),
          isFalse);
      expect(config.isTrustedWebUri(Uri.parse('https://nextel.example.evil.test/')),
          isFalse);
      expect(config.isTrustedWebUri(Uri.parse('https://nextel.example:444/')),
          isFalse);
      expect(
        config.isTrustedWebUri(
          Uri.parse('https://user@nextel.example/dashboard'),
        ),
        isFalse,
      );
    });
  });

  group('web-session redirect validation', () {
    test('keeps the path and query but discards a foreign authority', () {
      final resolved = config.resolveWebSessionRedirect(
        'https://attacker.example/dashboard/profile?tab=security#section',
      );

      expect(resolved, isNotNull);
      expect(resolved!.origin, 'https://nextel.example');
      expect(resolved.path, '/dashboard/profile');
      expect(resolved.queryParameters['tab'], 'security');
      expect(resolved.hasFragment, isFalse);
    });

    test('falls back to the dashboard for malformed or non-path redirects', () {
      expect(
        config.resolveWebSessionRedirect('javascript:alert(1)')?.path,
        '/dashboard',
      );
      expect(config.resolveWebSessionRedirect('')?.path, '/dashboard');
    });
  });
}
