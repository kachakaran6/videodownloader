import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/compliance/content_authorization.dart';
import '../../../core/storage/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/category_badge.dart';
import '../../../core/widgets/quality_chip.dart';
import '../../compliance/presentation/authorization_selector_sheet.dart';
import '../../compliance/presentation/policy_consent_dialog.dart';
import '../../downloads/presentation/download_controller.dart';
import '../data/video_inspector.dart';

/// Modal Preview Sheet (draggable) for Media Downloader.
///
/// Features:
/// - Draggable modal sheet with 28dp top radius
/// - Large thumbnail with 14dp rounded corners
/// - Soft gradient header derived from category color
/// - 2-line title wrap, duration, author
/// - Format toggle (Video / Audio)
/// - Quality selector segmented chips (360p, 480p, 720p, 1080p, Audio only + size)
/// - Amber full-width "Save" button with estimated size
/// - Secondary "Add to queue" action
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
  late ContentAuthorizationType _authorizationType;
  bool _isAudioMode = false;

  @override
  void initState() {
    super.initState();
    _isAudioMode = widget.video.isSpotify;

    final initialList = _getFilteredOptions(_isAudioMode);
    _selectedOption = initialList.firstWhere(
      (o) => o.isRecommended,
      orElse: () => initialList.isNotEmpty ? initialList.first : widget.video.options.first,
    );

    final lastAuth = ref.read(preferencesServiceProvider).lastAuthorizationType;
    _authorizationType = ContentAuthorizationType.fromId(lastAuth);
  }

  bool get _hasAudioAvailable {
    return widget.video.options.any((o) => o.isAudioOnly || o.hasAudio);
  }

  List<StreamOption> _getFilteredOptions(bool audioOnly) {
    if (audioOnly) {
      final audios = widget.video.options.where((o) => o.isAudioOnly).toList();
      if (audios.isNotEmpty) return audios;

      // Fallback: derive audio options from any stream with audio
      final withAudio = widget.video.options
          .where((o) => o.hasAudio && !o.label.toLowerCase().contains('photo'))
          .toList();
      if (withAudio.isNotEmpty) {
        final base = withAudio.first;
        final estSize = base.fileSizeBytes != null ? (base.fileSizeBytes! * 0.25).round() : null;
        return [
          StreamOption(
            id: '${base.id}_audio_m4a',
            label: 'Audio (M4A)',
            container: 'm4a',
            hasAudio: true,
            fileSizeBytes: estSize,
            isRecommended: true,
            isAudioOnly: true,
            directUrl: base.directUrl,
            streamInfo: base.streamInfo,
            audioStreamInfo: base.audioStreamInfo,
          ),
          StreamOption(
            id: '${base.id}_audio_mp3',
            label: 'Audio (MP3 320 kbps)',
            container: 'mp3',
            hasAudio: true,
            fileSizeBytes: estSize,
            isRecommended: false,
            isAudioOnly: true,
            directUrl: base.directUrl,
            streamInfo: base.streamInfo,
            audioStreamInfo: base.audioStreamInfo,
          ),
        ];
      }
      return const [];
    } else {
      return widget.video.options.where((o) => !o.isAudioOnly).toList();
    }
  }

  MediaCategory _getCategory() {
    if (widget.video.isSpotify) return MediaCategory.music;
    if (widget.video.isInstagram) return MediaCategory.clips;
    return MediaCategory.video;
  }

  Future<void> _startDownload({bool queueOnly = false}) async {
    HapticFeedback.lightImpact();
    final prefs = ref.read(preferencesServiceProvider);

    // Verify compliance policy acceptance
    if (!prefs.hasAcceptedPolicy) {
      final accepted = await PolicyConsentDialog.show(context);
      if (accepted != true || !mounted) return;
    }

    final downloadController = ref.read(downloadControllerProvider.notifier);

    Navigator.of(context).pop();

    await downloadController.startDownload(
      video: widget.video,
      option: _selectedOption,
      authorizationType: _authorizationType,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(queueOnly ? 'Added to download queue' : 'Download started'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final category = _getCategory();
    final categoryColor = CategoryBadge.getColor(context, category);
    final filteredOptions = _getFilteredOptions(_isAudioMode);

    final sizeText = _selectedOption.fileSizeBytes != null
        ? Formatters.formatBytes(_selectedOption.fileSizeBytes!)
        : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadii.sheetTop,
            border: Border.all(color: colors.outline, width: 1.0),
          ),
          child: Stack(
            children: [
              // Soft gradient behind header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 180,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.sheetTop,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        categoryColor.withValues(alpha: 0.14),
                        categoryColor.withValues(alpha: 0.02),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Column(
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.outline,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        // Media Header: Thumbnail + Title + Author + Duration
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: AppRadii.r14,
                              child: Stack(
                                children: [
                                  SizedBox(
                                    width: 120,
                                    height: 80,
                                    child: widget.video.thumbnailUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: widget.video.thumbnailUrl,
                                            fit: BoxFit.cover,
                                            errorWidget: (context, url, error) => Container(
                                              color: colors.surfaceAlt,
                                              child: Icon(CategoryBadge.getIcon(category), color: categoryColor),
                                            ),
                                          )
                                        : Container(
                                            color: colors.surfaceAlt,
                                            child: Icon(CategoryBadge.getIcon(category), color: categoryColor),
                                          ),
                                  ),
                                  if (widget.video.duration != Duration.zero)
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.75),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          Formatters.formatDuration(widget.video.duration),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CategoryBadge(category: category, compact: true),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.video.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.subtitle(context).copyWith(
                                      fontSize: 15,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.video.author,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption(context),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Format Toggle: Video / Audio
                        if (!widget.video.isSpotify && _hasAudioAvailable) ...[
                          Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.surfaceAlt,
                              borderRadius: AppRadii.rPill,
                              border: Border.all(color: colors.outline),
                            ),
                            padding: const EdgeInsets.all(3),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _isAudioMode = false;
                                        final list = _getFilteredOptions(false);
                                        if (list.isNotEmpty) {
                                          _selectedOption = list.firstWhere(
                                            (o) => o.isRecommended,
                                            orElse: () => list.first,
                                          );
                                        }
                                      });
                                    },
                                    borderRadius: AppRadii.rPill,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: !_isAudioMode ? colors.surface : Colors.transparent,
                                        borderRadius: AppRadii.rPill,
                                        boxShadow: !_isAudioMode
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.05),
                                                  blurRadius: 4,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.videocam_outlined,
                                            size: 16,
                                            color: !_isAudioMode ? colors.primary : colors.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Video',
                                            style: AppTypography.caption(context).copyWith(
                                              fontWeight: !_isAudioMode ? FontWeight.w700 : FontWeight.w500,
                                              color: !_isAudioMode ? colors.primary : colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _isAudioMode = true;
                                        final list = _getFilteredOptions(true);
                                        if (list.isNotEmpty) {
                                          _selectedOption = list.firstWhere(
                                            (o) => o.isRecommended,
                                            orElse: () => list.first,
                                          );
                                        }
                                      });
                                    },
                                    borderRadius: AppRadii.rPill,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _isAudioMode ? colors.surface : Colors.transparent,
                                        borderRadius: AppRadii.rPill,
                                        boxShadow: _isAudioMode
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.05),
                                                  blurRadius: 4,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.music_note_outlined,
                                            size: 16,
                                            color: _isAudioMode ? colors.primary : colors.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Audio Only',
                                            style: AppTypography.caption(context).copyWith(
                                              fontWeight: _isAudioMode ? FontWeight.w700 : FontWeight.w500,
                                              color: _isAudioMode ? colors.primary : colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Quality Selector Section
                        Text(
                          'SELECT QUALITY',
                          style: AppTypography.overline(context),
                        ),
                        const SizedBox(height: 10),

                        if (filteredOptions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                _isAudioMode
                                    ? 'No audio track available for this media.'
                                    : 'No video streams available for this media.',
                                style: AppTypography.caption(context).copyWith(color: colors.textSecondary),
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: filteredOptions.map((opt) {
                              final isSel = opt.id == _selectedOption.id;
                              final optSize = opt.fileSizeBytes != null
                                  ? Formatters.formatBytes(opt.fileSizeBytes!)
                                  : null;

                              return QualityChip(
                                label: opt.label,
                                sizeEstimate: optSize,
                                isSelected: isSel,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() => _selectedOption = opt);
                                },
                              );
                            }).toList(),
                          ),

                        const SizedBox(height: 24),

                        // Authorization declaration row
                        InkWell(
                          onTap: () async {
                            final selected = await AuthorizationSelectorSheet.show(context);
                            if (selected != null && mounted) {
                              setState(() => _authorizationType = selected);
                            }
                          },
                          borderRadius: AppRadii.r12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: colors.surfaceAlt,
                              borderRadius: AppRadii.r12,
                              border: Border.all(color: colors.outline),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.shield_outlined, size: 18, color: colors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Authorization: ${_authorizationType.label}',
                                        style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        'Tap to change declaration',
                                        style: AppTypography.overline(context).copyWith(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, size: 18, color: colors.textTertiary),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Primary Action: Amber "Save" Button
                        AppButton.accent(
                          label: _isAudioMode
                              ? (sizeText != null ? 'Save Audio ($sizeText)' : 'Save Audio')
                              : (sizeText != null ? 'Save ($sizeText)' : 'Save Media'),
                          icon: _isAudioMode ? Icons.music_note_rounded : Icons.download_rounded,
                          isFullWidth: true,
                          onPressed: filteredOptions.isNotEmpty ? () => _startDownload(queueOnly: false) : null,
                        ),

                        const SizedBox(height: 10),

                        // Secondary Action: Add to Queue
                        AppButton.outlined(
                          label: 'Add to queue',
                          icon: Icons.playlist_add_rounded,
                          isFullWidth: true,
                          onPressed: filteredOptions.isNotEmpty ? () => _startDownload(queueOnly: true) : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
