import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/config/app_config.dart';
import 'app/nextel_app.dart';
import 'app/providers.dart';
import 'core/security/native_platform_bridge.dart';
import 'core/security/session_store.dart';
import 'core/storage/legacy_data_migrator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final nativeBridge = NativePlatformBridge();
  Map<String, Object?>? nativeConfig;
  try {
    nativeConfig = await nativeBridge
        .loadRuntimeConfig()
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    // The public URL defaults let the UI start and display a recoverable
    // configuration/network error; no credential or gate secret is in Dart.
  }
  final appConfig = AppConfig.fromNative(nativeConfig);
  final preferences = await SharedPreferences.getInstance();
  final sessionStore = SessionStore(preferences: preferences);

  // Import the old named preferences, game histories and Keystore-protected
  // Sanctum token before any route can decide that the person is signed out.
  await LegacyDataMigrator(
    nativeBridge: nativeBridge,
    sessionStore: sessionStore,
    preferences: preferences,
  ).migrate();
  await sessionStore.expireUnrememberedSession();

  // The native bridge reads its protected build input and never exposes the
  // app_gate value to Dart. This must finish before API or WebView traffic.
  await nativeBridge.ensureAppGateCookie();

  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(appConfig),
      nativePlatformBridgeProvider.overrideWithValue(nativeBridge),
      sharedPreferencesProvider.overrideWithValue(preferences),
      sessionStoreProvider.overrideWithValue(sessionStore),
    ],
  );
  runApp(UncontrolledProviderScope(
    container: container,
    child: const NextelApp(),
  ));
}
