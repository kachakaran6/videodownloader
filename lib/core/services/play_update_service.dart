import 'dart:async';
import 'package:flutter/services.dart';

/// Service interfacing with Google Play Core native in-app updates.
///
/// Uses the 100% native Google Play Store in-app update UI managed by
/// Android's AppUpdateManager. No custom or simulated Flutter bottom sheets.
class PlayUpdateService {
  static const MethodChannel _channel = MethodChannel('app.mediaurl.applicaiton/playcore');

  /// Queries Google Play Store for available native in-app updates.
  /// If an update is available on Google Play, the native Play Store bottom sheet
  /// is automatically launched by Android's native AppUpdateManager.
  static Future<bool> checkForUpdate() async {
    try {
      final isAvailable = await _channel.invokeMethod<bool>('checkForUpdate');
      return isAvailable ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Triggers completion/restart for a downloaded flexible update.
  static Future<bool> completeUpdate() async {
    try {
      final completed = await _channel.invokeMethod<bool>('completeUpdate');
      return completed ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Records a successful positive action towards the review eligibility threshold.
  static Future<void> recordSuccessfulAction() async {
    try {
      await _channel.invokeMethod('recordSuccessfulAction');
    } catch (_) {}
  }

  /// Attempts to trigger Google Play's native In-App Review bottom sheet.
  /// Triggered after genuine positive moments like a completed download.
  static Future<void> tryRequestReview({bool force = false}) async {
    try {
      await _channel.invokeMethod('tryRequestReview', {'force': force});
    } catch (_) {}
  }
}
