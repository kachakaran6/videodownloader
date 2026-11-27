import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage/preferences_service.dart';
import 'ad_config.dart';

final frequencyCapServiceProvider = Provider<FrequencyCapService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FrequencyCapService(prefs);
});

/// Manages all frequency counters, cooldown timers, install age,
/// and session counts locally and privately.
class FrequencyCapService {
  final SharedPreferences _prefs;

  FrequencyCapService(this._prefs);

  static const String _keyInstallTime = 'ad_freq_install_time';
  static const String _keySessionCount = 'ad_freq_session_count';
  static const String _keyCompletedDownloads = 'ad_freq_completed_downloads';
  static const String _keyLastInterstitialTime = 'ad_freq_last_interstitial_time';
  static const String _keyInterstitialDate = 'ad_freq_interstitial_date';
  static const String _keyInterstitialDailyCount = 'ad_freq_interstitial_daily_count';
  static const String _keyRewardedDate = 'ad_freq_rewarded_date';
  static const String _keyRewardedDailyCount = 'ad_freq_rewarded_daily_count';
  static const String _keyZenBoostExpiry = 'ad_freq_zen_boost_expiry';
  static const String _keyLastSeenWallClock = 'ad_freq_last_seen_wall_clock';
  static const String _keyPriorityQueueDownloads = 'ad_freq_priority_queue_downloads';
  static const String _keyTestBypassCooldowns = 'ad_test_bypass_cooldowns';

  bool get isTestBypassEnabled => _prefs.getBool(_keyTestBypassCooldowns) ?? false;

  Future<void> setTestBypassEnabled(bool enabled) async {
    await _prefs.setBool(_keyTestBypassCooldowns, enabled);
  }

  Future<void> resetTestingCounters() async {
    await _prefs.remove(_keyLastInterstitialTime);
    await _prefs.remove(_keyInterstitialDailyCount);
    await _prefs.remove(_keyRewardedDailyCount);
    await _prefs.setInt(_keySessionCount, 5);
    await _prefs.setInt(_keyCompletedDownloads, 3);
  }

  // ─── Initializer & Session Tracker ────────────────────────────────────────

  /// Record session startup, update install time if first launch, and check clock health.
  Future<void> recordAppLaunch() async {
    final now = DateTime.now();

    // 1. Install time
    if (!_prefs.containsKey(_keyInstallTime)) {
      await _prefs.setString(_keyInstallTime, now.toIso8601String());
    }

    // 2. Increment session count
    final sessions = (_prefs.getInt(_keySessionCount) ?? 0) + 1;
    await _prefs.setInt(_keySessionCount, sessions);

    // 3. Update last seen wall clock
    await updateLastSeenTime(now);
  }

  /// Store current wall clock to detect user clock manipulation.
  Future<void> updateLastSeenTime([DateTime? time]) async {
    final current = time ?? DateTime.now();
    await _prefs.setString(_keyLastSeenWallClock, current.toIso8601String());
  }

  /// Checks if device clock was rolled back earlier than last recorded timestamp.
  bool isClockTampered() {
    final lastSeenStr = _prefs.getString(_keyLastSeenWallClock);
    if (lastSeenStr == null) return false;
    final lastSeen = DateTime.tryParse(lastSeenStr);
    if (lastSeen == null) return false;

    final now = DateTime.now();
    // Allow up to 2 minutes clock skew before flagging tampering
    if (now.isBefore(lastSeen.subtract(const Duration(minutes: 2)))) {
      return true;
    }
    return false;
  }

  // ─── Session & Install Queries ────────────────────────────────────────────

  DateTime get installTime {
    final str = _prefs.getString(_keyInstallTime);
    if (str == null) return DateTime.now();
    return DateTime.tryParse(str) ?? DateTime.now();
  }

  int get sessionCount => _prefs.getInt(_keySessionCount) ?? 1;

  int get completedDownloadsCount => _prefs.getInt(_keyCompletedDownloads) ?? 0;

  Future<void> recordDownloadCompleted() async {
    final count = completedDownloadsCount + 1;
    await _prefs.setInt(_keyCompletedDownloads, count);
  }

  // ─── Interstitial Frequency Enforcement ───────────────────────────────────

  /// Verifies whether an interstitial is allowed right now based on all hard rules:
  /// 1. Not in first 24 hours of install (interstitialInstallCooldown)
  /// 2. Not in first 3 sessions (interstitialMinSessions)
  /// 3. Minimum 8 minutes since last interstitial (interstitialCooldown)
  /// 4. Maximum 3 interstitials per day (interstitialDailyCap)
  /// 5. Download count must be a multiple of 3 (interstitialDownloadFrequency)
  bool canShowInterstitial({bool bypassCooldowns = false}) {
    if (bypassCooldowns || isTestBypassEnabled) {
      return true;
    }

    final now = DateTime.now();

    // Rule 1: Install age >= 24h
    if (now.difference(installTime) < AdConfig.interstitialInstallCooldown) {
      return false;
    }

    // Rule 2: Session count >= 3
    if (sessionCount < AdConfig.interstitialMinSessions) {
      return false;
    }

    // Rule 3: Must be at least 3 completed downloads and hit download step
    if (completedDownloadsCount < AdConfig.interstitialDownloadFrequency) {
      return false;
    }
    if (completedDownloadsCount % AdConfig.interstitialDownloadFrequency != 0) {
      return false;
    }

    // Rule 4: Minimum 8 minutes cooldown
    final lastTimeStr = _prefs.getString(_keyLastInterstitialTime);
    if (lastTimeStr != null) {
      final lastTime = DateTime.tryParse(lastTimeStr);
      if (lastTime != null &&
          now.difference(lastTime) < AdConfig.interstitialCooldown) {
        return false;
      }
    }

    // Rule 5: Daily cap (max 3/day)
    final todayStr = _todayKey(now);
    final savedDate = _prefs.getString(_keyInterstitialDate);
    final dailyCount = (savedDate == todayStr)
        ? (_prefs.getInt(_keyInterstitialDailyCount) ?? 0)
        : 0;

    if (dailyCount >= AdConfig.interstitialDailyCap) {
      return false;
    }

    return true;
  }

  /// Record that an interstitial was displayed.
  Future<void> recordInterstitialShown() async {
    final now = DateTime.now();
    await _prefs.setString(_keyLastInterstitialTime, now.toIso8601String());

    final todayStr = _todayKey(now);
    final savedDate = _prefs.getString(_keyInterstitialDate);
    final dailyCount = (savedDate == todayStr)
        ? (_prefs.getInt(_keyInterstitialDailyCount) ?? 0) + 1
        : 1;

    await _prefs.setString(_keyInterstitialDate, todayStr);
    await _prefs.setInt(_keyInterstitialDailyCount, dailyCount);
    await updateLastSeenTime(now);
  }

  // ─── Rewarded "Zen Boost" Frequency Enforcement ────────────────────────────

  /// Remaining rewarded ads allowed today (capped at 3/day).
  int get remainingRewardedToday {
    final now = DateTime.now();
    final todayStr = _todayKey(now);
    final savedDate = _prefs.getString(_keyRewardedDate);
    final dailyCount = (savedDate == todayStr)
        ? (_prefs.getInt(_keyRewardedDailyCount) ?? 0)
        : 0;
    return max(0, AdConfig.rewardedDailyCap - dailyCount);
  }

  bool canWatchRewarded() => remainingRewardedToday > 0;

  /// Record a watched rewarded ad.
  Future<void> recordRewardedWatched() async {
    final now = DateTime.now();
    final todayStr = _todayKey(now);
    final savedDate = _prefs.getString(_keyRewardedDate);
    final dailyCount = (savedDate == todayStr)
        ? (_prefs.getInt(_keyRewardedDailyCount) ?? 0) + 1
        : 1;

    await _prefs.setString(_keyRewardedDate, todayStr);
    await _prefs.setInt(_keyRewardedDailyCount, dailyCount);
    await updateLastSeenTime(now);
  }

  // ─── Zen Boost Expiry Management ──────────────────────────────────────────

  /// Expiry timestamp for Zen Boost ad-free period.
  DateTime? get zenBoostExpiry {
    final str = _prefs.getString(_keyZenBoostExpiry);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  /// Whether Zen Boost is currently active.
  bool get isZenBoostActive {
    if (isClockTampered()) return false;
    final expiry = zenBoostExpiry;
    if (expiry == null) return false;
    return DateTime.now().isBefore(expiry);
  }

  /// Remaining duration of Zen Boost.
  Duration get zenBoostRemaining {
    final expiry = zenBoostExpiry;
    if (expiry == null) return Duration.zero;
    final diff = expiry.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Grants 2 hours of ad-free time, stacking up to a maximum of 6 hours total.
  Future<DateTime> grantZenBoostReward() async {
    final now = DateTime.now();
    DateTime currentExpiry = zenBoostExpiry ?? now;
    if (currentExpiry.isBefore(now)) {
      currentExpiry = now;
    }

    // Add 2 hours, cap at now + 6 hours
    DateTime newExpiry = currentExpiry.add(AdConfig.zenBoostAdFreeDuration);
    final maxAllowed = now.add(AdConfig.zenBoostMaxStackDuration);
    if (newExpiry.isAfter(maxAllowed)) {
      newExpiry = maxAllowed;
    }

    await _prefs.setString(_keyZenBoostExpiry, newExpiry.toIso8601String());
    await recordRewardedWatched();
    return newExpiry;
  }

  // ─── Priority Queue Downloads ─────────────────────────────────────────────

  int get priorityDownloadsRemaining =>
      _prefs.getInt(_keyPriorityQueueDownloads) ?? 0;

  Future<void> grantPriorityDownloadsReward([int count = 3]) async {
    final current = priorityDownloadsRemaining;
    await _prefs.setInt(_keyPriorityQueueDownloads, current + count);
    await recordRewardedWatched();
  }

  Future<void> consumePriorityDownload() async {
    final current = priorityDownloadsRemaining;
    if (current > 0) {
      await _prefs.setInt(_keyPriorityQueueDownloads, current - 1);
    }
  }

  // ─── Helper ───────────────────────────────────────────────────────────────

  String _todayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
