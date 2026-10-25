import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/liquid_glass_tokens.dart';
import 'liquid_glass_surface.dart';

enum LiquidGlassButtonStyle {
  primary,
  glass,
  outlined,
}

/// Tactile Liquid Glass Button.
class LiquidGlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final LiquidGlassButtonStyle style;
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const LiquidGlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.style = LiquidGlassButtonStyle.primary,
    this.height = 48.0,
    this.width,
    this.borderRadius,
  });

  const LiquidGlassButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 48.0,
    this.width,
    this.borderRadius,
  }) : style = LiquidGlassButtonStyle.primary;

  const LiquidGlassButton.glass({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 48.0,
    this.width,
    this.borderRadius,
  }) : style = LiquidGlassButtonStyle.glass;

  const LiquidGlassButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 48.0,
    this.width,
    this.borderRadius,
  }) : style = LiquidGlassButtonStyle.outlined;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? AppRadii.r12;
    final isDark = LiquidGlassTokens.isDark(context);

    Color textColor;
    if (style == LiquidGlassButtonStyle.primary) {
      textColor = isDark ? const Color(0xFF1C1A22) : Colors.white;
    } else {
      textColor = AppColors.textPrimary(context);
    }

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: width != null ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: textColor,
            ),
          ),
        ],
      ],
    );

    if (style == LiquidGlassButtonStyle.primary) {
      return SizedBox(
        width: width,
        height: height,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOf(context),
            foregroundColor: textColor,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: effectiveRadius),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          onPressed: isLoading ? null : onPressed,
          child: content,
        ),
      );
    }

    return LiquidGlassSurface(
      width: width,
      height: height,
      borderRadius: effectiveRadius,
      blurSigma: LiquidGlassTokens.blurSubtle,
      surfaceColor: style == LiquidGlassButtonStyle.outlined
          ? Colors.transparent
          : LiquidGlassTokens.surface(context, subtle: true),
      borderColor: style == LiquidGlassButtonStyle.outlined
          ? LiquidGlassTokens.border(context, accent: true)
          : LiquidGlassTokens.border(context),
      onTap: isLoading ? null : onPressed,
      child: Center(child: content),
    );
  }
}
