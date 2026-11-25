import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/preferences_service.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static ThemeMode _parseMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  static String _modeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
      default:
        return 'dark';
    }
  }

  @override
  ThemeMode build() {
    final prefs = ref.watch(preferencesServiceProvider);
    return _parseMode(prefs.themeModeString);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final targetMode = (mode == ThemeMode.light) ? ThemeMode.light : ThemeMode.dark;
    state = targetMode;
    final prefs = ref.read(preferencesServiceProvider);
    await prefs.setThemeModeString(_modeToString(targetMode));
  }

  Future<void> toggleTheme() async {
    if (state == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// 5 Curated Professional Accent Color Themes supporting both Light & Dark modes
enum AppAccentTheme {
  lagoon('lagoon', 'Lagoon Teal', Color(0xFF0A6B6B), Color(0xFF3FD8C4)),
  sapphire('sapphire', 'Ocean Sapphire', Color(0xFF1565C0), Color(0xFF4DA3FF)),
  emerald('emerald', 'Luxe Emerald', Color(0xFF166534), Color(0xFF4ADE80)),
  rose('rose', 'Sunset Rose', Color(0xFFBE185D), Color(0xFFF472B6)),
  amethyst('amethyst', 'Royal Amethyst', Color(0xFF7E22CE), Color(0xFFC084FC));

  final String key;
  final String label;
  final Color lightColor;
  final Color darkColor;

  const AppAccentTheme(this.key, this.label, this.lightColor, this.darkColor);

  static AppAccentTheme fromKey(String? key) {
    return AppAccentTheme.values.firstWhere(
      (e) => e.key == key,
      orElse: () => AppAccentTheme.lagoon,
    );
  }
}

class AccentThemeNotifier extends Notifier<AppAccentTheme> {
  @override
  AppAccentTheme build() {
    final prefs = ref.watch(preferencesServiceProvider);
    return AppAccentTheme.fromKey(prefs.accentThemeName);
  }

  Future<void> setAccentTheme(AppAccentTheme theme) async {
    state = theme;
    final prefs = ref.read(preferencesServiceProvider);
    await prefs.setAccentThemeName(theme.key);
  }
}

final accentThemeProvider =
    NotifierProvider<AccentThemeNotifier, AppAccentTheme>(AccentThemeNotifier.new);
