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
  static const Color glassSurfaceLight = Color(0xD4FFFFFF); // ~83% translucent white
  static const Color glassSurfaceElevatedLight = Color(0xEAFFFFFF); // ~92% elevated
  static const Color glassSurfaceSubtleLight = Color(0xA6FFFFFF); // ~65% subtle
  
  /// Translucent lavender-tinted border defining the crisp glass edge.
  static const Color glassBorderLight = Color(0x2E7045E8); // subtle lavender rim
  static const Color glassBorderNeutralLight = Color(0x1F211B30); // 12% clean hairline
  
  /// Top-edge specular highlight simulating directional light refraction.
  static const Color glassHighlightLight = Color(0x40FFFFFF); // 25% soft white reflection

  // ─── Dark Mode Glass Material Colors ───────────────────────────────────────
  /// Translucent deep charcoal surface - allows true backdrop diffusion without muddy grey opacity.
  static const Color glassSurfaceDark = Color(0x731C1A24); // ~45% clean dark charcoal
  static const Color glassSurfaceElevatedDark = Color(0x99221F2C); // ~60% elevated
  static const Color glassSurfaceSubtleDark = Color(0x4D181620); // ~30% deep
  
  /// Translucent hairline border defining the silhouette without heavy metallic frames.
  static const Color glassBorderDark = Color(0x1FFFFFFF); // ~12% white hairline rim
  static const Color glassBorderAccentDark = Color(0x38B49AFF); // subtle purple rim
  
  /// Localized soft highlight for dark glass.
  static const Color glassHighlightDark = Color(0x14FFFFFF); // 8% restrained reflection

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

  /// Refraction linear gradient for glass edge highlights (subtle, non-embossed).
  static LinearGradient specularGradient(BuildContext context) {
    final dark = isDark(context);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        dark ? const Color(0x14FFFFFF) : const Color(0x26FFFFFF),
        const Color(0x00FFFFFF),
      ],
      stops: const [0.0, 0.25],
    );
  }

  /// Border gradient giving glass surfaces a natural light-catching top edge.
  static Gradient borderGradient(BuildContext context, {bool accent = false}) {
    final dark = isDark(context);
    final topBorder = accent
        ? (dark ? glassBorderAccentDark : glassBorderLight)
        : (dark ? const Color(0x29FFFFFF) : const Color(0x2E7045E8));
    final bottomBorder = dark ? const Color(0x0DFFFFFF) : const Color(0x0F211B30);

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [topBorder, bottomBorder],
    );
  }

  // ─── Animation Durations & Curves ──────────────────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 180);
  static const Duration durationStandard = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 350);
  static const Curve curveDefault = Curves.easeOutCubic;

  /// Checks if reduced effects should be used (e.g. accessibility reduced motion).
  static bool isReducedEffects(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }
}
