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
import '../../disclaimer/presentation/disclaimer_dialog.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/theme/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    // Show disclaimer on first launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DisclaimerDialog.showIfNeeded(context, ref);
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      setState(() {
        _urlController.text = text;
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
        _validationError = 'Please paste a video link first.';
      });
      return;
    }

    if (!UrlValidator.isValidYouTubeUrl(rawUrl)) {
      if (rawUrl.contains('list=')) {
        setState(() {
          _validationError = 'Playlists are not supported in MVP. Please paste a single video link.';
        });
      } else {
        setState(() {
          _validationError = 'This link is not a supported YouTube video URL.';
        });
      }
      return;
    }

    setState(() {
      _validationError = null;
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
    final recentDownloads = historyRepo
        .getHistory()
        .where((i) => i.status == DownloadStatus.completed)
        .take(5)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Media Saver'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
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
            // Subtitle & Authorized Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_open_rounded, size: 12, color: AppColors.secondary),
                      SizedBox(width: 6),
                      Text(
                        'Direct CDN Streamer',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main URL Input Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderDark),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Save YouTube Video',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Paste a permitted video link to inspect qualities and save.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // URL Input Field
                  TextField(
                    controller: _urlController,
                    focusNode: _focusNode,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimaryDark),
                    decoration: InputDecoration(
                      hintText: 'https://youtube.com/watch?v=...',
                      prefixIcon: const Icon(Icons.link_rounded, size: 20),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_urlController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                setState(() {
                                  _urlController.clear();
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
                                  color: AppColors.surfaceDark,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.borderDark),
                                ),
                                child: const Text(
                                  'PASTE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    onChanged: (_) {
                      if (_validationError != null) {
                        setState(() {
                          _validationError = null;
                        });
                      }
                    },
                    onSubmitted: (_) => _onCheckVideo(),
                  ),

                  // Validation Error or Inspect Error
                  if (_validationError != null || inspectState.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _validationError ?? inspectState.errorMessage ?? '',
                              style: const TextStyle(fontSize: 12, color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(),
                  ],

                  const SizedBox(height: 20),

                  // Primary "Check Video" Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
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
                              Icon(Icons.search_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Check Video',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Recent Downloads Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Downloads',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                if (recentDownloads.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const HistoryScreen()),
                      );
                    },
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Recent Downloads Content
            if (recentDownloads.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.cardDark.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.5)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.download_for_offline_outlined,
                        size: 40,
                        color: AppColors.textMutedDark.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No downloads yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Paste a link above to save your first video.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMutedDark,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...recentDownloads.map((item) => _buildRecentItemCard(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItemCard(DownloadItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 80,
              height: 52,
              child: item.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.surfaceElevatedDark,
                        child: const Icon(Icons.movie_outlined, size: 20),
                      ),
                    )
                  : Container(
                      color: AppColors.surfaceElevatedDark,
                      child: const Icon(Icons.movie_outlined, size: 20),
                    ),
            ),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.qualityLabel} · ${Formatters.formatBytes(item.fileSizeBytes)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMutedDark,
                  ),
                ),
              ],
            ),
          ),

          // Play button
          IconButton(
            icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 30),
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
