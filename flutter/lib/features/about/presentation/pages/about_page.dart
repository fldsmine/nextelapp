import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/about_content.dart';
import '../about_actions.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nextelColors;
    final versionName = ref.watch(appConfigProvider).versionName;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('About Nextel')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/branding/nextel_logo.png',
                    width: 190,
                    height: 72,
                    fit: BoxFit.contain,
                    semanticLabel: 'Nextel Connect',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AboutContent.tagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _contentCard(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About us',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AboutContent.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.text,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 14),
                  for (final highlight in AboutContent.highlights)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle, size: 18, color: colors.primary),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              highlight,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: colors.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _contentCard(
              context,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _actionTile(
                    context,
                    icon: Icons.quiz_outlined,
                    title: 'Frequently asked questions',
                    subtitle: 'Browse answers to common questions',
                    onTap: () => context.push(AppRoutes.faq),
                  ),
                  Divider(height: 1, color: colors.border),
                  _actionTile(
                    context,
                    icon: Icons.link,
                    title: 'Support link',
                    subtitle: '@contact_support',
                    onTap: () => openExternalSupport(context),
                  ),
                  Divider(height: 1, color: colors.border),
                  _actionTile(
                    context,
                    icon: Icons.support_agent_outlined,
                    title: 'Online chat',
                    subtitle: 'Chat with the Nextel support team',
                    onTap: () => openAboutSupport(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Version $versionName',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.muted,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              AboutContent.developerCredit,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.muted,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentCard(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) =>
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: context.nextelColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.nextelColors.border),
        ),
        child: child,
      );

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        leading: Icon(icon, color: context.nextelColors.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
