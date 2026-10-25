import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/liquid_glass_tokens.dart';
import '../../../../core/utils/media_launcher.dart';
import '../../../../core/widgets/liquid_glass_surface.dart';
import '../../domain/whatsapp_status_item.dart';
import '../whatsapp_status_controller.dart';
import 'app_video_player_view.dart';

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
              child: LiquidGlassSurface(
                borderRadius: AppRadii.r16,
                blurSigma: LiquidGlassTokens.blurStandard,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
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
                              fontSize: 15,
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
                    if (item.isVideo)
                      IconButton(
                        icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 20),
                        tooltip: 'Open with External Player',
                        onPressed: () {
                          MediaLauncher.openMedia(context, item.path, title: item.fileName);
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                      tooltip: 'Share Status',
                      onPressed: () {
                        ref.read(whatsappStatusControllerProvider.notifier).shareStatus(item);
                      },
                    ),
                  ],
                ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: LiquidGlassSurface(
                blurSigma: LiquidGlassTokens.blurElevated,
                borderRadius: AppRadii.r20,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Share Button
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: AppRadii.r12),
                        ),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w600)),
                        onPressed: () {
                          ref.read(whatsappStatusControllerProvider.notifier).shareStatus(item);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Download / Saved Button
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSaved ? AppColors.success : AppColors.primaryOf(context),
                          borderRadius: AppRadii.r12,
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: AppRadii.r12),
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
                              fontWeight: FontWeight.w700,
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
                                            success ? AppColors.success : AppColors.error,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AppVideoPlayerView(
        filePath: item.path,
        autoPlay: true,
        loop: true,
      ),
    );
  }
}
