import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';

final adServiceProvider = Provider<AdService>((ref) => AdService.instance);

/// Central Ad Service managing Google Mobile Ads SDK initialization, UMP privacy consent,
/// preloading of interstitials and rewarded ads, and clean memory disposal.
class AdService {
  static final AdService instance = AdService._internal();
  AdService._internal();

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isConsentChecked = false;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;

  bool get isInitialized => _isInitialized;
  bool get isConsentChecked => _isConsentChecked;
  bool get isInterstitialReady => _interstitialAd != null;
  bool get isRewardedReady => _rewardedAd != null;

  void markSdkInitialized() {
    _isInitialized = true;
  }

  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
    } catch (e) {
      debugPrint('[AdService] ensureInitialized error: $e');
    }
  }

  // ─── Initialization ─────────────────────────────────────────────────────────

  /// Initializes the Google Mobile Ads SDK with COPPA / Content Rating policies
  /// and requests UMP consent if required.
  Future<void> initialize({bool adsEnabled = true}) async {
    if (_isInitialized || _isInitializing) return;
    if (!adsEnabled) {
      debugPrint('[AdService] Ads are disabled (Promo or Zen Boost active). Skipping init.');
      return;
    }

    _isInitializing = true;

    try {
      // 1. Configure RequestConfiguration (PG Rating, not child directed)
      await MobileAds.instance.updateRequestConfiguration(
        AdConfig.requestConfiguration,
      );

      // 2. Handle UMP consent first
      await _requestConsent();

      // 3. Initialize Google Mobile Ads SDK
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('[AdService] Google Mobile Ads initialized successfully.');

      // 4. Preload initial ads
      preloadInterstitial();
      preloadRewarded();
    } catch (e) {
      debugPrint('[AdService] Error during initialization: $e');
    } finally {
      _isInitializing = false;
    }
  }

  /// Convenience wrapper called on first launch after onboarding
  Future<void> initializeConsentAndAds({
    required BuildContext context,
    bool force = false,
  }) async {
    await initialize(adsEnabled: true);
  }

  // ─── UMP Consent Handling ──────────────────────────────────────────────────

  Future<void> _requestConsent() async {
    final completer = Completer<void>();

    final params = ConsentRequestParameters(
      tagForUnderAgeOfConsent: false,
    );

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        ConsentForm.loadAndShowConsentFormIfRequired((formError) {
          if (formError != null) {
            debugPrint('[AdService] UMP Consent Form error: ${formError.message}');
          }
          _isConsentChecked = true;
          if (!completer.isCompleted) completer.complete();
        });
      },
      (formError) {
        debugPrint('[AdService] ConsentInfoUpdate error: ${formError.message}');
        _isConsentChecked = true;
        if (!completer.isCompleted) completer.complete();
      },
    );

    // Give consent check a maximum timeout so startup is never stalled
    return completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        debugPrint('[AdService] Consent check timed out. Proceeding.');
      },
    );
  }

  /// Called from Settings > "Privacy choices" to allow users to update their consent preferences.
  Future<bool> showPrivacyOptionsForm([BuildContext? context]) async {
    final completer = Completer<bool>();
    ConsentForm.showPrivacyOptionsForm((formError) {
      if (formError != null) {
        debugPrint('[AdService] showPrivacyOptionsForm error: ${formError.message}');
        completer.complete(false);
      } else {
        completer.complete(true);
      }
    });
    return completer.future;
  }

  /// Checks if privacy options (consent management) should be displayed in Settings.
  Future<bool> isPrivacyOptionsRequired() async {
    try {
      final status = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  // ─── Interstitial Preload & Presentation ───────────────────────────────────

  void preloadInterstitial({String? unitId}) {
    if (_interstitialAd != null || _isInterstitialLoading) return;
    _isInterstitialLoading = true;

    final targetUnitId = unitId ?? AdConfig.interstitialAdUnitId;

    InterstitialAd.load(
      adUnitId: targetUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          debugPrint('[AdService] Interstitial loaded ($targetUnitId).');
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Interstitial failed ($targetUnitId): ${error.message}');
          _interstitialAd = null;
          _isInterstitialLoading = false;
          if (targetUnitId != AdConfig.fallbackInterstitialAdUnitId) {
            preloadInterstitial(unitId: AdConfig.fallbackInterstitialAdUnitId);
          }
        },
      ),
    );
  }

  Future<bool> loadInterstitialWithFallback() async {
    if (_interstitialAd != null) return true;
    final completer = Completer<bool>();
    _isInterstitialLoading = true;

    void loadUnit(String unitId, bool isFallback) {
      InterstitialAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isInterstitialLoading = false;
            debugPrint('[AdService] Interstitial loaded successfully ($unitId).');
            if (!completer.isCompleted) completer.complete(true);
          },
          onAdFailedToLoad: (error) {
            debugPrint('[AdService] Interstitial load error ($unitId): ${error.message}');
            if (!isFallback && unitId != AdConfig.fallbackInterstitialAdUnitId) {
              loadUnit(AdConfig.fallbackInterstitialAdUnitId, true);
            } else {
              _interstitialAd = null;
              _isInterstitialLoading = false;
              if (!completer.isCompleted) completer.complete(false);
            }
          },
        ),
      );
    }

    loadUnit(AdConfig.interstitialAdUnitId, false);
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _isInterstitialLoading = false;
        return false;
      },
    );
  }

  void showInterstitial({
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailed,
  }) {
    if (_interstitialAd == null) {
      onAdFailed?.call();
      preloadInterstitial();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        onAdDismissed?.call();
        // Preload next interstitial after completion
        preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] Interstitial failed to show: ${error.message}');
        ad.dispose();
        _interstitialAd = null;
        onAdFailed?.call();
        preloadInterstitial();
      },
    );

    _interstitialAd!.show();
  }

  // ─── Rewarded "Zen Boost" Preload & Presentation ───────────────────────────

  void preloadRewarded({String? unitId}) {
    if (_rewardedAd != null || _isRewardedLoading) return;
    _isRewardedLoading = true;

    final targetUnitId = unitId ?? AdConfig.rewardedAdUnitId;

    RewardedAd.load(
      adUnitId: targetUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          debugPrint('[AdService] Rewarded ad loaded ($targetUnitId).');
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Rewarded ad failed ($targetUnitId): ${error.message}');
          _rewardedAd = null;
          _isRewardedLoading = false;
          if (targetUnitId != AdConfig.fallbackRewardedAdUnitId) {
            preloadRewarded(unitId: AdConfig.fallbackRewardedAdUnitId);
          }
        },
      ),
    );
  }

  Future<bool> loadRewardedWithFallback() async {
    if (_rewardedAd != null) return true;
    final completer = Completer<bool>();
    _isRewardedLoading = true;

    void loadUnit(String unitId, bool isFallback) {
      RewardedAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isRewardedLoading = false;
            debugPrint('[AdService] Rewarded ad loaded successfully ($unitId).');
            if (!completer.isCompleted) completer.complete(true);
          },
          onAdFailedToLoad: (error) {
            debugPrint('[AdService] Rewarded ad load error ($unitId): ${error.message}');
            if (!isFallback && unitId != AdConfig.fallbackRewardedAdUnitId) {
              loadUnit(AdConfig.fallbackRewardedAdUnitId, true);
            } else {
              _rewardedAd = null;
              _isRewardedLoading = false;
              if (!completer.isCompleted) completer.complete(false);
            }
          },
        ),
      );
    }

    loadUnit(AdConfig.rewardedAdUnitId, false);
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _isRewardedLoading = false;
        return false;
      },
    );
  }

  void showRewarded({
    required Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailed,
  }) {
    if (_rewardedAd == null) {
      onAdFailed?.call();
      preloadRewarded();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        onAdDismissed?.call();
        preloadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] Rewarded ad failed to show: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        onAdFailed?.call();
        preloadRewarded();
      },
    );

    _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      onUserEarnedReward(reward);
    });
  }

  Future<void> showRewardedZenBoost({
    required BuildContext context,
    required VoidCallback onRewardGranted,
    required Function(String error) onFailure,
  }) async {
    if (!isRewardedReady) {
      final success = await loadRewardedWithFallback();
      if (!success || _rewardedAd == null) {
        onFailure('Sponsored clip is currently unavailable. Please check your network connection.');
        return;
      }
    }

    showRewarded(
      onUserEarnedReward: (reward) {
        onRewardGranted();
      },
      onAdFailed: () {
        onFailure('Failed to display sponsor video');
      },
    );
  }

  Future<bool> showInterstitialIfEligible({
    required BuildContext context,
    VoidCallback? onDismissed,
  }) async {
    final completer = Completer<bool>();
    if (!isInterstitialReady) {
      final success = await loadInterstitialWithFallback();
      if (!success || _interstitialAd == null) {
        return false;
      }
    }

    showInterstitial(
      onAdDismissed: () {
        onDismissed?.call();
        completer.complete(true);
      },
      onAdFailed: () {
        completer.complete(false);
      },
    );

    return completer.future;
  }

  // ─── Native Ad Helper ──────────────────────────────────────────────────────

  NativeAd createNativeAd({
    required Function(NativeAd ad) onLoaded,
    required Function(LoadAdError error) onFailed,
  }) {
    return NativeAd(
      adUnitId: AdConfig.nativeAdUnitId,
      factoryId: AdConfig.nativeAdFactoryId,
      request: const AdRequest(),
      nativeAdOptions: NativeAdOptions(
        mediaAspectRatio: MediaAspectRatio.landscape,
        adChoicesPlacement: AdChoicesPlacement.topRightCorner,
        videoOptions: VideoOptions(
          startMuted: true, // Audio muted by default per policy
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) => onLoaded(ad as NativeAd),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onFailed(error);
        },
      ),
    );
  }

  // ─── Clean Memory Disposal ────────────────────────────────────────────────

  /// Frees all cached ads in memory when promo code or Zen Boost is enabled.
  void disposeAllAds() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialLoading = false;

    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedLoading = false;

    debugPrint('[AdService] All cached ads disposed.');
  }
}
