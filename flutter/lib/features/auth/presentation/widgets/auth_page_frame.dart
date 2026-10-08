import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.backAction,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final VoidCallback? backAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: -105,
            right: -72,
            child: _Circle(size: 230, color: Color(0x3348948A)),
          ),
          const Positioned(
            left: -165,
            bottom: -150,
            child: _Circle(size: 290, color: Color(0x2218443E)),
          ),
          Positioned(
            right: 34,
            bottom: 110,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: context.nextelColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 34),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 58),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/images/branding/nextel_logo.png',
                          width: 190,
                          height: 70,
                          fit: BoxFit.contain,
                          semanticLabel: 'Nextel Connect',
                        ),
                      ),
                      if (backAction != null) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: backAction,
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: const Text('Back'),
                            style: TextButton.styleFrom(
                              foregroundColor: context.nextelColors.primary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 27),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.nextelColors.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.nextelColors.muted,
                              height: 1.4,
                            ),
                      ),
                      const SizedBox(height: 26),
                      child,
                      if (footer != null) ...[
                        const SizedBox(height: 20),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
