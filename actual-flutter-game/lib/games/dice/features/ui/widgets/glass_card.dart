import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;

  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final BoxBorder? border;
  final Color? color;
  final double? blurX;
  final double? blurY;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.border,
    this.color,
    this.blurX,
    this.blurY,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius effectiveRadius =
        borderRadius ?? BorderRadius.circular(20);

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurX ?? 15,
          sigmaY: blurY ?? 15,
        ),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.05),
            borderRadius: effectiveRadius,
            border: border ?? Border.all(color: Colors.white12),
          ),
          child: child,
        ),
      ),
    );
  }
}