import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import '../theme/liquid_glass_tokens.dart';

/// Translucent Liquid Glass App Bar.
///
/// Features:
/// - Predictable 56 dp height
/// - Translucent glass surface with ImageFilter.blur backdrop diffusion
/// - Subtle bottom glass border
/// - Specular highlight along top status bar boundary
class LiquidGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final double elevation;
  final bool showBottomBorder;

  const LiquidGlassAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.elevation = 0,
    this.showBottomBorder = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final surfaceColor = LiquidGlassTokens.surface(context, elevated: true);
    final borderColor = LiquidGlassTokens.border(context);
    final isReduced = LiquidGlassTokens.isReducedEffects(context);

    Widget appBarContent = Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: showBottomBorder
            ? Border(
                bottom: BorderSide(
                  color: borderColor,
                  width: 1.0,
                ),
              )
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: NavigationToolbar(
          leading: leading,
          middle: Text(
            title,
            style: AppTypography.screenTitle(context).copyWith(fontSize: 22),
          ),
          trailing: actions != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!,
                )
              : null,
          centerMiddle: centerTitle,
        ),
      ),
    );

    if (isReduced) {
      return appBarContent;
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: LiquidGlassTokens.blurElevated,
          sigmaY: LiquidGlassTokens.blurElevated,
        ),
        child: appBarContent,
      ),
    );
  }
}
