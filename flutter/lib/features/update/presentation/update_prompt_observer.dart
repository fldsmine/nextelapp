import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';

/// Surfaces a cached WorkManager result when the app returns to the foreground.
class UpdatePromptObserver extends ConsumerStatefulWidget {
  const UpdatePromptObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<UpdatePromptObserver> createState() =>
      _UpdatePromptObserverState();
}

class _UpdatePromptObserverState extends ConsumerState<UpdatePromptObserver>
    with WidgetsBindingObserver {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_showPendingUpdate());
    }
  }

  Future<void> _showPendingUpdate() async {
    if (_checking) return;
    _checking = true;
    try {
      final router = ref.read(appRouterProvider);
      if (_isUpdateOrSplashRoute(router)) return;

      final repository = ref.read(updateRepositoryProvider);
      final update = await repository.pendingUpdatePrompt();
      if (!mounted || update == null || _isUpdateOrSplashRoute(router)) return;

      await repository.markPrompted(update);
      if (!mounted) return;
      if (update.isMandatory) {
        router.go(AppRoutes.update, extra: update);
      } else {
        await router.push<Object?>(AppRoutes.update, extra: update);
      }
    } catch (_) {
      // A background-result handoff is best-effort; the explicit check remains available.
    } finally {
      _checking = false;
    }
  }

  bool _isUpdateOrSplashRoute(GoRouter router) {
    final location = router.routeInformationProvider.value.uri.path;
    return location == AppRoutes.update || location == AppRoutes.splash;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
