import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/ads/widgets/native_ad_card.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/media_launcher.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/category_badge.dart';
import '../../downloads/domain/download_item.dart';
import '../../downloads/presentation/download_detail_screen.dart';
import '../domain/library_group.dart';

class LinkGroupDetailScreen extends ConsumerStatefulWidget {
  final LibraryGroup initialGroup;

  const LinkGroupDetailScreen({
    super.key,
    required this.initialGroup,
  });

  static Future<void> show(BuildContext context, LibraryGroup group) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LinkGroupDetailScreen(initialGroup: group),
      ),
    );
  }

  @override
  ConsumerState<LinkGroupDetailScreen> createState() => _LinkGroupDetailScreenState();
}

class _LinkGroupDetailScreenState extends ConsumerState<LinkGroupDetailScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  MediaCategory _itemToCategory(DownloadItem item) {
    if (item.isSpotify) return MediaCategory.music;
    if (item.isInstagram || item.isFacebook) return MediaCategory.clips;
    return MediaCategory.video;
  }

  Future<void> _shareAll(List<DownloadItem> items) async {
    HapticFeedback.lightImpact();
    final validPaths = items
        .map((e) => e.filePath)
        .where((p) => p.trim().isNotEmpty)
        .toList();

    if (validPaths.isNotEmpty) {
      await MediaLauncher.shareFiles(validPaths, text: widget.initialGroup.title);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No files found on disk to share.')),
        );
      }
    }
  }

  Future<void> _deleteGroupWithConfirmation(BuildContext context, List<DownloadItem> items) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errColor = AppColors.of(context).error;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Collection?'),
        content: Text('This will delete all ${items.length} downloaded files from your device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: errColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.mediumImpact();
      for (final it in items) {
        await ref.read(downloadHistoryProvider.notifier).deleteItem(it.id, deleteFile: true);
      }
      if (mounted) {
        nav.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Deleted "${widget.initialGroup.title}" (${items.length} files)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteSingleItem(DownloadItem item) async {
    HapticFeedback.mediumImpact();
    await ref.read(downloadHistoryProvider.notifier).deleteItem(item.id, deleteFile: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${item.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            ref.read(downloadHistoryProvider.notifier).saveItem(item);
          },
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _renameItem(DownloadItem item) async {
    final controller = TextEditingController(text: item.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'File Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != item.title) {
      await ref.read(downloadHistoryProvider.notifier).renameItem(item.id, newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final allHistory = ref.watch(downloadHistoryProvider);
    final groups = groupDownloadItems(allHistory);
    final currentGroup = groups.cast<LibraryGroup?>().firstWhere(
      (g) => g?.key == widget.initialGroup.key,
      orElse: () => null,
    );

    // If all items were deleted, navigate back
    if (currentGroup == null || currentGroup.items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: const Text('Collection')),
        body: const SizedBox.shrink(),
      );
    }

    final category = _itemToCategory(currentGroup.items.first);
    final filteredItems = currentGroup.items.where((it) {
      if (_searchQuery.isEmpty) return true;
      return it.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          it.author.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          currentGroup.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.title(context).copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            tooltip: 'Share All',
            onPressed: () => _shareAll(currentGroup.items),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 20, color: colors.error),
            tooltip: 'Delete Collection',
            onPressed: () => _deleteGroupWithConfirmation(context, currentGroup.items),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            // Hero Header Card
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Large Artwork
                      ClipRRect(
                        borderRadius: AppRadii.r16,
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: (currentGroup.thumbnailUrl != null && currentGroup.thumbnailUrl!.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: currentGroup.thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => Container(
                                    color: colors.surfaceAlt,
                                    child: Icon(CategoryBadge.getIcon(category), size: 36, color: colors.textSecondary),
                                  ),
                                )
                              : Container(
                                  color: colors.surfaceAlt,
                                  child: Icon(CategoryBadge.getIcon(category), size: 36, color: colors.textSecondary),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentGroup.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.title(context).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                CategoryBadge(category: category, compact: true),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${currentGroup.itemCount} files • ${Formatters.formatBytes(currentGroup.totalSizeBytes)}',
                                    style: AppTypography.caption(context).copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action Buttons Row
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (currentGroup.items.isNotEmpty) {
                              final firstPlayable = currentGroup.items.firstWhere(
                                (i) => i.filePath.isNotEmpty,
                                orElse: () => currentGroup.items.first,
                              );
                              MediaLauncher.openMedia(context, firstPlayable.filePath, title: firstPlayable.title);
                            }
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text('Play First'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: AppRadii.r12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _shareAll(currentGroup.items),
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: const Text('Share All'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            side: BorderSide(color: colors.outline),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: AppRadii.r12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Ad Card
            const NativeAdCard(height: 260),
            const SizedBox(height: 14),

            // Search Bar (if > 4 items)
            if (currentGroup.itemCount > 4) ...[
              TextField(
                controller: _searchController,
                style: AppTypography.body(context),
                decoration: InputDecoration(
                  hintText: 'Search within this collection...',
                  prefixIcon: Icon(Icons.search_rounded, color: colors.primary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
              const SizedBox(height: 12),
            ],

            // Section Header
            Row(
              children: [
                Text(
                  'DOWNLOADED FILES (${filteredItems.length})',
                  style: AppTypography.overline(context).copyWith(
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // List of items
            for (int i = 0; i < filteredItems.length; i++) ...[
              _buildTrackTile(context, filteredItems[i], i + 1),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrackTile(BuildContext context, DownloadItem item, int index) {
    final colors = AppColors.of(context);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: AppRadii.r16,
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
      ),
      onDismissed: (_) => _deleteSingleItem(item),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () {
          MediaLauncher.openMedia(context, item.filePath, title: item.title);
        },
        child: Row(
          children: [
            // Track Number Badge or Thumbnail
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: AppRadii.r12,
              ),
              child: Text(
                '$index',
                style: AppTypography.caption(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Song Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.subtitle(context).copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (item.author.isNotEmpty && item.author != 'Unknown') ...[
                        Flexible(
                          child: Text(
                            item.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption(context).copyWith(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('·', style: AppTypography.caption(context).copyWith(fontSize: 11)),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        Formatters.formatBytes(item.fileSizeBytes),
                        style: AppTypography.caption(context).copyWith(fontSize: 11),
                      ),
                      if (item.durationSeconds > 0) ...[
                        const SizedBox(width: 6),
                        Text('·', style: AppTypography.caption(context).copyWith(fontSize: 11)),
                        const SizedBox(width: 6),
                        Text(
                          Formatters.formatDuration(Duration(seconds: item.durationSeconds)),
                          style: AppTypography.caption(context).copyWith(fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Play Button
            IconButton(
              icon: Icon(Icons.play_circle_fill_rounded, color: colors.primary, size: 28),
              tooltip: 'Play',
              onPressed: () {
                MediaLauncher.openMedia(context, item.filePath, title: item.title);
              },
            ),

            // 3-dot Menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 18, color: colors.textSecondary),
              shape: RoundedRectangleBorder(borderRadius: AppRadii.r16),
              onSelected: (val) {
                switch (val) {
                  case 'open':
                    MediaLauncher.openMedia(context, item.filePath, title: item.title);
                    break;
                  case 'share':
                    MediaLauncher.shareFiles([item.filePath], text: item.title);
                    break;
                  case 'rename':
                    _renameItem(item);
                    break;
                  case 'details':
                    DownloadDetailScreen.show(context, item);
                    break;
                  case 'delete':
                    _deleteSingleItem(item);
                    break;
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'open', child: Text('Open')),
                const PopupMenuItem(value: 'share', child: Text('Share')),
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                const PopupMenuItem(value: 'details', child: Text('Details')),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: colors.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
