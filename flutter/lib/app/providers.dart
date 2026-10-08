import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import '../core/network/nextel_api.dart';
import '../core/security/native_platform_bridge.dart';
import '../core/security/session_store.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/user_account.dart';
import '../features/update/data/update_repository.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw StateError('AppConfig was not initialized.'),
);

final nativePlatformBridgeProvider = Provider<NativePlatformBridge>(
  (ref) => throw StateError('Native platform bridge was not initialized.'),
);

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('SharedPreferences was not initialized.'),
);

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => throw StateError('SessionStore was not initialized.'),
);

/// Current API profile for the authenticated Flutter session and drawer.
final currentUserProvider = StateProvider<UserAccount?>((ref) => null);

final nextelApiProvider = Provider<NextelApi>((ref) {
  return NextelApi(
    config: ref.watch(appConfigProvider),
    nativeBridge: ref.watch(nativePlatformBridgeProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(nextelApiProvider),
    config: ref.watch(appConfigProvider),
    nativeBridge: ref.watch(nativePlatformBridgeProvider),
    sessionStore: ref.watch(sessionStoreProvider),
  );
});

final updateRepositoryProvider = Provider<UpdateRepository>((ref) {
  return UpdateRepository(
    config: ref.watch(appConfigProvider),
    preferences: ref.watch(sharedPreferencesProvider),
    nativeBridge: ref.watch(nativePlatformBridgeProvider),
  );
});
