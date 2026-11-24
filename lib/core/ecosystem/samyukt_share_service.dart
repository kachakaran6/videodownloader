import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_config.dart';

/// Service managing native Android Sharesheet dissemination with dynamic ecosystem metadata.
class SamyuktShareService {
  /// Launches the native Android Sharesheet with dynamic application metadata and attribution.
  static Future<void> shareApplication(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final packageName = packageInfo.packageName.isNotEmpty
          ? packageInfo.packageName
          : 'app.mediaurl.applicaiton';

      final appName = AppConfig.appName;
      final tagline = AppConfig.appTagline;
      final storeUrl = 'https://play.google.com/store/apps/details?id=$packageName';

      final message = '''Discover $appName — $tagline.

Explore the app and try it today:
$storeUrl

Made with care by Samyukt.''';

      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'Discover $appName',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open share menu.')),
        );
      }
    }
  }
}
