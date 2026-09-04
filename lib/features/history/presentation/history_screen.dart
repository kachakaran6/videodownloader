import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
import '../../downloads/presentation/download_controller.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../downloads/domain/download_item.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _filter = 'all'; // 'all', 'youtube', 'instagram', 'completed', 'failed'

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(historyRepositoryProvider);
    final allItems = repo.getHistory();

    final filteredItems = allItems.where((item) {
      if (_filter == 'completed') return item.status == DownloadStatus.completed;
      if (_filter == 'failed') {
        return item.status == DownloadStatus.failed || item.status == DownloadStatus.cancelled;
      }
      if (_filter == 'youtube') return item.isYouTube;
      if (_filter == 'instagram') return item.isInstagram;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          'Download History',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.textPrimary(context),
          ),
        ),
        actions: [
          if (allItems.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined, color: AppColors.textPrimary(context)),
              tooltip: 'Clear History',
              onPressed: () => _confirmClearHistory(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs (Scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${allItems.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'youtube',
                  'YouTube (${allItems.where((i) => i.isYouTube).length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'instagram',
                  'Instagram (${allItems.where((i) => i.isInstagram).length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'completed',
                  'Completed (${allItems.where((i) => i.status == DownloadStatus.completed).length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'failed',
                  'Failed (${allItems.where((i) => i.status == DownloadStatus.failed || i.status == DownloadStatus.cancelled).length})',
                ),
              ],
            ),
          ),

          // Items List
          Expanded(
            child: filteredItems.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildHistoryCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _filter == filterKey;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _filter = filterKey;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border(context),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(DownloadItem item) {
    final isCompleted = item.status == DownloadStatus.completed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with platform badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 90,
                  height: 60,
                  child: item.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            color: AppColors.surfaceElevated(context),
                            child: Icon(Icons.movie_outlined, color: AppColors.textMuted(context)),
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceElevated(context),
                          child: Icon(Icons.movie_outlined, color: AppColors.textMuted(context)),
                        ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    item.isInstagram
                        ? Icons.camera_alt_outlined
                        : Icons.play_arrow_rounded,
                    size: 11,
                    color: item.isInstagram ? AppColors.instagramPink : const Color(0xFFFF0033),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.author} · ${item.qualityLabel} · ${Formatters.formatBytes(item.fileSizeBytes)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted(context),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildStatusBadge(item.status),
                    const Spacer(),
                    if (isCompleted) ...[
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        color: AppColors.textSecondary(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Share',
                        onPressed: () {
                          ref.read(downloadControllerProvider.notifier).shareFile(item.filePath, item.title);
                        },
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.play_circle_fill_rounded, size: 28),
                        color: AppColors.primary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Play',
                        onPressed: () {
                          OpenFilex.open(item.filePath);
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(DownloadStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case DownloadStatus.completed:
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.success;
        label = 'Completed';
        break;
      case DownloadStatus.failed:
        bg = AppColors.error.withValues(alpha: 0.15);
        fg = AppColors.error;
        label = 'Failed';
        break;
      case DownloadStatus.cancelled:
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = AppColors.warning;
        label = 'Cancelled';
        break;
      case DownloadStatus.downloading:
        bg = AppColors.primary.withValues(alpha: 0.15);
        fg = AppColors.primary;
        label = 'Downloading';
        break;
      default:
        bg = AppColors.surfaceElevated(context);
        fg = AppColors.textMuted(context);
        label = 'Queued';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_toggle_off_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No history found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Downloaded items will appear here.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted(context),
            ),
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
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.border(context)),
        ),
        title: Text(
          'Clear Download History?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
          ),
        ),
        content: Text(
          'This will remove all records from the app history. Your downloaded files on disk will not be deleted.',
          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(historyRepositoryProvider).clearHistory();
              setState(() {});
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
