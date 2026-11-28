import 'dart:io';
import 'package:flutter/services.dart';

/// Service managing the native Android Foreground Service, WakeLock, and
/// live download progress notifications.
class DownloadNotificationService {
  DownloadNotificationService._();

  static const MethodChannel _channel =
      MethodChannel('app.mediaurl.applicaiton/downloads');

  static int _lastUpdateMs = 0;

  /// Requests notification permission on Android 13+ (API 33+)
  static Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (_) {}
  }

  /// Starts the foreground service and shows ongoing notification
  static Future<void> start({
    required String title,
    required String subtitle,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startDownloadForeground', {
        'title': title,
        'subtitle': subtitle,
      });
    } catch (_) {}
  }

  /// Updates ongoing notification progress with throttling (max once per 300ms)
  static Future<void> updateProgress({
    required String title,
    required int progress,
    required String statusText,
    bool force = false,
  }) async {
    if (!Platform.isAndroid) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _lastUpdateMs < 300) {
      return;
    }
    _lastUpdateMs = now;

    try {
      await _channel.invokeMethod('updateDownloadProgress', {
        'title': title,
        'progress': progress.clamp(0, 100),
        'statusText': statusText,
      });
    } catch (_) {}
  }

  /// Marks download as completed and displays the tap-to-open completion notification
  static Future<void> complete({
    required String title,
    required String statusText,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('completeDownloadForeground', {
        'title': title,
        'statusText': statusText,
      });
    } catch (_) {}
  }

  /// Stops the foreground service and removes ongoing notification
  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopDownloadForeground');
    } catch (_) {}
  }
}
