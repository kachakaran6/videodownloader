import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';

/// Screen displaying the application's Master Terms & Conditions and Acceptable Use Policy.
class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.violetGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
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
                      child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 22),
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
                            'Policy Version ${AppConfig.policyVersion} • Lawful Use Only',
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
                  'Please review these terms carefully before utilizing this application. '
                  'By accessing, downloading, or using this application, you agree to be bound by these Terms.',
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

          _buildClauseCard(
            context,
            number: '1',
            title: 'Lawful Use Requirement',
            content:
                'This application is provided exclusively for lawful personal and authorized professional use. '
                'Users may only download, format, convert, or cache media content that they legally own, for which they '
                'have obtained express permission or licensing from the copyright holder, or which is lawfully '
                'accessible in the public domain or under an applicable open license (such as Creative Commons).',
          ),

          _buildClauseCard(
            context,
            number: '2',
            title: 'User Copyright Responsibility & No Legal Immunity',
            content:
                'You are solely and strictly responsible for verifying that your use of downloaded media complies with '
                'applicable domestic and international copyright laws, intellectual property statutes, and source '
                'platform terms.\n\n'
                'IMPORTANT: Using this application, accepting disclaimers, or clicking confirmations DOES NOT make an '
                'otherwise unauthorized download legal. Statements regarding "personal use", "educational use", or '
                '"fair use" do not grant legal immunity from copyright infringement claims.',
          ),

          _buildClauseCard(
            context,
            number: '3',
            title: 'Platform-Specific Restrictions & Prohibited Bypasses',
            content:
                'Users agree not to utilize this application to circumvent digital rights management (DRM), encryption, '
                'paywalls, tokenized access controls, private account restrictions, or any other technological protection '
                'measure implemented by third-party content providers. Any attempt to reverse engineer or bypass '
                'security mechanisms is strictly prohibited.',
          ),

          _buildClauseCard(
            context,
            number: '4',
            title: 'Google Play & Distribution Channel Compliance',
            content:
                'When distributed via Google Play, this application adheres strictly to Google Play Developer Program Policies, '
                'including the Device and Network Abuse and Intellectual Property policies. In Google Play releases, '
                'features facilitating the unauthorized download of YouTube streams or services violating third-party terms '
                'are permanently disabled. No hidden switches, bypasses, or circumvention tools are provided.',
          ),

          _buildClauseCard(
            context,
            number: '5',
            title: 'Prohibited Commercial Piracy & Redistribution',
            content:
                'You may not distribute, sell, lease, broadcast, publicly perform, or commercially exploit any media '
                'processed through this application unless you own the complete intellectual property rights or possess '
                'written commercial distribution licenses.',
          ),

          _buildClauseCard(
            context,
            number: '6',
            title: 'No Guarantee of Source Availability',
            content:
                'Third-party platforms and media formats frequently update protocols and security measures. '
                'The application provides no warranty that any particular URL, service, or stream format will remain '
                'available, supported, or uninterrupted. The developers reserve the right to restrict or disable any '
                'source platform at any time without prior notice.',
          ),

          _buildClauseCard(
            context,
            number: '7',
            title: 'Copyright Complaints & Takedown Procedure',
            content:
                'We respect intellectual property rights and respond promptly to verified rights holder requests. '
                'Copyright owners may submit inquiries or takedown requests directly via the in-app "Report Copyright / '
                'Content Issue" form or by contacting our designated agent at ${AppConfig.copyrightContactEmail}. '
                'Legitimate complaints are reviewed and appropriate operational restrictions will be instituted.',
          ),

          _buildClauseCard(
            context,
            number: '8',
            title: 'Termination & Abusive Use Restrictions',
            content:
                'We reserve the right to restrict access, suspend features, or refuse service to any user who '
                'repeatedly engages in infringing conduct, attempts to disable safety controls, or violates these Terms.',
          ),

          _buildClauseCard(
            context,
            number: '9',
            title: 'Disclaimer of Warranties & Limitation of Liability',
            content:
                'This application is provided "AS IS" without warranties of any kind, express or implied. '
                'To the maximum extent permitted by applicable law, in no event shall the authors, contributors, or '
                'distributors be liable for any direct, indirect, incidental, or consequential damages resulting from your '
                'use or misuse of the application or third-party media.',
          ),
        ],
      ),
    );
  }

  Widget _buildClauseCard(
    BuildContext context, {
    required String number,
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
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
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
          const SizedBox(height: 10),
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
