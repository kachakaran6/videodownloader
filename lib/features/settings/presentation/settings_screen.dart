import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/ecosystem/our_apps/our_apps_screen.dart';
import '../../../core/ecosystem/play_review_service.dart';
import '../../../core/ecosystem/play_update_service.dart';
import '../../../core/ecosystem/samyukt_share_service.dart';
import '../../../core/services/play_update_service.dart' as legacy;
import '../../../core/storage/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../compliance/presentation/copyright_disclaimer_dialog.dart';
import '../../compliance/presentation/privacy_policy_screen.dart';
import '../../compliance/presentation/terms_and_conditions_screen.dart';
import '../../downloads/data/stream_downloader.dart';
import 'package:flutter/foundation.dart';
import '../../../core/ads/ad_gate.dart';
import '../../../core/ads/ad_service.dart';
import '../../../core/ads/frequency_cap.dart';
import '../../../core/ads/interstitial_manager.dart';
import 'promo_code_card.dart';

/// Settings Screen with Lagoon & Amber design system.
///
/// Features:
/// - Grouped cards: Appearance, Downloads, Storage, About and Legal
/// - Appearance: System / Light / Dark segmented selector, Dynamic Accent toggle
/// - Downloads: Default quality dropdown, Wi-Fi only switch, parallel downloads slider (1-5), Speed boost switch, auto-retry switch
/// - Storage: public folder path (/Download/ClipVault), cache size and clear cache button
/// - About and Legal: Copyright & Acceptable Use, Privacy, Terms, Version
/// - 100dp bottom padding
class SettingsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const SettingsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _storagePath = 'Loading...';
  int _cacheSizeBytes = 0;
  String _versionDisplay = 'Version 1.0.4 (Build 27)';
  int _debugPressCount = 0;
  bool _showDebugAdPanel = false;

  @override
  void initState() {
    super.initState();
    _loadStoragePath();
    _calculateCacheSize();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted && info.version.isNotEmpty) {
        setState(() {
          _versionDisplay = 'Version ${info.version} (Build ${info.buildNumber})';
        });
        return;
      }
    } catch (_) {}

    try {
      final meta = await legacy.PlayUpdateService.getAppInfo();
      if (mounted) {
        setState(() {
          _versionDisplay = meta.formattedVersion;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStoragePath() async {
    final custom = ref.read(preferencesServiceProvider).customDownloadDirectory;
    if (custom != null && custom.isNotEmpty) {
      if (mounted) setState(() => _storagePath = custom);
      return;
    }
    final path = await StreamDownloader.getSafeDownloadDirectory();
    if (mounted) {
      setState(() => _storagePath = path);
    }
  }

  Future<void> _calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int total = 0;
      if (tempDir.existsSync()) {
        final files = tempDir.listSync(recursive: true, followLinks: false);
        for (final f in files) {
          if (f is File) {
            total += f.lengthSync();
          }
        }
      }
      if (mounted) {
        setState(() => _cacheSizeBytes = total);
      }
    } catch (_) {}
  }

  Future<void> _clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final files = tempDir.listSync(recursive: true, followLinks: false);
        for (final f in files) {
          try {
            if (f is File) f.deleteSync();
          } catch (_) {}
        }
      }
      await _calculateCacheSize();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Temporary cache cleared cleanly.')),
        );
      }
    } catch (_) {}
  }

  Future<void> _confirmClearWatchData() async {
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.r20),
        title: Text(
          'Clear Watch Data?',
          style: AppTypography.subtitle(context).copyWith(
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          'This will clear all cookies and cached web files. You will be signed out of any active sessions in the Watch tab.',
          style: AppTypography.body(context).copyWith(
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadii.r12),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await InAppWebViewController.clearAllCache();
        await CookieManager.instance().deleteAllCookies();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Watch cookies and cache cleared successfully.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear watch data: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: colors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final prefs = ref.watch(preferencesServiceProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: Text('Settings', style: AppTypography.title(context)),
            ),
      body: SafeArea(
        top: !widget.isEmbedded,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            // ─── 0. Remove Ads Group ──────────────────────────────────────────
            _buildGroupHeader(context, 'REMOVE ADS'),
            const PromoCodeCard(),
            const SizedBox(height: 24),

            // ─── 1. Appearance Group ─────────────────────────────────────────
            _buildGroupHeader(context, 'APPEARANCE'),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: AppRadii.r12,
                        ),
                        child: Icon(
                          themeMode == ThemeMode.light
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: colors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Theme Mode',
                              style: AppTypography.subtitle(context).copyWith(fontSize: 15),
                            ),
                            Text(
                              'Switch between Light and Dark mode',
                              style: AppTypography.caption(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Light / Dark segmented control (System option removed)
                  Container(
                    height: 44,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: AppRadii.r16,
                      border: Border.all(color: colors.outline),
                    ),
                    child: Row(
                      children: [
                        _buildThemeSegment(
                          context,
                          'Light',
                          Icons.light_mode_rounded,
                          ThemeMode.light,
                          themeMode,
                        ),
                        _buildThemeSegment(
                          context,
                          'Dark',
                          Icons.dark_mode_rounded,
                          ThemeMode.dark,
                          themeMode,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── 2. Downloads Group ──────────────────────────────────────────
            _buildGroupHeader(context, 'DOWNLOADS'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSettingTile(
                    context: context,
                    icon: Icons.high_quality_outlined,
                    title: 'Default Quality',
                    subtitle: prefs.preferredQuality.toUpperCase(),
                    trailing: DropdownButton<String>(
                      value: prefs.preferredQuality,
                      underline: const SizedBox(),
                      dropdownColor: colors.surface,
                      items: const [
                        DropdownMenuItem(value: '1080p', child: Text('1080p Full HD')),
                        DropdownMenuItem(value: '720p', child: Text('720p HD')),
                        DropdownMenuItem(value: '480p', child: Text('480p Standard')),
                        DropdownMenuItem(value: '360p', child: Text('360p Data Saver')),
                        DropdownMenuItem(value: 'audio', child: Text('Audio Only')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          prefs.setPreferredQuality(val);
                          setState(() {});
                        }
                      },
                    ),
                  ),
                  Divider(color: colors.outline, height: 1),

                  _buildSettingTile(
                    context: context,
                    icon: Icons.bolt_rounded,
                    title: 'Speed Boost',
                    subtitle: 'Multi-connection segmented downloads',
                    trailing: Switch(
                      value: prefs.speedBoost,
                      activeThumbColor: colors.accent,
                      onChanged: (val) {
                        prefs.setSpeedBoost(val);
                        setState(() {});
                      },
                    ),
                  ),
                  Divider(color: colors.outline, height: 1),

                  _buildSettingTile(
                    context: context,
                    icon: Icons.wifi_outlined,
                    title: 'Download on Wi-Fi Only',
                    subtitle: 'Conserve mobile data allowance',
                    trailing: Switch(
                      value: prefs.wifiOnly,
                      activeThumbColor: colors.primary,
                      onChanged: (val) {
                        prefs.setWifiOnly(val);
                        setState(() {});
                      },
                    ),
                  ),
                  Divider(color: colors.outline, height: 1),

                  _buildSettingTile(
                    context: context,
                    icon: Icons.replay_rounded,
                    title: 'Auto-Retry',
                    subtitle: 'Exponential backoff on dropped network',
                    trailing: Switch(
                      value: prefs.autoRetry,
                      activeThumbColor: colors.primary,
                      onChanged: (val) {
                        prefs.setAutoRetry(val);
                        setState(() {});
                      },
                    ),
                  ),
                  Divider(color: colors.outline, height: 1),

                  // Parallel Downloads Slider (1-5)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Parallel Downloads', style: AppTypography.subtitle(context).copyWith(fontSize: 15)),
                            Text('${prefs.concurrentDownloads} concurrent', style: AppTypography.tabularFigures(context, color: colors.primary)),
                          ],
                        ),
                        Slider(
                          value: prefs.concurrentDownloads.toDouble(),
                          min: 1.0,
                          max: 5.0,
                          divisions: 4,
                          activeColor: colors.primary,
                          onChanged: (v) {
                            prefs.setConcurrentDownloads(v.toInt());
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  Divider(color: colors.outline, height: 1),

                  // Clear watch data (cookies and cache)
                  _buildSettingTile(
                    context: context,
                    icon: Icons.cleaning_services_outlined,
                    title: 'Clear watch data (cookies and cache)',
                    subtitle: 'Reset site sign-in, cached scripts, and cookies',
                    trailing: Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
                    onTap: _confirmClearWatchData,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── 3. Storage Group ────────────────────────────────────────────
            _buildGroupHeader(context, 'STORAGE'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSettingTile(
                    context: context,
                    icon: Icons.folder_open_rounded,
                    title: 'Download Location',
                    subtitle: _storagePath,
                    trailing: const Icon(Icons.folder_shared_outlined, size: 20),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Files are saved to your public device Downloads/ClipVault folder.'),
                        ),
                      );
                    },
                  ),
                  Divider(color: colors.outline, height: 1),

                  _buildSettingTile(
                    context: context,
                    icon: Icons.cleaning_services_outlined,
                    title: 'Temporary Cache',
                    subtitle: Formatters.formatBytes(_cacheSizeBytes),
                    trailing: OutlinedButton(
                      onPressed: _cacheSizeBytes > 0 ? _clearCache : null,
                      child: const Text('Clear'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── 4. Our Apps & More Group ────────────────────────────────────
            _buildGroupHeader(context, 'OUR APPS & MORE'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSettingTile(
                    context: context,
                    icon: Icons.system_update_rounded,
                    title: 'Check for Updates',
                    subtitle: 'Check for new releases via Google Play',
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => PlayUpdateService().checkForUpdateManual(context),
                  ),
                  Divider(color: colors.outline, height: 1),

                  _buildSettingTile(
                    context: context,
                    icon: Icons.star_rate_rounded,
                    title: 'Rate ${AppConfig.appName}',
                    subtitle: 'Share your feedback on the Google Play Store',
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => PlayReviewService.openStoreListing(context),
                  ),
                  Divider(color: colors.outline, height: 1),

                  _buildSettingTile(
                    context: context,
                    icon: Icons.share_rounded,
                    title: 'Share This App',
                    subtitle: 'Recommend ClipVault to friends and colleagues',
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => SamyuktShareService.shareApplication(context),
                  ),
                  Divider(color: colors.outline, height: 1),

                  _buildSettingTile(
                    context: context,
                    icon: Icons.apps_rounded,
                    title: 'Our Apps',
                    subtitle: 'Explore other apps and projects by Samyukt',
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OurAppsScreen()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── 5. About & Legal Group ──────────────────────────────────────
            _buildGroupHeader(context, 'ABOUT & LEGAL'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSettingTile(
                    context: context,
                    icon: Icons.copyright_rounded,
                    title: 'Copyright & Acceptable Use',
                    subtitle: 'Only save content you own or have permission to download',
                    onTap: () => CopyrightDisclaimerDialog.show(context),
                  ),
                  Divider(color: colors.outline, height: 1),

                  _buildSettingTile(
                    context: context,
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    subtitle: 'No data collection or third-party ad tracking',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                    ),
                  ),
                  Divider(color: colors.outline, height: 1),

                  _buildSettingTile(
                    context: context,
                    icon: Icons.shield_outlined,
                    title: 'Privacy choices',
                    subtitle: 'Review or update your advertising privacy choices',
                    onTap: () async {
                      final adService = ref.read(adServiceProvider);
                      final shown = await adService.showPrivacyOptionsForm(context);
                      if (!shown && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Privacy choices are not required for your region.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                  Divider(color: colors.outline, height: 1),

                  _buildSettingTile(
                    context: context,
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    subtitle: 'Terms governing lawful media saving',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TermsAndConditionsScreen()),
                    ),
                  ),
                  Divider(color: colors.outline, height: 1),

                  _buildSettingTile(
                    context: context,
                    icon: Icons.info_outline_rounded,
                    title: AppConfig.appName,
                    subtitle: _versionDisplay,
                    onLongPress: () {
                      if (!kDebugMode) return;
                      _debugPressCount++;
                      if (_debugPressCount >= 7) {
                        HapticFeedback.heavyImpact();
                        setState(() {
                          _showDebugAdPanel = !_showDebugAdPanel;
                          _debugPressCount = 0;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _showDebugAdPanel
                                  ? 'Developer Ad Panel Activated'
                                  : 'Developer Ad Panel Deactivated',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        HapticFeedback.selectionClick();
                      }
                    },
                  ),
                ],
              ),
            ),

            if (kDebugMode && _showDebugAdPanel) ...[
              const SizedBox(height: 16),
              _buildDeveloperAdPanel(context),
            ],

            const SizedBox(height: 32),

            // ─── Samyukt Attribution ─────────────────────────────────────────
            Center(
              child: InkWell(
                onTap: () => legacy.PlayUpdateService.openUrl('https://samyukt.pro'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Made with care by Samyukt',
                        style: AppTypography.caption(context).copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.open_in_new_rounded, size: 14, color: colors.primary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppTypography.overline(context),
      ),
    );
  }

  Widget _buildThemeSegment(
    BuildContext context,
    String label,
    IconData icon,
    ThemeMode mode,
    ThemeMode currentMode,
  ) {
    final colors = AppColors.of(context);
    final isSelected = currentMode == mode;

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(themeModeProvider.notifier).setThemeMode(mode);
        },
        borderRadius: AppRadii.r12,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : Colors.transparent,
            borderRadius: AppRadii.r12,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? colors.onPrimary : colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.caption(context).copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? colors.onPrimary : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: AppRadii.r12,
              ),
              child: Icon(icon, color: colors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.subtitle(context).copyWith(fontSize: 15),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(context),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeveloperAdPanel(BuildContext context) {
    final colors = AppColors.of(context);
    final adsEnabled = ref.watch(adsEnabledProvider);
    final promo = ref.watch(promoStateProvider);
    final zen = ref.watch(zenBoostProvider);
    final freqCap = ref.watch(frequencyCapServiceProvider);

    return AppCard(
      padding: const EdgeInsets.all(16),
      borderColor: Colors.amber,
      backgroundColor: colors.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Developer Ad & Monetization Panel',
                style: AppTypography.subtitle(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildDebugRow(context, 'Ads Master Gate:', adsEnabled ? 'ENABLED' : 'DISABLED',
              adsEnabled ? Colors.greenAccent : Colors.redAccent),
          _buildDebugRow(context, 'Promo Active:', promo.isUnlocked ? 'YES (${promo.label})' : 'NO'),
          if (promo.isUnlocked)
            _buildDebugRow(context, 'Promo Duration:', promo.statusDisplayLabel),
          _buildDebugRow(context, 'Zen Boost Active:', zen.isActive ? 'YES' : 'NO'),
          if (zen.isActive)
            _buildDebugRow(context, 'Zen Boost Remaining:', zen.remaining.toString().split('.').first),
          _buildDebugRow(context, 'Total Sessions:', '${freqCap.sessionCount}'),
          _buildDebugRow(context, 'Completed Downloads:', '${freqCap.completedDownloadsCount}'),
          _buildDebugRow(context, 'Can Show Interstitial:', freqCap.canShowInterstitial() ? 'YES' : 'NO'),
          _buildDebugRow(context, 'Rewarded Left Today:', '${freqCap.remainingRewardedToday}'),
          _buildDebugRow(context, 'Clock Tampered:', freqCap.isClockTampered() ? 'YES (Warning)' : 'NO (Healthy)'),
          const Divider(height: 20),
          Text(
            'Instant Verification Actions:',
            style: AppTypography.caption(context).copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Loading and presenting Interstitial Ad...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  final shown = await ref.read(interstitialManagerProvider).forceShowTestInterstitial(context);
                  if (!shown && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Interstitial is preloading in background, try once more in 2 seconds.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.fullscreen_rounded, size: 16),
                label: const Text('Test Interstitial'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(adServiceProvider).showRewardedZenBoost(
                    context: context,
                    onRewardGranted: () {
                      ref.read(zenBoostProvider.notifier).grantZenBoost();
                    },
                    onFailure: (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                      }
                    },
                  );
                },
                icon: const Icon(Icons.play_circle_filled_rounded, size: 16),
                label: const Text('Test Rewarded'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await freqCap.resetTestingCounters();
                  if (mounted) setState(() {});
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ad testing counters & session counts reset!')),
                    );
                  }
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset Cooldowns'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugRow(BuildContext context, String label, String value, [Color? valueColor]) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.caption(context).copyWith(color: colors.textSecondary)),
          Text(
            value,
            style: AppTypography.caption(context).copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
