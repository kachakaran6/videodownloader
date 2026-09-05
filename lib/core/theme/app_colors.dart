import 'package:flutter/material.dart';

class AppColors {
  // Core Violet Accent Palette
  static const Color primary = Color(0xFF7C3AED); // Electric Amethyst / Violet-600
  static const Color primaryLight = Color(0xFF9333EA); // Violet-500
  static const Color primaryDark = Color(0xFF6D28D9); // Violet-700
  static const Color primaryMuted = Color(0xFFDDD6FE); // Soft Violet-200
  static const Color secondary = Color(0xFF8B5CF6); // Purple Accent
  static const Color accent = Color(0xFFF43F5E); // YouTube Red / Rose
  static const Color accentCyan = Color(0xFF06B6D4); // Vibrant Cyan Highlight
  static const Color violetGlow = Color(0x337C3AED);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Dark Mode Palette (True Pure Black OLED & Neutral Dark)
  static const Color backgroundDark = Color(0xFF000000); // Pure Black
  static const Color surfaceDark = Color(0xFF0E0E11); // Deep neutral dark surface
  static const Color surfaceElevatedDark = Color(0xFF18181C); // Elevated neutral dark surface
  static const Color cardDark = Color(0xFF121215); // Deep neutral dark card
  static const Color borderDark = Color(0xFF222227); // Neutral dark border

  // Dark Mode Text
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color textMutedDark = Color(0xFF6B7280);

  // Light Mode Palette (Lilac Snow)
  static const Color backgroundLight = Color(0xFFF8F7FD);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFF3F0FD);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE4DCFD);

  // Light Mode Text
  static const Color textPrimaryLight = Color(0xFF1E1438);
  static const Color textSecondaryLight = Color(0xFF534875);
  static const Color textMutedLight = Color(0xFF8B82A8);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient violetGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFF43F5E), Color(0xFFFF7849)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradientDark = LinearGradient(
    colors: [Color(0xFF161619), Color(0xFF101012)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradientLight = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF9F7FE)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Social Platform Palettes
  static const Color instagramPink = Color(0xFFE1306C);
  static const Color instagramPurple = Color(0xFF833AB4);
  static const Color instagramOrange = Color(0xFFF77737);
  static const LinearGradient instagramGradient = LinearGradient(
    colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient youtubeGradient = LinearGradient(
    colors: [Color(0xFFFF0033), Color(0xFFFF4B4B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient whatsappGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroCardGradientDark = LinearGradient(
    colors: [Color(0xFF1E1435), Color(0xFF131024), Color(0xFF0F0D1B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroCardGradientLight = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF6F3FE), Color(0xFFEDE8FD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Context-aware Adaptive Theme Helpers
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
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

  static LinearGradient cardGradient(BuildContext context) {
    return isDark(context) ? cardGradientDark : cardGradientLight;
  }
}
