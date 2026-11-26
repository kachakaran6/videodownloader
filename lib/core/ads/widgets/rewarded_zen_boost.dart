import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_typography.dart';
import '../ad_gate.dart';
import '../ad_service.dart';
import '../frequency_cap.dart';

/// Friendly, opt-in Rewarded Ad card.
/// Enables users to earn 2 hours of ad-free time or priority downloads.
/// Automatically hides if ads are already disabled via Promo Code or active Zen Boost.
class RewardedZenBoostCard extends ConsumerStatefulWidget {
  final bool isCompact;

  const RewardedZenBoostCard({
    super.key,
    this.isCompact = false,
  });

  @override
  ConsumerState<RewardedZenBoostCard> createState() =>
      _RewardedZenBoostCardState();
}

class _RewardedZenBoostCardState extends ConsumerState<RewardedZenBoostCard> {
  bool _isLoading = false;

  Future<void> _handleWatchAd({required bool isPriorityQueue}) async {
    final freqCap = ref.read(frequencyCapServiceProvider);
    if (!freqCap.canWatchRewarded()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily Zen Boost limit reached (3/day). Come back tomorrow!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final adService = ref.read(adServiceProvider);
    await adService.showRewardedZenBoost(
      context: context,
      onRewardGranted: () async {
        HapticFeedback.mediumImpact();
        if (isPriorityQueue) {
          await ref.read(zenBoostProvider.notifier).grantPriorityQueue();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Priority queue unlocked for your next 3 downloads!'),
                backgroundColor: AppColors.of(context).primary,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          await ref.read(zenBoostProvider.notifier).grantZenBoost();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('2 hours ad-free activated! Enjoy ClipVault.'),
                    ),
                  ],
                ),
                backgroundColor: AppColors.of(context).primary,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      onFailure: (message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adsEnabled = ref.watch(adsEnabledProvider);
    // If ads are disabled everywhere (Promo or Zen Boost active), hide the card completely
    if (!adsEnabled) {
      return const SizedBox.shrink();
    }

    final freqCap = ref.watch(frequencyCapServiceProvider);
    final remaining = freqCap.remainingRewardedToday;
    if (remaining <= 0) {
      return const SizedBox.shrink();
    }

    final colors = AppColors.of(context);

    if (widget.isCompact) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.spa_rounded,
                size: 20,
                color: colors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2 Hours Ad-Free',
                    style: AppTypography.subtitle(context).copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Watch a short clip ($remaining left today)',
                    style: AppTypography.caption(context).copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: _isLoading ? null : () => _handleWatchAd(isPriorityQueue: false),
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Unlock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: colors.outline,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.spa_rounded,
                  size: 22,
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Zen Boost',
                          style: AppTypography.subtitle(context).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$remaining left today',
                            style: AppTypography.caption(context).copyWith(
                              color: colors.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Watch a short clip for 2 hours ad-free.',
                      style: AppTypography.body(context).copyWith(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _handleWatchAd(isPriorityQueue: true),
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('Priority Queue', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(
                      color: colors.primary.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : () => _handleWatchAd(isPriorityQueue: false),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('2h Ad-Free', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
