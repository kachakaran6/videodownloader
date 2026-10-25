import 'package:flutter/material.dart';

/// Centralized Corner Radius Tokens.
class AppRadii {
  AppRadii._();

  /// 8 dp - small controls, badges, chips
  static const double sm = 8.0;

  /// 12 dp - compact cards, list rows
  static const double md = 12.0;

  /// 16 dp - standard cards, modal containers
  static const double lg = 16.0;

  /// 20 dp - large bottom sheets, hero cards
  static const double xl = 20.0;

  /// 24 dp - prominent dialogs
  static const double xxl = 24.0;

  /// 999 dp - fully rounded pills for filter chips
  static const double pill = 999.0;

  // BorderRadius objects
  static const BorderRadius r8 = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius r12 = BorderRadius.all(Radius.circular(md));
  static const BorderRadius r16 = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius r20 = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius r24 = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius rPill = BorderRadius.all(Radius.circular(pill));

  // Top-only for bottom sheets
  static const BorderRadius sheetTop = BorderRadius.vertical(top: Radius.circular(xl));
}
