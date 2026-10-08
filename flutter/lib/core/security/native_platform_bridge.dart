import 'package:flutter/services.dart';

/// Narrow MethodChannel boundary for Android-only cookie/session/media work.
/// No password or app-gate-cookie value is ever returned through this API.
class NativePlatformBridge {
  NativePlatformBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'pynith.apps.nextel/native';
  final MethodChannel _channel;

  Future<Map<String, Object?>?> loadRuntimeConfig() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'runtimeConfig',
      );
      return result;
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> ensureAppGateCookie() async {
    try {
      return await _channel.invokeMethod<bool>('ensureAppGateCookie') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<String?> getCookieHeader(Uri uri) async {
    try {
      return await _channel.invokeMethod<String>(
        'getCookieHeader',
        {'url': uri.toString()},
      );
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> setCookies(Uri uri, List<String> cookies) async {
    if (cookies.isEmpty) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'setCookies',
            {'url': uri.toString(), 'cookies': cookies},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> flushCookies() async {
    try {
      await _channel.invokeMethod<bool>('flushCookies');
    } on MissingPluginException {
      // Cookies are shared automatically on Android; a missing flush hook
      // should not make otherwise valid API responses fail.
    }
  }

  Future<bool> clearWebSession() async {
    try {
      return await _channel.invokeMethod<bool>('clearWebSession') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<Map<String, Object?>?> readLegacyData() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'readLegacyData',
      );
      return result;
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> completeLegacyImport() async {
    try {
      return await _channel.invokeMethod<bool>(
            'completeLegacyImport',
            const {'complete': true},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> saveCanvasImage(String data) async =>
      await _channel.invokeMethod<bool>(
        'saveCanvasImage',
        {'data': data},
      ) ??
      false;

  Future<bool> shareCanvasImage(String data) async =>
      await _channel.invokeMethod<bool>(
        'shareCanvasImage',
        {'data': data},
      ) ??
      false;

  Future<bool> notificationPermissionGranted() async {
    try {
      return await _channel.invokeMethod<bool>(
            'notificationPermissionGranted',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    try {
      return await _channel.invokeMethod<bool>(
            'requestNotificationPermission',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> setDailyReminder(bool enabled) async {
    try {
      return await _channel.invokeMethod<bool>(
            'setDailyReminder',
            {'enabled': enabled},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> restoreDailyReminders() async {
    try {
      return await _channel.invokeMethod<bool>('restoreDailyReminders') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<Map<String, Object?>?> readBackgroundUpdateState() async {
    try {
      return await _channel.invokeMapMethod<String, Object?>(
        'readBackgroundUpdateState',
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> canInstallApks() async {
    try {
      return await _channel.invokeMethod<bool>('canInstallApks') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<String?> updateDownloadDirectory() async {
    try {
      return await _channel.invokeMethod<String>('updateDownloadDirectory');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Opens Android's per-app "install unknown apps" permission screen.
  Future<bool> requestInstallApkPermission() async {
    try {
      return await _channel.invokeMethod<bool>(
            'requestInstallApkPermission',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the Android package installer for an APK saved by the updater.
  Future<bool> installApk(String filePath) async {
    try {
      return await _channel.invokeMethod<bool>(
            'installApk',
            {'filePath': filePath},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> writeLegacyAppSetting(String key, Object value) async {
    try {
      return await _channel.invokeMethod<bool>(
            'writeLegacyAppSetting',
            {'key': key, 'value': value},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens Android's image-only ACTION_CHOOSER with gallery and camera intents.
  /// The returned URI is a short-lived content URI, not a file-system path.
  Future<Uri?> chooseWebViewImage() async {
    try {
      final value = await _channel.invokeMethod<String>('chooseWebViewImage');
      return value == null ? null : Uri.tryParse(value);
    } on MissingPluginException {
      return null;
    }
  }
}
