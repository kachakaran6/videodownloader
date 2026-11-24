import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../storage/preferences_service.dart';

final playReviewServiceProvider = Provider<PlayReviewService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PlayReviewService(prefs: prefs);
});

const String _kKeyLastReviewAttempt = 'play_review_last_attempt_ms';
const String _kKeyEngagementCounter = 'play_review_engagement_counter';
const int _kCooldownDays = 15;
const int _kRequiredEngagementCount = 2;

/// Service governing native Google Play In-App Reviews and Rate Now listing intents.
class PlayReviewService {
  final SharedPreferences prefs;
  final InAppReview _inAppReview;
  bool _sessionAttempted = false;

  PlayReviewService({
    required this.prefs,
    InAppReview? inAppReview,
  })  : _inAppReview = inAppReview ?? InAppReview.instance;

  /// Records a successful, meaningful user action (e.g. completed media download or save).
  /// Automatically checks if engagement threshold and cooldown conditions are satisfied.
  Future<void> recordEngagementAndConsiderReview() async {
    try {
      final currentCount = (prefs.getInt(_kKeyEngagementCounter) ?? 0) + 1;
      await prefs.setInt(_kKeyEngagementCounter, currentCount);

      if (currentCount >= _kRequiredEngagementCount) {
        await maybeRequestReview();
      }
    } catch (_) {}
  }

  /// Evaluates the 15-day cooldown and requests the native Google Play In-App Review flow if eligible.
  Future<bool> maybeRequestReview({bool ignorePlatformCheckForTesting = false}) async {
    if (!Platform.isAndroid && !ignorePlatformCheckForTesting) return false;
    if (_sessionAttempted) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final lastAttempt = prefs.getInt(_kKeyLastReviewAttempt) ?? 0;
    final elapsedMs = now - lastAttempt;
    final cooldownMs = _kCooldownDays * 24 * 60 * 60 * 1000;

    if (elapsedMs < cooldownMs) {
      debugPrint('[PlayReviewService] Cooldown active. Elapsed: ${elapsedMs ~/ 86400000} days / $_kCooldownDays days.');
      return false;
    }

    _sessionAttempted = true;
    await prefs.setInt(_kKeyLastReviewAttempt, now);

    try {
      final isAvailable = await _inAppReview.isAvailable();
      if (isAvailable) {
        debugPrint('[PlayReviewService] Requesting official Google Play in-app review...');
        await _inAppReview.requestReview();
        return true;
      }
    } catch (e) {
      debugPrint('[PlayReviewService] Review flow failed or unavailable: $e');
    }
    return false;
  }

  /// Explicit "Rate Now" action that opens the official Google Play listing in the Play Store app or browser.
  static Future<void> openStoreListing(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final packageName = packageInfo.packageName.trim();

      if (packageName.isEmpty) {
        throw Exception('Package name could not be resolved');
      }

      final marketUri = Uri.parse('market://details?id=$packageName');
      final webUri = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');

      bool launched = false;
      try {
        if (await canLaunchUrl(marketUri)) {
          launched = await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}

      if (!launched) {
        launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Play Store.')),
        );
      }
    } catch (e) {
      debugPrint('[PlayReviewService] Error opening store listing: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Play Store.')),
        );
      }
    }
  }
}
