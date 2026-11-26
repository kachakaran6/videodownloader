import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_saver/core/ads/ad_config.dart';
import 'package:media_saver/core/ads/ad_gate.dart';
import 'package:media_saver/core/ads/frequency_cap.dart';
import 'package:media_saver/core/ads/promo_code_service.dart';
import 'package:media_saver/core/storage/preferences_service.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSecureStorage fakeStorage;
  late SharedPreferences prefs;
  late PromoCodeService promoService;
  late FrequencyCapService freqCapService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fakeStorage = FakeSecureStorage();
    promoService = PromoCodeService(fakeStorage);
    freqCapService = FrequencyCapService(prefs);
  });

  group('Promo Code Normalization & Offline Hashing', () {
    test('normalizes spaces, dashes, underscores, and lowercase correctly', () {
      expect(PromoCodeService.normalizeCode(' lifetime-premium '), 'LIFETIMEPREMIUM');
      expect(PromoCodeService.normalizeCode('zen_30_days'), 'ZEN30DAYS');
      expect(PromoCodeService.normalizeCode(' clip - 7 - days '), 'CLIP7DAYS');
    });

    test('hashes match preconfigured validPromoCodes in AdConfig', () {
      final lifetimeHash = PromoCodeService.hashPromoCode(
        PromoCodeService.normalizeCode('LIFETIME-PREMIUM'),
      );
      final days30Hash = PromoCodeService.hashPromoCode(
        PromoCodeService.normalizeCode('ZEN-30DAYS'),
      );
      final days7Hash = PromoCodeService.hashPromoCode(
        PromoCodeService.normalizeCode('CLIP-7DAYS'),
      );

      final validHashes = AdConfig.validPromoCodes.map((e) => e.sha256Hash).toList();

      expect(validHashes.contains(lifetimeHash), isTrue);
      expect(validHashes.contains(days30Hash), isTrue);
      expect(validHashes.contains(days7Hash), isTrue);
    });
  });

  group('Promo Code Lockout & Application', () {
    test('successfully activates lifetime promo pass', () async {
      final result = await promoService.applyCode(' lifetime-premium ');
      expect(result.status, PromoApplyStatus.success);
      expect(result.isLifetime, isTrue);

      final loadedState = await promoService.checkPromoState();
      expect(loadedState.isUnlocked, isTrue);
      expect(loadedState.isLifetime, isTrue);
    });

    test('locks out user after 5 wrong attempts for 5 minutes', () async {
      for (var i = 0; i < 4; i++) {
        final res = await promoService.applyCode('WRONG_CODE_$i');
        expect(res.status, PromoApplyStatus.invalidCode);
      }

      // 5th failed attempt triggers lockout
      final res5 = await promoService.applyCode('WRONG_CODE_5');
      expect(res5.status, PromoApplyStatus.lockedOut);

      final state = await promoService.checkPromoState();
      expect(state.isLockoutActive, isTrue);

      // Attempting valid code while locked out fails
      final lockedAttempt = await promoService.applyCode('LIFETIME-PREMIUM');
      expect(lockedAttempt.status, PromoApplyStatus.lockedOut);
    });
  });

  group('Clock Tampering & Expiry', () {
    test('clears promo and flags expired dialog when date passes expiration', () async {
      await promoService.applyCode('CLIP-7DAYS');
      final activeState = await promoService.checkPromoState();
      expect(activeState.isUnlocked, isTrue);

      // Artificially fast-forward expiration into the past
      await fakeStorage.write(
        key: 'cv_sec_promo_expiry',
        value: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      );

      final expiredState = await promoService.checkPromoState();
      expect(expiredState.isUnlocked, isFalse);
      expect(expiredState.hasExpiredNoticePending, isTrue);
    });
  });

  group('Frequency Capping Rules', () {
    test('blocks interstitial on fresh install within 24 hours', () async {
      await freqCapService.recordAppLaunch();
      // Fresh install time is now
      expect(freqCapService.canShowInterstitial(), isFalse);
    });

    test('enforces session count, download count step, and daily cap', () async {
      // Simulate app installed 2 days ago
      await prefs.setString(
        'ad_freq_install_time',
        DateTime.now().subtract(const Duration(hours: 48)).toIso8601String(),
      );

      // Sessions < 3 -> should fail
      await prefs.setInt('ad_freq_session_count', 2);
      expect(freqCapService.canShowInterstitial(), isFalse);

      // Sessions >= 3
      await prefs.setInt('ad_freq_session_count', 4);

      // Completed downloads not multiple of 3 -> should fail
      await prefs.setInt('ad_freq_completed_downloads', 2);
      expect(freqCapService.canShowInterstitial(), isFalse);

      // Completed downloads = 3 -> should pass
      await prefs.setInt('ad_freq_completed_downloads', 3);
      expect(freqCapService.canShowInterstitial(), isTrue);

      // Show interstitial, records last show timestamp
      await freqCapService.recordInterstitialShown();

      // Immediate second call blocked by 8-minute cooldown
      expect(freqCapService.canShowInterstitial(), isFalse);
    });

    test('rewarded ads cap at 3 per day and zen boost stacks up to 6 hours', () async {
      expect(freqCapService.remainingRewardedToday, 3);
      expect(freqCapService.isZenBoostActive, isFalse);

      // Grant first 2h
      final firstExpiry = await freqCapService.grantZenBoostReward();
      expect(freqCapService.isZenBoostActive, isTrue);
      expect(freqCapService.remainingRewardedToday, 2);

      // Grant second 2h (stacks to 4h)
      final secondExpiry = await freqCapService.grantZenBoostReward();
      expect(secondExpiry.isAfter(firstExpiry), isTrue);
      expect(freqCapService.remainingRewardedToday, 1);

      // Grant third 2h (stacks to 6h max)
      final thirdExpiry = await freqCapService.grantZenBoostReward();
      expect(thirdExpiry.isAfter(secondExpiry), isTrue);
      expect(freqCapService.remainingRewardedToday, 0);
      expect(freqCapService.canWatchRewarded(), isFalse);
    });
  });

  group('Master adsEnabledProvider Gating', () {
    test('evaluates true by default and false when promo or zen boost is active', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStorageProvider.overrideWithValue(fakeStorage),
        ],
      );

      // Initially enabled
      expect(container.read(adsEnabledProvider), isTrue);

      // Activate Zen Boost -> ads disabled
      await container.read(zenBoostProvider.notifier).grantZenBoost();
      expect(container.read(adsEnabledProvider), isFalse);

      // Clear Zen Boost, ads enabled again
      await prefs.remove('ad_freq_zen_boost_expiry');
      container.read(zenBoostProvider.notifier).refresh();
      expect(container.read(adsEnabledProvider), isTrue);

      // Apply Promo Code -> ads disabled
      await container.read(promoStateProvider.notifier).applyCode('LIFETIME-PREMIUM');
      expect(container.read(adsEnabledProvider), isFalse);
    });
  });
}
