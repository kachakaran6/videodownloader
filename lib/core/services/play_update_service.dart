import 'dart:async';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

/// Resolved application package metadata.
class PackageMetadata {
  final String packageName;
  final String appName;
  final String versionName;
  final int versionCode;

  const PackageMetadata({
    required this.packageName,
    required this.appName,
    required this.versionName,
    required this.versionCode,
  });

  String get formattedVersion => 'Version $versionName (Build $versionCode)';
}

/// Service interfacing with Google Play Core native APIs, platform intents,
/// and the Samyukt mobile ecosystem standard.
class PlayUpdateService {
  static const MethodChannel _channel = MethodChannel('app.mediaurl.applicaiton/playcore');

  static PackageMetadata? _cachedMetadata;

  /// Queries Google Play Store for available native in-app updates.
  /// If an update is available on Google Play, the native Play Store update flow
  /// (immediate or flexible based on priority or flag) is launched by Android's native AppUpdateManager.
  static Future<bool> checkForUpdate({bool immediate = false}) async {
    try {
      final isAvailable = await _channel.invokeMethod<bool>('checkForUpdate', {'immediate': immediate});
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
  /// Respects the minimum 15-day cooldown and session gating.
  static Future<void> tryRequestReview({bool force = false}) async {
    try {
      await _channel.invokeMethod('tryRequestReview', {'force': force});
    } catch (_) {}
  }

  /// Retrieves real installed application metadata dynamically via Android PackageManager.
  static Future<PackageMetadata> getAppInfo() async {
    if (_cachedMetadata != null) return _cachedMetadata!;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getAppInfo');
      if (res != null) {
        _cachedMetadata = PackageMetadata(
          packageName: res['packageName']?.toString() ?? 'app.mediaurl.applicaiton',
          appName: res['appName']?.toString() ?? AppConfig.appName,
          versionName: res['versionName']?.toString() ?? '1.0.4',
          versionCode: (res['versionCode'] as num?)?.toInt() ?? 27,
        );
        return _cachedMetadata!;
      }
    } catch (_) {}

    // Fallback if platform query fails
    return const PackageMetadata(
      packageName: 'app.mediaurl.applicaiton',
      appName: AppConfig.appName,
      versionName: '1.0.4',
      versionCode: 27,
    );
  }

  /// Opens the official Google Play listing for the given [packageName]
  /// (or current app if omitted) using market:// intent with browser fallback.
  static Future<bool> openPlayStoreListing({String? packageName}) async {
    try {
      final targetPackage = packageName ?? (await getAppInfo()).packageName;
      final marketUri = Uri.parse('market://details?id=$targetPackage');
      final webUri = Uri.parse('https://play.google.com/store/apps/details?id=$targetPackage');

      if (await canLaunchUrl(marketUri)) {
        return await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      }
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Opens an external URL via Android browser Intent.
  static Future<bool> openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Shares the application using the native Android Sharesheet with standard Samyukt ecosystem copy.
  static Future<void> shareCurrentApp({
    String? customName,
    String? customDescription,
  }) async {
    final info = await getAppInfo();
    final name = customName ?? AppConfig.appName;
    final description = customDescription ?? AppConfig.appTagline;
    final playStoreUrl = 'https://play.google.com/store/apps/details?id=${info.packageName}';

    final message = '''Discover $name — $description.

Explore the app and try it today:
$playStoreUrl

Made with care by Samyukt.''';

    await SharePlus.instance.share(
      ShareParams(
        text: message.trim(),
        subject: 'Discover $name',
      ),
    );
  }
}
