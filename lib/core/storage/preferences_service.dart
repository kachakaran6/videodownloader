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
  static const _keyPolicyAccepted = 'compliance_policy_accepted';
  static const _keyPolicyAcceptedTimestamp = 'compliance_policy_accepted_timestamp';
  static const _keyPolicyAcceptedVersion = 'compliance_policy_accepted_version';
  static const _keyLastAuthType = 'compliance_last_auth_type';
  static const _keyPreferredQuality = 'preferred_quality';
  static const _keyWifiOnly = 'wifi_only_download';

  static const _keyThemeMode = 'app_theme_mode';

  bool get hasAcceptedDisclaimer => _prefs.getBool(_keyDisclaimer) ?? false;

  Future<void> setAcceptedDisclaimer(bool value) async {
    await _prefs.setBool(_keyDisclaimer, value);
  }

  /// Whether the user has explicitly accepted the Copyright & Policy agreement.
  bool get hasAcceptedPolicy => _prefs.getBool(_keyPolicyAccepted) ?? false;

  /// The timestamp when the user accepted the compliance policy.
  DateTime? get policyAcceptedTimestamp {
    final str = _prefs.getString(_keyPolicyAcceptedTimestamp);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  /// The version of the policy accepted by the user.
  String? get policyAcceptedVersion =>
      _prefs.getString(_keyPolicyAcceptedVersion);

  /// Save user acceptance of the compliance policy with timestamp and version.
  Future<void> recordPolicyAcceptance({required String version}) async {
    await _prefs.setBool(_keyPolicyAccepted, true);
    await _prefs.setString(
      _keyPolicyAcceptedTimestamp,
      DateTime.now().toIso8601String(),
    );
    await _prefs.setString(_keyPolicyAcceptedVersion, version);
  }

  /// Last selected authorization type (e.g. 'owner', 'licensee').
  String? get lastAuthorizationType => _prefs.getString(_keyLastAuthType);

  Future<void> setLastAuthorizationType(String authType) async {
    await _prefs.setString(_keyLastAuthType, authType);
  }

  /// Helper methods for audit and complaints logs
  List<String>? getStringList(String key) => _prefs.getStringList(key);

  Future<bool> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  Future<bool> removeKey(String key) => _prefs.remove(key);

  String get preferredQuality => _prefs.getString(_keyPreferredQuality) ?? '720p';

  Future<void> setPreferredQuality(String quality) async {
    await _prefs.setString(_keyPreferredQuality, quality);
  }

  bool get wifiOnly => _prefs.getBool(_keyWifiOnly) ?? false;

  Future<void> setWifiOnly(bool value) async {
    await _prefs.setBool(_keyWifiOnly, value);
  }

  String get themeModeString => _prefs.getString(_keyThemeMode) ?? 'dark';

  Future<void> setThemeModeString(String mode) async {
    await _prefs.setString(_keyThemeMode, mode);
  }
}
