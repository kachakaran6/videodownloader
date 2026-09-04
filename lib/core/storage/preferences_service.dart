import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in main()');
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesService(prefs);
});

class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static const _keyDisclaimer = 'legal_disclaimer_accepted';
  static const _keyPreferredQuality = 'preferred_quality';
  static const _keyWifiOnly = 'wifi_only_download';

  bool get hasAcceptedDisclaimer => _prefs.getBool(_keyDisclaimer) ?? false;

  Future<void> setAcceptedDisclaimer(bool value) async {
    await _prefs.setBool(_keyDisclaimer, value);
  }

  String get preferredQuality => _prefs.getString(_keyPreferredQuality) ?? '720p';

  Future<void> setPreferredQuality(String quality) async {
    await _prefs.setString(_keyPreferredQuality, quality);
  }

  bool get wifiOnly => _prefs.getBool(_keyWifiOnly) ?? false;

  Future<void> setWifiOnly(bool value) async {
    await _prefs.setBool(_keyWifiOnly, value);
  }
}
