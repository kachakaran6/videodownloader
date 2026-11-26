import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/ads/ad_gate.dart';
import '../core/ads/ad_service.dart';
import '../core/ads/frequency_cap.dart';
import '../core/config/app_config.dart';
import '../core/storage/preferences_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../features/inspect/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class MediaSaverApp extends ConsumerStatefulWidget {
  const MediaSaverApp({super.key});

  @override
  ConsumerState<MediaSaverApp> createState() => _MediaSaverAppState();
}

class _MediaSaverAppState extends ConsumerState<MediaSaverApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Record launch and initialize frequency cap & clock health
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final freqCap = ref.read(frequencyCapServiceProvider);
      await freqCap.recordAppLaunch();

      final prefs = ref.read(preferencesServiceProvider);
      if (prefs.isOnboardingDone && mounted) {
        final adService = ref.read(adServiceProvider);
        await adService.initializeConsentAndAds(context: context);
      }

      _checkExpiredPromoNotification();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-validate expiry and clock integrity on resume
      ref.read(promoStateProvider.notifier).refresh();
      ref.read(zenBoostProvider.notifier).refresh();
      ref.read(frequencyCapServiceProvider).updateLastSeenTime();

      _checkExpiredPromoNotification();
    }
  }

  void _checkExpiredPromoNotification() {
    final promo = ref.read(promoStateProvider);
    if (promo.hasExpiredNoticePending) {
      ref.read(promoStateProvider.notifier).dismissExpiredNotification();

      final navContext = navigatorKey.currentContext;
      if (navContext != null) {
        showDialog(
          context: navContext,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.hourglass_bottom_rounded, color: Colors.amber),
                SizedBox(width: 10),
                Text('Promo Pass Expired'),
              ],
            ),
            content: const Text(
              'Your ad-free promo pass has reached the end of its duration and expired. Advertising has resumed.\n\nYou can enter another code or activate Zen Boost at any time in Settings.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isOnboardingDone = ref.watch(preferencesServiceProvider).isOnboardingDone;

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      home: isOnboardingDone ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
