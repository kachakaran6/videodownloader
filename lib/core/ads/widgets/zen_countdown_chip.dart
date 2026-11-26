import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../ad_gate.dart';

/// Live countdown chip displayed in the top bar when Zen Boost is active.
/// Examples: "Ad-free 1:42:10" or "Ad-free 45:12".
class ZenCountdownChip extends ConsumerWidget {
  const ZenCountdownChip({super.key});

  String _formatDuration(Duration d) {
    if (d <= Duration.zero) return '00:00';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zenState = ref.watch(zenBoostProvider);
    final promoState = ref.watch(promoStateProvider);
    final colors = AppColors.of(context);

    // If lifetime promo is already active, user has perpetual ad-free pass
    if (promoState.isUnlocked && promoState.isLifetime) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.stars_rounded,
              size: 14,
              color: colors.accent,
            ),
            const SizedBox(width: 5),
            Text(
              'VIP Ad-Free',
              style: AppTypography.caption(context).copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    if (!zenState.isActive || zenState.remaining <= Duration.zero) {
      return const SizedBox.shrink();
    }

    final timeStr = _formatDuration(zenState.remaining);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.spa_rounded,
                  color: colors.accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Zen Boost Active ($timeStr remaining). Enjoy ad-free browsing!',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.accent.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.accent.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.spa_rounded,
              size: 13,
              color: colors.accent,
            ),
            const SizedBox(width: 5),
            Text(
              'Ad-free $timeStr',
              style: AppTypography.caption(context).copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
