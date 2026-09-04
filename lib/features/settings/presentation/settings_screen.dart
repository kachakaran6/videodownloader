import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../disclaimer/presentation/disclaimer_dialog.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Preferences
          _buildSectionHeader('Preferences'),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Column(
              children: [
                // Preferred Quality
                ListTile(
                  leading: const Icon(Icons.high_quality_outlined, color: AppColors.secondary),
                  title: const Text(
                    'Default Quality',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    prefs.preferredQuality.toUpperCase(),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMutedDark),
                  ),
                  trailing: DropdownButton<String>(
                    value: prefs.preferredQuality,
                    dropdownColor: AppColors.surfaceElevatedDark,
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
                const Divider(color: AppColors.borderDark, height: 1),

                // Wi-Fi Only
                SwitchListTile(
                  secondary: const Icon(Icons.wifi_outlined, color: AppColors.secondary),
                  title: const Text(
                    'Download on Wi-Fi Only',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Prevent downloads on cellular data',
                    style: TextStyle(fontSize: 12, color: AppColors.textMutedDark),
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
          _buildSectionHeader('Storage & Location'),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.folder_outlined, color: AppColors.secondary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Download Location',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _storagePath,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMutedDark),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: Legal & Info
          _buildSectionHeader('About & Legal'),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.gavel_outlined, color: AppColors.secondary),
                  title: const Text(
                    'Authorized Use Policy',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Review terms and licensing notice',
                    style: TextStyle(fontSize: 12, color: AppColors.textMutedDark),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMutedDark),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const DisclaimerDialog(),
                    );
                  },
                ),
                const Divider(color: AppColors.borderDark, height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded, color: AppColors.secondary),
                  title: Text(
                    'Media Saver',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Version 1.0.0 (YouTube Direct MVP)',
                    style: TextStyle(fontSize: 12, color: AppColors.textMutedDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.secondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
