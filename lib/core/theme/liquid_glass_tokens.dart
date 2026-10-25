import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized Design Tokens for the Liquid Glass System.
///
/// Follows Apple-inspired material translucency, controlled backdrop blur,
/// dual-layer highlights, and restrained border reflections.
class LiquidGlassTokens {
  LiquidGlassTokens._();

  // ─── Blur Sigmas ───────────────────────────────────────────────────────────
  /// Subtle blur for compact chips, segmented controls, or small buttons.
  static const double blurSubtle = 8.0;

  /// Standard blur for cards, inputs, and general surfaces.
  static const double blurStandard = 16.0;

  /// Elevated blur for navigation bars, app bars, and floating action panels.
  static const double blurElevated = 24.0;

  /// High blur for modal sheets and dialogs.
  static const double blurModal = 32.0;

  // ─── Light Mode Glass Material Colors ──────────────────────────────────────
  /// Translucent white surface allowing diffused background luminosity.
  static const Color glassSurfaceLight = Color(0xD9FFFFFF); // ~85% white
  static const Color glassSurfaceElevatedLight = Color(0xF2FFFFFF); // ~95% white
  static const Color glassSurfaceSubtleLight = Color(0xB3FFFFFF); // ~70% white

  /// Translucent lavender-tinted border defining the crisp glass edge.
  static const Color glassBorderLight = Color(0x597045E8); // subtle lavender rim
  static const Color glassBorderNeutralLight = Color(0x33201A2E); // 20% dark edge

  /// Top-edge specular highlight simulating directional light refraction.
  static const Color glassHighlightLight = Color(0x99FFFFFF); // 60% white reflection

  // ─── Dark Mode Glass Material Colors ───────────────────────────────────────
  /// Translucent deep charcoal surface.
  static const Color glassSurfaceDark = Color(0xB81C1A22); // ~72% charcoal
  static const Color glassSurfaceElevatedDark = Color(0xD124212C); // ~82% elevated
  static const Color glassSurfaceSubtleDark = Color(0x8A16141D); // ~54% deep

  /// Translucent low-contrast border.
  static const Color glassBorderDark = Color(0x38B5AEC2); // ~22% light gray rim
  static const Color glassBorderAccentDark = Color(0x4DB69AFF); // subtle purple rim

  /// Top-edge specular highlight for dark glass.
  static const Color glassHighlightDark = Color(0x26FFFFFF); // 15% white reflection

  // ─── Dynamic Resolvers ─────────────────────────────────────────────────────
  static bool isDark(BuildContext context) => AppColors.isDark(context);

  /// Resolves the glass surface color based on theme and elevation.
  static Color surface(BuildContext context, {bool elevated = false, bool subtle = false}) {
    final dark = isDark(context);
    if (subtle) {
      return dark ? glassSurfaceSubtleDark : glassSurfaceSubtleLight;
    }
    if (elevated) {
      return dark ? glassSurfaceElevatedDark : glassSurfaceElevatedLight;
    }
    return dark ? glassSurfaceDark : glassSurfaceLight;
  }

  /// Resolves the glass border color.
  static Color border(BuildContext context, {bool accent = false}) {
    final dark = isDark(context);
    if (accent) {
      return dark ? glassBorderAccentDark : glassBorderLight;
    }
    return dark ? glassBorderDark : glassBorderNeutralLight;
  }

  /// Resolves top specular reflection highlight.
  static Color highlight(BuildContext context) {
    return isDark(context) ? glassHighlightDark : glassHighlightLight;
  }

  /// Refraction linear gradient for glass edge highlights.
  static LinearGradient specularGradient(BuildContext context) {
    final dark = isDark(context);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        dark ? const Color(0x2EFFFFFF) : const Color(0x80FFFFFF),
        dark ? const Color(0x00FFFFFF) : const Color(0x00FFFFFF),
      ],
      stops: const [0.0, 0.4],
    );
  }

  /// Border gradient giving glass surfaces a natural light-catching top edge.
  static Gradient borderGradient(BuildContext context, {bool accent = false}) {
    final dark = isDark(context);
    final topBorder = accent
        ? (dark ? glassBorderAccentDark : glassBorderLight)
        : (dark ? const Color(0x52FFFFFF) : const Color(0x66FFFFFF));
    final bottomBorder = dark ? const Color(0x1F383342) : const Color(0x29E7E1F0);

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [topBorder, bottomBorder],
    );
  }

  /// Checks if reduced effects should be used (e.g. accessibility reduced motion).
  static bool isReducedEffects(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }
}
