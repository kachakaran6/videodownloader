import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/media_launcher.dart';
import '../../domain/whatsapp_status_item.dart';
import '../whatsapp_status_controller.dart';

class StatusPreviewDialog extends ConsumerWidget {
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
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => StatusPreviewDialog(item: item),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(whatsappStatusControllerProvider);
    final isSaving = state.savingPaths.contains(item.path);
    final isSaved = state.savedPaths.contains(item.path) || item.isSaved;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.isVideo ? 'Status Video' : 'Status Photo',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${item.sourceApp.displayName} • ${item.formattedSize}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Quick Share Button
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                    tooltip: 'Share Status',
                    onPressed: () {
                      ref.read(whatsappStatusControllerProvider.notifier).shareStatus(item);
                    },
                  ),
                ],
              ),
            ),

            // Media Preview Area
            Expanded(
              child: Center(
                child: item.isVideo
                    ? _buildVideoPreview(context)
                    : _buildImagePreview(context),
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1834).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  if (item.isVideo) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                        label: const Text('Play Video', style: TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: () {
                          MediaLauncher.openMedia(context, item.path, title: item.fileName);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Download / Saved Button
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isSaved ? null : AppColors.violetGradient,
                        color: isSaved ? const Color(0xFF10B981) : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: (isSaved ? const Color(0xFF10B981) : AppColors.primary)
                                .withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: isSaving
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isSaved ? Icons.check_circle_rounded : Icons.file_download_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                        label: Text(
                          isSaved ? 'Saved to Gallery' : 'Save Status',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: (isSaving || isSaved)
                            ? null
                            : () async {
                                final success = await ref
                                    .read(whatsappStatusControllerProvider.notifier)
                                    .saveStatus(item);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(
                                            success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
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
                                      backgroundColor:
                                          success ? const Color(0xFF10B981) : AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                  ),
                ],
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
        File(item.path),
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

  Widget _buildVideoPreview(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Darkened video preview area
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: Container(
              color: Colors.black26,
            ),
          ),
        ),
        // Big Play Button
        InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: () {
            MediaLauncher.openMedia(context, item.path, title: item.fileName);
          },
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppColors.violetGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ],
    );
  }
}
