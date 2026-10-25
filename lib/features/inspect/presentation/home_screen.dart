import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/media_launcher.dart';
import 'inspect_controller.dart';
import 'video_details_sheet.dart';
import 'album_details_sheet.dart';
import '../../history/presentation/history_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../whatsapp_status/presentation/whatsapp_status_screen.dart';
import '../../youtube_browser/presentation/youtube_browser_screen.dart';
import '../../downloads/presentation/download_controller.dart';
import '../../downloads/presentation/download_detail_screen.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/url_validator.dart';
import '../../../core/services/share_receiver_service.dart';
// media_export_service used in history/settings screens only
import '../../downloads/domain/download_item.dart';
import '../../../core/config/app_config.dart';
import '../../../core/compliance/source_policy.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/theme/liquid_glass_tokens.dart';
import '../../../core/widgets/liquid_glass_surface.dart';
import '../../../core/widgets/liquid_glass_card.dart';

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
  int _currentTab = 0; // 0: Downloader, 1: YouTube, 2: Status Saver, 3: Downloads, 4: Settings
  StreamSubscription<String>? _shareSubscription;

  @override
  void initState() {
    super.initState();
    _initShareReceiver();
  }

  void _initShareReceiver() {
    final shareService = ref.read(shareReceiverServiceProvider);

    // Listen for incoming share intents while app is running
    _shareSubscription = shareService.onShareReceived.listen((text) {
      _processIncomingShare(text);
    });

    // Check for cold-start share intent
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialText = await shareService.getInitialSharedText();
      if (initialText != null && initialText.isNotEmpty) {
        _processIncomingShare(initialText);
      }
    });
  }

  void _processIncomingShare(String sharedText) {
    if (!mounted) return;

    final url = UrlValidator.extractFirstSupportedUrl(sharedText) ??
        (UrlValidator.isValidUrl(sharedText.trim()) ? sharedText.trim() : null);

    if (url != null) {
      final platform = UrlValidator.detectPlatform(url);

      if (AppConfig.isPlayStoreBuild &&
          (platform == MediaPlatform.youtube || platform == MediaPlatform.youtubePlaylist)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(SourcePolicy.youtubePlayStoreNotice),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      setState(() {
        _currentTab = 0; // Switch to Downloader tab
        _urlController.text = url;
        _detectedPlatform = platform;
        _validationError = null;
      });

      final platformName = _detectedPlatform == MediaPlatform.youtube
          ? 'YouTube'
          : (_detectedPlatform == MediaPlatform.spotifyTrack
              ? 'Spotify'
              : (_detectedPlatform == MediaPlatform.facebookVideo
                  ? 'Facebook'
                  : (_detectedPlatform == MediaPlatform.instagramReel
                      ? 'Instagram Reel'
                      : 'Instagram')));

      final snackColor = _detectedPlatform == MediaPlatform.spotifyTrack
          ? const Color(0xFF1DB954)
          : (_detectedPlatform == MediaPlatform.facebookVideo
              ? const Color(0xFF1877F2)
              : AppColors.primary);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.share_arrival_time_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Opening $platformName link...',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: snackColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      _onCheckVideo();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppConfig.isPlayStoreBuild
              ? 'Received shared link, but no supported Instagram or Facebook link was found.'
              : 'Received shared link, but no supported YouTube, Instagram, Spotify, or Facebook link was found.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
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
        _validationError = AppConfig.isPlayStoreBuild
            ? 'Please paste an Instagram or Facebook link first.'
            : 'Please paste a YouTube, Instagram, Spotify or Facebook link first.';
      });
      return;
    }

    final platform = UrlValidator.detectPlatform(rawUrl);

    // Fail immediately if YouTube in Google Play build
    if (AppConfig.isPlayStoreBuild &&
        (platform == MediaPlatform.youtube || platform == MediaPlatform.youtubePlaylist)) {
      setState(() {
        _validationError = SourcePolicy.youtubePlayStoreNotice;
      });
      return;
    }

    // Fail immediately if Spotify in Google Play build
    if (AppConfig.isPlayStoreBuild &&
        (platform == MediaPlatform.spotifyTrack ||
            platform == MediaPlatform.spotifyAlbum ||
            platform == MediaPlatform.spotifyPlaylist)) {
      setState(() {
        _validationError = SourcePolicy.getPolicy(platform, isPlayStoreBuild: true).policyNotice;
      });
      return;
    }

    if (platform == MediaPlatform.unsupported) {
      setState(() {
        _validationError = SourcePolicy.failSafeNotice;
      });
      return;
    }

    setState(() {
      _validationError = null;
      _detectedPlatform = platform;
    });

    _focusNode.unfocus();
    final result = await ref.read(inspectControllerProvider.notifier).checkUrl(rawUrl);

    if (result != null && mounted) {
      final isRealMultiTrackAlbum = (result.isAlbum || result.isPlaylist) &&
          ((result.spotifyTracks != null && result.spotifyTracks!.length > 1) ||
              (result.playlistVideos != null && result.playlistVideos!.length > 1));
      if (isRealMultiTrackAlbum) {
        AlbumDetailsSheet.show(context, result);
      } else {
        VideoDetailsSheet.show(context, result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inspectState = ref.watch(inspectControllerProvider);
    final allHistory = ref.watch(downloadHistoryProvider);
    final activeDownload = ref.watch(downloadControllerProvider);
    final isDark = AppColors.isDark(context);

    final allCompleted = allHistory
        .where((i) => i.status == DownloadStatus.completed)
        .toList();

    final recentDownloads = allCompleted.take(6).toList();

    return PopScope(
      canPop: _currentTab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentTab != 0) {
          if (_currentTab == 1) {
            return;
          }
          setState(() {
            _currentTab = 0;
          });
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: AppColors.background(context),
        appBar: _currentTab == 1
            ? null
            : AppBar(
                titleSpacing: 16,
                title: _buildAppBarTitle(context),
                actions: _buildAppBarActions(context, isDark, allCompleted.isNotEmpty),
              ),
        body: SafeArea(
          bottom: false,
          child: _buildBody(
            context,
            inspectState,
            allCompleted,
            recentDownloads,
            activeDownload,
            isDark,
          ),
        ),
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: _currentTab,
          onDestinationSelected: (index) {
            setState(() {
              _currentTab = index;
            });
          },
        ),
      ),
    );
  }

  Widget _buildAppBarTitle(BuildContext context) {
    if (_currentTab == 2) {
      return Text(
        'WhatsApp Statuses',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: -0.3,
        ),
      );
    }

    if (_currentTab == 3) {
      return Text(
        'Downloads',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: -0.3,
        ),
      );
    }

    if (_currentTab == 4) {
      return Text(
        'Settings',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: -0.3,
        ),
      );
    }

    // Default Tab 0: Downloader - Clean header without PRO badge
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer(context),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            Icons.download_rounded,
            color: AppColors.primaryOf(context),
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            AppConfig.appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, bool isDark, bool hasHistory) {
    return [
      AppIconButton(
        icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        color: isDark ? const Color(0xFFFBBF24) : AppColors.primaryOf(context),
        tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
        onPressed: () {
          HapticFeedback.lightImpact();
          ref.read(themeModeProvider.notifier).toggleTheme();
        },
      ),
      const SizedBox(width: 8),
    ];
  }

  Widget _buildBody(
    BuildContext context,
    InspectState inspectState,
    List<DownloadItem> allCompleted,
    List<DownloadItem> recentDownloads,
    ActiveDownloadState activeDownload,
    bool isDark,
  ) {
    switch (_currentTab) {
      case 1:
        return YouTubeBrowserScreen(
          isEmbedded: true,
          onBackToHome: () {
            setState(() {
              _currentTab = 0;
            });
          },
        );
      case 2:
        return const WhatsAppStatusScreen(isEmbedded: true);
      case 3:
        return const HistoryScreen(isEmbedded: true);
      case 4:
        return const SettingsScreen(isEmbedded: true);
      default:
        return _buildDownloaderBody(
          context,
          inspectState,
          allCompleted,
          recentDownloads,
          activeDownload,
          isDark,
        );
    }
  }

  Widget _buildDownloaderBody(
    BuildContext context,
    InspectState inspectState,
    List<DownloadItem> allCompleted,
    List<DownloadItem> recentDownloads,
    ActiveDownloadState activeDownload,
    bool isDark,
  ) {
    final hasError = _validationError != null || inspectState.errorMessage != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        // ─── URL Input Field ───────────────────────────────────────────────
        LiquidGlassSurface(
          borderRadius: BorderRadius.circular(14),
          blurSigma: LiquidGlassTokens.blurStandard,
          surfaceColor: LiquidGlassTokens.surface(context),
          borderColor: hasError ? AppColors.error : LiquidGlassTokens.border(context),
          borderWidth: hasError ? 1.2 : 0.8,
          child: TextField(
            controller: _urlController,
            focusNode: _focusNode,
            style: AppTypography.body(context),
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              hintText: AppConfig.isPlayStoreBuild
                  ? 'Paste an Instagram or Facebook link...'
                  : 'Paste a media link...',
              hintStyle: AppTypography.supporting(context),
              prefixIcon: Icon(Icons.link_rounded, size: 20, color: AppColors.primaryOf(context)),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_urlController.text.isNotEmpty)
                    AppIconButton(
                      icon: Icons.close_rounded,
                      size: 18,
                      tooltip: 'Clear',
                      onPressed: () => setState(() {
                        _urlController.clear();
                        _detectedPlatform = MediaPlatform.unsupported;
                        _validationError = null;
                      }),
                    ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: isDark ? const Color(0x33B49AFF) : const Color(0x207045E8),
                        foregroundColor: AppColors.primaryOf(context),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(Icons.content_paste_rounded, size: 14, color: AppColors.primaryOf(context)),
                      label: Text(
                        'Paste',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryOf(context),
                        ),
                      ),
                      onPressed: _pasteFromClipboard,
                    ),
                  ),
                ],
              ),
            ),
            onChanged: _onUrlChanged,
            onSubmitted: (_) => _onCheckVideo(),
          ),
        ),

        // Error message
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _validationError ?? inspectState.errorMessage ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 200.ms),
          ),
        ],

        const SizedBox(height: 12),

        // ─── Inspect Media Action ──────────────────────────────────────────
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOf(context),
              foregroundColor: isDark ? const Color(0xFF101014) : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: inspectState.isLoading ? null : _onCheckVideo,
            child: inspectState.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? const Color(0xFF101014) : Colors.white,
                      ),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_rounded, size: 19),
                      SizedBox(width: 8),
                      Text(
                        'Inspect media',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        // ─── Active Download Card ──────────────────────────────────────────
        if (activeDownload.isDownloading && activeDownload.item != null) ...[
          const SizedBox(height: 18),
          _buildActiveDownloadCard(context, activeDownload),
        ],

        // ─── Recent Downloads Section ──────────────────────────────────────
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent downloads',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppColors.textPrimary(context),
              ),
            ),
            if (allCompleted.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _currentTab = 3),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See all',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryOf(context),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.primaryOf(context),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (recentDownloads.isEmpty)
          const AppEmptyState(
            icon: Icons.download_for_offline_outlined,
            title: 'No downloads yet',
            description: 'Paste a media link above to inspect and download.',
          )
        else
          LiquidGlassCard(
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: recentDownloads.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: LiquidGlassTokens.border(context),
                      ),
                    _buildSimpleHistoryTile(context, item),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildActiveDownloadCard(BuildContext context, ActiveDownloadState activeState) {
    final item = activeState.item!;
    final progress = activeState.progress;
    final progressFraction = progress?.progress ?? 0.0;
    final percentInt = (progressFraction * 100).clamp(0, 100).toInt();
    final speed = Formatters.formatSpeed(progress?.speedBytesPerSecond ?? 0);

    return LiquidGlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const DownloadDetailScreen()),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: AppRadii.r8,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: item.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
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
                      style: AppTypography.cardTitle(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      progress?.stage ?? 'Downloading...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$percentInt%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryOf(context),
                ),
              ),
            ],
          ),
          AppSpacing.gapMd,
          ClipRRect(
            borderRadius: AppRadii.r8,
            child: LinearProgressIndicator(
              value: progressFraction > 0 ? progressFraction : null,
              minHeight: 6,
              backgroundColor: AppColors.surfaceElevated(context),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOf(context)),
            ),
          ),
          AppSpacing.gapSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                speed,
                style: AppTypography.metadata(context),
              ),
              Text(
                'Tap for details',
                style: AppTypography.metadata(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleHistoryTile(BuildContext context, DownloadItem item) {
    final isDark = AppColors.isDark(context);
    final isImage = item.isImage;
    final isAudio = item.isAudio;

    final Color platformColor = item.isSpotify
        ? const Color(0xFF1DB954)
        : (item.isFacebook
            ? const Color(0xFF1877F2)
            : (item.isInstagram ? AppColors.instagramPink : AppColors.youtubeRed));
    final String platformLabel = item.isSpotify
        ? 'Spotify'
        : (item.isFacebook
            ? 'Facebook'
            : (item.isInstagram ? 'Instagram' : 'YouTube'));

    return InkWell(
      onTap: () => MediaLauncher.openMedia(context, item.filePath, title: item.title),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52,
                height: 52,
                child: item.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            _buildThumbnailFallback(context, isImage: isImage, isAudio: isAudio),
                      )
                    : _buildThumbnailFallback(context, isImage: isImage, isAudio: isAudio),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: platformColor.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          platformLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: platformColor,
                          ),
                        ),
                      ),
                      if (item.durationSeconds > 0 && !isImage) ...[
                        const SizedBox(width: 6),
                        Text(
                          Formatters.formatDuration(Duration(seconds: item.durationSeconds)),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                      if (item.qualityLabel.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.qualityLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Play / Audio / Photo button
            GestureDetector(
              onTap: () => MediaLauncher.openMedia(context, item.filePath, title: item.title),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x26FFFFFF) : const Color(0x167045E8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isImage
                      ? Icons.image_rounded
                      : (isAudio ? Icons.music_note_rounded : Icons.play_arrow_rounded),
                  size: 18,
                  color: AppColors.primaryOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailFallback(BuildContext context, {required bool isImage, required bool isAudio}) {
    return Container(
      color: AppColors.surfaceElevated(context),
      child: Center(
        child: Icon(
          isImage
              ? Icons.image_rounded
              : (isAudio ? Icons.music_note_rounded : Icons.movie_outlined),
          size: 26,
          color: AppColors.textMuted(context),
        ),
      ),
    );
  }
}

