import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/media_launcher.dart';
import '../../downloads/presentation/download_controller.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/services/media_export_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/utils/formatters.dart';
import '../../downloads/domain/download_item.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const HistoryScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(downloadHistoryProvider);
    final activeDownload = ref.watch(downloadControllerProvider);

    final filteredItems = allItems.where((item) {
      if (_filter == 'completed') return item.status == DownloadStatus.completed;
      if (_filter == 'failed') {
        return item.status == DownloadStatus.failed || item.status == DownloadStatus.cancelled;
      }
      if (_filter == 'youtube') return item.isYouTube;
      if (_filter == 'instagram') return item.isInstagram;
      if (_filter == 'spotify') return item.isSpotify;
      if (_filter == 'facebook') return item.isFacebook;
      return true;
    }).toList();

    final bodyContent = Column(
      children: [
        // Source Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildFilterChip(
                filterKey: 'all',
                label: 'All',
                count: allItems.length,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                filterKey: 'youtube',
                label: 'YouTube',
                count: allItems.where((i) => i.isYouTube).length,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                filterKey: 'instagram',
                label: 'Instagram',
                count: allItems.where((i) => i.isInstagram).length,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                filterKey: 'spotify',
                label: 'Spotify',
                count: allItems.where((i) => i.isSpotify).length,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                filterKey: 'facebook',
                label: 'Facebook',
                count: allItems.where((i) => i.isFacebook).length,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                filterKey: 'completed',
                label: 'Completed',
                count: allItems.where((i) => i.status == DownloadStatus.completed).length,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                filterKey: 'failed',
                label: 'Failed',
                count: allItems.where((i) => i.status == DownloadStatus.failed || i.status == DownloadStatus.cancelled).length,
              ),
            ],
          ),
        ),

        // Active Download Live Banner
        if (activeDownload.isDownloading && activeDownload.item != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildActiveDownloadBanner(context, activeDownload),
          ),

        // Downloads List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.read(downloadHistoryProvider.notifier).refresh();
            },
            color: AppColors.primaryOf(context),
            child: filteredItems.isEmpty
                ? const AppEmptyState(
                    icon: Icons.folder_open_rounded,
                    title: 'No downloads found',
                    description: 'Downloaded media will appear here for easy playback and sharing.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildCompactMediaItem(context, item);
                    },
                  ),
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(
          'Downloads',
          style: AppTypography.screenTitle(context),
        ),
        actions: [
          if (allItems.isNotEmpty)
            AppIconButton(
              icon: Icons.delete_sweep_outlined,
              tooltip: 'Clear history',
              onPressed: () => _confirmClearHistory(context),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildFilterChip({
    required String filterKey,
    required String label,
    required int count,
  }) {
    final isSelected = _filter == filterKey;
    final isDark = AppColors.isDark(context);

    return InkWell(
      borderRadius: AppRadii.rPill,
      onTap: () {
        setState(() {
          _filter = filterKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryOf(context)
              : AppColors.surface(context),
          borderRadius: AppRadii.rPill,
          border: Border.all(
            color: isSelected
                ? AppColors.primaryOf(context)
                : AppColors.border(context),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? const Color(0xFF1C1A22) : Colors.white)
                    : AppColors.textPrimary(context),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                          ? const Color(0xFF1C1A22).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.25))
                      : AppColors.primaryContainer(context),
                  borderRadius: AppRadii.rPill,
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? (isDark ? const Color(0xFF1C1A22) : Colors.white)
                        : AppColors.primaryOf(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDownloadBanner(
    BuildContext context,
    ActiveDownloadState active,
  ) {
    final item = active.item;
    final progress = active.progress;
    if (item == null || progress == null) return const SizedBox.shrink();

    final pct = (progress.progress * 100).clamp(0, 100).toInt();

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer(context),
                  borderRadius: AppRadii.r8,
                ),
                child: Text(
                  'DOWNLOADING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.primaryOf(context),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryOf(context),
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cardTitle(context),
          ),
          AppSpacing.gapSm,
          ClipRRect(
            borderRadius: AppRadii.r8,
            child: LinearProgressIndicator(
              value: progress.progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.surfaceElevated(context),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOf(context)),
              minHeight: 6,
            ),
          ),
          AppSpacing.gapSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  progress.stage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.metadata(context),
                ),
              ),
              InkWell(
                onTap: () {
                  ref.read(downloadControllerProvider.notifier).cancelDownload();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMediaItem(BuildContext context, DownloadItem item) {
    final isCompleted = item.status == DownloadStatus.completed;
    final isImage = item.isImage;
    final isAudio = item.isAudio;

    final String sourceLabel = item.isSpotify
        ? 'Spotify'
        : (item.isFacebook
            ? 'Facebook'
            : (item.isInstagram ? 'Instagram' : 'YouTube'));

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: isCompleted
          ? () => MediaLauncher.openMedia(context, item.filePath, title: item.title)
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 56x56 Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: item.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => _buildThumbnailFallback(
                        context,
                        isImage: isImage,
                        isAudio: isAudio,
                      ),
                    )
                  : _buildThumbnailFallback(
                      context,
                      isImage: isImage,
                      isAudio: isAudio,
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      sourceLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryOf(context),
                      ),
                    ),
                    if (item.fileSizeBytes > 0) ...[
                      Text(
                        ' • ',
                        style: AppTypography.metadata(context),
                      ),
                      Text(
                        Formatters.formatBytes(item.fileSizeBytes),
                        style: AppTypography.metadata(context),
                      ),
                    ],
                    if (item.durationSeconds > 0 && !isImage) ...[
                      Text(
                        ' • ',
                        style: AppTypography.metadata(context),
                      ),
                      Text(
                        Formatters.formatDuration(Duration(seconds: item.durationSeconds)),
                        style: AppTypography.metadata(context),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                _buildStatusRow(context, item.status),
              ],
            ),
          ),

          const SizedBox(width: 4),

          // Consistent Trailing Overflow Menu across all cards
          _buildItemOverflowMenu(context, item),
        ],
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, DownloadStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case DownloadStatus.completed:
        color = AppColors.success;
        label = 'Completed';
        icon = Icons.check_circle_outline_rounded;
        break;
      case DownloadStatus.failed:
        color = AppColors.error;
        label = 'Failed';
        icon = Icons.error_outline_rounded;
        break;
      case DownloadStatus.cancelled:
        color = AppColors.warning;
        label = 'Cancelled';
        icon = Icons.cancel_outlined;
        break;
      case DownloadStatus.downloading:
        color = AppColors.primaryOf(context);
        label = 'Downloading';
        icon = Icons.downloading_rounded;
        break;
      default:
        color = AppColors.textSecondary(context);
        label = 'Queued';
        icon = Icons.schedule_rounded;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildItemOverflowMenu(BuildContext context, DownloadItem item) {
    final isCompleted = item.status == DownloadStatus.completed;

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondary(context)),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.r12,
        side: BorderSide(color: AppColors.border(context)),
      ),
      color: AppColors.surface(context),
      onSelected: (value) async {
        if (value == 'play') {
          MediaLauncher.openMedia(context, item.filePath, title: item.title);
        } else if (value == 'share') {
          ref.read(downloadControllerProvider.notifier).shareFile(item.filePath, item.title);
        } else if (value == 'folder') {
          final messenger = ScaffoldMessenger.of(context);
          final opened = await MediaExportService.openInFileManager(item.filePath);
          if (!opened) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Saved in: Internal storage / Download'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else if (value == 'delete') {
          _confirmDeleteItem(context, item);
        }
      },
      itemBuilder: (context) => [
        if (isCompleted) ...[
          const PopupMenuItem(
            value: 'play',
            child: Row(
              children: [
                Icon(Icons.play_arrow_rounded, size: 18),
                SizedBox(width: 10),
                Text('Play'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'share',
            child: Row(
              children: [
                Icon(Icons.share_outlined, size: 18),
                SizedBox(width: 10),
                Text('Share'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'folder',
            child: Row(
              children: [
                Icon(Icons.folder_open_rounded, size: 18),
                SizedBox(width: 10),
                Text('Show in files'),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
              SizedBox(width: 10),
              Text('Delete', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailFallback(BuildContext context, {required bool isImage, required bool isAudio}) {
    return Container(
      color: AppColors.surfaceElevated(context),
      child: Center(
        child: Icon(
          isImage
              ? Icons.image_rounded
              : (isAudio ? Icons.music_note_rounded : Icons.movie_outlined),
          size: 24,
          color: AppColors.textSecondary(context),
        ),
      ),
    );
  }

  void _confirmDeleteItem(BuildContext context, DownloadItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.r20,
          side: BorderSide(color: AppColors.border(context)),
        ),
        title: Text(
          'Delete download?',
          style: AppTypography.cardTitle(context),
        ),
        content: Text(
          'Remove "${item.title}" from download history?',
          style: AppTypography.supporting(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(downloadHistoryProvider.notifier).deleteItem(item.id, deleteFile: false);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.r20,
          side: BorderSide(color: AppColors.border(context)),
        ),
        title: Text(
          'Clear download history?',
          style: AppTypography.cardTitle(context),
        ),
        content: Text(
          'This will remove all records from history. Downloaded files in your device storage will not be deleted.',
          style: AppTypography.supporting(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(downloadHistoryProvider.notifier).clearHistory();
            },
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }
}
