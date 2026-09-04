import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
import 'inspect_controller.dart';
import 'video_details_sheet.dart';
import '../../history/presentation/history_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../downloads/presentation/download_controller.dart';
import '../../downloads/presentation/download_detail_screen.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/url_validator.dart';
import '../../downloads/domain/download_item.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _validationError;
  MediaPlatform _detectedPlatform = MediaPlatform.unsupported;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onUrlChanged(String val) {
    final platform = UrlValidator.detectPlatform(val.trim());
    if (platform != _detectedPlatform) {
      setState(() {
        _detectedPlatform = platform;
      });
    }
    if (_validationError != null) {
      setState(() {
        _validationError = null;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      setState(() {
        _urlController.text = text;
        _detectedPlatform = UrlValidator.detectPlatform(text);
        _validationError = null;
      });
      _onCheckVideo();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
    }
  }

  Future<void> _onCheckVideo() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _validationError = 'Please paste a YouTube or Instagram link first.';
      });
      return;
    }

    final platform = UrlValidator.detectPlatform(rawUrl);
    if (platform == MediaPlatform.unsupported) {
      if (rawUrl.contains('list=')) {
        setState(() {
          _validationError = 'Playlists are not supported. Please paste a single video link.';
        });
      } else {
        setState(() {
          _validationError =
              'Please paste a valid YouTube video/Shorts or Instagram Reel/Video/Story URL.';
        });
      }
      return;
    }

    setState(() {
      _validationError = null;
      _detectedPlatform = platform;
    });

    _focusNode.unfocus();
    final result = await ref.read(inspectControllerProvider.notifier).checkUrl(rawUrl);

    if (result != null && mounted) {
      VideoDetailsSheet.show(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inspectState = ref.watch(inspectControllerProvider);
    final historyRepo = ref.watch(historyRepositoryProvider);
    final activeDownload = ref.watch(downloadControllerProvider);
    final isDark = AppColors.isDark(context);

    final recentDownloads = historyRepo
        .getHistory()
        .where((i) => i.status == DownloadStatus.completed)
        .take(5)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.violetGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Video Downloader',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.5,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
        actions: [
          // Quick Theme Toggle Button
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey(isDark),
                color: isDark ? const Color(0xFFFBBF24) : AppColors.primary,
              ),
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
          IconButton(
            icon: Icon(Icons.history_rounded, color: AppColors.textPrimary(context)),
            tooltip: 'History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: AppColors.textPrimary(context)),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // Supported Platforms Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildPlatformTag(
                    context: context,
                    icon: Icons.play_arrow_rounded,
                    label: 'YouTube & Shorts',
                    color: const Color(0xFFFF0033),
                  ),
                  const SizedBox(width: 8),
                  _buildPlatformTag(
                    context: context,
                    icon: Icons.camera_alt_outlined,
                    label: 'Instagram Reels & Stories',
                    gradient: AppColors.instagramGradient,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Main URL Input Card (Violet Amethyst Glow)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border(context), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Download Video or Reel',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                      if (_detectedPlatform != MediaPlatform.unsupported) ...[
                        const SizedBox(width: 8),
                        _buildDetectedPlatformBadge(_detectedPlatform),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Paste a YouTube or Instagram link to inspect and save.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // URL Input Field
                  TextField(
                    controller: _urlController,
                    focusNode: _focusNode,
                    style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'https://youtube.com/... or https://instagram.com/reel/...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted(context),
                      ),
                      prefixIcon: Icon(Icons.link_rounded, size: 20, color: AppColors.primary),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_urlController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted(context)),
                              onPressed: () {
                                setState(() {
                                  _urlController.clear();
                                  _detectedPlatform = MediaPlatform.unsupported;
                                  _validationError = null;
                                });
                              },
                            ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: _pasteFromClipboard,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                ),
                                child: const Text(
                                  'PASTE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    onChanged: _onUrlChanged,
                    onSubmitted: (_) => _onCheckVideo(),
                  ),

                  // Validation Error or Inspect Error
                  if (_validationError != null || inspectState.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _validationError ?? inspectState.errorMessage ?? '',
                              style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(),
                  ],

                  const SizedBox(height: 20),

                  // Primary "Check Video" Button
                  Container(
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
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: inspectState.isLoading ? null : _onCheckVideo,
                      child: inspectState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_rounded, size: 20, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Check Video',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Active Download Progress Card (if actively downloading)
            if (activeDownload.isDownloading && activeDownload.item != null) ...[
              const SizedBox(height: 24),
              _buildActiveDownloadCard(context, activeDownload),
            ],

            const SizedBox(height: 32),

            // Recent Downloads Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Downloads',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                if (recentDownloads.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const HistoryScreen()),
                      );
                    },
                    child: const Text('View All', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Recent Downloads Content
            if (recentDownloads.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.download_for_offline_outlined,
                          size: 36,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No downloads yet',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Paste a link above to save your first video or reel.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...recentDownloads.map((item) => _buildRecentItemCard(context, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformTag({
    required BuildContext context,
    required IconData icon,
    required String label,
    Color? color,
    Gradient? gradient,
  }) {
    final isDark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primary).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (color ?? AppColors.primary).withValues(alpha: isDark ? 0.35 : 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (gradient != null)
            ShaderMask(
              shaderCallback: (bounds) => gradient.createShader(bounds),
              child: Icon(icon, size: 13, color: Colors.white),
            )
          else
            Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedPlatformBadge(MediaPlatform platform) {
    final isIg = platform == MediaPlatform.instagramReel ||
        platform == MediaPlatform.instagramPost ||
        platform == MediaPlatform.instagramStory;

    final label = platform == MediaPlatform.instagramReel
        ? 'Instagram Reel'
        : (platform == MediaPlatform.instagramStory
            ? 'Instagram Story'
            : (platform == MediaPlatform.instagramPost
                ? 'Instagram Video'
                : 'YouTube Video'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: isIg ? AppColors.instagramGradient : null,
        color: isIg ? null : const Color(0xFFFF0033),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isIg ? AppColors.instagramPink : Colors.red).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isIg ? Icons.camera_alt_outlined : Icons.play_arrow_rounded,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack);
  }

  Widget _buildActiveDownloadCard(BuildContext context, ActiveDownloadState activeState) {
    final item = activeState.item!;
    final progress = activeState.progress;
    final progressFraction = progress?.progress ?? 0.0;
    final percentInt = (progressFraction * 100).clamp(0, 100).toInt();
    final speed = Formatters.formatSpeed(progress?.speedBytesPerSecond ?? 0);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const DownloadDetailScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: item.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(
                              color: AppColors.surfaceElevated(context),
                              child: const Icon(Icons.movie_outlined, size: 20),
                            ),
                          )
                        : Container(
                            color: AppColors.surfaceElevated(context),
                            child: const Icon(Icons.movie_outlined, size: 20),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        progress?.stage ?? 'Downloading...',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$percentInt%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressFraction > 0 ? progressFraction : null,
                minHeight: 8,
                backgroundColor: AppColors.surfaceElevated(context),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  speed,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted(context),
                  ),
                ),
                Text(
                  'Tap for details',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItemCard(BuildContext context, DownloadItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          // Thumbnail with platform badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 80,
                  height: 52,
                  child: item.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            color: AppColors.surfaceElevated(context),
                            child: const Icon(Icons.movie_outlined, size: 20),
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceElevated(context),
                          child: const Icon(Icons.movie_outlined, size: 20),
                        ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    item.isInstagram
                        ? Icons.camera_alt_outlined
                        : Icons.play_arrow_rounded,
                    size: 11,
                    color: item.isInstagram ? AppColors.instagramPink : const Color(0xFFFF0033),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.author} · ${item.qualityLabel} · ${Formatters.formatBytes(item.fileSizeBytes)}',
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

          // Play button
          IconButton(
            icon: const Icon(Icons.play_circle_fill_rounded,
                color: AppColors.primary, size: 32),
            tooltip: 'Play',
            onPressed: () {
              OpenFilex.open(item.filePath);
            },
          ),
        ],
      ),
    );
  }
}
