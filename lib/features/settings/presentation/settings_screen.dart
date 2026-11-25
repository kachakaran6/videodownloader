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
    final accentTheme = ref.watch(accentThemeProvider);

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
                        child: Icon(Icons.palette_outlined, color: colors.primary, size: 20),
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
                              'Choose between System, Light, or Dark',
                              style: AppTypography.caption(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // System / Light / Dark segmented control
                  Container(
                    height: 42,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: AppRadii.r16,
                      border: Border.all(color: colors.outline),
                    ),
                    child: Row(
                      children: [
                        _buildThemeSegment(context, 'System', ThemeMode.system, themeMode),
                        _buildThemeSegment(context, 'Light', ThemeMode.light, themeMode),
                        _buildThemeSegment(context, 'Dark', ThemeMode.dark, themeMode),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Divider(color: colors.outline, height: 1),
                  const SizedBox(height: 14),

                  // 5 Curated Accent Palettes
                  _buildAccentColorSelector(context, accentTheme),

                  const SizedBox(height: 14),
                  Divider(color: colors.outline, height: 1),
                  const SizedBox(height: 10),

                  // Dynamic Accent Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dynamic Accent', style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w600)),
                            Text('Harmonize accent highlights with device wallpaper', style: AppTypography.caption(context).copyWith(fontSize: 11)),
                          ],
                        ),
                      ),
                      Switch(
                        value: prefs.dynamicAccent,
                        activeThumbColor: colors.accent,
                        onChanged: (val) {
                          prefs.setDynamicAccent(val);
                          setState(() {});
                        },
                      ),
                    ],
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
                  ),
                ],
              ),
            ),

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

  Widget _buildThemeSegment(BuildContext context, String label, ThemeMode mode, ThemeMode currentMode) {
    final colors = AppColors.of(context);
    final isSelected = currentMode == mode;

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(themeModeProvider.notifier).setThemeMode(mode);
        },
        borderRadius: AppRadii.r12,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : Colors.transparent,
            borderRadius: AppRadii.r12,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.caption(context).copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? colors.onPrimary : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccentColorSelector(BuildContext context, AppAccentTheme currentTheme) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Accent Palette',
              style: AppTypography.caption(context).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(
              currentTheme.label,
              style: AppTypography.caption(context).copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: AppAccentTheme.values.map((theme) {
            final isSelected = theme == currentTheme;
            final swatchColor = isDark ? theme.darkColor : theme.lightColor;

            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(accentThemeProvider.notifier).setAccentTheme(theme);
              },
              borderRadius: AppRadii.r16,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primaryContainer.withValues(alpha: 0.35)
                      : Colors.transparent,
                  borderRadius: AppRadii.r16,
                  border: Border.all(
                    color: isSelected ? swatchColor : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: swatchColor,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: swatchColor.withValues(alpha: 0.45),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      theme.label.split(' ').last,
                      style: AppTypography.overline(context).copyWith(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? colors.primary : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
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
}
