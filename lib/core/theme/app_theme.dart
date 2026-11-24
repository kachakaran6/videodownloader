import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_radii.dart';
import 'app_spacing.dart';

/// Centralized Material 3 Theme Definition: "Lagoon & Amber".
///
/// Features:
/// - Primary Lagoon: #0A6B6B (Light) / #3FD8C4 (Dark)
/// - Accent Amber: #FFAA1D (Light) / #FFC24D (Dark)
/// - Background: #F6F3EC (Light warm paper) / #0A1011 (Dark ink-teal)
/// - Sora headings + Inter body typography
/// - 20dp card radius, 16dp button radius, 28dp sheet radius
class AppTheme {
  AppTheme._();

  // ─── Light Theme ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final colors = AppColors.light;
    final colorScheme = ColorScheme.light(
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.primaryContainer,
      onPrimaryContainer: colors.primary,
      secondary: colors.accent,
      onSecondary: colors.onAccent,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      surfaceContainerHighest: colors.surfaceAlt,
      outline: colors.outline,
      outlineVariant: colors.outline.withValues(alpha: 0.5),
      error: colors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colors.background,
      colorScheme: colorScheme,
      extensions: const [AppColors.light],
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w700, color: colors.textPrimary),
        displayMedium: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: colors.textPrimary),
        titleLarge: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w600, color: colors.textPrimary),
        titleMedium: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: colors.textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textPrimary),
        bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: colors.textSecondary),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
        labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: colors.textTertiary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.sora(
          color: colors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.r20,
          side: BorderSide(color: colors.outline, width: 1.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.r16),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.r16),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          side: BorderSide(color: colors.outline, width: 1.0),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.r16),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.sheetTop,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.r24,
          side: BorderSide(color: colors.outline, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadii.r16,
          borderSide: BorderSide(color: colors.outline, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.r16,
          borderSide: BorderSide(color: colors.outline, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.r16,
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.r16,
          borderSide: BorderSide(color: colors.error, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.r16,
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(
          color: colors.textTertiary,
          fontSize: 14,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outline,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ─── Dark Theme ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final colors = AppColors.dark;
    final colorScheme = ColorScheme.dark(
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.primaryContainer,
      onPrimaryContainer: colors.primary,
      secondary: colors.accent,
      onSecondary: colors.onAccent,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      surfaceContainerHighest: colors.surfaceAlt,
      outline: colors.outline,
      outlineVariant: colors.outline.withValues(alpha: 0.5),
      error: colors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.background,
      colorScheme: colorScheme,
      extensions: const [AppColors.dark],
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w700, color: colors.textPrimary),
        displayMedium: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: colors.textPrimary),
        titleLarge: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w600, color: colors.textPrimary),
        titleMedium: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: colors.textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textPrimary),
        bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: colors.textSecondary),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
        labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: colors.textTertiary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.sora(
          color: colors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.r20,
          side: BorderSide(color: colors.outline, width: 1.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.r16),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.r16),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          side: BorderSide(color: colors.outline, width: 1.0),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.r16),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.sheetTop,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.r24,
          side: BorderSide(color: colors.outline, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadii.r16,
          borderSide: BorderSide(color: colors.outline, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.r16,
          borderSide: BorderSide(color: colors.outline, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.r16,
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.r16,
          borderSide: BorderSide(color: colors.error, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.r16,
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(
          color: colors.textTertiary,
          fontSize: 14,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outline,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
