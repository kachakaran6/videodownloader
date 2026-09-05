import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/whatsapp_status_service.dart';
import '../../domain/whatsapp_status_item.dart';

class StatusThumbnailWidget extends ConsumerStatefulWidget {
  final WhatsAppStatusItem item;
  final BoxFit fit;

  const StatusThumbnailWidget({
    super.key,
    required this.item,
    this.fit = BoxFit.cover,
  });

  @override
  ConsumerState<StatusThumbnailWidget> createState() => _StatusThumbnailWidgetState();
}

class _StatusThumbnailWidgetState extends ConsumerState<StatusThumbnailWidget> {
  String? _resolvedThumbPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initThumbnail();
  }

  @override
  void didUpdateWidget(covariant StatusThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path ||
        oldWidget.item.thumbnailPath != widget.item.thumbnailPath) {
      _initThumbnail();
    }
  }

  void _initThumbnail() {
    if (!widget.item.isVideo) return;

    if (widget.item.thumbnailPath != null &&
        File(widget.item.thumbnailPath!).existsSync()) {
      _resolvedThumbPath = widget.item.thumbnailPath;
      return;
    }

    _fetchThumbnail();
  }

  Future<void> _fetchThumbnail() async {
    if (!mounted || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      final service = ref.read(whatsappStatusServiceProvider);
      final thumb = await service.getVideoThumbnail(widget.item.path);
      if (mounted) {
        setState(() {
          _resolvedThumbPath = thumb;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!widget.item.isVideo) {
      // Photo Status
      return Image.file(
        File(widget.item.path),
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildFallbackPlaceholder(isDark),
      );
    }

    // Video Status
    if (_resolvedThumbPath != null && File(_resolvedThumbPath!).existsSync()) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(_resolvedThumbPath!),
            fit: widget.fit,
            errorBuilder: (context, error, stackTrace) => _buildFallbackPlaceholder(isDark),
          ),
          _buildPlayOverlay(),
        ],
      );
    }

    // While generating or loading thumbnail
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildLoadingPlaceholder(isDark),
        _buildPlayOverlay(),
      ],
    );
  }

  Widget _buildPlayOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E1834), const Color(0xFF120E22)]
              : [const Color(0xFFE8E5F5), const Color(0xFFDCD7F0)],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackPlaceholder(bool isDark) {
    return Container(
      color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight,
      child: Center(
        child: Icon(
          widget.item.isVideo ? Icons.videocam_rounded : Icons.image_rounded,
          color: AppColors.textMuted(context),
          size: 36,
        ),
      ),
    );
  }
}
