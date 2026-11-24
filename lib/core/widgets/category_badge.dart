import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

enum MediaCategory {
  video,
  clips,
  music,
  status,
  all,
}

/// Neutral category badge using Lagoon & Amber design tokens.
///
/// Strictly brand-free, generic icons only:
/// - Video: Azure badge, play-circle icon
/// - Clips: Coral badge, smart-display / clip icon
/// - Music: Mint badge, music-note icon
/// - Status: Sun badge, history-toggle icon
class CategoryBadge extends StatelessWidget {
  final MediaCategory category;
  final String? label;
  final bool showIcon;
  final bool compact;

  const CategoryBadge({
    super.key,
    required this.category,
    this.label,
    this.showIcon = true,
    this.compact = false,
  });

  static Color getColor(BuildContext context, MediaCategory category) {
    final colors = AppColors.of(context);
    switch (category) {
      case MediaCategory.video:
        return colors.categoryVideo;
      case MediaCategory.clips:
        return colors.categoryClips;
      case MediaCategory.music:
        return colors.categoryMusic;
      case MediaCategory.status:
        return colors.categoryStatus;
      case MediaCategory.all:
        return colors.primary;
    }
  }

  static IconData getIcon(MediaCategory category) {
    switch (category) {
      case MediaCategory.video:
        return Icons.play_circle_outline_rounded;
      case MediaCategory.clips:
        return Icons.movie_creation_outlined;
      case MediaCategory.music:
        return Icons.music_note_rounded;
      case MediaCategory.status:
        return Icons.history_toggle_off_rounded;
      case MediaCategory.all:
        return Icons.dashboard_outlined;
    }
  }

  static String getDefaultLabel(MediaCategory category) {
    switch (category) {
      case MediaCategory.video:
        return 'Video';
      case MediaCategory.clips:
        return 'Clips';
      case MediaCategory.music:
        return 'Music';
      case MediaCategory.status:
        return 'Status';
      case MediaCategory.all:
        return 'All';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = getColor(context, category);
    final icon = getIcon(category);
    final text = label ?? getDefaultLabel(category);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8.0 : 10.0,
        vertical: compact ? 3.0 : 5.0,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.rPill,
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            Icon(icon, size: compact ? 12 : 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: AppTypography.caption(context).copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
