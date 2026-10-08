import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/about_content.dart';
import '../about_actions.dart';

class FaqPage extends ConsumerWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nextelColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Frequently Asked Questions')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(Icons.quiz_outlined, size: 36, color: colors.accent),
                  const SizedBox(height: 10),
                  Text(
                    'Frequently asked questions',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AboutContent.tagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < AboutContent.faqs.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _faqCard(
                  context,
                  index: index + 1,
                  item: AboutContent.faqs[index],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need more help?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Contact Nextel support for help with your account or questions.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.muted,
                        ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => openAboutSupport(context, ref),
                    icon: const Icon(Icons.support_agent_outlined),
                    label: const Text('Contact support'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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

  Widget _faqCard(
    BuildContext context, {
    required int index,
    required FaqEntry item,
  }) {
    final colors = context.nextelColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colors.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: Text('$index'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.question,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 7),
                Text(
                  item.answer,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.muted,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
