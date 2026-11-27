import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'core/ads/ad_service.dart';
import 'core/storage/preferences_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  // Initialize Mobile Ads SDK safely before widget tree mounts
  try {
    await MobileAds.instance.initialize();
    AdService.instance.markSdkInitialized();
  } catch (e) {
    debugPrint('[Main] MobileAds.initialize error: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MediaSaverApp(),
    ),
  );
}
