import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class PlayUpdateService {
  static const MethodChannel _channel = MethodChannel('app.mediaurl.applicaiton/playcore');

  /// Queries Google Play Store for available native in-app updates.
  /// Note: Real Play Store updates require the app to be downloaded from Google Play
  /// with a newer versionCode published on Play Console.
  static Future<bool> checkForUpdate() async {
    try {
      final isAvailable = await _channel.invokeMethod<bool>('checkForUpdate');
      return isAvailable ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Triggers completion/restart for a downloaded flexible update.
  static Future<bool> completeUpdate() async {
    try {
      final completed = await _channel.invokeMethod<bool>('completeUpdate');
      return completed ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Displays the native Google Play-style In-App Update bottom sheet.
  /// Allows testing and previewing the complete flexible update workflow
  /// on debug and local builds without needing an active Play Store release.
  static Future<void> showUpdateBottomSheet(
    BuildContext context, {
    bool isSimulated = true,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _GooglePlayUpdateSheet(isSimulated: isSimulated),
    );
  }
}

class _GooglePlayUpdateSheet extends StatefulWidget {
  final bool isSimulated;
  const _GooglePlayUpdateSheet({required this.isSimulated});

  @override
  State<_GooglePlayUpdateSheet> createState() => _GooglePlayUpdateSheetState();
}

class _GooglePlayUpdateSheetState extends State<_GooglePlayUpdateSheet> {
  bool _isDownloading = false;
  double _progress = 0.0;
  Timer? _progressTimer;

  void _startDownload() {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
    });

    _progressTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      setState(() {
        _progress += 0.05;
        if (_progress >= 1.0) {
          _progress = 1.0;
          timer.cancel();
          _onDownloadFinished();
        }
      });
    });
  }

  void _onDownloadFinished() {
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'An update has been downloaded.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'RESTART',
          textColor: const Color(0xFF00E676),
          onPressed: () {
            PlayUpdateService.completeUpdate();
          },
        ),
        backgroundColor: const Color(0xFF202124),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1F1F1F);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF5F6368);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header with App Icon & Google Play branding
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: AppColors.violetGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.download_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Video Downloader',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: Color(0xFF01875F), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Google Play Store',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF01875F),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· 14.8 MB',
                          style: TextStyle(fontSize: 12, color: secondaryTextColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            'Update available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'To get the latest improvements, download performance updates, and Spotify music support, update now.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: secondaryTextColor,
            ),
          ),

          const SizedBox(height: 16),

          // What's New Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F3F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "What's New in v1.1.0",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                _buildBullet(isDark, '🎵 Direct Spotify track & music audio downloading'),
                _buildBullet(isDark, '⚡ 2x faster background download streaming'),
                _buildBullet(isDark, '🖤 Pure Black OLED dark mode & floating bottom bar'),
                _buildBullet(isDark, '▶️ Native video player integration with fallback'),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Progress or Action Buttons
          if (_isDownloading) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Downloading update in background...',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textColor),
                    ),
                    Text(
                      '%',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF01875F)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: isDark ? Colors.white12 : Colors.black12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF01875F)),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can continue using the app while the update downloads.',
                  style: TextStyle(fontSize: 11.5, color: secondaryTextColor),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'No thanks',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF01875F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBullet(bool isDark, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
