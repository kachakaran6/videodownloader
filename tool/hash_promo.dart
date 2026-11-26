// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Secret salt used to hash promo codes offline.
/// Must match AdConfig.promoCodeSalt exactly.
const String promoCodeSalt = 'ClipVault_AdFree_Monetization_Salt_2026_SecureKey';

/// Standalone CLI tool to generate hashed promo code entries for AdConfig.
///
/// Usage:
///   `dart run tool/hash_promo.dart [CODE] [days|lifetime] [label]`
///
/// Examples:
///   `dart run tool/hash_promo.dart LIFETIME-PREMIUM lifetime "VIP Lifetime"`
///   `dart run tool/hash_promo.dart ZEN-30DAYS 30 "Special 30 Days"`
///   `dart run tool/hash_promo.dart CLIP-7DAYS 7 "Trial 7 Days"`
void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart run tool/hash_promo.dart <CODE> <days|lifetime> [label]');
    print('Example: dart run tool/hash_promo.dart MYCODE lifetime "VIP Pass"');
    return;
  }

  final rawCode = args[0];
  final durationArg = args.length > 1 ? args[1].toLowerCase() : 'lifetime';
  final label = args.length > 2 ? args.sublist(2).join(' ') : 'Promo Pass';

  // Normalize code: uppercase, trim, remove whitespace and hyphens
  final normalized = rawCode.trim().toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');

  // Calculate sha256(salt + normalized)
  final bytes = utf8.encode('$promoCodeSalt$normalized');
  final hash = sha256.convert(bytes).toString();

  final isLifetime = durationArg == 'lifetime' || durationArg == '0';
  final days = isLifetime ? 0 : (int.tryParse(durationArg) ?? 30);

  print('================================================================');
  print('ClipVault Promo Code Generator');
  print('================================================================');
  print('Input Code:        $rawCode');
  print('Normalized Code:   $normalized');
  print('Duration:          ${isLifetime ? "Lifetime" : "$days Days"}');
  print('Label:             $label');
  print('SHA-256 Hash:      $hash');
  print('----------------------------------------------------------------');
  print('Paste the line below into AdConfig.validPromoCodes:');
  print('----------------------------------------------------------------');
  if (isLifetime) {
    print("  PromoCodeEntry.lifetime('$hash', '$label'),");
  } else {
    print("  PromoCodeEntry.days('$hash', $days, '$label'),");
  }
  print('================================================================');
}
