import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_theme.dart';

class SuspendedRouteDetails {
  const SuspendedRouteDetails({
    required this.message,
    this.supportToken,
  });

  final String message;
  final String? supportToken;
}

class SuspendedPage extends StatelessWidget {
  const SuspendedPage({required this.details, super.key});

  final SuspendedRouteDetails details;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NextelPalette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/branding/nextel_logo.png',
                  width: 190,
                  height: 72,
                  fit: BoxFit.contain,
                  semanticLabel: 'Nextel Connect',
                ),
                const SizedBox(height: 36),
                const Icon(
                  Icons.lock_person_outlined,
                  size: 56,
                  color: NextelPalette.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Account suspended',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: NextelPalette.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  details.message.isEmpty
                      ? 'This account has been suspended. Please contact support.'
                      : details.message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: NextelPalette.muted,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.support,
                    extra: details.supportToken,
                  ),
                  icon: const Icon(Icons.support_agent),
                  label: const Text('Contact support'),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Return to login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
