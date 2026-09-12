import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';

/// Screen detailing the application's Privacy Policy and Google Play Data Safety compliance.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Privacy & Data Safety'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConfig.appName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Privacy & Data Safety Commitment',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'We believe in radical data minimalism. This application processes media locally on your device '
                  'and does not transmit your personal files, account credentials, or downloads to external servers.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildPrivacyCard(
            context,
            icon: Icons.cloud_off_rounded,
            title: 'Zero Media or Server Uploads',
            content:
                'Downloaded video, audio, and image files are saved directly to your local device storage. '
                'At no point is your downloaded media uploaded, mirrored, or sent to developer-owned or third-party servers.',
          ),

          _buildPrivacyCard(
            context,
            icon: Icons.key_off_rounded,
            title: 'Zero Credential & Cookie Harvesting',
            content:
                'We do not ask for, capture, or store your passwords, login credentials, social media authentication '
                'tokens, or private cookies. The application operates strictly on publicly accessible CDN resources.',
          ),

          _buildPrivacyCard(
            context,
            icon: Icons.phonelink_lock_rounded,
            title: 'Local Device Permissions',
            content:
                'Storage and media permissions requested by the app are used exclusively to write downloaded files '
                'into your Movies/ or Music/ folders via standard Android MediaStore / Storage Access Framework APIs. '
                'We never read or scan your private photos or documents.',
          ),

          _buildPrivacyCard(
            context,
            icon: Icons.fact_check_outlined,
            title: 'Minimal Non-Sensitive Audit Logging',
            content:
                'To maintain policy transparency and verify acceptable use compliance, the app records minimal '
                'operational metadata locally (platform name, timestamp, and authorization basis such as "I own this content"). '
                'These records contain zero personal data, never leave your device, and can be cleared at any time in Settings.',
          ),

          _buildPrivacyCard(
            context,
            icon: Icons.delete_outline_rounded,
            title: 'Data Deletion & User Control',
            content:
                'Because no user data is stored on remote servers, you maintain 100% control over your data. '
                'Clearing app storage or uninstalling the application instantly deletes all local preferences, '
                'history records, and compliance logs.',
          ),

          _buildPrivacyCard(
            context,
            icon: Icons.mail_outline_rounded,
            title: 'Privacy Contact',
            content:
                'If you have questions regarding our privacy practices or Data Safety disclosures, contact our privacy officer at '
                'privacy@mediasaver.app.',
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0D9488), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
