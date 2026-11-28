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
import '../domain/library_group.dart';
import 'link_group_detail_screen.dart';

enum SortOption {
  newest,
  oldest,
  sizeLargest,
  nameAZ,
}

/// Library (Downloads) Screen with Lagoon & Amber design system.
///
/// Features:
/// - Grouping by Link / Collection: Multiple files from one link (e.g. Spotify playlist/album)
///   are grouped into a single elegant card with item counts. Tapping opens LinkGroupDetailScreen.
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

  // Multi-selection state (group keys)
  bool _isSelectMode = false;
  final Set<String> _selectedKeys = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelectMode([String? initialKey]) {
    HapticFeedback.selectionClick();
    setState(() {
      _isSelectMode = !_isSelectMode;
      _selectedKeys.clear();
      if (_isSelectMode && initialKey != null) {
        _selectedKeys.add(initialKey);
      }
    });
  }

  void _toggleGroupSelection(String groupKey) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedKeys.contains(groupKey)) {
        _selectedKeys.remove(groupKey);
        if (_selectedKeys.isEmpty) {
          _isSelectMode = false;
        }
      } else {
        _selectedKeys.add(groupKey);
      }
    });
  }

  MediaCategory _groupToCategory(LibraryGroup group) {
    if (group.isSpotify) return MediaCategory.music;
    if (group.isInstagram || group.isFacebook) return MediaCategory.clips;
    return MediaCategory.video;
  }

  MediaCategory _itemToCategory(DownloadItem item) {
    if (item.isSpotify) return MediaCategory.music;
    if (item.isInstagram || item.isFacebook) return MediaCategory.clips;
    return MediaCategory.video;
  }

  List<LibraryGroup> _applyFilterAndSort(List<LibraryGroup> allGroups) {
    var groups = allGroups.where((group) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = group.title.toLowerCase().contains(q);
        final matchesItems = group.items.any((i) => i.title.toLowerCase().contains(q) || i.author.toLowerCase().contains(q));
        if (!matchesTitle && !matchesItems) return false;
      }
      if (_filter == 'video') return group.isYouTube;
      if (_filter == 'clips') return group.isInstagram || group.isFacebook;
      if (_filter == 'music') return group.isSpotify;
      if (_filter == 'status') return group.isFacebook;
      return true;
    }).toList();

    switch (_sortOption) {
      case SortOption.newest:
        groups.sort((a, b) => b.latestCreatedAt.compareTo(a.latestCreatedAt));
        break;
      case SortOption.oldest:
        groups.sort((a, b) => a.latestCreatedAt.compareTo(b.latestCreatedAt));
        break;
      case SortOption.sizeLargest:
        groups.sort((a, b) => b.totalSizeBytes.compareTo(a.totalSizeBytes));
        break;
      case SortOption.nameAZ:
        groups.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }

    return groups;
  }

  Map<String, List<LibraryGroup>> _groupByDate(List<LibraryGroup> groups) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final map = <String, List<LibraryGroup>>{
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };

    for (final group in groups) {
      final date = DateTime(group.latestCreatedAt.year, group.latestCreatedAt.month, group.latestCreatedAt.day);
      if (date.isAtSameMomentAs(today)) {
        map['Today']!.add(group);
      } else if (date.isAtSameMomentAs(yesterday)) {
        map['Yesterday']!.add(group);
      } else {
        map['Earlier']!.add(group);
      }
    }

    map.removeWhere((_, list) => list.isEmpty);
    return map;
  }

  Future<void> _shareSelected(List<LibraryGroup> groups) async {
    final selectedGroups = groups.where((g) => _selectedKeys.contains(g.key)).toList();
    if (selectedGroups.isEmpty) return;
    HapticFeedback.lightImpact();

    final validPaths = <String>[];
    for (final g in selectedGroups) {
      for (final it in g.items) {
        if (it.filePath.trim().isNotEmpty) {
          validPaths.add(it.filePath);
        }
      }
    }

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

  Future<void> _deleteGroupWithUndo(LibraryGroup group) async {
    HapticFeedback.mediumImpact();
    for (final item in group.items) {
      await ref.read(downloadHistoryProvider.notifier).deleteItem(item.id, deleteFile: true);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(group.isSingle ? 'Deleted "${group.title}"' : 'Deleted "${group.title}" (${group.itemCount} files)'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            for (final item in group.items) {
              ref.read(downloadHistoryProvider.notifier).saveItem(item);
            }
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
    final allGroups = groupDownloadItems(allItems);
    final filteredGroups = _applyFilterAndSort(allGroups);

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
                      '${_selectedKeys.length} selected',
                      style: AppTypography.caption(context).copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedKeys.length == filteredGroups.length) {
                            _selectedKeys.clear();
                          } else {
                            _selectedKeys.addAll(filteredGroups.map((e) => e.key));
                          }
                        });
                      },
                      child: Text(
                        _selectedKeys.length == filteredGroups.length ? 'Deselect all' : 'Select all',
                        style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.share_outlined, color: colors.primary, size: 20),
                      tooltip: 'Share',
                      onPressed: _selectedKeys.isEmpty ? null : () => _shareSelected(filteredGroups),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: colors.error, size: 20),
                      tooltip: 'Delete',
                      onPressed: _selectedKeys.isEmpty
                          ? null
                          : () async {
                              final toDelete = filteredGroups.where((g) => _selectedKeys.contains(g.key)).toList();
                              for (final grp in toDelete) {
                                for (final it in grp.items) {
                                  await ref.read(downloadHistoryProvider.notifier).deleteItem(it.id, deleteFile: true);
                                }
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

            // Top Bar: Title + Actions (Clean separate header)
            if (widget.isEmbedded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
                child: Row(
                  children: [
                    Text(
                      'Library',
                      style: AppTypography.title(context).copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    const ZenCountdownChip(),
                    IconButton(
                      icon: Icon(
                        _isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded,
                        size: 20,
                        color: _isSearchOpen ? colors.primary : colors.textSecondary,
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
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        _isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded,
                        size: 20,
                        color: _isSearchOpen ? colors.primary : colors.textSecondary,
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

            // Search Bar (if opened)
            if (_isSearchOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: AppTypography.body(context),
                  decoration: InputDecoration(
                    hintText: 'Search downloads or collections...',
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

            // Dedicated Full-Width Filter Chips Bar (grouped counts)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterChip(
                    context: context,
                    keyName: 'all',
                    label: 'All',
                    count: allGroups.length,
                    dotColor: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    context: context,
                    keyName: 'video',
                    label: 'Video',
                    count: allGroups.where((g) => g.isYouTube).length,
                    dotColor: colors.categoryVideo,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    context: context,
                    keyName: 'clips',
                    label: 'Clips',
                    count: allGroups.where((g) => g.isInstagram || g.isFacebook).length,
                    dotColor: colors.categoryClips,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    context: context,
                    keyName: 'music',
                    label: 'Music',
                    count: allGroups.where((g) => g.isSpotify).length,
                    dotColor: colors.categoryMusic,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    context: context,
                    keyName: 'status',
                    label: 'Status',
                    count: allGroups.where((g) => g.isFacebook).length,
                    dotColor: colors.categoryStatus,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Content List / Grid grouped by date
            Expanded(
              child: filteredGroups.isEmpty
                  ? const EmptyState(
                      icon: Icons.folder_open_rounded,
                      title: 'No downloads found',
                      description: 'Media saved from links will appear here organized by date.',
                    )
                  : _buildGroupedContent(context, filteredGroups),
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

  Widget _buildGroupedContent(BuildContext context, List<LibraryGroup> groups) {
    if (_isGridView) {
      return _buildGridContent(context, groups);
    }

    final dateGroups = _groupByDate(groups);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: dateGroups.keys.length,
      itemBuilder: (context, groupIndex) {
        final dateKey = dateGroups.keys.elementAt(groupIndex);
        final currentGroups = dateGroups[dateKey]!;

        final children = <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              dateKey.toUpperCase(),
              style: AppTypography.overline(context),
            ),
          ),
        ];

        for (int i = 0; i < currentGroups.length; i++) {
          final grp = currentGroups[i];
          final globalIndex = groups.indexOf(grp) + 1;

          if (grp.isSingle) {
            children.add(_buildSingleItemTile(context, grp));
          } else {
            children.add(_buildCollectionTile(context, grp));
          }

          // Natural in-feed sponsored card after item 2, then every 8 items
          if (globalIndex == 2 || (globalIndex > 2 && (globalIndex - 2) % 8 == 0)) {
            children.add(
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: NativeAdCard(height: 260),
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

  Widget _buildGridContent(BuildContext context, List<LibraryGroup> groups) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final grp = groups[index];
        if (grp.isSingle) {
          return _buildGridTile(context, grp);
        } else {
          return _buildGroupGridTile(context, grp);
        }
      },
    );
  }

  /// Single Item in Grid View
  Widget _buildGridTile(BuildContext context, LibraryGroup group) {
    final colors = AppColors.of(context);
    final item = group.singleItem;
    final category = _itemToCategory(item);
    final isSelected = _selectedKeys.contains(group.key);

    return AppCard(
      padding: const EdgeInsets.all(8),
      borderColor: isSelected ? colors.primary : colors.outline,
      backgroundColor: isSelected ? colors.primaryContainer.withValues(alpha: 0.3) : colors.surface,
      onTap: () {
        if (_isSelectMode) {
          _toggleGroupSelection(group.key);
        } else {
          MediaLauncher.openMedia(context, item.filePath, title: item.title);
        }
      },
      onLongPress: () => _toggleSelectMode(group.key),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  Formatters.formatBytes(item.fileSizeBytes),
                  style: AppTypography.caption(context).copyWith(fontSize: 11),
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
                      _showItemDetails(item);
                      break;
                    case 'delete':
                      _deleteGroupWithUndo(group);
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
        ],
      ),
    );
  }

  /// Multi-item Collection in Grid View
  Widget _buildGroupGridTile(BuildContext context, LibraryGroup group) {
    final colors = AppColors.of(context);
    final category = _groupToCategory(group);
    final isSelected = _selectedKeys.contains(group.key);

    return AppCard(
      padding: const EdgeInsets.all(8),
      borderColor: isSelected ? colors.primary : colors.primary.withValues(alpha: 0.3),
      backgroundColor: isSelected ? colors.primaryContainer.withValues(alpha: 0.3) : colors.surface,
      onTap: () {
        if (_isSelectMode) {
          _toggleGroupSelection(group.key);
        } else {
          LinkGroupDetailScreen.show(context, group);
        }
      },
      onLongPress: () => _toggleSelectMode(group.key),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadii.r14,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  (group.thumbnailUrl != null && group.thumbnailUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: group.thumbnailUrl!,
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
                  // Stack badge indicator
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: AppRadii.rPill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.layers_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${group.itemCount}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
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
            group.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.subtitle(context).copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${group.itemCount} files • ${Formatters.formatBytes(group.totalSizeBytes)}',
                  style: AppTypography.caption(context).copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Single Item in List View
  Widget _buildSingleItemTile(BuildContext context, LibraryGroup group) {
    final colors = AppColors.of(context);
    final item = group.singleItem;
    final category = _itemToCategory(item);
    final isSelected = _selectedKeys.contains(group.key);

    return Dismissible(
      key: ValueKey(group.key),
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
          if (item.filePath.isNotEmpty) {
            await MediaLauncher.shareFiles([item.filePath], text: item.title);
          }
          return false;
        } else {
          return true;
        }
      },
      onDismissed: (_) => _deleteGroupWithUndo(group),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          padding: const EdgeInsets.all(10),
          borderColor: isSelected ? colors.primary : colors.outline,
          backgroundColor: isSelected ? colors.primaryContainer.withValues(alpha: 0.3) : colors.surface,
          onTap: () {
            if (_isSelectMode) {
              _toggleGroupSelection(group.key);
            } else {
              MediaLauncher.openMedia(context, item.filePath, title: item.title);
            }
          },
          onLongPress: () => _toggleSelectMode(group.key),
          child: Row(
            children: [
              if (_isSelectMode) ...[
                Checkbox(
                  value: isSelected,
                  activeColor: colors.primary,
                  onChanged: (_) => _toggleGroupSelection(group.key),
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
                      _deleteGroupWithUndo(group);
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

  /// Multi-item Collection Card in List View (e.g. 50 songs from Pop Mix playlist/album)
  Widget _buildCollectionTile(BuildContext context, LibraryGroup group) {
    final colors = AppColors.of(context);
    final category = _groupToCategory(group);
    final isSelected = _selectedKeys.contains(group.key);

    return Dismissible(
      key: ValueKey(group.key),
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
          final validPaths = group.items
              .map((i) => i.filePath)
              .where((p) => p.trim().isNotEmpty)
              .toList();
          if (validPaths.isNotEmpty) {
            await MediaLauncher.shareFiles(validPaths, text: group.title);
          }
          return false;
        } else {
          return true;
        }
      },
      onDismissed: (_) => _deleteGroupWithUndo(group),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          padding: const EdgeInsets.all(10),
          borderColor: isSelected ? colors.primary : colors.primary.withValues(alpha: 0.25),
          backgroundColor: isSelected ? colors.primaryContainer.withValues(alpha: 0.3) : colors.surface,
          onTap: () {
            if (_isSelectMode) {
              _toggleGroupSelection(group.key);
            } else {
              LinkGroupDetailScreen.show(context, group);
            }
          },
          onLongPress: () => _toggleSelectMode(group.key),
          child: Row(
            children: [
              if (_isSelectMode) ...[
                Checkbox(
                  value: isSelected,
                  activeColor: colors.primary,
                  onChanged: (_) => _toggleGroupSelection(group.key),
                ),
                const SizedBox(width: 4),
              ],

              // 72dp Thumbnail with stack badge overlay
              ClipRRect(
                borderRadius: AppRadii.r14,
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      (group.thumbnailUrl != null && group.thumbnailUrl!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: group.thumbnailUrl!,
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
                      // Badge overlay indicating multiple tracks/items
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: AppRadii.rPill,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.layers_rounded, size: 10, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(
                                '${group.itemCount}',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title & Collection details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.subtitle(context).copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        CategoryBadge(category: category, compact: true),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${group.itemCount} files · ${Formatters.formatBytes(group.totalSizeBytes)}',
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

              // Chevron Right Indicator
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: colors.primary,
              ),

              // 3-dot Menu: View, Share All, Delete Collection
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 20, color: colors.textSecondary),
                shape: RoundedRectangleBorder(borderRadius: AppRadii.r16),
                onSelected: (val) {
                  switch (val) {
                    case 'view':
                      LinkGroupDetailScreen.show(context, group);
                      break;
                    case 'share':
                      final validPaths = group.items
                          .map((i) => i.filePath)
                          .where((p) => p.trim().isNotEmpty)
                          .toList();
                      if (validPaths.isNotEmpty) {
                        MediaLauncher.shareFiles(validPaths, text: group.title);
                      }
                      break;
                    case 'delete':
                      _deleteGroupWithUndo(group);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'view', child: Text('View Files')),
                  const PopupMenuItem(value: 'share', child: Text('Share All')),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Collection', style: TextStyle(color: colors.error)),
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
