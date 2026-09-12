/// Global Application Configuration
///
/// Controls environment-specific capabilities, compliance flags,
/// and metadata across development, distribution, and Google Play Store builds.
class AppConfig {
  AppConfig._();

  /// Flag indicating whether the application is compiled for Google Play Store release.
  ///
  /// Can be toggled at compile-time via:
  /// `--dart-define=PLAY_STORE_BUILD=true`
  ///
  /// When `true`:
  /// - YouTube stream extraction and downloading are strictly disabled.
  /// - The YouTube browser tab is removed or replaced with a compliant guide.
  /// - Spotify YouTube-proxy extraction is disabled.
  /// - Marketing and UI copy avoids any prohibited terms.
  static const bool isPlayStoreBuild = bool.fromEnvironment(
    'PLAY_STORE_BUILD',
    defaultValue: false,
  );

  /// Current legal & acceptable use policy version.
  /// Whenever significant policy updates occur, increment this version
  /// to request renewed user confirmation.
  static const String policyVersion = '1.0.0';

  /// Compliant application display name.
  static String get appName =>
      isPlayStoreBuild ? 'Media Saver Pro' : 'Media Downloader & Saver';

  /// Contact email for copyright inquiries and DMCA/takedown notices.
  static const String copyrightContactEmail = 'legal@mediasaver.app';

  /// Official Play Store listing URL / support URL.
  static const String privacyPolicyUrl =
      'https://mediasaver.app/privacy-policy';
  static const String termsOfServiceUrl =
      'https://mediasaver.app/terms-of-service';
}
