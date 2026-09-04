import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/video_inspector.dart';
import '../../downloads/presentation/download_controller.dart';
import '../../downloads/presentation/download_detail_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';

class VideoDetailsSheet extends ConsumerStatefulWidget {
  final VideoInspectionResult video;

  const VideoDetailsSheet({super.key, required this.video});

  static Future<void> show(BuildContext context, VideoInspectionResult video) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      builder: (context) => VideoDetailsSheet(video: video),
    );
  }

  @override
  ConsumerState<VideoDetailsSheet> createState() => _VideoDetailsSheetState();
}

class _VideoDetailsSheetState extends ConsumerState<VideoDetailsSheet> {
  late StreamOption _selectedOption;
  bool _rightsConfirmed = false;

  @override
  void initState() {
    super.initState();
    _selectedOption = widget.video.options.firstWhere(
      (o) => o.isRecommended,
      orElse: () => widget.video.options.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final isOver200Mb = (_selectedOption.fileSizeBytes ?? 0) > (200 * 1024 * 1024);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    // Video Card with Thumbnail and Details
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              SizedBox(
                                width: 130,
                                height: 80,
                                child: video.thumbnailUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: video.thumbnailUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (_, _) => Container(
                                          color: AppColors.surfaceElevatedDark,
                                          child: const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (_, _, _) => Container(
                                          color: AppColors.surfaceElevatedDark,
                                          child: const Icon(Icons.movie_outlined, color: AppColors.textMutedDark),
                                        ),
                                      )
                                    : Container(
                                        color: AppColors.surfaceElevatedDark,
                                        child: const Icon(Icons.movie_outlined, color: AppColors.textMutedDark),
                                      ),
                              ),
                              Positioned(
                                bottom: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    Formatters.formatDuration(video.duration),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Title and Author
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                video.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimaryDark,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.account_circle_outlined, size: 14, color: AppColors.secondary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      video.author,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Divider(color: AppColors.borderDark, height: 1),
                    const SizedBox(height: 20),

                    // Section Title
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Quality',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryDark,
                          ),
                        ),
                        Text(
                          'Direct CDN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Format Options List
                    ...video.options.map((option) {
                      final isSelected = _selectedOption.id == option.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() {
                              _selectedOption = option;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : AppColors.surfaceElevatedDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.borderDark,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Radio check
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textMutedDark,
                                  size: 22,
                                ),
                                const SizedBox(width: 14),

                                // Option details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            option.label,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: isSelected
                                                  ? AppColors.textPrimaryDark
                                                  : AppColors.textSecondaryDark,
                                            ),
                                          ),
                                          if (option.isRecommended)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.secondary.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: AppColors.secondary.withValues(alpha: 0.5),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: const Text(
                                                'RECOMMENDED',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.secondary,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${option.container.toUpperCase()} · ${option.isAudioOnly ? "Audio Only" : (option.hasAudio ? "Video + Audio" : "Video Only")}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMutedDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Estimated Size Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardDark,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.borderDark),
                                  ),
                                  child: Text(
                                    Formatters.formatBytes(option.fileSizeBytes),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    // Wi-Fi warning if size > 200MB
                    if (isOver200Mb)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.wifi_outlined, size: 20, color: AppColors.warning),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Large file (>200 MB). Wi-Fi connection recommended to avoid mobile data charges.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warning,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(),

                    const SizedBox(height: 16),

                    // Rights Confirmation Checkbox (Mandatory!)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevatedDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _rightsConfirmed
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : AppColors.borderDark,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _rightsConfirmed = !_rightsConfirmed;
                          });
                        },
                        child: Row(
                          children: [
                            Checkbox(
                              value: _rightsConfirmed,
                              onChanged: (val) {
                                setState(() {
                                  _rightsConfirmed = val ?? false;
                                });
                              },
                            ),
                            const Expanded(
                              child: Text(
                                'I own this content or have explicit permission to download it.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Download Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _rightsConfirmed ? AppColors.primary : AppColors.surfaceElevatedDark,
                        foregroundColor: _rightsConfirmed ? Colors.white : AppColors.textMutedDark,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _rightsConfirmed
                          ? () {
                              Navigator.of(context).pop();
                              ref.read(downloadControllerProvider.notifier).startDownload(
                                    video: widget.video,
                                    option: _selectedOption,
                                  );
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const DownloadDetailScreen(),
                                ),
                              );
                            }
                          : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.download_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _rightsConfirmed
                                ? 'Download Now (${Formatters.formatBytes(_selectedOption.fileSizeBytes)})'
                                : 'Confirm rights to download',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
