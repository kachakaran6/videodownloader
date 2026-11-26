import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'frequency_cap.dart';
import 'promo_code_service.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );
});

final promoCodeServiceProvider = Provider<PromoCodeService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return PromoCodeService(storage);
});

// ─── Promo State Controller ─────────────────────────────────────────────────

class PromoStateNotifier extends Notifier<PromoState> {
  late final PromoCodeService _service;

  @override
  PromoState build() {
    _service = ref.watch(promoCodeServiceProvider);
    _init();
    return const PromoState.initial();
  }

  Future<void> _init() async {
    state = await _service.checkPromoState();
  }

  Future<PromoApplyResult> applyCode(String code) async {
    final result = await _service.applyCode(code);
    state = await _service.checkPromoState();
    return result;
  }

  Future<void> removePromo() async {
    await _service.removeCode();
    state = await _service.checkPromoState();
  }

  Future<void> dismissExpiredNotification() async {
    await _service.dismissExpiredNotice();
    state = await _service.checkPromoState();
  }

  Future<void> refresh() async {
    state = await _service.checkPromoState();
  }
}

final promoStateProvider =
    NotifierProvider<PromoStateNotifier, PromoState>(PromoStateNotifier.new);

// ─── Zen Boost Controller ───────────────────────────────────────────────────

class ZenBoostState {
  final bool isActive;
  final Duration remaining;
  final DateTime? expiresAt;
  final int priorityDownloadsRemaining;

  const ZenBoostState({
    required this.isActive,
    required this.remaining,
    this.expiresAt,
    this.priorityDownloadsRemaining = 0,
  });

  const ZenBoostState.inactive()
      : isActive = false,
        remaining = Duration.zero,
        expiresAt = null,
        priorityDownloadsRemaining = 0;
}

class ZenBoostNotifier extends Notifier<ZenBoostState> {
  late final FrequencyCapService _frequencyCap;
  Timer? _ticker;

  @override
  ZenBoostState build() {
    _frequencyCap = ref.watch(frequencyCapServiceProvider);
    ref.onDispose(() {
      _ticker?.cancel();
    });

    final active = _frequencyCap.isZenBoostActive;
    final remaining = _frequencyCap.zenBoostRemaining;
    final expiry = _frequencyCap.zenBoostExpiry;
    final priority = _frequencyCap.priorityDownloadsRemaining;

    if (active) {
      _startTicker();
    }

    return ZenBoostState(
      isActive: active,
      remaining: remaining,
      expiresAt: expiry,
      priorityDownloadsRemaining: priority,
    );
  }

  void refresh() {
    final active = _frequencyCap.isZenBoostActive;
    final remaining = _frequencyCap.zenBoostRemaining;
    final expiry = _frequencyCap.zenBoostExpiry;
    final priority = _frequencyCap.priorityDownloadsRemaining;

    state = ZenBoostState(
      isActive: active,
      remaining: remaining,
      expiresAt: expiry,
      priorityDownloadsRemaining: priority,
    );

    if (active && (_ticker == null || !_ticker!.isActive)) {
      _startTicker();
    } else if (!active && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _frequencyCap.zenBoostRemaining;
      if (remaining <= Duration.zero) {
        timer.cancel();
        _ticker = null;
        state = ZenBoostState(
          isActive: false,
          remaining: Duration.zero,
          expiresAt: null,
          priorityDownloadsRemaining: _frequencyCap.priorityDownloadsRemaining,
        );
      } else {
        state = ZenBoostState(
          isActive: true,
          remaining: remaining,
          expiresAt: _frequencyCap.zenBoostExpiry,
          priorityDownloadsRemaining: _frequencyCap.priorityDownloadsRemaining,
        );
      }
    });
  }

  Future<void> grantZenBoost() async {
    await _frequencyCap.grantZenBoostReward();
    refresh();
  }

  Future<void> grantPriorityQueue() async {
    await _frequencyCap.grantPriorityDownloadsReward(3);
    refresh();
  }

  Future<void> consumePriorityDownload() async {
    await _frequencyCap.consumePriorityDownload();
    refresh();
  }
}

final zenBoostProvider =
    NotifierProvider<ZenBoostNotifier, ZenBoostState>(ZenBoostNotifier.new);

// ─── Single Unified Gate Provider ───────────────────────────────────────────

/// Master provider that controls whether ads are enabled anywhere in the app.
/// Returns false if either Promo Code is active OR Zen Boost is active.
/// When false:
/// - Ads are completely disabled
/// - AdMob requests are blocked
/// - Ad slots collapse to SizedBox.shrink()
/// - Consent dialogs are suppressed
/// - Loaded ads in memory are released
final adsEnabledProvider = Provider<bool>((ref) {
  final promo = ref.watch(promoStateProvider);
  final zen = ref.watch(zenBoostProvider);

  if (promo.isUnlocked) return false;
  if (zen.isActive) return false;

  return true;
});
