import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant { primary, accent, secondary, outlined, text }

/// Production-ready Button following Lagoon & Amber design system.
///
/// Features:
/// - 16dp border radius
/// - 48dp minimum touch target
/// - Lagoon primary / Amber accent
/// - Non-jumping inline loading indicator
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final Color? customColor;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.customColor,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.customColor,
  }) : variant = AppButtonVariant.primary;

  const AppButton.accent({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.customColor,
  }) : variant = AppButtonVariant.accent;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.customColor,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.customColor,
  }) : variant = AppButtonVariant.outlined;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final effectiveColor = customColor ??
        (variant == AppButtonVariant.accent
            ? colors.accent
            : colors.primary);

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: variant == AppButtonVariant.accent
                  ? colors.onAccent
                  : (variant == AppButtonVariant.primary ? Colors.white : effectiveColor),
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.button(context),
            ),
          ),
        ],
      ],
    );

    final buttonStyle = _getButtonStyle(context, colors, effectiveColor);

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.accent:
        button = ElevatedButton(
          style: buttonStyle,
          onPressed: isLoading ? null : onPressed,
          child: content,
        );
        break;
      case AppButtonVariant.secondary:
        button = FilledButton.tonal(
          style: buttonStyle,
          onPressed: isLoading ? null : onPressed,
          child: content,
        );
        break;
      case AppButtonVariant.outlined:
        button = OutlinedButton(
          style: buttonStyle,
          onPressed: isLoading ? null : onPressed,
          child: content,
        );
        break;
      case AppButtonVariant.text:
        button = TextButton(
          style: buttonStyle,
          onPressed: isLoading ? null : onPressed,
          child: content,
        );
        break;
    }

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  ButtonStyle _getButtonStyle(BuildContext context, AppColors colors, Color effectiveColor) {
    const minSize = Size(64, 48);

    switch (variant) {
      case AppButtonVariant.accent:
        return ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          elevation: 0,
          minimumSize: minSize,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.r16),
        );
      case AppButtonVariant.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: effectiveColor,
          foregroundColor: colors.onPrimary,
          elevation: 0,
          minimumSize: minSize,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.r16),
        );
      case AppButtonVariant.secondary:
        return FilledButton.styleFrom(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.primary,
          elevation: 0,
          minimumSize: minSize,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.r16),
        );
      case AppButtonVariant.outlined:
        return OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.outline, width: 1.0),
          minimumSize: minSize,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.r16),
        );
      case AppButtonVariant.text:
        return TextButton.styleFrom(
          foregroundColor: effectiveColor,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.r12),
        );
    }
  }
}
