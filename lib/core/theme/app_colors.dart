import 'package:flutter/material.dart';

/// Centralized Design System Color Tokens.
///
/// Follows the refined Samyukt media downloader color identity:
/// Restrained purple accents, high readability, and dedicated light & dark themes.
class AppColors {
  AppColors._();

  // ─── Light Theme Palette ───────────────────────────────────────────────────
  static const Color primaryLightMode = Color(0xFF6D3FE8);
  static const Color primaryContainerLight = Color(0xFFEEE7FF);
  static const Color backgroundLight = Color(0xFFF8F7FC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFF3F0FD);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE7E1F0);
  static const Color textPrimaryLight = Color(0xFF201A2E);
  static const Color textSecondaryLight = Color(0xFF706A80);
  static const Color textMutedLight = Color(0xFF908A9E);
  static const Color successLight = Color(0xFF16865B);
  static const Color errorLight = Color(0xFFC83D4B);
  static const Color warningLight = Color(0xFFA86B12);

  // ─── Dark Theme Palette ────────────────────────────────────────────────────
  static const Color primaryDarkMode = Color(0xFFB69AFF);
  static const Color primaryContainerDark = Color(0xFF352451);
  static const Color backgroundDark = Color(0xFF121116);
  static const Color surfaceDark = Color(0xFF1C1A22);
  static const Color surfaceElevatedDark = Color(0xFF24212C);
  static const Color cardDark = Color(0xFF1C1A22);
  static const Color borderDark = Color(0xFF383342);
  static const Color textPrimaryDark = Color(0xFFF4F0FA);
  static const Color textSecondaryDark = Color(0xFFB5AEC2);
  static const Color textMutedDark = Color(0xFF7D778A);
  static const Color successDark = Color(0xFF57C99A);
  static const Color errorDark = Color(0xFFFF7B86);
  static const Color warningDark = Color(0xFFE8B85C);

  // ─── Brand & Platform Anchors (Constant) ───────────────────────────────────
  static const Color primary = Color(0xFF6D3FE8);
  static const Color primaryLight = Color(0xFF8D65F0);
  static const Color primaryDark = Color(0xFF5528CC);
  static const Color secondary = Color(0xFF8B5CF6);
  static const Color success = Color(0xFF16865B);
  static const Color warning = Color(0xFFA86B12);
  static const Color error = Color(0xFFC83D4B);

  // Media Platform Identifiers
  static const Color youtubeRed = Color(0xFFFF0033);
  static const Color instagramPink = Color(0xFFE1306C);
  static const Color spotifyGreen = Color(0xFF1DB954);
  static const Color facebookBlue = Color(0xFF1877F2);
  static const Color whatsappGreen = Color(0xFF25D366);

  // ─── Context-Aware Dynamic Resolvers ───────────────────────────────────────
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color primaryOf(BuildContext context) {
    return isDark(context) ? primaryDarkMode : primaryLightMode;
  }

  static Color primaryContainer(BuildContext context) {
    return isDark(context) ? primaryContainerDark : primaryContainerLight;
  }

  static Color background(BuildContext context) {
    return isDark(context) ? backgroundDark : backgroundLight;
  }

  static Color surface(BuildContext context) {
    return isDark(context) ? surfaceDark : surfaceLight;
  }

  static Color surfaceElevated(BuildContext context) {
    return isDark(context) ? surfaceElevatedDark : surfaceElevatedLight;
  }

  static Color card(BuildContext context) {
    return isDark(context) ? cardDark : cardLight;
  }

  static Color border(BuildContext context) {
    return isDark(context) ? borderDark : borderLight;
  }

  static Color textPrimary(BuildContext context) {
    return isDark(context) ? textPrimaryDark : textPrimaryLight;
  }

  static Color textSecondary(BuildContext context) {
    return isDark(context) ? textSecondaryDark : textSecondaryLight;
  }

  static Color textMuted(BuildContext context) {
    return isDark(context) ? textMutedDark : textMutedLight;
  }

  static Color successOf(BuildContext context) {
    return isDark(context) ? successDark : successLight;
  }

  static Color errorOf(BuildContext context) {
    return isDark(context) ? errorDark : errorLight;
  }

  static Color warningOf(BuildContext context) {
    return isDark(context) ? warningDark : warningLight;
  }

  // ─── Liquid Glass Material Resolvers ───────────────────────────────────────
  static Color glassSurface(BuildContext context, {bool elevated = false}) {
    if (isDark(context)) {
      return elevated ? const Color(0xD124212C) : const Color(0xB81C1A22);
    }
    return elevated ? const Color(0xF2FFFFFF) : const Color(0xD9FFFFFF);
  }

  static Color glassBorder(BuildContext context) {
    return isDark(context) ? const Color(0x38B5AEC2) : const Color(0x4DE7E1F0);
  }

  static Color glassHighlight(BuildContext context) {
    return isDark(context) ? const Color(0x26FFFFFF) : const Color(0x80FFFFFF);
  }

  // Legacy gradient definitions provided for backward compatibility
  static const LinearGradient violetGradient = LinearGradient(
    colors: [primaryLight, Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = violetGradient;

  static const LinearGradient instagramGradient = LinearGradient(
    colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
