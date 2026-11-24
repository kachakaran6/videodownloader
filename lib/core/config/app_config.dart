/// Global Application Configuration
///
/// Controls environment-specific capabilities, compliance flags,
/// and metadata across development, distribution, and Google Play Store builds.
class AppConfig {
  AppConfig._();

  // ─── Build Environment ─────────────────────────────────────────────────────

  /// Flag indicating whether the application is compiled for Google Play Store release.
  ///
  /// Can be toggled at compile-time via:
  /// `--dart-define=PLAY_STORE_BUILD=true`
  ///
  /// When `true`:
  /// - Video stream extraction and downloading from restricted sources are strictly disabled.
  /// - The browser tab displays a compliant guide.
  /// - Audio proxy extraction from restricted sources is disabled.
  /// - Marketing and UI copy strictly avoids prohibited third-party brand names.
  static const bool isPlayStoreBuild = bool.fromEnvironment(
    'PLAY_STORE_BUILD',
    defaultValue: false,
  );

  // ─── App Identity ──────────────────────────────────────────────────────────

  /// Canonical application name shown in UI headers and system dialogs.
  static const String appName = 'ClipVault';

  /// Application tagline shown on welcome/onboarding surfaces.
  static const String appTagline = 'Paste. Preview. Save.';

  /// Core promise of the application.
  static const String appPromise = 'A fast, private link-to-file saver for videos, clips, music, and statuses.';

  /// Neutral copyright and acceptable use statement.
  static const String copyrightNotice =
      'Only save content you own or have permission to download. You are responsible for how you use saved files.';

  /// Current legal & acceptable use policy version.
  static const String policyVersion = '1.1.0';

  // ─── Legal & Contact ───────────────────────────────────────────────────────

  /// Contact email for copyright inquiries and support.
  static const String copyrightContactEmail = 'support@clipvault.app';

  /// Official support URLs.
  static const String privacyPolicyUrl =
      'https://clipvault.app/privacy-policy';
  static const String termsOfServiceUrl =
      'https://clipvault.app/terms-of-service';
}
