import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/api_failure.dart';
import 'suspended_page.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(authRepositoryProvider).retryQueuedRevocations());
      _restoreSession();
    });
  }

  Future<void> _restoreSession() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final repository = ref.read(authRepositoryProvider);
    try {
      final user = await repository.validateStoredSession();
      if (!mounted) return;
      if (user == null) {
        context.go(AppRoutes.login);
        return;
      }
      if (user.isSuspended) {
        await _routeToSuspended(
          'This account has been suspended. Please contact support.',
          null,
          serverRevoked: false,
        );
        return;
      }
      if (!user.emailVerified) {
        context.go(AppRoutes.verify, extra: user.email);
        return;
      }
      await _openDashboard();
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      if (failure.statusCode == 401) {
        context.go(AppRoutes.login);
      } else if (failure.statusCode == 403) {
        final supportToken = failure.dataMap['support_token']?.toString();
        await _routeToSuspended(
          failure.message,
          supportToken,
          serverRevoked: supportToken?.isNotEmpty == true,
        );
      } else {
        setState(() {
          _loading = false;
          _error = failure.displayMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to reach Nextel right now. Check your connection and retry.';
        });
      }
    }
  }

  Future<void> _openDashboard() async {
    try {
      final session = await ref.read(authRepositoryProvider).openWebSession();
      if (mounted) context.go(AppRoutes.dashboard, extra: session.destination);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      if (failure.statusCode == 401) {
        context.go(AppRoutes.login);
      } else if (failure.statusCode == 403) {
        final supportToken = failure.dataMap['support_token']?.toString();
        await _routeToSuspended(
          failure.message,
          supportToken,
          serverRevoked: true,
        );
      } else {
        setState(() {
          _loading = false;
          _error = failure.displayMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not establish a secure website session. Please retry.';
        });
      }
    }
  }

  Future<void> _routeToSuspended(
    String message,
    String? supportToken, {
    required bool serverRevoked,
  }) async {
    await ref.read(authRepositoryProvider).handleSuspended(
          serverRevokedCurrentToken: serverRevoked,
        );
    if (!mounted) return;
    context.go(
      AppRoutes.suspended,
      extra: SuspendedRouteDetails(
        message: message,
        supportToken: supportToken,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nextelColors.primary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.86, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) => Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                  child: Image.asset(
                    'assets/images/branding/nextel_logo.png',
                    width: 220,
                    height: 84,
                    fit: BoxFit.contain,
                    semanticLabel: 'Nextel Connect',
                  ),
                ),
                const SizedBox(height: 36),
                if (_loading)
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: context.nextelColors.accent,
                    ),
                  ),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.tonal(
                    onPressed: _restoreSession,
                    child: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('Sign in instead'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
