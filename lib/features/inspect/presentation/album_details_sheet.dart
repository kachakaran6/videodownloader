import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/video_inspector.dart';
import '../../downloads/presentation/download_controller.dart';
import '../../downloads/presentation/download_detail_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/url_validator.dart';

class AlbumDetailsSheet extends ConsumerStatefulWidget {
  final VideoInspectionResult album;

  const AlbumDetailsSheet({super.key, required this.album});

  static Future<void> show(BuildContext context, VideoInspectionResult album) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AlbumDetailsSheet(album: album),
    );
  }

  @override
  ConsumerState<AlbumDetailsSheet> createState() => _AlbumDetailsSheetState();
}

class _AlbumDetailsSheetState extends ConsumerState<AlbumDetailsSheet> {
  late Set<String> _selectedTrackIds;
  bool _previewOnly = false;

  @override
  void initState() {
    super.initState();
    final tracks = widget.album.spotifyTracks ?? [];
    // Select all tracks by default so 1-tap "Download Full Album" works out of the box
    _selectedTrackIds = tracks.map((t) => t.trackId).toSet();
  }

  void _toggleAll() {
    final tracks = widget.album.spotifyTracks ?? [];
    setState(() {
      if (_selectedTrackIds.length == tracks.length) {
        _selectedTrackIds.clear();
      } else {
        _selectedTrackIds = tracks.map((t) => t.trackId).toSet();
      }
    });
  }

  void _toggleTrack(String trackId) {
    setState(() {
      if (_selectedTrackIds.contains(trackId)) {
        _selectedTrackIds.remove(trackId);
      } else {
        _selectedTrackIds.add(trackId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final album = widget.album;
    final tracks = album.spotifyTracks ?? [];
    final isDark = AppColors.isDark(context);
    final totalSelected = _selectedTrackIds.length;
    final allSelected = tracks.isNotEmpty && totalSelected == tracks.length;
    final isYouTube = album.platform == MediaPlatform.youtubePlaylist;
    final primaryColor = isYouTube ? const Color(0xFFFF0000) : const Color(0xFF1DB954);
    final secondaryColor = isYouTube ? const Color(0xFFE50914) : const Color(0xFF10B981);
    final platformTitle = isYouTube ? 'YouTube Playlist' : 'Spotify Album';
    final platformIcon = isYouTube ? Icons.playlist_play_rounded : Icons.album_rounded;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border(context),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Header Card with Album Art, Title, Artist, and Meta
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border(context)),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Album Cover Art
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: album.thumbnailUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: album.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => Container(
                                    color: AppColors.surfaceElevated(context),
                                    child: Icon(platformIcon, size: 36, color: primaryColor),
                                  ),
                                )
                              : Container(
                                  color: AppColors.surfaceElevated(context),
                                  child: Icon(platformIcon, size: 36, color: primaryColor),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Album Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(platformIcon, size: 12, color: primaryColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        platformTitle,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${tracks.length} Songs',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              album.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              album.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Selection Toolbar: Select All / Deselect All + Counter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$totalSelected of ${tracks.length} selected',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: primaryColor,
                      ),
                      icon: Icon(
                        allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                        size: 16,
                      ),
                      label: Text(allSelected ? 'Deselect All' : 'Select All'),
                      onPressed: _toggleAll,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, indent: 20, endIndent: 20),

              // Scrollable Song List
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: tracks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final isSelected = _selectedTrackIds.contains(track.trackId);

                    return Material(
                      color: isSelected
                          ? (isDark
                              ? primaryColor.withValues(alpha: 0.12)
                              : primaryColor.withValues(alpha: 0.08))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _toggleTrack(track.trackId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              // Checkbox
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleTrack(track.trackId),
                                  activeColor: primaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Track index
                              SizedBox(
                                width: 22,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted(context),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Track Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                        color: isSelected
                                            ? AppColors.textPrimary(context)
                                            : AppColors.textPrimary(context).withValues(alpha: 0.85),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      track.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Duration
                              if (track.duration != null)
                                Text(
                                  Formatters.formatDuration(track.duration),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted(context),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Sticky Action Bar
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  border: Border(top: BorderSide(color: AppColors.border(context))),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (!isYouTube) ...[
                      // Format Selection Pill Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text('Full Audio MP3 (Recommended)'),
                            selected: !_previewOnly,
                            onSelected: (sel) {
                              if (sel) setState(() => _previewOnly = false);
                            },
                            selectedColor: primaryColor.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: !_previewOnly
                                  ? primaryColor
                                  : AppColors.textSecondary(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('30s Preview Clips'),
                            selected: _previewOnly,
                            onSelected: (sel) {
                              if (sel) setState(() => _previewOnly = true);
                            },
                            selectedColor: primaryColor.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _previewOnly
                                  ? primaryColor
                                  : AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Action Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: totalSelected > 0
                            ? LinearGradient(
                                colors: [primaryColor, secondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: totalSelected > 0
                            ? [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: totalSelected > 0 ? Colors.transparent : Colors.grey.shade800,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 20),
                        label: Text(
                          totalSelected == 0
                              ? 'Select at least 1 song'
                              : (allSelected
                                  ? (isYouTube
                                      ? 'Download Full Playlist (${tracks.length} Songs)'
                                      : 'Download Full Album (${tracks.length} Songs)')
                                  : 'Download Selected Songs ($totalSelected Songs)'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: totalSelected == 0
                            ? null
                            : () {
                                Navigator.of(context).pop();

                                if (isYouTube) {
                                  final selectedVideos = album.playlistVideos != null
                                      ? album.playlistVideos!
                                          .where((v) => _selectedTrackIds.contains(v.videoId))
                                          .toList()
                                      : <VideoInspectionResult>[];
                                  ref.read(downloadControllerProvider.notifier).startBulkYouTubePlaylistDownload(
                                        playlist: album,
                                        selectedVideos: selectedVideos,
                                      );
                                } else {
                                  final selectedList = tracks
                                      .where((t) => _selectedTrackIds.contains(t.trackId))
                                      .toList();
                                  ref.read(downloadControllerProvider.notifier).startBulkAlbumDownload(
                                        album: album,
                                        selectedTracks: selectedList,
                                        previewOnly: _previewOnly,
                                      );
                                }

                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const DownloadDetailScreen(),
                                  ),
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
