import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Defines the duration type for a promo code.
enum PromoDurationType {
  lifetime,
  days,
}

/// Represents a secure, hashed promo code rule.
class PromoCodeEntry {
  final String sha256Hash;
  final PromoDurationType type;
  final int days;
  final String label;

  const PromoCodeEntry({
    required this.sha256Hash,
    required this.type,
    this.days = 0,
    required this.label,
  });

  const PromoCodeEntry.lifetime(this.sha256Hash, this.label)
      : type = PromoDurationType.lifetime,
        days = 0;

  const PromoCodeEntry.days(this.sha256Hash, this.days, this.label)
      : type = PromoDurationType.days;

  bool get isLifetime => type == PromoDurationType.lifetime;
}

/// Central configuration for all monetization, AdMob ad units, safety policies,
/// frequency caps, and promo code verification.
class AdConfig {
  AdConfig._();

  // ─── Salt for Promo Code Offline Hashing ──────────────────────────────────
  static const String promoCodeSalt =
      'ClipVault_AdFree_Monetization_Salt_2026_SecureKey';

  // ─── Native Ad Factory Identifier ─────────────────────────────────────────
  static const String nativeAdFactoryId = 'clipvault_native_card';

  // ─── Pre-configured Valid Promo Codes (SHA-256 Hashes) ────────────────────
  // Test codes generated via `dart run tool/hash_promo.dart`:
  // 1. LIFETIME-PREMIUM -> Lifetime ad removal
  // 2. ZEN-30DAYS       -> 30-day ad removal
  // 3. CLIP-7DAYS       -> 7-day ad removal
  // 4. VAULT-30DAYS-PASS -> 30-day ad removal
  // 5. VAULT-7DAYS-TRIAL -> 7-day ad removal
  static const List<PromoCodeEntry> validPromoCodes = [
    PromoCodeEntry.lifetime(
      'b7e22b3ce513710e11a7e9fdc1a5c5e65a05f078a5f5a792868be10b199fedd4',
      'VIP Lifetime Pass',
    ),
    PromoCodeEntry.days(
      '61d99019e4edf71f63f535ecafb97b57f7db1f90c81a2dbabe93633d5fa44945',
      30,
      'Zen Pass (30 Days)',
    ),
    PromoCodeEntry.days(
      'be62ca494151a5a60f9d71b58769edbf77c17a022ce72cdc3b690228f7c6759d',
      7,
      'Trial Pass (7 Days)',
    ),
    PromoCodeEntry.days(
      '7bccf3e14e3bb0ff1e069056f9b217f3412975c54a4cf21f23670beb6dd55e42',
      30,
      '30-Day Ad-Free Pass',
    ),
    PromoCodeEntry.days(
      'ef90eb9255ef0697029fa3941a3b550a167ac158086943c2028ac9c801fe1a54',
      7,
      '7-Day Trial',
    ),
  ];

  // ─── AdMob App ID ─────────────────────────────────────────────────────────
  // Configured in AndroidManifest.xml:
  // Sample Test App ID: ca-app-pub-3940256099942544~3347511713
  // Replace in release with: ca-app-pub-YOUR_PUBLISHER_ID~YOUR_APP_ID

  // ─── Ad Unit IDs ──────────────────────────────────────────────────────────
  // Google Official Test IDs used in Debug; Real IDs plugged in for Release.
  // --------------------------------------------------------------------------

  // 1. Native Ad Unit IDs
  static const String _androidNativeTest = 'ca-app-pub-3940256099942544/2247696110';
  static const String _androidNativeRelease = 'ca-app-pub-6721729055053884/6587366634';
  static const String _iosNativeTest = 'ca-app-pub-3940256099942544/3986624511';
  static const String _iosNativeRelease = 'ca-app-pub-6721729055053884/6587366634';

  static String get nativeAdUnitId {
    if (kDebugMode) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _iosNativeTest
          : _androidNativeTest;
    }
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _iosNativeRelease
        : _androidNativeRelease;
  }

  // 2. Interstitial Ad Unit IDs
  static const String _androidInterstitialTest = 'ca-app-pub-3940256099942544/1033173712';
  static const String _androidInterstitialRelease = 'ca-app-pub-6721729055053884/2600467279';
  static const String _iosInterstitialTest = 'ca-app-pub-3940256099942544/4411468910';
  static const String _iosInterstitialRelease = 'ca-app-pub-6721729055053884/2600467279';

  static String get interstitialAdUnitId {
    if (kDebugMode) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _iosInterstitialTest
          : _androidInterstitialTest;
    }
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _iosInterstitialRelease
        : _androidInterstitialRelease;
  }

  // 3. Rewarded "Zen Boost" Ad Unit IDs
  static const String _androidRewardedTest = 'ca-app-pub-3940256099942544/5224354917';
  static const String _androidRewardedRelease = 'ca-app-pub-6721729055053884/1172543374';
  static const String _iosRewardedTest = 'ca-app-pub-3940256099942544/1712485313';
  static const String _iosRewardedRelease = 'ca-app-pub-6721729055053884/1172543374';

  static String get rewardedAdUnitId {
    if (kDebugMode) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _iosRewardedTest
          : _androidRewardedTest;
    }
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _iosRewardedRelease
        : _androidRewardedRelease;
  }

  static String get fallbackNativeAdUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS ? _iosNativeTest : _androidNativeTest;

  static String get fallbackInterstitialAdUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS ? _iosInterstitialTest : _androidInterstitialTest;

  static String get fallbackRewardedAdUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS ? _iosRewardedTest : _androidRewardedTest;

  // ─── Target & Privacy RequestConfiguration ────────────────────────────────
  static RequestConfiguration get requestConfiguration => RequestConfiguration(
        maxAdContentRating: MaxAdContentRating.pg,
        ageRestrictedTreatment: AgeRestrictedTreatment.unspecified,
      );

  // ─── Frequency Caps & Timing Rules ────────────────────────────────────────
  /// Refresh visible native ad at most once every 60 seconds
  static const Duration nativeAdRefreshInterval = Duration(seconds: 60);

  /// Interstitial: minimum cooldown between consecutive interstitials (8 minutes)
  static const Duration interstitialCooldown = Duration(minutes: 8);

  /// Interstitial: minimum time since app installation before any interstitial can appear (24 hours)
  static const Duration interstitialInstallCooldown = Duration(hours: 24);

  /// Interstitial: minimum session count before interstitials can appear
  static const int interstitialMinSessions = 3;

  /// Interstitial: only eligible after every 3rd completed download
  static const int interstitialDownloadFrequency = 3;

  /// Interstitial: maximum interstitials shown per calendar day
  static const int interstitialDailyCap = 3;

  /// Interstitial: idle duration after download completion before pre-notice appears
  static const Duration interstitialPostDownloadIdle = Duration(seconds: 2);

  /// Interstitial: soft pre-notice display duration before ad presentation
  static const Duration interstitialPreNoticeDuration = Duration(milliseconds: 1200);

  /// Rewarded Zen Boost: maximum rewarded ads per calendar day
  static const int rewardedDailyCap = 3;

  /// Rewarded Zen Boost: ad-free time awarded per completed ad
  static const Duration zenBoostAdFreeDuration = Duration(hours: 2);

  /// Rewarded Zen Boost: maximum total stackable ad-free time (6 hours)
  static const Duration zenBoostMaxStackDuration = Duration(hours: 6);

  /// Rewarded Zen Boost: priority queue downloads granted (optional)
  static const int zenBoostPriorityDownloads = 3;

  /// Promo code: wrong attempts threshold triggering lockout
  static const int promoMaxFailedAttempts = 5;

  /// Promo code: lockout duration after 5 failed attempts (5 minutes)
  static const Duration promoLockoutDuration = Duration(minutes: 5);

  // ─── Blocked Sensitive Categories (for AdMob Console Blocking Controls) ────
  // Configure these in Google AdMob Console > Blocking controls > Sensitive categories:
  // 1. Alcohol & Tobacco
  // 2. Gambling & Betting
  // 3. Dating & Personal Relationships
  // 4. Politics, Elections & Activism
  // 5. Religion & Belief Systems
  // 6. Weight Loss, Diets & Supplements
  // 7. Get-Rich-Quick, Crypto Speculation & Work-From-Home schemes
  // 8. Adult, Sexual Content & Suggestive Themes
}
