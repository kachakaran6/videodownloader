import 'package:flutter/material.dart';

/// Centralized Corner Radius Tokens.
///
/// Design system:
/// - Cards: 20dp
/// - Buttons: 16dp
/// - Chips: full pill (999dp)
/// - Bottom sheets top: 28dp
/// - Thumbnails: 14dp
class AppRadii {
  AppRadii._();

  static const double thumbnail = 14.0;
  static const double button = 16.0;
  static const double card = 20.0;
  static const double sheetTopRadius = 28.0;
  static const double pill = 999.0;

  // Generic sizes
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double sheet = 28.0;

  // BorderRadius objects
  static const BorderRadius r8 = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius r12 = BorderRadius.all(Radius.circular(md));
  static const BorderRadius r14 = BorderRadius.all(Radius.circular(thumbnail));
  static const BorderRadius r16 = BorderRadius.all(Radius.circular(button));
  static const BorderRadius r20 = BorderRadius.all(Radius.circular(card));
  static const BorderRadius r24 = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius r28 = BorderRadius.all(Radius.circular(sheet));
  static const BorderRadius rPill = BorderRadius.all(Radius.circular(pill));

  // Top-only for bottom sheets (28dp)
  static const BorderRadius sheetTop = BorderRadius.vertical(top: Radius.circular(sheet));
}
