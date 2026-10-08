import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/app/theme/app_theme.dart';
import 'package:nextel_connect/features/settings/domain/app_settings.dart';

void main() {
  group('AppSettings migration mapping', () {
    test('reads the legacy preference keys and normalizes choices', () {
      final settings = AppSettings.fromMap({
        'notifications_enabled': false,
        'sound': false,
        'vibration': true,
        'daily_reminder': true,
        'xbg_biometric_enabled': true,
        'theme': 'blue',
        'fontFamily': 'montserrat',
        'fontScale': 1.25,
      });

      expect(settings.notificationsEnabled, isFalse);
      expect(settings.notificationSound, isFalse);
      expect(settings.notificationVibration, isTrue);
      expect(settings.dailyReminder, isTrue);
      expect(settings.biometricEnabled, isTrue);
      expect(settings.theme, 'Blue');
      expect(settings.fontFamily, 'Montserrat');
      expect(settings.fontScale, 1.25);
    });

    test('falls back for missing, malformed and non-finite font scales', () {
      for (final value in <Object?>[
        null,
        'large',
        double.nan,
        double.infinity,
      ]) {
        final settings = AppSettings.fromMap({'fontScale': value});
        expect(settings.fontScale, 1.0);
      }
      expect(AppSettings.fromMap({}).fontScale, 1.0);
    });

    test('uses safe defaults for missing or unsupported preference values', () {
      final settings = AppSettings.fromMap({
        'theme': 'neon',
        'fontFamily': 'Comic Sans',
        'fontScale': 9.0,
      });

      expect(settings.notificationsEnabled, isTrue);
      expect(settings.notificationSound, isTrue);
      expect(settings.notificationVibration, isFalse);
      expect(settings.dailyReminder, isFalse);
      expect(settings.biometricEnabled, isFalse);
      expect(settings.theme, 'Light');
      expect(settings.fontFamily, 'Patrick');
      expect(settings.fontScale, AppSettings.maxFontScale);
    });
  });

  test('builds the selected theme and font family', () {
    final theme = NextelTheme.dark(fontFamily: 'Montserrat');

    expect(theme.brightness, Brightness.dark);
    expect(theme.fontFamily, 'Montserrat');
    expect(
      theme.extension<NextelColors>()?.background,
      NextelColors.dark.background,
    );
  });
}
