import 'package:flutter/material.dart';

class AppColors {
  // Dark Theme Palette
  static const Color backgroundDark = Color(0xFF0B0F19);
  static const Color surfaceDark = Color(0xFF131B2E);
  static const Color surfaceElevatedDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF162032);
  static const Color borderDark = Color(0xFF23324D);

  // Accents
  static const Color primary = Color(0xFF6366F1); // Modern Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color secondary = Color(0xFF06B6D4); // Vibrant Cyan
  static const Color accent = Color(0xFFF43F5E); // Rose/Red for YouTube vibe
  
  // Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  
  // Text
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFF43F5E), Color(0xFFFF7849)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF162032), Color(0xFF131B2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
