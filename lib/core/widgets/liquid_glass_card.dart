import 'package:flutter/material.dart';
import '../theme/app_radii.dart';
import '../theme/liquid_glass_tokens.dart';
import 'liquid_glass_surface.dart';

/// Clean Liquid Glass Card component.
///
/// Combines subtle translucency, backdrop diffusion, and a crisp 1 dp border.
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? surfaceColor;
  final Color? borderColor;
  final double borderWidth;
  final double blurSigma;
  final bool elevated;
  final bool subtle;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.borderRadius,
    this.surfaceColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.blurSigma = LiquidGlassTokens.blurStandard,
    this.elevated = false,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      borderRadius: borderRadius ?? AppRadii.r16,
      blurSigma: blurSigma,
      surfaceColor: surfaceColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      padding: padding,
      margin: margin,
      onTap: onTap,
      elevated: elevated,
      subtle: subtle,
      child: child,
    );
  }
}
