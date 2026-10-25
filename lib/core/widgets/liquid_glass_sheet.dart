import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_radii.dart';
import '../theme/liquid_glass_tokens.dart';

/// Modal bottom sheet container styled with translucent frosted Liquid Glass.
class LiquidGlassSheet extends StatelessWidget {
  final Widget child;
  final double? maxHeight;
  final EdgeInsetsGeometry padding;
  final bool showDragHandle;

  const LiquidGlassSheet({
    super.key,
    required this.child,
    this.maxHeight,
    this.padding = EdgeInsets.zero,
    this.showDragHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSurface = LiquidGlassTokens.surface(context, elevated: true);
    final effectiveBorder = LiquidGlassTokens.border(context);
    final isReduced = LiquidGlassTokens.isReducedEffects(context);

    Widget sheetContent = Container(
      decoration: BoxDecoration(
        color: effectiveSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: effectiveBorder, width: 1.0),
          left: BorderSide(color: effectiveBorder, width: 1.0),
          right: BorderSide(color: effectiveBorder, width: 1.0),
        ),
      ),
      child: Stack(
        children: [
          // Specular highlight on the top curved rim
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 36,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  gradient: LiquidGlassTokens.specularGradient(context),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDragHandle)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: effectiveBorder,
                      borderRadius: AppRadii.rPill,
                    ),
                  ),
                ),
              Flexible(
                child: Padding(
                  padding: padding,
                  child: child,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (isReduced) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: sheetContent,
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: LiquidGlassTokens.blurModal,
          sigmaY: LiquidGlassTokens.blurModal,
        ),
        child: sheetContent,
      ),
    );
  }
}
