import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_routes.dart';
import '../domain/about_content.dart';

Future<void> openAboutSupport(BuildContext context, WidgetRef ref) async {
  final token = await ref.read(sessionStoreProvider).readToken();
  if (!context.mounted) return;
  if (token == null || token.isEmpty) {
    context.go(AppRoutes.login);
    return;
  }
  await context.push(AppRoutes.support, extra: token);
}

Future<void> openExternalSupport(BuildContext context) async {
  final uri = Uri.parse(AboutContent.supportLink);
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      _showLinkError(context);
    }
  } catch (_) {
    if (context.mounted) _showLinkError(context);
  }
}

void _showLinkError(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(content: Text('Could not open the support link.')),
    );
}
