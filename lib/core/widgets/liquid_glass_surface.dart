import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_radii.dart';
import '../theme/liquid_glass_tokens.dart';

/// Core Reusable Liquid Glass Surface.
///
/// Features:
/// - True background translucency with BackdropFilter and ImageFilter.blur
/// - Dual-layer specular edge highlight simulating Apple-like glass reflection
/// - Precise shape clipping with zero blur bleeding
/// - Graceful fallback in reduced-effects mode
/// - 100% crisp child content rendering without internal blurring
class LiquidGlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final double blurSigma;
  final Color? surfaceColor;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool hasSpecularHighlight;
  final bool elevated;
  final bool subtle;
  final double? width;
  final double? height;

  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.blurSigma = LiquidGlassTokens.blurStandard,
    this.surfaceColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.hasSpecularHighlight = true,
    this.elevated = false,
    this.subtle = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? AppRadii.r16;
    final effectiveSurface = surfaceColor ??
        LiquidGlassTokens.surface(context, elevated: elevated, subtle: subtle);
    final effectiveBorder = borderColor ?? LiquidGlassTokens.border(context);
    final isReduced = LiquidGlassTokens.isReducedEffects(context);

    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          child: content,
        ),
      );
    }

    Widget glassContainer = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: effectiveSurface,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: effectiveBorder,
          width: borderWidth,
        ),
      ),
      child: hasSpecularHighlight
          ? Stack(
              children: [
                // Specular reflection gradient overlay on the upper half
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: effectiveRadius,
                        gradient: LiquidGlassTokens.specularGradient(context),
                      ),
                    ),
                  ),
                ),
                content,
              ],
            )
          : content,
    );

    // In reduced effects mode, skip the BackdropFilter pass to optimize GPU load
    if (isReduced || blurSigma <= 0) {
      return Container(
        margin: margin,
        child: ClipRRect(
          borderRadius: effectiveRadius,
          child: glassContainer,
        ),
      );
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: glassContainer,
        ),
      ),
    );
  }
}
