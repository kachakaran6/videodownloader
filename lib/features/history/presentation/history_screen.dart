import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/media_launcher.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/category_badge.dart';
import '../../downloads/domain/download_item.dart';
import '../../downloads/presentation/download_detail_screen.dart';
import '../../../core/ads/widgets/native_ad_card.dart';
import '../../../core/ads/widgets/zen_countdown_chip.dart';

enum SortOption {
  newest,
  oldest,
  sizeLargest,
  nameAZ,
}

/// Library (Downloads) Screen with Lagoon & Amber design system.
///
/// Features:
/// - Filter chips: All, Video, Clips, Music, Status with count and color dot
/// - Search bar, sort menu, grid/list toggle
/// - 72dp thumbnail, 2-line title wrap, category badge, size, duration, 3-dot menu
/// - Long-press multi-select with contextual top bar
/// - Swipe right = Share, Swipe left = Delete with undo
/// - Section headers by date (Today, Yesterday, Earlier)
/// - 100dp bottom padding
class HistoryScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const HistoryScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _filter = 'all';
  String _searchQuery = '';
  bool _isSearchOpen = false;
  bool _isGridView = false;
  SortOption _sortOption = SortOption.newest;
  final TextEditingController _searchController = TextEditingController();

  // Multi-selection state
  bool _isSelectMode = false;
  final Set<String> _selectedIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelectMode([String? initialId]) {
    HapticFeedback.selectionClick();
    setState(() {
      _isSelectMode = !_isSelectMode;
      _selectedIds.clear();
      if (_isSelectMode && initialId != null) {
        _selectedIds.add(initialId);
      }
    });
  }

  void _toggleItemSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  MediaCategory _itemToCategory(DownloadItem item) {
    if (item.isSpotify) return MediaCategory.music;
    if (item.isInstagram || item.isFacebook) return MediaCategory.clips;
    return MediaCategory.video;
  }

  List<DownloadItem> _applyFilterAndSort(List<DownloadItem> allItems) {
    var items = allItems.where((item) {
      if (_searchQuery.isNotEmpty) {
        if (!item.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      if (_filter == 'video') return item.isYouTube;
      if (_filter == 'clips') return item.isInstagram;
      if (_filter == 'music') return item.isSpotify;
      if (_filter == 'status') return item.isFacebook;
      return true;
    }).toList();

    switch (_sortOption) {
      case SortOption.newest:
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.oldest:
        items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.sizeLargest:
        items.sort((a, b) => b.fileSizeBytes.compareTo(a.fileSizeBytes));
        break;
      case SortOption.nameAZ:
        items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }

    return items;
  }

  Map<String, List<DownloadItem>> _groupByDate(List<DownloadItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <String, List<DownloadItem>>{
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };

    for (final item in items) {
      final itemDate = DateTime(item.createdAt.year, item.createdAt.month, item.createdAt.day);
      if (itemDate.isAtSameMomentAs(today)) {
        groups['Today']!.add(item);
      } else if (itemDate.isAtSameMomentAs(yesterday)) {
        groups['Yesterday']!.add(item);
      } else {
        groups['Earlier']!.add(item);
      }
    }

    groups.removeWhere((_, list) => list.isEmpty);
    return groups;
  }

  Future<void> _shareSelected(List<DownloadItem> items) async {
    final selectedItems = items.where((i) => _selectedIds.contains(i.id)).toList();
    if (selectedItems.isEmpty) return;
    HapticFeedback.lightImpact();

    final validPaths = selectedItems
        .map((e) => e.filePath)
        .where((p) => p.trim().isNotEmpty)
        .toList();

    if (validPaths.isNotEmpty) {
      await MediaLauncher.shareFiles(validPaths);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected files could not be located on disk.')),
        );
      }
    }
    setState(() => _isSelectMode = false);
  }

  Future<void> _deleteItemWithUndo(DownloadItem item) async {
    HapticFeedback.mediumImpact();
    // Delete via downloadHistoryProvider.notifier so Riverpod state updates immediately and triggers UI rebuild
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

  void _showItemDetails(DownloadItem item) {
    DownloadDetailScreen.show(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final allItems = ref.watch(downloadHistoryProvider);
    final filteredItems = _applyFilterAndSort(allItems);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: Text('Library', style: AppTypography.title(context)),
              actions: const [
                ZenCountdownChip(),
                SizedBox(width: 8),
              ],
            ),
      body: SafeArea(
        top: !widget.isEmbedded,
        child: Column(
          children: [
            // Multi-Select Contextual Header Bar
            if (_isSelectMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: colors.primaryContainer,
                child: Row(
                  children: [
                    Text(
                      '${_selectedIds.length} selected',
                      style: AppTypography.caption(context).copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedIds.length == filteredItems.length) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds.addAll(filteredItems.map((e) => e.id));
                          }
                        });
                      },
                      child: Text(
                        _selectedIds.length == filteredItems.length ? 'Deselect all' : 'Select all',
                        style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.share_outlined, color: colors.primary, size: 20),
                      tooltip: 'Share',
                      onPressed: _selectedIds.isEmpty ? null : () => _shareSelected(filteredItems),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: colors.error, size: 20),
                      tooltip: 'Delete',
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () async {
                              final toDelete = filteredItems.where((i) => _selectedIds.contains(i.id)).toList();
                              for (final it in toDelete) {
                                await ref.read(downloadHistoryProvider.notifier).deleteItem(it.id, deleteFile: true);
                              }
                              setState(() => _isSelectMode = false);
                            },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => setState(() => _isSelectMode = false),
                    ),
                  ],
                ),
              ),

            // Search Bar (if opened)
            if (_isSearchOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: AppTypography.body(context),
                  decoration: InputDecoration(
                    hintText: 'Search downloads...',
                    prefixIcon: Icon(Icons.search_rounded, color: colors.primary, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                          _isSearchOpen = false;
                        });
                      },
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),

            // Filter Chips + View Controls Row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // Horizontally scrollable filter chips with category color dots
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _buildFilterChip(
                            context: context,
                            keyName: 'all',
                            label: 'All',
                            count: allItems.length,
                            dotColor: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            context: context,
                            keyName: 'video',
                            label: 'Video',
                            count: allItems.where((i) => i.isYouTube).length,
                            dotColor: colors.categoryVideo,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            context: context,
                            keyName: 'clips',
                            label: 'Clips',
                            count: allItems.where((i) => i.isInstagram || i.isFacebook).length,
                            dotColor: colors.categoryClips,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            context: context,
                            keyName: 'music',
                            label: 'Music',
                            count: allItems.where((i) => i.isSpotify).length,
                            dotColor: colors.categoryMusic,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            context: context,
                            keyName: 'status',
                            label: 'Status',
                            count: allItems.where((i) => i.isFacebook).length,
                            dotColor: colors.categoryStatus,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Actions: Search, Sort, Grid toggle
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ZenCountdownChip(),
                        IconButton(
                          icon: Icon(
                            _isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded,
                            size: 20,
                            color: colors.textSecondary,
                          ),
                          tooltip: 'Search',
                          onPressed: () => setState(() => _isSearchOpen = !_isSearchOpen),
                        ),
                        PopupMenuButton<SortOption>(
                          icon: Icon(Icons.sort_rounded, size: 20, color: colors.textSecondary),
                          tooltip: 'Sort by',
                          initialValue: _sortOption,
                          onSelected: (val) => setState(() => _sortOption = val),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: SortOption.newest, child: Text('Newest')),
                            const PopupMenuItem(value: SortOption.oldest, child: Text('Oldest')),
                            const PopupMenuItem(value: SortOption.sizeLargest, child: Text('Largest')),
                            const PopupMenuItem(value: SortOption.nameAZ, child: Text('Name (A-Z)')),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                            size: 20,
                            color: colors.textSecondary,
                          ),
                          tooltip: _isGridView ? 'List view' : 'Grid view',
                          onPressed: () => setState(() => _isGridView = !_isGridView),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content List / Grid grouped by date
            Expanded(
              child: filteredItems.isEmpty
                  ? const EmptyState(
                      icon: Icons.folder_open_rounded,
                      title: 'No downloads found',
                      description: 'Media saved from links will appear here organized by date.',
                    )
                  : _buildGroupedContent(context, filteredItems),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String keyName,
    required String label,
    required int count,
    required Color dotColor,
  }) {
    final colors = AppColors.of(context);
    final isSelected = _filter == keyName;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _filter = keyName);
      },
      borderRadius: AppRadii.rPill,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? colors.primaryContainer : colors.surfaceAlt,
          borderRadius: AppRadii.rPill,
          border: Border.all(
            color: isSelected ? colors.primary : colors.outline,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.caption(context).copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? colors.primary : colors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($count)',
              style: AppTypography.overline(context).copyWith(
                fontSize: 10,
                color: isSelected ? colors.primary : colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedContent(BuildContext context, List<DownloadItem> items) {
    if (_isGridView) {
      return _buildGridContent(context, items);
    }

    final groups = _groupByDate(items);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: groups.keys.length,
      itemBuilder: (context, groupIndex) {
        final dateKey = groups.keys.elementAt(groupIndex);
        final groupItems = groups[dateKey]!;

        final children = <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              dateKey.toUpperCase(),
              style: AppTypography.overline(context),
            ),
          ),
        ];

        for (final item in groupItems) {
          final globalIndex = items.indexOf(item) + 1;
          children.add(_buildItemTile(context, item));

          // One card after the 6th item, then every 10 items (6, 16, 26, ...)
          if (globalIndex == 6 ||
              (globalIndex > 6 && (globalIndex - 6) % 10 == 0)) {
            children.add(
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: NativeAdCard(),
              ),
            );
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }

  Widget _buildGridContent(BuildContext context, List<DownloadItem> items) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildGridTile(context, items[index]);
      },
    );
  }

  Widget _buildGridTile(BuildContext context, DownloadItem item) {
    final colors = AppColors.of(context);
    final category = _itemToCategory(item);
    final isSelected = _selectedIds.contains(item.id);

    return AppCard(
      padding: const EdgeInsets.all(8),
      borderColor: isSelected ? colors.primary : colors.outline,
      backgroundColor: isSelected ? colors.primaryContainer.withValues(alpha: 0.3) : colors.surface,
      onTap: () {
        if (_isSelectMode) {
          _toggleItemSelection(item.id);
        } else {
          MediaLauncher.openMedia(context, item.filePath, title: item.title);
        }
      },
      onLongPress: () => _toggleSelectMode(item.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadii.r14,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            color: colors.surfaceAlt,
                            child: Icon(CategoryBadge.getIcon(category), color: colors.textSecondary),
                          ),
                        )
                      : Container(
                          color: colors.surfaceAlt,
                          child: Icon(CategoryBadge.getIcon(category), color: colors.textSecondary),
                        ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: CategoryBadge(category: category, compact: true),
                  ),
                  if (_isSelectMode)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.primary : Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSelected ? Icons.check : Icons.circle_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
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
          Text(
            Formatters.formatBytes(item.fileSizeBytes),
            style: AppTypography.caption(context).copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, DownloadItem item) {
    final colors = AppColors.of(context);
    final category = _itemToCategory(item);
    final isSelected = _selectedIds.contains(item.id);

    return Dismissible(
      key: ValueKey(item.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: AppRadii.r20,
        ),
        child: const Icon(Icons.share_rounded, color: Colors.white, size: 24),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: AppRadii.r20,
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right = Share
          if (item.filePath.isNotEmpty) {
            await MediaLauncher.shareFiles([item.filePath], text: item.title);
          }
          return false;
        } else {
          // Swipe left = Delete
          return true;
        }
      },
      onDismissed: (_) => _deleteItemWithUndo(item),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          padding: const EdgeInsets.all(10),
          borderColor: isSelected ? colors.primary : colors.outline,
          backgroundColor: isSelected ? colors.primaryContainer.withValues(alpha: 0.3) : colors.surface,
          onTap: () {
            if (_isSelectMode) {
              _toggleItemSelection(item.id);
            } else {
              MediaLauncher.openMedia(context, item.filePath, title: item.title);
            }
          },
          onLongPress: () => _toggleSelectMode(item.id),
          child: Row(
            children: [
              if (_isSelectMode) ...[
                Checkbox(
                  value: isSelected,
                  activeColor: colors.primary,
                  onChanged: (_) => _toggleItemSelection(item.id),
                ),
                const SizedBox(width: 4),
              ],

              // 72dp Thumbnail with 14dp radius
              ClipRRect(
                borderRadius: AppRadii.r14,
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: item.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            color: colors.surfaceAlt,
                            child: Icon(CategoryBadge.getIcon(category), color: colors.textSecondary),
                          ),
                        )
                      : Container(
                          color: colors.surfaceAlt,
                          child: Icon(CategoryBadge.getIcon(category), color: colors.textSecondary),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Title (2 lines wrap) & metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
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
                          Formatters.formatBytes(item.fileSizeBytes),
                          style: AppTypography.caption(context),
                        ),
                        if (item.durationSeconds > 0) ...[
                          const SizedBox(width: 6),
                          Text('·', style: AppTypography.caption(context)),
                          const SizedBox(width: 6),
                          Text(
                            Formatters.formatDuration(Duration(seconds: item.durationSeconds)),
                            style: AppTypography.caption(context),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // 3-dot Menu: Open, Share, Rename, Details, Delete
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 20, color: colors.textSecondary),
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
                      _showItemDetails(item);
                      break;
                    case 'delete':
                      _deleteItemWithUndo(item);
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
      ),
    );
  }
}
