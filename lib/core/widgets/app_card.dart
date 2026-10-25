import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Reusable clean Card component with consistent border, radius, and surface color.
///
/// Avoids heavy saturated purple gradients or glowing floating shadows.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? AppRadii.r16;
    final effectiveBg = backgroundColor ?? AppColors.card(context);
    final effectiveBorder = borderColor ?? AppColors.border(context);

    return Padding(
      padding: margin,
      child: Material(
        color: effectiveBg,
        shape: RoundedRectangleBorder(
          borderRadius: effectiveRadius,
          side: BorderSide(color: effectiveBorder, width: borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                child: Padding(
                  padding: padding,
                  child: child,
                ),
              )
            : Padding(
                padding: padding,
                child: child,
              ),
      ),
    );
  }
}
