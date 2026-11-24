import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized Material 3 Typography Tokens.
///
/// Headings: Sora (600/700)
/// Body/UI: Inter (400/500/600)
/// Numbers (speed, size, time): Inter with tabular figures
class AppTypography {
  AppTypography._();

  // ─── Display & Titles (Sora) ──────────────────────────────────────────────
  static TextStyle display(BuildContext context, {Color? color}) {
    return GoogleFonts.sora(
      fontSize: 32,
      height: 40 / 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: color ?? AppColors.of(context).textPrimary,
    );
  }

  static TextStyle title(BuildContext context, {Color? color}) {
    return GoogleFonts.sora(
      fontSize: 22,
      height: 28 / 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: color ?? AppColors.of(context).textPrimary,
    );
  }

  static TextStyle subtitle(BuildContext context, {Color? color}) {
    return GoogleFonts.sora(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      color: color ?? AppColors.of(context).textPrimary,
    );
  }

  // ─── Body & UI (Inter) ────────────────────────────────────────────────────
  static TextStyle body(BuildContext context, {Color? color}) {
    return GoogleFonts.inter(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.of(context).textPrimary,
    );
  }

  static TextStyle bodyMedium(BuildContext context, {Color? color}) {
    return GoogleFonts.inter(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w500,
      color: color ?? AppColors.of(context).textPrimary,
    );
  }

  static TextStyle bodySemiBold(BuildContext context, {Color? color}) {
    return GoogleFonts.inter(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w600,
      color: color ?? AppColors.of(context).textPrimary,
    );
  }

  static TextStyle caption(BuildContext context, {Color? color}) {
    return GoogleFonts.inter(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w500,
      color: color ?? AppColors.of(context).textSecondary,
    );
  }

  static TextStyle overline(BuildContext context, {Color? color}) {
    return GoogleFonts.inter(
      fontSize: 11,
      height: 14 / 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: color ?? AppColors.of(context).textTertiary,
    );
  }

  // ─── Tabular Numbers (speed, size, time) ──────────────────────────────────
  static TextStyle tabularFigures(BuildContext context, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: color ?? AppColors.of(context).textPrimary,
    );
  }

  // ─── Legacy Method Compatibility ──────────────────────────────────────────
  static TextStyle screenTitle(BuildContext context) => title(context);
  static TextStyle sectionHeading(BuildContext context) => subtitle(context);
  static TextStyle sectionSubheading(BuildContext context) => body(context, color: AppColors.of(context).textSecondary);
  static TextStyle cardTitle(BuildContext context) => subtitle(context);
  static TextStyle supporting(BuildContext context) => body(context, color: AppColors.of(context).textSecondary);
  static TextStyle metadata(BuildContext context) => caption(context);
  static TextStyle button(BuildContext context) => bodySemiBold(context);
  static TextStyle chip(BuildContext context) => caption(context, color: AppColors.of(context).textPrimary);
}
