import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized Material 3 Typography Tokens.
///
/// Ensures clear visual hierarchy, accessible line heights, and consistent sizing
/// across all screens.
class AppTypography {
  AppTypography._();

  static TextStyle screenTitle(BuildContext context) {
    return TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.25,
      color: AppColors.textPrimary(context),
    );
  }

  static TextStyle sectionHeading(BuildContext context) {
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.3,
      color: AppColors.textPrimary(context),
    );
  }

  static TextStyle sectionSubheading(BuildContext context) {
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: AppColors.textSecondary(context),
    );
  }

  static TextStyle cardTitle(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      height: 1.35,
      color: AppColors.textPrimary(context),
    );
  }

  static TextStyle body(BuildContext context) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: AppColors.textPrimary(context),
    );
  }

  static TextStyle bodyMedium(BuildContext context) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: AppColors.textPrimary(context),
    );
  }

  static TextStyle supporting(BuildContext context) {
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: AppColors.textSecondary(context),
    );
  }

  static TextStyle metadata(BuildContext context) {
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.3,
      color: AppColors.textMuted(context),
    );
  }

  static TextStyle button(BuildContext context) {
    return const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.2,
    );
  }

  static TextStyle caption(BuildContext context) {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      height: 1.2,
      color: AppColors.textMuted(context),
    );
  }
}
