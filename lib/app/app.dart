import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../core/storage/preferences_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../features/inspect/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';

class MediaSaverApp extends ConsumerWidget {
  const MediaSaverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isOnboardingDone = ref.watch(preferencesServiceProvider).isOnboardingDone;

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      home: isOnboardingDone ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
