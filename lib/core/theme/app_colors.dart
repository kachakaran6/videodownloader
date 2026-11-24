import 'package:flutter/material.dart';

/// Centralized Design System: "Lagoon & Amber" Color Tokens.
///
/// Implemented as a [ThemeExtension] so colors are never hardcoded in widgets,
/// meeting WCAG AA contrast compliance across both Light and Dark themes.
class AppColors extends ThemeExtension<AppColors> {
  // Core theme colors
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color outline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color accent;
  final Color onAccent;

  // Category colors
  final Color categoryVideo;
  final Color categoryClips;
  final Color categoryMusic;
  final Color categoryStatus;

  // Semantic
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.accent,
    required this.onAccent,
    required this.categoryVideo,
    required this.categoryClips,
    required this.categoryMusic,
    required this.categoryStatus,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });

  // ─── Light Mode Tokens (Warm paper + Lagoon + Amber) ──────────────────────
  static const light = AppColors(
    background: Color(0xFFF6F3EC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEF2EF),
    outline: Color(0xFFDCE3DF),
    textPrimary: Color(0xFF11191B),
    textSecondary: Color(0xFF5B6B6E),
    textTertiary: Color(0xFF8A9899),
    primary: Color(0xFF0A6B6B),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFCBEDE8),
    accent: Color(0xFFFFAA1D),
    onAccent: Color(0xFF2A1B00),
    categoryVideo: Color(0xFF3E86F5),
    categoryClips: Color(0xFFFF6A5C),
    categoryMusic: Color(0xFF2FCB8B),
    categoryStatus: Color(0xFFF5B301),
    success: Color(0xFF1E9E6A),
    warning: Color(0xFFE39B0B),
    error: Color(0xFFE0474C),
    info: Color(0xFF3E86F5),
  );

  // ─── Dark Mode Tokens (Ink-teal black + Lagoon glow + Amber) ─────────────
  static const dark = AppColors(
    background: Color(0xFF0A1011),
    surface: Color(0xFF111B1D),
    surfaceAlt: Color(0xFF182427),
    outline: Color(0xFF25363A),
    textPrimary: Color(0xFFEAF3F2),
    textSecondary: Color(0xFF9DB2B3),
    textTertiary: Color(0xFF6C8283),
    primary: Color(0xFF3FD8C4),
    onPrimary: Color(0xFF00201C),
    primaryContainer: Color(0xFF0F3B38),
    accent: Color(0xFFFFC24D),
    onAccent: Color(0xFF2A1B00),
    categoryVideo: Color(0xFF5C9CFF),
    categoryClips: Color(0xFFFF8578),
    categoryMusic: Color(0xFF4BE4A4),
    categoryStatus: Color(0xFFFFC933),
    success: Color(0xFF1E9E6A),
    warning: Color(0xFFE39B0B),
    error: Color(0xFFE0474C),
    info: Color(0xFF3E86F5),
  );

  // ─── Static Constants for Legacy Compatibility ────────────────────────────
  static const Color primaryLightMode = Color(0xFF0A6B6B);
  static const Color primaryDarkMode = Color(0xFF3FD8C4);
  static const Color backgroundLight = Color(0xFFF6F3EC);
  static const Color backgroundDark = Color(0xFF0A1011);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF111B1D);
  static const Color surfaceElevatedLight = Color(0xFFEEF2EF);
  static const Color surfaceElevatedDark = Color(0xFF182427);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF111B1D);
  static const Color borderLight = Color(0xFFDCE3DF);
  static const Color borderDark = Color(0xFF25363A);
  static const Color textPrimaryLight = Color(0xFF11191B);
  static const Color textPrimaryDark = Color(0xFFEAF3F2);
  static const Color textSecondaryLight = Color(0xFF5B6B6E);
  static const Color textSecondaryDark = Color(0xFF9DB2B3);
  static const Color textMutedLight = Color(0xFF8A9899);
  static const Color textMutedDark = Color(0xFF6C8283);

  // Constants without instance name collision
  static const Color sourceVideo = Color(0xFF3E86F5);
  static const Color sourceClips = Color(0xFFFF6A5C);
  static const Color sourceMusic = Color(0xFF2FCB8B);
  static const Color sourceStatus = Color(0xFFF5B301);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0A6B6B), Color(0xFF3FD8C4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── ThemeExtension Implementation ─────────────────────────────────────────
  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? outline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? accent,
    Color? onAccent,
    Color? categoryVideo,
    Color? categoryClips,
    Color? categoryMusic,
    Color? categoryStatus,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      outline: outline ?? this.outline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      categoryVideo: categoryVideo ?? this.categoryVideo,
      categoryClips: categoryClips ?? this.categoryClips,
      categoryMusic: categoryMusic ?? this.categoryMusic,
      categoryStatus: categoryStatus ?? this.categoryStatus,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      categoryVideo: Color.lerp(categoryVideo, other.categoryVideo, t)!,
      categoryClips: Color.lerp(categoryClips, other.categoryClips, t)!,
      categoryMusic: Color.lerp(categoryMusic, other.categoryMusic, t)!,
      categoryStatus: Color.lerp(categoryStatus, other.categoryStatus, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }

  // ─── Static Helpers ───────────────────────────────────────────────────────
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static AppColors of(BuildContext context) {
    final ext = Theme.of(context).extension<AppColors>();
    if (ext != null) return ext;
    return isDark(context) ? dark : light;
  }

  static Color primaryOf(BuildContext context) => of(context).primary;
  static Color primaryContainerOf(BuildContext context) => of(context).primaryContainer;
  static Color backgroundOf(BuildContext context) => of(context).background;
  static Color surfaceOf(BuildContext context) => of(context).surface;
  static Color textPrimaryOf(BuildContext context) => of(context).textPrimary;
  static Color textSecondaryOf(BuildContext context) => of(context).textSecondary;
  static Color accentOf(BuildContext context) => of(context).accent;
  static Color errorOf(BuildContext context) => of(context).error;
  static Color successOf(BuildContext context) => of(context).success;

  // Non-colliding helper methods for backward compatibility
  static Color border(BuildContext context) => of(context).outline;
  static Color card(BuildContext context) => of(context).surface;
  static Color surfaceElevated(BuildContext context) => of(context).surfaceAlt;
  static Color textMuted(BuildContext context) => of(context).textTertiary;
}
