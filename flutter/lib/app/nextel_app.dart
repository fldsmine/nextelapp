import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/presentation/providers/app_settings_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class NextelApp extends ConsumerWidget {
  const NextelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final theme = switch (settings.theme) {
      'Dark' => NextelTheme.dark(fontFamily: settings.fontFamily),
      'Blue' => NextelTheme.blue(fontFamily: settings.fontFamily),
      _ => NextelTheme.light(fontFamily: settings.fontFamily),
    };

    return MaterialApp.router(
      title: 'Nextel',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.light,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        // Keep platform accessibility scaling while applying the app preference.
        final platformScale = media.textScaler.scale(16) / 16;
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(settings.fontScale * platformScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
