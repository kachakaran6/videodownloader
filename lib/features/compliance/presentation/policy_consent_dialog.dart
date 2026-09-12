import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/compliance/compliance_audit_service.dart';
import '../../../core/compliance/source_policy.dart';
import '../../../core/storage/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_validator.dart';
import 'terms_and_conditions_screen.dart';
import 'privacy_policy_screen.dart';

/// Mandatory first-time user consent modal ensuring explicit confirmation of
/// content authorization and copyright compliance before any download can proceed.
class PolicyConsentDialog extends ConsumerStatefulWidget {
  const PolicyConsentDialog({super.key});

  /// Ensures user has accepted the Master Policy.
  /// If already accepted, returns true immediately. Otherwise, presents dialog.
  static Future<bool> ensurePolicyAccepted(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final prefs = ref.read(preferencesServiceProvider);
    if (prefs.hasAcceptedPolicy) {
      return true;
    }

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PolicyConsentDialog(),
    );

    return accepted ?? false;
  }

  @override
  ConsumerState<PolicyConsentDialog> createState() => _PolicyConsentDialogState();
}

class _PolicyConsentDialogState extends ConsumerState<PolicyConsentDialog> {
  bool _understandsTerms = false;
  bool _isAccepting = false;

  Future<void> _onAccept() async {
    if (!_understandsTerms || _isAccepting) return;

    setState(() {
      _isAccepting = true;
    });

    final prefs = ref.read(preferencesServiceProvider);
    final audit = ref.read(complianceAuditServiceProvider);

    await prefs.recordPolicyAcceptance(version: AppConfig.policyVersion);
    await audit.recordEvent(
      platform: MediaPlatform.unsupported,
      action: 'policy_accept',
      decision: 'permitted',
      reason: 'User explicitly confirmed authorization and agreed to policy v${AppConfig.policyVersion}',
    );

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.violetGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lawful Use Confirmation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  Text(
                    'Mandatory Compliance Policy',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Confirmation declaration box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.format_quote_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        SourcePolicy.preDownloadConfirmationText,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Important Legal Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Accepting this confirmation does NOT make an otherwise unauthorized download legal. '
                        'You must possess legitimate rights from the copyright holder.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Agreement Checkbox
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _understandsTerms = !_understandsTerms),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _understandsTerms,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (v) => setState(() => _understandsTerms = v ?? false),
                      ),
                      Expanded(
                        child: Text(
                          'I agree to the Terms & Conditions and declare that I will only download authorized content.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Legal Links
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TermsAndConditionsScreen()),
                      );
                    },
                    child: const Text('View Terms', style: TextStyle(fontSize: 11.5)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                      );
                    },
                    child: const Text('Privacy Policy', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isAccepting ? null : () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: _understandsTerms && !_isAccepting ? _onAccept : null,
            child: _isAccepting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'I Confirm & Agree',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}
