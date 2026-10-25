import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Accessible Icon Button with guaranteed 48x48dp minimum touch target.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? color;
  final Color? backgroundColor;
  final bool hasBorder;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
    this.backgroundColor,
    this.hasBorder = false,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.textPrimary(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor ?? Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.r12,
          side: hasBorder
              ? BorderSide(color: AppColors.border(context), width: 1.0)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadii.r12,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: size,
              color: onPressed != null ? effectiveColor : AppColors.textMuted(context),
            ),
          ),
        ),
      ),
    );
  }
}
