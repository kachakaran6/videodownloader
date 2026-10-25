import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_card.dart';
import '../../downloads/data/stream_downloader.dart';
import '../../../core/services/play_update_service.dart';
import '../../../core/config/app_config.dart';
import '../../compliance/presentation/copyright_disclaimer_dialog.dart';
import '../../compliance/presentation/terms_and_conditions_screen.dart';
import '../../compliance/presentation/privacy_policy_screen.dart';
import '../../compliance/presentation/copyright_complaint_dialog.dart';
import '../../samyukt_ecosystem/presentation/our_apps_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const SettingsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _storagePath = 'Loading...';
  String _versionDisplay = 'Version 1.0.0 (Build 22)';

  @override
  void initState() {
    super.initState();
    _loadStoragePath();
    _loadAppInfo();
  }

  Future<void> _loadStoragePath() async {
    final path = await StreamDownloader.getSafeDownloadDirectory();
    if (mounted) {
      setState(() {
        _storagePath = path;
      });
    }
  }

  Future<void> _loadAppInfo() async {
    final info = await PlayUpdateService.getAppInfo();
    if (mounted) {
      setState(() {
        _versionDisplay = info.formattedVersion;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesServiceProvider);
    final currentThemeMode = ref.watch(themeModeProvider);

    final bodyContent = ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // ─── Section: Appearance ─────────────────────────────────────────
        _buildSectionHeader(context, 'APPEARANCE'),
        AppSpacing.gapSm,

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
                      color: AppColors.primaryContainer(context),
                      borderRadius: AppRadii.r8,
                    ),
                    child: Icon(Icons.palette_outlined, color: AppColors.primaryOf(context), size: 20),
                  ),
                  AppSpacing.gapMd,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme Mode',
                        style: AppTypography.cardTitle(context),
                      ),
                      Text(
                        'Choose your visual appearance',
                        style: AppTypography.supporting(context),
                      ),
                    ],
                  ),
                ],
              ),
              AppSpacing.gapLg,
              Row(
                children: [
                  Expanded(
                    child: _buildThemeModeOption(
                      context,
                      title: 'System',
                      icon: Icons.brightness_auto_rounded,
                      mode: ThemeMode.system,
                      selected: currentThemeMode == ThemeMode.system,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildThemeModeOption(
                      context,
                      title: 'Light',
                      icon: Icons.light_mode_rounded,
                      mode: ThemeMode.light,
                      selected: currentThemeMode == ThemeMode.light,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildThemeModeOption(
                      context,
                      title: 'Dark',
                      icon: Icons.dark_mode_rounded,
                      mode: ThemeMode.dark,
                      selected: currentThemeMode == ThemeMode.dark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        AppSpacing.gapXl,

        // ─── Section: Download Preferences ──────────────────────────────
        _buildSectionHeader(context, 'PREFERENCES'),
        AppSpacing.gapSm,

        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Preferred Quality
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer(context),
                    borderRadius: AppRadii.r8,
                  ),
                  child: Icon(Icons.high_quality_outlined, color: AppColors.primaryOf(context), size: 20),
                ),
                title: Text(
                  'Default Quality',
                  style: AppTypography.cardTitle(context),
                ),
                subtitle: Text(
                  prefs.preferredQuality.toUpperCase(),
                  style: AppTypography.supporting(context),
                ),
                trailing: DropdownButton<String>(
                  value: prefs.preferredQuality,
                  dropdownColor: AppColors.surface(context),
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: '720p', child: Text('720p HD')),
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
              Divider(color: AppColors.border(context), height: 1),

              // Wi-Fi Only
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer(context),
                    borderRadius: AppRadii.r8,
                  ),
                  child: Icon(Icons.wifi_outlined, color: AppColors.primaryOf(context), size: 20),
                ),
                title: Text(
                  'Download on Wi-Fi Only',
                  style: AppTypography.cardTitle(context),
                ),
                subtitle: Text(
                  'Conserve cellular data for downloads',
                  style: AppTypography.supporting(context),
                ),
                value: prefs.wifiOnly,
                activeTrackColor: AppColors.primaryOf(context),
                onChanged: (val) {
                  prefs.setWifiOnly(val);
                  setState(() {});
                },
              ),
            ],
          ),
        ),

        AppSpacing.gapXl,

        // ─── Section: Storage & Location ─────────────────────────────────
        _buildSectionHeader(context, 'STORAGE & LOCATION'),
        AppSpacing.gapSm,

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
                      color: AppColors.primaryContainer(context),
                      borderRadius: AppRadii.r8,
                    ),
                    child: Icon(Icons.folder_outlined, color: AppColors.primaryOf(context), size: 20),
                  ),
                  AppSpacing.gapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Download location',
                          style: AppTypography.cardTitle(context),
                        ),
                        Text(
                          'Internal storage / Download',
                          style: AppTypography.supporting(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AppSpacing.gapMd,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated(context),
                  borderRadius: AppRadii.r8,
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Text(
                  _storagePath,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
        ),

        AppSpacing.gapXl,

        // ─── Section: Legal & Policy Compliance ─────────────────────────
        _buildSectionHeader(context, 'LEGAL & POLICY COMPLIANCE'),
        AppSpacing.gapSm,

        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer(context),
                    borderRadius: AppRadii.r8,
                  ),
                  child: Icon(Icons.copyright_rounded, color: AppColors.primaryOf(context), size: 20),
                ),
                title: Text('Copyright & Acceptable Use', style: AppTypography.cardTitle(context)),
                subtitle: Text('Lawful use policy & source guidelines', style: AppTypography.supporting(context)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => CopyrightDisclaimerDialog.show(context),
              ),
              Divider(height: 1, color: AppColors.border(context)),

              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer(context),
                    borderRadius: AppRadii.r8,
                  ),
                  child: Icon(Icons.gavel_rounded, color: AppColors.primaryOf(context), size: 20),
                ),
                title: Text('Terms & Conditions', style: AppTypography.cardTitle(context)),
                subtitle: Text('User rights & copyright responsibilities', style: AppTypography.supporting(context)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsAndConditionsScreen()),
                  );
                },
              ),
              Divider(height: 1, color: AppColors.border(context)),

              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                    borderRadius: AppRadii.r8,
                  ),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFF0D9488), size: 20),
                ),
                title: Text('Privacy & Data Safety', style: AppTypography.cardTitle(context)),
                subtitle: Text('Google Play Data Safety disclosures', style: AppTypography.supporting(context)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                  );
                },
              ),
              Divider(height: 1, color: AppColors.border(context)),

              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: AppRadii.r8,
                  ),
                  child: const Icon(Icons.report_problem_outlined, color: AppColors.error, size: 20),
                ),
                title: Text('Report Copyright Issue', style: AppTypography.cardTitle(context)),
                subtitle: Text('Submit a takedown or rights inquiry', style: AppTypography.supporting(context)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => CopyrightComplaintDialog.show(context),
              ),
              Divider(height: 1, color: AppColors.border(context)),

              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (prefs.hasAcceptedPolicy ? AppColors.success : AppColors.warning)
                        .withValues(alpha: 0.12),
                    borderRadius: AppRadii.r8,
                  ),
                  child: Icon(
                    prefs.hasAcceptedPolicy
                        ? Icons.check_circle_outline_rounded
                        : Icons.pending_outlined,
                    color: prefs.hasAcceptedPolicy ? AppColors.success : AppColors.warning,
                    size: 20,
                  ),
                ),
                title: Text('Policy Agreement Status', style: AppTypography.cardTitle(context)),
                subtitle: Text(
                  prefs.hasAcceptedPolicy
                      ? 'Accepted (Policy v${prefs.policyAcceptedVersion ?? AppConfig.policyVersion})'
                      : 'Not yet confirmed (Required before download)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: prefs.hasAcceptedPolicy ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),

        AppSpacing.gapXl,

        // ─── Section: About & Ecosystem ──────────────────────────────────
        _buildSectionHeader(context, 'ABOUT & ECOSYSTEM'),
        AppSpacing.gapSm,

        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer(context),
                    borderRadius: AppRadii.r8,
                  ),
                  child: Icon(Icons.info_outline_rounded, color: AppColors.primaryOf(context), size: 20),
                ),
                title: Text(AppConfig.appName, style: AppTypography.cardTitle(context)),
                subtitle: Text(_versionDisplay, style: AppTypography.supporting(context)),
              ),
              Divider(height: 1, color: AppColors.border(context)),

              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: AppRadii.r8,
                  ),
                  child: const Icon(Icons.system_update_rounded, color: AppColors.success, size: 20),
                ),
                title: Text('Check for Updates', style: AppTypography.cardTitle(context)),
                subtitle: Text('Google Play In-App Updates', style: AppTypography.supporting(context)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text('Checking Google Play for updates...'),
                        ],
                      ),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  final hasUpdate = await PlayUpdateService.checkForUpdate();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();

                  if (!hasUpdate) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'App is up to date ($_versionDisplay)',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.r12),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
              Divider(height: 1, color: AppColors.border(context)),

              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: AppRadii.r8,
                  ),
                  child: const Icon(Icons.star_rate_rounded, color: Color(0xFFF59E0B), size: 20),
                ),
                title: Text('Rate Now', style: AppTypography.cardTitle(context)),
                subtitle: Text('Rate on Google Play Store', style: AppTypography.supporting(context)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => PlayUpdateService.openPlayStoreListing(),
              ),
              Divider(height: 1, color: AppColors.border(context)),

              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: AppRadii.r8,
                  ),
                  child: const Icon(Icons.share_rounded, color: Color(0xFF6366F1), size: 20),
                ),
                title: Text('Share This App', style: AppTypography.cardTitle(context)),
                subtitle: Text('Share with friends via Android Sharesheet', style: AppTypography.supporting(context)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => PlayUpdateService.shareCurrentApp(),
              ),
              Divider(height: 1, color: AppColors.border(context)),

              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer(context),
                    borderRadius: AppRadii.r8,
                  ),
                  child: Icon(Icons.apps_rounded, color: AppColors.primaryOf(context), size: 20),
                ),
                title: Text('Our Apps', style: AppTypography.cardTitle(context)),
                subtitle: Text('Explore apps in the Samyukt Ecosystem', style: AppTypography.supporting(context)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OurAppsScreen()),
                  );
                },
              ),
            ],
          ),
        ),

        AppSpacing.gapXl,

        // Standardized Samyukt Attribution
        Center(
          child: InkWell(
            onTap: () => PlayUpdateService.openUrl('https://samyukt.pro'),
            borderRadius: AppRadii.r8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    size: 14,
                    color: AppColors.primaryOf(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Made with care by Samyukt',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(context),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AppSpacing.gapSm,
      ],
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(
          'Settings',
          style: AppTypography.screenTitle(context),
        ),
      ),
      body: bodyContent,
    );
  }

  Widget _buildThemeModeOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required ThemeMode mode,
    required bool selected,
  }) {
    final isDark = AppColors.isDark(context);

    return InkWell(
      borderRadius: AppRadii.r8,
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryOf(context)
              : AppColors.surfaceElevated(context),
          borderRadius: AppRadii.r8,
          border: Border.all(
            color: selected ? AppColors.primaryOf(context) : AppColors.border(context),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? (isDark ? const Color(0xFF1C1A22) : Colors.white)
                  : AppColors.textSecondary(context),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? (isDark ? const Color(0xFF1C1A22) : Colors.white)
                    : AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryOf(context),
        letterSpacing: 0.8,
      ),
    );
  }
}
