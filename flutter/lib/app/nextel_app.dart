import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class NextelApp extends ConsumerWidget {
  const NextelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Nextel',
      debugShowCheckedModeBanner: false,
      theme: NextelTheme.light(),
      darkTheme: NextelTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
