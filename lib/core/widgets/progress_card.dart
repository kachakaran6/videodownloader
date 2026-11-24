import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';
import 'category_badge.dart';

/// Active Download Progress Card.
///
/// Features:
/// - 72dp thumbnail with 14dp radius
/// - 2-line title wrap with category badge
/// - Linear progress indicator with category color
/// - Tabular speed (MB/s) and ETA display
/// - Pause/Resume and Cancel actions with haptics
class ProgressCard extends StatelessWidget {
  final String title;
  final String? thumbnailUrl;
  final MediaCategory category;
  final double progress; // 0.0 to 1.0
  final String speedText; // e.g. "3.5 MB/s"
  final String etaText; // e.g. "ETA: 14s"
  final String downloadedSizeText; // e.g. "15 MB / 42 MB"
  final bool isPaused;
  final VoidCallback onPauseResume;
  final VoidCallback onCancel;

  const ProgressCard({
    super.key,
    required this.title,
    this.thumbnailUrl,
    required this.category,
    required this.progress,
    required this.speedText,
    required this.etaText,
    required this.downloadedSizeText,
    this.isPaused = false,
    required this.onPauseResume,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final categoryColor = CategoryBadge.getColor(context, category);

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: AppRadii.r14,
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            color: colors.surfaceAlt,
                            child: Icon(CategoryBadge.getIcon(category), color: categoryColor),
                          ),
                        )
                      : Container(
                          color: colors.surfaceAlt,
                          child: Icon(CategoryBadge.getIcon(category), color: categoryColor),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Title & details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.subtitle(context).copyWith(
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        CategoryBadge(category: category, compact: true),
                        const SizedBox(width: 8),
                        Text(
                          downloadedSizeText,
                          style: AppTypography.caption(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              IconButton(
                icon: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: colors.textSecondary,
                  size: 22,
                ),
                tooltip: isPaused ? 'Resume' : 'Pause',
                onPressed: onPauseResume,
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: colors.error, size: 20),
                tooltip: 'Cancel',
                onPressed: onCancel,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: AppRadii.rPill,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: colors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
            ),
          ),
          const SizedBox(height: 8),
          // Speed and ETA row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                speedText,
                style: AppTypography.tabularFigures(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
              Text(
                etaText,
                style: AppTypography.tabularFigures(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
