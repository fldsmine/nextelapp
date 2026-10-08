import 'package:flutter/material.dart';

/// Temporary explicit route while a feature is still being migrated. It does
/// not simulate or claim to implement the native feature.
class FeaturePlaceholderPage extends StatelessWidget {
  const FeaturePlaceholderPage({
    required this.title,
    required this.detail,
    super.key,
  });

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(detail, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
