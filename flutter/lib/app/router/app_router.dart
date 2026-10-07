import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/email_verification_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/password_reset_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/suspended_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/dashboard/presentation/pages/remote_legal_page.dart';
import '../../features/support/presentation/pages/support_page.dart';
import '../pages/feature_placeholder_page.dart';
import 'app_routes.dart';

export 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => LoginPage(
          prefillLogin: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.verify,
        builder: (context, state) => EmailVerificationPage(
          email: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.reset,
        builder: (context, state) => const PasswordResetPage(),
      ),
      GoRoute(
        path: AppRoutes.suspended,
        builder: (context, state) => SuspendedPage(
          details: state.extra as SuspendedRouteDetails? ??
              const SuspendedRouteDetails(message: 'This account is restricted.'),
        ),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => DashboardPage(
          initialUri: state.extra is Uri ? state.extra! as Uri : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const FeaturePlaceholderPage(
          title: 'App settings',
          detail: 'Settings migration is in progress.',
        ),
      ),
      GoRoute(
        path: AppRoutes.support,
        builder: (context, state) => SupportPage(
          initialToken: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.coupon,
        builder: (context, state) => const FeaturePlaceholderPage(
          title: 'Coupon search',
          detail: 'Coupon verification is being migrated.',
        ),
      ),
      GoRoute(
        path: AppRoutes.games,
        builder: (context, state) => const FeaturePlaceholderPage(
          title: 'Games',
          detail: 'Games are being migrated.',
        ),
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (context, state) => const FeaturePlaceholderPage(
          title: 'About Nextel',
          detail: 'Information pages are being migrated.',
        ),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (context, state) => const RemoteLegalPage(
          title: 'Terms & Conditions',
          path: 'terms',
        ),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (context, state) => const RemoteLegalPage(
          title: 'Privacy Policy',
          path: 'privacy',
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('This page could not be opened. ${state.error ?? ''}'),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});
