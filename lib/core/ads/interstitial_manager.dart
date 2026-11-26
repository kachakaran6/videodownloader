import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'ad_gate.dart';
import 'ad_service.dart';
import 'frequency_cap.dart';

final interstitialManagerProvider = Provider<InterstitialManager>((ref) {
  final adService = ref.watch(adServiceProvider);
  final freqCap = ref.watch(frequencyCapServiceProvider);
  return InterstitialManager(ref, adService, freqCap);
});

/// Coordinates polite post-download interstitial presentations.
class InterstitialManager {
  final Ref _ref;
  final AdService _adService;
  final FrequencyCapService _frequencyCap;

  bool _isModalOrSheetOpen = false;
  String _activeScreen = 'home';
  Timer? _idleTimer;

  InterstitialManager(this._ref, this._adService, this._frequencyCap);

  void setActiveScreen(String screen) {
    _activeScreen = screen.toLowerCase();
    _cancelPendingInterstitial();
  }

  void setModalOrSheetOpen(bool isOpen) {
    _isModalOrSheetOpen = isOpen;
    if (isOpen) {
      _cancelPendingInterstitial();
    }
  }

  void _cancelPendingInterstitial() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  /// Called whenever a download successfully finishes.
  Future<void> onDownloadCompleted(BuildContext context) async {
    // 1. Record download count
    await _frequencyCap.recordDownloadCompleted();

    final adsEnabled = _ref.read(adsEnabledProvider);
    if (!adsEnabled) return;

    // 2. Initial eligibility check
    if (!_isSafeScreen() || _isModalOrSheetOpen) {
      return;
    }

    if (!_frequencyCap.canShowInterstitial()) {
      return;
    }

    // 3. User idle delay (2 seconds without navigation or modal opening)
    _cancelPendingInterstitial();
    _idleTimer = Timer(const Duration(milliseconds: 2000), () async {
      if (!context.mounted) return;
      if (!_isSafeScreen() || _isModalOrSheetOpen) return;
      final stillAdsEnabled = _ref.read(adsEnabledProvider);
      if (!stillAdsEnabled) return;

      // 4. Show soft pre-notice chip for 1 second
      final confirmed = await _showSoftPreNotice(context);
      if (!confirmed || !context.mounted) return;

      // 5. Present ad
      await _adService.showInterstitialIfEligible(context: context);
    });
  }

  bool _isSafeScreen() {
    return _activeScreen == 'home' || _activeScreen == 'library';
  }

  /// Displays an unobtrusive 1-second pre-notice chip informing the user of a brief break.
  Future<bool> _showSoftPreNotice(BuildContext context) async {
    OverlayEntry? entry;
    final completer = Completer<bool>();

    try {
      final overlay = Overlay.of(context);
      final colors = AppColors.of(context);
      entry = OverlayEntry(
        builder: (ctx) => Positioned(
          bottom: 100,
          left: 24,
          right: 24,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.coffee_rounded,
                      size: 16,
                      color: colors.accent,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'A short break, then back to your files',
                        style: AppTypography.caption(context).copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      overlay.insert(entry);

      // Wait 1 second before resolving
      await Future.delayed(const Duration(milliseconds: 1000));
      completer.complete(true);
    } catch (_) {
      completer.complete(false);
    } finally {
      entry?.remove();
    }

    return completer.future;
  }
}
