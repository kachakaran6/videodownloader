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
    final isDark = AppColors.isDark(context);

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
        titleSpacing: 16,
        title: Text(
          'Download History',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.4,
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
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs (Design Course Category Chips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip(
                  filterKey: 'all',
                  label: 'All',
                  icon: Icons.grid_view_rounded,
                  count: allItems.length,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  filterKey: 'youtube',
                  label: 'YouTube',
                  icon: Icons.play_arrow_rounded,
                  count: allItems.where((i) => i.isYouTube).length,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  filterKey: 'instagram',
                  label: 'Instagram',
                  icon: Icons.camera_alt_outlined,
                  count: allItems.where((i) => i.isInstagram).length,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  filterKey: 'completed',
                  label: 'Completed',
                  icon: Icons.check_circle_outline_rounded,
                  count: allItems.where((i) => i.status == DownloadStatus.completed).length,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  filterKey: 'failed',
                  label: 'Failed',
                  icon: Icons.error_outline_rounded,
                  count: allItems.where((i) => i.status == DownloadStatus.failed || i.status == DownloadStatus.cancelled).length,
                ),
              ],
            ),
          ),

          // Items List (Hotel Booking + Design Course Modern Cards)
          Expanded(
            child: filteredItems.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildHistoryCard(item, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String filterKey,
    required String label,
    required IconData icon,
    required int count,
  }) {
    final isSelected = _filter == filterKey;
    final isDark = AppColors.isDark(context);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          _filter = filterKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.violetGradient : null,
          color: isSelected
              ? null
              : (isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.border(context),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : (filterKey == 'youtube'
                      ? const Color(0xFFFF0033)
                      : (filterKey == 'instagram'
                          ? AppColors.instagramPink
                          : AppColors.primary)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(DownloadItem item, bool isDark) {
    final isCompleted = item.status == DownloadStatus.completed;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 16:9 Thumbnail Header with Badges & Play Overlay
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: item.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            color: AppColors.surfaceElevated(context),
                            child: const Center(
                              child: Icon(Icons.movie_outlined, size: 36, color: AppColors.primary),
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceElevated(context),
                          child: const Center(
                            child: Icon(Icons.movie_outlined, size: 36, color: AppColors.primary),
                          ),
                        ),
                ),
                // Gradient Bottom Shadow
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Platform Tag Pill (Top Left)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: item.isInstagram ? AppColors.instagramGradient : null,
                      color: item.isInstagram ? null : const Color(0xFFFF0033),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.isInstagram ? Icons.camera_alt_outlined : Icons.play_arrow_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.isInstagram ? 'Instagram' : 'YouTube',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Status Badge (Top Right)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _buildStatusBadge(item.status),
                ),
                // Duration Pill (Bottom Right)
                if (item.durationSeconds > 0)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 11, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            Formatters.formatDuration(Duration(seconds: item.durationSeconds)),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Center Glassmorphic Circular Play Overlay
                if (isCompleted)
                  Positioned.fill(
                    child: Center(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () => OpenFilex.open(item.filePath),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Details & Actions
          Padding(
            padding: const EdgeInsets.all(14),
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
                const SizedBox(height: 6),

                // Author & Metadata
                if (item.author.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Metadata Tag Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildMetaPill(
                      label: item.qualityLabel,
                      icon: Icons.hd_rounded,
                      color: AppColors.primary,
                      isDark: isDark,
                    ),
                    _buildMetaPill(
                      label: Formatters.formatBytes(item.fileSizeBytes),
                      icon: Icons.sd_card_rounded,
                      color: AppColors.accentCyan,
                      isDark: isDark,
                    ),
                    _buildMetaPill(
                      label: Formatters.formatDate(item.createdAt),
                      icon: Icons.calendar_today_rounded,
                      color: AppColors.textMuted(context),
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Action Buttons Row (Play, Open, Share)
                if (isCompleted)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.violetGradient,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => OpenFilex.open(item.filePath),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_circle_fill_rounded, size: 17, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Play',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          OpenFilex.open(item.filePath);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border(context)),
                          ),
                          child: Icon(Icons.launch_rounded, size: 17, color: AppColors.textPrimary(context)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          ref.read(downloadControllerProvider.notifier).shareFile(item.filePath, item.title);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border(context)),
                          ),
                          child: Icon(Icons.share_outlined, size: 17, color: AppColors.textPrimary(context)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaPill({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
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
        bg = AppColors.success.withValues(alpha: 0.9);
        fg = Colors.white;
        label = 'Completed';
        break;
      case DownloadStatus.failed:
        bg = AppColors.error.withValues(alpha: 0.9);
        fg = Colors.white;
        label = 'Failed';
        break;
      case DownloadStatus.cancelled:
        bg = AppColors.warning.withValues(alpha: 0.9);
        fg = Colors.white;
        label = 'Cancelled';
        break;
      case DownloadStatus.downloading:
        bg = AppColors.primary.withValues(alpha: 0.9);
        fg = Colors.white;
        label = 'Downloading';
        break;
      default:
        bg = Colors.black.withValues(alpha: 0.7);
        fg = Colors.white;
        label = 'Queued';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
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
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
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
