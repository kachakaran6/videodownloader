import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/media_launcher.dart';

class AppVideoPlayerView extends StatefulWidget {
  final String filePath;
  final bool autoPlay;
  final bool loop;
  final VoidCallback? onFinished;

  const AppVideoPlayerView({
    super.key,
    required this.filePath,
    this.autoPlay = true,
    this.loop = true,
    this.onFinished,
  });

  static Future<void> showModal(
    BuildContext context, {
    required String filePath,
    String? title,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'In-App Video Player',
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title ?? filePath.split(Platform.pathSeparator).last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 20),
                        tooltip: 'Open with External Player',
                        onPressed: () {
                          MediaLauncher.openMedia(
                            context,
                            filePath,
                            title: title,
                            preferInApp: false,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AppVideoPlayerView(
                        filePath: filePath,
                        autoPlay: true,
                        loop: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  State<AppVideoPlayerView> createState() => _AppVideoPlayerViewState();
}

class _AppVideoPlayerViewState extends State<AppVideoPlayerView> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant AppVideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _disposePlayer();
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    setState(() {
      _isInitialized = false;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final file = File(widget.filePath);
      if (!file.existsSync() || file.lengthSync() == 0) {
        throw Exception('Video file not found or empty');
      }

      _controller = VideoPlayerController.file(file);

      await _controller.initialize();
      await _controller.setLooping(widget.loop);

      _controller.addListener(_onControllerUpdate);

      if (widget.autoPlay && mounted) {
        await _controller.play();
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _startHideControlsTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    if (_controller.value.position >= _controller.value.duration &&
        _controller.value.duration > Duration.zero &&
        !widget.loop) {
      widget.onFinished?.call();
    }

    setState(() {});
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_controller.value.isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _controller.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;

    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showControls = true;
        _hideControlsTimer?.cancel();
      } else {
        _controller.play();
        _startHideControlsTimer();
      }
    });
  }

  void _toggleMute() {
    if (!_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _seekTo(Duration position) {
    if (!_isInitialized) return;
    _controller.seekTo(position);
    _startHideControlsTimer();
  }

  void _disposePlayer() {
    _hideControlsTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorState();
    }

    if (!_isInitialized) {
      return _buildLoadingState();
    }

    final isPlaying = _controller.value.isPlaying;
    final position = _controller.value.position;
    final duration = _controller.value.duration;

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
          if (_showControls && isPlaying) {
            _startHideControlsTimer();
          }
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video Surface
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),

            // Controls Overlay
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.65),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Center Play / Pause Button
                      Center(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(50),
                          onTap: _togglePlayPause,
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),

                      // Top Controls (Mute Button)
                      Positioned(
                        top: 8,
                        right: 12,
                        child: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          onPressed: _toggleMute,
                        ),
                      ),

                      // Bottom Progress & Timestamp Bar
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 12,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Scrubber
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3.5,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: position.inMilliseconds.toDouble().clamp(
                                      0.0,
                                      duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                                    ),
                                min: 0.0,
                                max: duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                                onChanged: (value) {
                                  _seekTo(Duration(milliseconds: value.toInt()));
                                },
                              ),
                            ),
                            // Timestamps
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black45,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1834).withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Loading video...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.orangeAccent, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Unable to play video in-app',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Unsupported format or corrupted file.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open in external player'),
              onPressed: () {
                MediaLauncher.openMedia(context, widget.filePath);
              },
            ),
          ],
        ),
      ),
    );
  }
}
