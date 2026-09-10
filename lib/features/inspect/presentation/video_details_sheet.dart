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
      backgroundColor: Colors.transparent,
      builder: (context) => VideoDetailsSheet(video: video),
    );
  }

  @override
  ConsumerState<VideoDetailsSheet> createState() => _VideoDetailsSheetState();
}

class _VideoDetailsSheetState extends ConsumerState<VideoDetailsSheet> {
  late StreamOption _selectedOption;

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
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            children: [
                              SizedBox(
                                width: 130,
                                height: 85,
                                child: video.thumbnailUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: video.thumbnailUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (_, _) => Container(
                                          color: AppColors.surfaceElevated(context),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                        ),
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
                                    video.duration != Duration.zero
                                        ? Formatters.formatDuration(video.duration)
                                        : (video.isInstagram
                                            ? 'REEL'
                                            : (video.isFacebook ? 'FB VIDEO' : 'VIDEO')),
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

                        // Title, Platform Badge and Author
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: video.isInstagram ? AppColors.instagramGradient : null,
                                  color: video.isInstagram
                                      ? null
                                      : (video.isFacebook
                                          ? const Color(0xFF1877F2)
                                          : const Color(0xFFFF0033)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  video.platformBadgeText.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Text(
                                video.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary(context),
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.account_circle_outlined, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      video.author,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary(context),
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
                    Divider(color: AppColors.border(context), height: 1),
                    const SizedBox(height: 20),

                    // Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Quality',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          'Direct Source',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
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
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : AppColors.surfaceElevated(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border(context),
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
                                      : AppColors.textMuted(context),
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
                                                  ? AppColors.textPrimary(context)
                                                  : AppColors.textSecondary(context),
                                            ),
                                          ),
                                          if (option.isRecommended)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: AppColors.primary.withValues(alpha: 0.4),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: const Text(
                                                'RECOMMENDED',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primary,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${option.container.toUpperCase()} · ${option.isAudioOnly ? "Audio Only" : (option.hasAudio ? "Video + Audio" : "Video Only")}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Estimated Size
                                Text(
                                  option.fileSizeBytes != null && option.fileSizeBytes! > 0
                                      ? Formatters.formatBytes(option.fileSizeBytes)
                                      : 'Direct Stream',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Sticky Bottom Action Section
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  border: Border(
                    top: BorderSide(color: AppColors.border(context), width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Warning for large files (>200 MB)
                        if (isOver200Mb) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'File size exceeds 200 MB. Ensure a stable Wi-Fi connection.',
                                    style: TextStyle(fontSize: 11, color: AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(),
                        ],

                        // Download Action Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: AppColors.violetGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _startDownload,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  video.isInstagram ? Icons.camera_alt_outlined : Icons.download_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  video.isInstagram ? 'Download Instagram Reel' : 'Download Video Now',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isStarting = false;

  void _startDownload() {
    if (_isStarting) return;
    _isStarting = true;

    Navigator.of(context).pop(); // Close sheet

    ref.read(downloadControllerProvider.notifier).startDownload(
          video: widget.video,
          option: _selectedOption,
        );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const DownloadDetailScreen()),
    );
  }
}
