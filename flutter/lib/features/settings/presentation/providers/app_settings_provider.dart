import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../domain/app_settings.dart';

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
  AppSettingsController.new,
);

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    return AppSettings.fromMap({
      'notifications_enabled':
          preferences.getBool('notifications_enabled') ?? true,
      'sound': preferences.getBool('sound') ?? true,
      'vibration': preferences.getBool('vibration') ?? false,
      'daily_reminder': preferences.getBool('daily_reminder') ?? false,
      'xbg_biometric_enabled':
          preferences.getBool('xbg_biometric_enabled') ?? false,
      'theme': preferences.getString('theme'),
      'fontFamily': preferences.getString('fontFamily'),
      'fontScale': preferences.get('fontScale'),
    });
  }

  Future<void> setTheme(String theme) async {
    if (!AppSettings.themes.contains(theme)) return;
    await _persist('theme', theme, (current) => current.copyWith(theme: theme));
  }

  Future<void> setFontFamily(String fontFamily) async {
    if (!AppSettings.fontFamilies.contains(fontFamily)) return;
    await _persist(
      'fontFamily',
      fontFamily,
      (current) => current.copyWith(fontFamily: fontFamily),
    );
  }

  Future<void> setFontScale(double value) async {
    final scale = value
        .clamp(AppSettings.minFontScale, AppSettings.maxFontScale)
        .toDouble();
    await _persist(
      'fontScale',
      scale,
      (current) => current.copyWith(fontScale: scale),
    );
  }

  Future<bool> setNotificationsEnabled(bool enabled) async {
    final bridge = ref.read(nativePlatformBridgeProvider);
    if (enabled && !await bridge.requestNotificationPermission()) return false;
    await _persist(
      'notifications_enabled',
      enabled,
      (current) => current.copyWith(notificationsEnabled: enabled),
    );
    return true;
  }

  Future<void> setNotificationSound(bool enabled) async {
    await _persist(
      'sound',
      enabled,
      (current) => current.copyWith(notificationSound: enabled),
    );
  }

  Future<void> setNotificationVibration(bool enabled) async {
    await _persist(
      'vibration',
      enabled,
      (current) => current.copyWith(notificationVibration: enabled),
    );
  }

  Future<bool> setDailyReminder(bool enabled) async {
    final bridge = ref.read(nativePlatformBridgeProvider);
    if (enabled && !await bridge.requestNotificationPermission()) return false;
    if (!await bridge.setDailyReminder(enabled)) return false;

    await _persist(
      'daily_reminder',
      enabled,
      (current) => current.copyWith(dailyReminder: enabled),
      mirrorToNative: false,
    );
    return true;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await ref.read(sessionStoreProvider).setBiometricEnabled(enabled);
    await _persist(
      'xbg_biometric_enabled',
      enabled,
      (current) => current.copyWith(biometricEnabled: enabled),
    );
  }

  Future<void> synchronizeBiometricState() async {
    final sessionStore = ref.read(sessionStoreProvider);
    String? token;
    try {
      token = await sessionStore.readToken();
    } catch (_) {
      token = null;
    }
    if (token == null || token.isEmpty) {
      if (state.biometricEnabled) await setBiometricEnabled(false);
      return;
    }
    if (state.biometricEnabled && !sessionStore.rememberMe) {
      try {
        await sessionStore.saveToken(token, remember: true);
      } catch (_) {
        await setBiometricEnabled(false);
      }
    }
  }

  Future<void> _persist(
    String key,
    Object value,
    AppSettings Function(AppSettings current) update, {
    bool mirrorToNative = true,
  }) async {
    final preferences = ref.read(sharedPreferencesProvider);
    final saved = switch (value) {
      bool setting => await preferences.setBool(key, setting),
      int setting => await preferences.setInt(key, setting),
      double setting => await preferences.setDouble(key, setting),
      String setting => await preferences.setString(key, setting),
      _ => false,
    };
    if (!saved) throw StateError('Could not save the $key preference.');

    if (mirrorToNative) {
      try {
        await ref
            .read(nativePlatformBridgeProvider)
            .writeLegacyAppSetting(key, value);
      } catch (_) {
        // Flutter preferences remain the source of truth if no native mirror
        // is available; the next launch can retry legacy preference import.
      }
    }
    state = update(state);
  }
}
