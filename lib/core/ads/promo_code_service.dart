import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'ad_config.dart';

/// Result status when attempting to apply a promo code.
enum PromoApplyStatus {
  success,
  invalidCode,
  lockedOut,
  alreadyActive,
  clockTampered,
}

/// Rich result object containing outcome details and user-facing messages.
class PromoApplyResult {
  final PromoApplyStatus status;
  final String message;
  final String? label;
  final int? remainingLockoutSeconds;
  final DateTime? expiryDate;
  final bool isLifetime;

  const PromoApplyResult({
    required this.status,
    required this.message,
    this.label,
    this.remainingLockoutSeconds,
    this.expiryDate,
    this.isLifetime = false,
  });

  bool get isSuccess => status == PromoApplyStatus.success;
}

/// State representation of the user's promo code activation.
class PromoState {
  final bool isUnlocked;
  final bool isLifetime;
  final String? label;
  final String? codeHash;
  final DateTime? activationDate;
  final DateTime? expiryDate;
  final bool isLockoutActive;
  final int lockoutRemainingSeconds;
  final bool hasExpiredNoticePending;

  const PromoState({
    required this.isUnlocked,
    this.isLifetime = false,
    this.label,
    this.codeHash,
    this.activationDate,
    this.expiryDate,
    this.isLockoutActive = false,
    this.lockoutRemainingSeconds = 0,
    this.hasExpiredNoticePending = false,
  });

  const PromoState.initial()
      : isUnlocked = false,
        isLifetime = false,
        label = null,
        codeHash = null,
        activationDate = null,
        expiryDate = null,
        isLockoutActive = false,
        lockoutRemainingSeconds = 0,
        hasExpiredNoticePending = false;

  PromoState copyWith({
    bool? isUnlocked,
    bool? isLifetime,
    String? label,
    String? codeHash,
    DateTime? activationDate,
    DateTime? expiryDate,
    bool? isLockoutActive,
    int? lockoutRemainingSeconds,
    bool? hasExpiredNoticePending,
  }) {
    return PromoState(
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isLifetime: isLifetime ?? this.isLifetime,
      label: label ?? this.label,
      codeHash: codeHash ?? this.codeHash,
      activationDate: activationDate ?? this.activationDate,
      expiryDate: expiryDate ?? this.expiryDate,
      isLockoutActive: isLockoutActive ?? this.isLockoutActive,
      lockoutRemainingSeconds:
          lockoutRemainingSeconds ?? this.lockoutRemainingSeconds,
      hasExpiredNoticePending:
          hasExpiredNoticePending ?? this.hasExpiredNoticePending,
    );
  }

  /// Days remaining until expiration (null if lifetime or inactive).
  int? get remainingDays {
    if (!isUnlocked || isLifetime || expiryDate == null) return null;
    final diff = expiryDate!.difference(DateTime.now());
    if (diff.isNegative) return 0;
    return diff.inDays + (diff.inHours % 24 > 0 ? 1 : 0);
  }

  /// Formatted duration label (e.g. "Lifetime" or "12 days left").
  String get statusDisplayLabel {
    if (!isUnlocked) return 'Inactive';
    if (isLifetime) return 'Lifetime Ad-Free';
    final days = remainingDays ?? 0;
    if (days <= 0) return 'Expiring Today';
    if (days == 1) return '1 day left';
    return '$days days left';
  }
}

/// Local-only service for offline promo code validation, persistence in
/// FlutterSecureStorage, brute-force lockout, and clock-rollback protection.
class PromoCodeService {
  static const String _keyPromoActive = 'cv_sec_promo_active';
  static const String _keyPromoLifetime = 'cv_sec_promo_is_lifetime';
  static const String _keyPromoLabel = 'cv_sec_promo_label';
  static const String _keyPromoHash = 'cv_sec_promo_hash';
  static const String _keyPromoActivationDate = 'cv_sec_promo_activation';
  static const String _keyPromoExpiryDate = 'cv_sec_promo_expiry';
  static const String _keyPromoLastSeen = 'cv_sec_promo_last_seen';
  static const String _keyFailedAttempts = 'cv_sec_failed_attempts';
  static const String _keyLockoutUntil = 'cv_sec_lockout_until';
  static const String _keyExpiredNoticePending = 'cv_sec_expired_dialog_pending';

  final FlutterSecureStorage _storage;

  PromoCodeService([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(resetOnError: true),
            );

  static final PromoCodeService instance = PromoCodeService();

  // ─── Code Normalization and Offline Hashing ───────────────────────────────

  /// Normalizes promo code input: uppercase, strips spaces, hyphens, and underscores.
  static String normalizeCode(String input) {
    return input.trim().toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');
  }

  /// Computes SHA-256(salt + normalizedCode).
  static String hashPromoCode(String normalizedCode, {String? salt}) {
    final effectiveSalt = salt ?? AdConfig.promoCodeSalt;
    final combined = '$effectiveSalt$normalizedCode';
    return sha256.convert(utf8.encode(combined)).toString();
  }

  // ─── State Inspection & Expiry / Rollback Check ───────────────────────────

  /// Checks the current promo status, re-validating expiration, lockout, and
  /// device clock tampering.
  Future<PromoState> checkPromoState() async {
    try {
      final now = DateTime.now();

      // Check lockout first
      final lockoutUntilStr = await _storage.read(key: _keyLockoutUntil);
      bool isLockoutActive = false;
      int lockoutRemainingSec = 0;

      if (lockoutUntilStr != null) {
        final lockoutUntil = DateTime.tryParse(lockoutUntilStr);
        if (lockoutUntil != null && now.isBefore(lockoutUntil)) {
          isLockoutActive = true;
          lockoutRemainingSec = lockoutUntil.difference(now).inSeconds;
        } else {
          // Lockout elapsed, clear failed attempts
          await _storage.delete(key: _keyLockoutUntil);
          await _storage.delete(key: _keyFailedAttempts);
        }
      }

      final activeStr = await _storage.read(key: _keyPromoActive);
      final hasPendingExpired =
          (await _storage.read(key: _keyExpiredNoticePending)) == 'true';

      if (activeStr != 'true') {
        return PromoState(
          isUnlocked: false,
          isLockoutActive: isLockoutActive,
          lockoutRemainingSeconds: lockoutRemainingSec,
          hasExpiredNoticePending: hasPendingExpired,
        );
      }

      final isLifetime =
          (await _storage.read(key: _keyPromoLifetime)) == 'true';
      final label = await _storage.read(key: _keyPromoLabel);
      final hash = await _storage.read(key: _keyPromoHash);
      final activationStr =
          await _storage.read(key: _keyPromoActivationDate);
      final expiryStr = await _storage.read(key: _keyPromoExpiryDate);
      final lastSeenStr = await _storage.read(key: _keyPromoLastSeen);

      final activationDate =
          activationStr != null ? DateTime.tryParse(activationStr) : null;
      final expiryDate =
          expiryStr != null ? DateTime.tryParse(expiryStr) : null;
      final lastSeenTime =
          lastSeenStr != null ? DateTime.tryParse(lastSeenStr) : null;

      // ─── Clock Rollback Guard ─────────────────────────────────────────────
      // If current time is earlier than last seen time (clock rewound):
      if (lastSeenTime != null && now.isBefore(lastSeenTime)) {
        if (!isLifetime && expiryDate != null) {
          // If the last seen time already passed the expiry, expire immediately
          if (lastSeenTime.isAfter(expiryDate)) {
            await _expirePromo();
            return PromoState(
              isUnlocked: false,
              isLockoutActive: isLockoutActive,
              lockoutRemainingSeconds: lockoutRemainingSec,
              hasExpiredNoticePending: true,
            );
          }
        }
      }

      // Record latest clock observation
      await _storage.write(
          key: _keyPromoLastSeen, value: now.toIso8601String());

      // ─── Expiry Guard ──────────────────────────────────────────────────────
      if (!isLifetime && expiryDate != null && now.isAfter(expiryDate)) {
        await _expirePromo();
        return PromoState(
          isUnlocked: false,
          isLockoutActive: isLockoutActive,
          lockoutRemainingSeconds: lockoutRemainingSec,
          hasExpiredNoticePending: true,
        );
      }

      return PromoState(
        isUnlocked: true,
        isLifetime: isLifetime,
        label: label ?? 'Premium Pass',
        codeHash: hash,
        activationDate: activationDate,
        expiryDate: expiryDate,
        isLockoutActive: isLockoutActive,
        lockoutRemainingSeconds: lockoutRemainingSec,
        hasExpiredNoticePending: hasPendingExpired,
      );
    } catch (e) {
      debugPrint('PromoCodeService checkPromoState error: $e');
      return const PromoState.initial();
    }
  }

  Future<void> _expirePromo() async {
    await _storage.write(key: _keyPromoActive, value: 'false');
    await _storage.write(key: _keyExpiredNoticePending, value: 'true');
  }

  /// Dismisses one-time expired dialog notice.
  Future<void> dismissExpiredNotice() async {
    await _storage.delete(key: _keyExpiredNoticePending);
  }

  // ─── Brute-Force Lockout Management ───────────────────────────────────────

  Future<void> _recordFailedAttempt() async {
    final failedStr = await _storage.read(key: _keyFailedAttempts);
    final count = (int.tryParse(failedStr ?? '0') ?? 0) + 1;
    await _storage.write(key: _keyFailedAttempts, value: count.toString());

    if (count >= AdConfig.promoMaxFailedAttempts) {
      final lockoutUntil =
          DateTime.now().add(AdConfig.promoLockoutDuration);
      await _storage.write(
          key: _keyLockoutUntil, value: lockoutUntil.toIso8601String());
    }
  }

  Future<void> _resetFailedAttempts() async {
    await _storage.delete(key: _keyFailedAttempts);
    await _storage.delete(key: _keyLockoutUntil);
  }

  // ─── Apply Code Offline ───────────────────────────────────────────────────

  /// Validates, hashes and applies the promo code offline.
  Future<PromoApplyResult> applyCode(String rawInput) async {
    final now = DateTime.now();

    // 1. Lockout check
    final lockoutUntilStr = await _storage.read(key: _keyLockoutUntil);
    if (lockoutUntilStr != null) {
      final lockoutUntil = DateTime.tryParse(lockoutUntilStr);
      if (lockoutUntil != null && now.isBefore(lockoutUntil)) {
        final remaining = lockoutUntil.difference(now).inSeconds;
        return PromoApplyResult(
          status: PromoApplyStatus.lockedOut,
          message:
              'Too many failed attempts. Try again in ${(remaining / 60).ceil()} minute(s).',
          remainingLockoutSeconds: remaining,
        );
      }
    }

    final normalized = normalizeCode(rawInput);
    if (normalized.isEmpty) {
      return const PromoApplyResult(
        status: PromoApplyStatus.invalidCode,
        message: "That code isn't valid",
      );
    }

    // 2. Offline SHA-256 match
    final computedHash = hashPromoCode(normalized);

    PromoCodeEntry? matchedEntry;
    for (final entry in AdConfig.validPromoCodes) {
      if (entry.sha256Hash.toLowerCase() == computedHash.toLowerCase()) {
        matchedEntry = entry;
        break;
      }
    }

    if (matchedEntry == null) {
      await _recordFailedAttempt();
      final updatedLockoutStr = await _storage.read(key: _keyLockoutUntil);
      if (updatedLockoutStr != null) {
        final lockUntil = DateTime.tryParse(updatedLockoutStr);
        if (lockUntil != null && now.isBefore(lockUntil)) {
          final remSec = lockUntil.difference(now).inSeconds;
          return PromoApplyResult(
            status: PromoApplyStatus.lockedOut,
            message:
                'Too many failed attempts. Locked out for ${(remSec / 60).ceil()} minute(s).',
            remainingLockoutSeconds: remSec,
          );
        }
      }
      return const PromoApplyResult(
        status: PromoApplyStatus.invalidCode,
        message: "That code isn't valid",
      );
    }

    // 3. Valid code! Reset lockout
    await _resetFailedAttempts();

    DateTime? expiryDate;
    if (!matchedEntry.isLifetime) {
      expiryDate = now.add(Duration(days: matchedEntry.days));
    }

    // Store activation
    await _storage.write(key: _keyPromoActive, value: 'true');
    await _storage.write(
        key: _keyPromoLifetime, value: matchedEntry.isLifetime.toString());
    await _storage.write(key: _keyPromoLabel, value: matchedEntry.label);
    await _storage.write(key: _keyPromoHash, value: computedHash);
    await _storage.write(
        key: _keyPromoActivationDate, value: now.toIso8601String());
    if (expiryDate != null) {
      await _storage.write(
          key: _keyPromoExpiryDate, value: expiryDate.toIso8601String());
    } else {
      await _storage.delete(key: _keyPromoExpiryDate);
    }
    await _storage.write(
        key: _keyPromoLastSeen, value: now.toIso8601String());
    await _storage.delete(key: _keyExpiredNoticePending);

    return PromoApplyResult(
      status: PromoApplyStatus.success,
      message: 'Ads removed. Thank you!',
      label: matchedEntry.label,
      expiryDate: expiryDate,
      isLifetime: matchedEntry.isLifetime,
    );
  }

  /// Clears active promo code.
  Future<void> removeCode() async {
    await _storage.delete(key: _keyPromoActive);
    await _storage.delete(key: _keyPromoLifetime);
    await _storage.delete(key: _keyPromoLabel);
    await _storage.delete(key: _keyPromoHash);
    await _storage.delete(key: _keyPromoActivationDate);
    await _storage.delete(key: _keyPromoExpiryDate);
    await _storage.delete(key: _keyPromoLastSeen);
    await _storage.delete(key: _keyExpiredNoticePending);
  }
}
