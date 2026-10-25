import 'package:flutter/material.dart';

/// Centralized 8dp Spacing System.
class AppSpacing {
  AppSpacing._();

  /// 4 dp - compact icon-to-text spacing
  static const double xs = 4.0;

  /// 8 dp - related elements
  static const double sm = 8.0;

  /// 12 dp - compact component spacing
  static const double md = 12.0;

  /// 16 dp - standard internal padding
  static const double lg = 16.0;

  /// 20 dp - generous container padding
  static const double xlg = 20.0;

  /// 24 dp - section spacing
  static const double xl = 24.0;

  /// 32 dp - major section separation
  static const double xxl = 32.0;

  // Convenient SizedBox horizontal spacers
  static const Widget h4 = SizedBox(width: xs);
  static const Widget h8 = SizedBox(width: sm);
  static const Widget h12 = SizedBox(width: md);
  static const Widget h16 = SizedBox(width: lg);
  static const Widget h24 = SizedBox(width: xl);

  // Convenient SizedBox vertical spacers
  static const Widget v4 = SizedBox(height: xs);
  static const Widget v8 = SizedBox(height: sm);
  static const Widget v12 = SizedBox(height: md);
  static const Widget v16 = SizedBox(height: lg);
  static const Widget v20 = SizedBox(height: xlg);
  static const Widget v24 = SizedBox(height: xl);
  static const Widget v32 = SizedBox(height: xxl);

  // Semantic vertical gap spacers
  static const Widget gapXs = v4;
  static const Widget gapSm = v8;
  static const Widget gapMd = v12;
  static const Widget gapLg = v16;
  static const Widget gapXlg = v20;
  static const Widget gapXl = v24;
  static const Widget gapXxl = v32;

  // Standard EdgeInsets
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets compactCardPadding = EdgeInsets.all(12);
}
