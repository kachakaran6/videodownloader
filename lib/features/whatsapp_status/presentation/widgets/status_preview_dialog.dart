import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/utils/media_launcher.dart';
import '../../domain/whatsapp_status_item.dart';
import '../whatsapp_status_controller.dart';
import 'app_video_player_view.dart';

class StatusPreviewDialog extends ConsumerStatefulWidget {
  final WhatsAppStatusItem item;

  const StatusPreviewDialog({
    super.key,
    required this.item,
  });

  static Future<void> show(BuildContext context, WhatsAppStatusItem item) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Status Preview',
      barrierColor: Colors.black.withValues(alpha: 0.95),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => StatusPreviewDialog(item: item),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<StatusPreviewDialog> createState() => _StatusPreviewDialogState();
}

class _StatusPreviewDialogState extends ConsumerState<StatusPreviewDialog> {
  bool _showOverlays = true;

  void _toggleOverlays() {
    setState(() {
      _showOverlays = !_showOverlays;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(whatsappStatusControllerProvider);
    final isSaving = state.savingPaths.contains(widget.item.path);
    final isSaved = state.savedPaths.contains(widget.item.path) || widget.item.isSaved;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleOverlays,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ─── Center Media Viewer ─────────────────────────────────────────
            Center(
              child: widget.item.isVideo
                  ? AppVideoPlayerView(
                      filePath: widget.item.path,
                      autoPlay: true,
                      loop: true,
                    )
                  : _buildImagePreview(context),
            ),

            // ─── Top Immersive Scrim & Controls ─────────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              top: _showOverlays ? 0 : -120,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xCC000000), // ~80% black
                      Color(0x66000000), // ~40% black
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.7, 1.0],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Close Button
                        Material(
                          color: const Color(0x55000000),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Title & Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    widget.item.isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
                                    size: 16,
                                    color: widget.item.isVideo
                                        ? const Color(0xFF34D399) // Emerald
                                        : const Color(0xFFFBBF24), // Amber
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.item.isVideo ? 'Status Video' : 'Status Photo',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.item.sourceApp.displayName} • ${widget.item.formattedSize}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // External Player Button (for video)
                        if (widget.item.isVideo) ...[
                          Tooltip(
                            message: 'Open with External Player',
                            child: Material(
                              color: const Color(0x55000000),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  MediaLauncher.openMedia(
                                    context,
                                    widget.item.path,
                                    title: widget.item.fileName,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                  ),
                                  child: const Icon(
                                    Icons.open_in_new_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        // Top Share Button
                        Tooltip(
                          message: 'Share Status',
                          child: Material(
                            color: const Color(0x55000000),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                ref.read(whatsappStatusControllerProvider.notifier).shareStatus(widget.item);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: const Icon(
                                  Icons.share_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ─── Bottom Immersive Scrim & Actions Bar ────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              bottom: _showOverlays ? 0 : -140,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xE6000000), // ~90% black
                      Color(0x80000000), // ~50% black
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.7, 1.0],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                    child: Row(
                      children: [
                        // Share Button
                        Expanded(
                          flex: 2,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref.read(whatsappStatusControllerProvider.notifier).shareStatus(widget.item);
                              },
                              borderRadius: AppRadii.r16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: AppRadii.r16,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.share_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Share',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Save / Saved Button
                        Expanded(
                          flex: 3,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: (isSaving || isSaved)
                                  ? null
                                  : () async {
                                      HapticFeedback.mediumImpact();
                                      final success = await ref
                                          .read(whatsappStatusControllerProvider.notifier)
                                          .saveStatus(widget.item);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                Icon(
                                                  success
                                                      ? Icons.check_circle_rounded
                                                      : Icons.error_outline_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    success
                                                        ? 'Status saved to Gallery and Downloads!'
                                                        : 'Failed to save status.',
                                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: success
                                                ? const Color(0xFF059669)
                                                : const Color(0xFFDC2626),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    },
                              borderRadius: AppRadii.r16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: isSaved
                                      ? null
                                      : const LinearGradient(
                                          colors: [Color(0xFF059669), Color(0xFF10B981)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  color: isSaved
                                      ? const Color(0xFF065F46).withValues(alpha: 0.9)
                                      : null,
                                  borderRadius: AppRadii.r16,
                                  border: isSaved
                                      ? Border.all(
                                          color: const Color(0xFF34D399).withValues(alpha: 0.5),
                                          width: 1.2,
                                        )
                                      : null,
                                  boxShadow: isSaved
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                            blurRadius: 14,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isSaving)
                                      const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    else
                                      Icon(
                                        isSaved ? Icons.check_circle_rounded : Icons.file_download_rounded,
                                        color: isSaved ? const Color(0xFF34D399) : Colors.white,
                                        size: 22,
                                      ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isSaving
                                          ? 'Saving...'
                                          : (isSaved ? 'Saved to Gallery' : 'Save Status'),
                                      style: TextStyle(
                                        color: isSaved ? const Color(0xFFD1FAE5) : Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4.0,
      child: Image.file(
        File(widget.item.path),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
              SizedBox(height: 8),
              Text(
                'Unable to load image',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
