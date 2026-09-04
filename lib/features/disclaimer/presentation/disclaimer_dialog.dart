import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/preferences_service.dart';
import '../../../core/theme/app_colors.dart';

class DisclaimerDialog extends ConsumerStatefulWidget {
  const DisclaimerDialog({super.key});

  static Future<bool> showIfNeeded(BuildContext context, WidgetRef ref) async {
    final prefs = ref.read(preferencesServiceProvider);
    if (!prefs.hasAcceptedDisclaimer) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const DisclaimerDialog(),
      );
      return result ?? false;
    }
    return true;
  }

  @override
  ConsumerState<DisclaimerDialog> createState() => _DisclaimerDialogState();
}

class _DisclaimerDialogState extends ConsumerState<DisclaimerDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Authorized Use Only',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(height: 12),

            // Description
            const Text(
              'Media Saver is an offline personal tool designed strictly for content you own, public domain works, or media you have explicit rights to download.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 16),

            // Policy note container
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevatedDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: AppColors.secondary),
                      SizedBox(width: 8),
                      Text(
                        'Compliance Principles',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• No bypassing DRM or access controls\n• No private or age-restricted media\n• Direct-from-source streaming with no cloud data capture',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textMutedDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Agreement checkbox
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _agreed = !_agreed;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _agreed,
                      onChanged: (val) {
                        setState(() {
                          _agreed = val ?? false;
                        });
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'I confirm I will only save content I am authorized to download.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Accept button
            ElevatedButton(
              onPressed: _agreed
                  ? () async {
                      await ref
                          .read(preferencesServiceProvider)
                          .setAcceptedDisclaimer(true);
                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    }
                  : null,
              child: const Text('I Understand & Accept'),
            ),
          ],
        ),
      ),
    );
  }
}
