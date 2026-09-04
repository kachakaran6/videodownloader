import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../downloads/data/stream_downloader.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _storagePath = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadStoragePath();
  }

  Future<void> _loadStoragePath() async {
    final path = await StreamDownloader.getSafeDownloadDirectory();
    if (mounted) {
      setState(() {
        _storagePath = path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesServiceProvider);
    final currentThemeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Appearance
          _buildSectionHeader(context, 'Appearance'),
          const SizedBox(height: 8),

          Material(
            color: AppColors.card(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.border(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.palette_outlined, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Theme Mode',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          Text(
                            'Select your visual experience',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildThemeModeOption(
                          context,
                          title: 'Light',
                          icon: Icons.light_mode_rounded,
                          mode: ThemeMode.light,
                          selected: currentThemeMode == ThemeMode.light,
                        ),
                      ),
                      const SizedBox(width: 12),
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
          ),

          const SizedBox(height: 24),

          // Section: Preferences
          _buildSectionHeader(context, 'Preferences'),
          const SizedBox(height: 8),

          Material(
            color: AppColors.card(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.border(context)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Preferred Quality
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.high_quality_outlined, color: AppColors.primary, size: 20),
                  ),
                  title: Text(
                    'Default Quality',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  subtitle: Text(
                    prefs.preferredQuality.toUpperCase(),
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted(context)),
                  ),
                  trailing: DropdownButton<String>(
                    value: prefs.preferredQuality,
                    dropdownColor: AppColors.surfaceElevated(context),
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
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.wifi_outlined, color: AppColors.primary, size: 20),
                  ),
                  title: Text(
                    'Download on Wi-Fi Only',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  subtitle: Text(
                    'Prevent downloads on cellular data',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted(context)),
                  ),
                  value: prefs.wifiOnly,
                  activeTrackColor: AppColors.primary,
                  onChanged: (val) {
                    prefs.setWifiOnly(val);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: Storage
          _buildSectionHeader(context, 'Storage & Location'),
          const SizedBox(height: 8),

          Material(
            color: AppColors.card(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.border(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.folder_outlined, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Download Location',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Text(
                      _storagePath,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Section: About
          _buildSectionHeader(context, 'About'),
          const SizedBox(height: 8),

          Material(
            color: AppColors.card(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.border(context)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                  ),
                  title: Text(
                    'Video Downloader',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  subtitle: Text(
                    'Version 1.0.0 (Violet & Amethyst Edition)',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted(context)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required ThemeMode mode,
    required bool selected,
  }) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.15)
          : AppColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border(context),
          width: selected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ref.read(themeModeProvider.notifier).setThemeMode(mode);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? AppColors.primary : AppColors.textMuted(context),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
        letterSpacing: 1.0,
      ),
    );
  }
}
