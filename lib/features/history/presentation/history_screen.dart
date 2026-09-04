import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
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
  String _filter = 'all'; // 'all', 'completed', 'failed'

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(historyRepositoryProvider);
    final allItems = repo.getHistory();

    final filteredItems = allItems.where((item) {
      if (_filter == 'completed') return item.status == DownloadStatus.completed;
      if (_filter == 'failed') return item.status == DownloadStatus.failed || item.status == DownloadStatus.cancelled;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download History'),
        actions: [
          if (allItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear History',
              onPressed: () => _confirmClearHistory(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${allItems.length})'),
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
          color: isSelected ? AppColors.primary : AppColors.surfaceElevatedDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderDark,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondaryDark,
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
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 90,
              height: 60,
              child: item.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.surfaceElevatedDark,
                        child: const Icon(Icons.movie_outlined),
                      ),
                    )
                  : Container(
                      color: AppColors.surfaceElevatedDark,
                      child: const Icon(Icons.movie_outlined),
                    ),
            ),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryDark,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.qualityLabel.isNotEmpty ? item.qualityLabel : item.status.name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isCompleted ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (item.fileSizeBytes > 0)
                      Text(
                        Formatters.formatBytes(item.fileSizeBytes),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedDark,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.formatDate(item.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMutedDark,
                  ),
                ),
              ],
            ),
          ),

          // Popup Action Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondaryDark),
            color: AppColors.surfaceElevatedDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (action) async {
              if (action == 'open' && isCompleted) {
                await OpenFilex.open(item.filePath);
              } else if (action == 'share' && isCompleted) {
                // ignore: deprecated_member_use
                await Share.shareXFiles([XFile(item.filePath)], text: item.title);
              } else if (action == 'delete') {
                await ref.read(historyRepositoryProvider).deleteItem(item.id, deleteFile: true);
                setState(() {});
              }
            },
            itemBuilder: (context) => [
              if (isCompleted) ...[
                const PopupMenuItem(
                  value: 'open',
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Play Video'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, size: 18, color: AppColors.secondary),
                      SizedBox(width: 8),
                      Text('Share / Export'),
                    ],
                  ),
                ),
              ],
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevatedDark,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_rounded,
              size: 48,
              color: AppColors.textMutedDark,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Downloads Yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Saved videos and audio will appear here.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Download History?'),
        content: const Text(
          'Do you want to clear your download history? Downloaded files on your device will remain safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(historyRepositoryProvider).clearHistory(deleteFiles: false);
      setState(() {});
    }
  }
}
