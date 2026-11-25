import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/config/app_config.dart';
import '../../../core/compliance/source_policy.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/media_launcher.dart';
import '../../../core/utils/url_validator.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/category_badge.dart';
import '../../../core/widgets/progress_card.dart';
import '../../../core/widgets/save_orb.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../downloads/domain/download_item.dart';
import '../../downloads/presentation/download_controller.dart';
import '../../history/presentation/history_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../whatsapp_status/presentation/whatsapp_status_screen.dart';
import '../../watch/presentation/watch_screen.dart';
import 'album_details_sheet.dart';
import 'inspect_controller.dart';
import 'video_details_sheet.dart';
import '../../../core/ecosystem/play_update_service.dart';
import '../../../core/services/share_receiver_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  int _currentTab = 0; // 0: Home, 1: Browse, 2: Status, 3: Library, 4: Settings
  MediaPlatform _detectedPlatform = MediaPlatform.unsupported;
  String? _validationError;
  String? _clipboardDetectedUrl;
  bool _dismissedClipboardBanner = false;
  MediaCategory _selectedCategoryFilter = MediaCategory.all;
  StreamSubscription<String>? _shareSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _urlController.addListener(_onUrlChanged);
    _checkClipboardForLink();
    _initShareReceiver();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PlayUpdateService().checkUpdateOnLifecycleResume();
    });
  }

  void _initShareReceiver() {
    final shareService = ref.read(shareReceiverServiceProvider);

    // 1. Listen for incoming shares while app is open / alive
    _shareSubscription = shareService.onShareReceived.listen((text) {
      _processIncomingShare(text);
    });

    // 2. Check for cold-start share intent when launching
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = await shareService.getInitialSharedText();
      if (initial != null && initial.trim().isNotEmpty) {
        _processIncomingShare(initial);
      }
    });
  }

  Future<void> _processIncomingShare(String sharedText) async {
    if (!mounted) return;

    final url = UrlValidator.extractFirstSupportedUrl(sharedText) ??
        (UrlValidator.isValidUrl(sharedText.trim()) ? sharedText.trim() : null);

    final targetUrl = url ??
        RegExp(r'https?://[^\s<>"{}|\\^`]+')
            .firstMatch(sharedText)
            ?.group(0)
            ?.replaceAll(RegExp(r'[.,)!?]+$'), '');

    if (targetUrl != null && targetUrl.isNotEmpty) {
      setState(() {
        _currentTab = 0; // Switch to Home tab immediately
        _urlController.text = targetUrl;
        _detectedPlatform = UrlValidator.detectPlatform(targetUrl);
        _validationError = null;
        _clipboardDetectedUrl = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.link_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Opening shared link...',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 1500),
          ),
        );
      }

      await _inspectAndDownload();
    }
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForLink();
      PlayUpdateService().checkUpdateOnLifecycleResume();
      ref.read(shareReceiverServiceProvider).getInitialSharedText().then((shared) {
        if (shared != null && shared.trim().isNotEmpty) {
          _processIncomingShare(shared);
        }
      });
    }
  }

  Future<void> _checkClipboardForLink() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isNotEmpty && UrlValidator.isValidUrl(text)) {
        final platform = UrlValidator.detectPlatform(text);
        if (platform != MediaPlatform.unsupported && text != _urlController.text.trim()) {
          if (mounted) {
            setState(() {
              _clipboardDetectedUrl = text;
              _dismissedClipboardBanner = false;
            });
          }
        }
      }
    } catch (_) {}
  }

  void _onUrlChanged() {
    final text = _urlController.text.trim();
    final platform = UrlValidator.detectPlatform(text);
    if (platform != _detectedPlatform) {
      setState(() {
        _detectedPlatform = platform;
        _validationError = null;
      });
    }
  }

  MediaCategory _platformToCategory(dynamic platform) {
    if (platform is MediaPlatform) {
      switch (platform) {
        case MediaPlatform.youtube:
        case MediaPlatform.youtubePlaylist:
          return MediaCategory.video;
        case MediaPlatform.instagramReel:
        case MediaPlatform.instagramPost:
        case MediaPlatform.instagramStory:
        case MediaPlatform.facebookVideo:
        case MediaPlatform.twitterVideo:
          return MediaCategory.clips;
        case MediaPlatform.spotifyTrack:
        case MediaPlatform.spotifyAlbum:
        case MediaPlatform.spotifyPlaylist:
          return MediaCategory.music;
        default:
          return MediaCategory.video;
      }
    }
    final pStr = platform.toString().toLowerCase();
    if (pStr.contains('spotify') || pStr.contains('music') || pStr.contains('audio')) {
      return MediaCategory.music;
    }
    if (pStr.contains('instagram') || pStr.contains('reel') || pStr.contains('clips') || pStr.contains('facebook')) {
      return MediaCategory.clips;
    }
    if (pStr.contains('status') || pStr.contains('whatsapp')) {
      return MediaCategory.status;
    }
    return MediaCategory.video;
  }

  Future<void> _pasteFromClipboard() async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      setState(() {
        _urlController.text = text;
        _detectedPlatform = UrlValidator.detectPlatform(text);
        _validationError = null;
        _clipboardDetectedUrl = null;
      });
      _inspectAndDownload();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
    }
  }

  Future<void> _inspectAndDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _validationError = 'Please paste a valid media link first.';
      });
      return;
    }

    final platform = UrlValidator.detectPlatform(url);

    // Google Play Store policy checks
    if (AppConfig.isPlayStoreBuild &&
        (platform == MediaPlatform.youtube || platform == MediaPlatform.youtubePlaylist)) {
      setState(() {
        _validationError = SourcePolicy.youtubePlayStoreNotice;
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
    final result = await ref.read(inspectControllerProvider.notifier).checkUrl(url);

    if (result != null && mounted) {
      // Dismiss any open modal bottom sheet so the newly requested video options show cleanly
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);

      final isMultiTrack = (result.isAlbum || result.isPlaylist) &&
          ((result.spotifyTracks != null && result.spotifyTracks!.length > 1) ||
              (result.playlistVideos != null && result.playlistVideos!.length > 1));
      if (isMultiTrack) {
        AlbumDetailsSheet.show(context, result);
      } else {
        VideoDetailsSheet.show(context, result);
      }
    }
  }

  SaveOrbState _resolveOrbState(InspectState inspectState, ActiveDownloadState activeDownload) {
    if (activeDownload.isDownloading) {
      return SaveOrbState.downloading;
    }
    if (inspectState.isLoading) {
      return SaveOrbState.analyzing;
    }
    if (_clipboardDetectedUrl != null && !_dismissedClipboardBanner) {
      return SaveOrbState.linkDetected;
    }
    if (_urlController.text.trim().isNotEmpty && _detectedPlatform != MediaPlatform.unsupported) {
      return SaveOrbState.ready;
    }
    return SaveOrbState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final inspectState = ref.watch(inspectControllerProvider);
    final activeDownload = ref.watch(downloadControllerProvider);
    final allHistory = ref.watch(downloadHistoryProvider);

    final orbState = _resolveOrbState(inspectState, activeDownload);

    return Scaffold(
      extendBody: true,
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Background texture: subtle radial gradient (primary at 6% alpha) at the top of Home only
          if (_currentTab == 0)
            Positioned(
              top: -80,
              left: -50,
              right: -50,
              height: 340,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 0.9,
                      colors: [
                        colors.primary.withValues(alpha: 0.08),
                        colors.primary.withValues(alpha: 0.02),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Main Tab Views
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildHomeBody(context, inspectState, activeDownload, allHistory, orbState),
                WatchScreen(
                  isEmbedded: true,
                  isActive: _currentTab == 1,
                  onBackToHome: () => setState(() => _currentTab = 0),
                  onNavigateToLibrary: () => setState(() => _currentTab = 3),
                ),
                const WhatsAppStatusScreen(isEmbedded: true),
                const HistoryScreen(isEmbedded: true),
                const SettingsScreen(isEmbedded: true),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _currentTab,
        activeDownloadTitle: activeDownload.isDownloading ? (activeDownload.item?.title ?? 'Downloading...') : null,
        activeProgress: activeDownload.progress?.progress ?? 0.0,
        activeSpeed: activeDownload.progress != null
            ? Formatters.formatSpeed(activeDownload.progress!.speedBytesPerSecond)
            : null,
        onDestinationSelected: (index) {
          setState(() {
            _currentTab = index;
          });
        },
      ),
    );
  }

  Widget _buildHomeBody(
    BuildContext context,
    InspectState inspectState,
    ActiveDownloadState activeDownload,
    List<DownloadItem> allHistory,
    SaveOrbState orbState,
  ) {
    final colors = AppColors.of(context);
    final completedDownloads = allHistory
        .where((item) => item.status == DownloadStatus.completed)
        .toList();
    final recentDownloads = completedDownloads.take(8).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: App Name + Tagline + Theme Toggle (A2) ───────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      AppConfig.appName,
                      style: AppTypography.display(context).copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      AppColors.isDark(context)
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: colors.textPrimary,
                      size: 22,
                    ),
                    tooltip: AppColors.isDark(context) ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                AppConfig.appTagline,
                style: AppTypography.subtitle(context).copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ─── Clipboard Detected Banner ─────────────────────────────────────
          if (_clipboardDetectedUrl != null && !_dismissedClipboardBanner) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.7),
                borderRadius: AppRadii.r16,
                border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, size: 20, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Link detected from clipboard',
                          style: AppTypography.caption(context).copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                        Text(
                          _clipboardDetectedUrl!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(context).copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _urlController.text = _clipboardDetectedUrl!;
                        _dismissedClipboardBanner = true;
                      });
                      _inspectAndDownload();
                    },
                    child: const Text('Use Link'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () => setState(() => _dismissedClipboardBanner = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ─── 2) Smart Paste Bar (A1: No grey rectangle, clean pill) ──────
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadii.rPill,
              border: Border.all(
                color: _validationError != null ? colors.error : colors.outline,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Row(
              children: [
                Icon(Icons.link_rounded, color: colors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    focusNode: _focusNode,
                    style: AppTypography.body(context),
                    decoration: InputDecoration(
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Search or paste a link...',
                      hintStyle: AppTypography.body(context, color: colors.textTertiary),
                    ),
                    onSubmitted: (_) => _inspectAndDownload(),
                  ),
                ),
                // Trailing: Clear button when text exists; "Paste" chip when empty
                if (_urlController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    color: colors.textSecondary,
                    tooltip: 'Clear',
                    onPressed: () {
                      _urlController.clear();
                      setState(() {
                        _detectedPlatform = MediaPlatform.unsupported;
                        _validationError = null;
                      });
                    },
                  )
                else
                  Material(
                    color: colors.primaryContainer,
                    borderRadius: AppRadii.rPill,
                    child: InkWell(
                      onTap: _pasteFromClipboard,
                      borderRadius: AppRadii.rPill,
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.content_paste_rounded, size: 16, color: colors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Paste',
                              style: AppTypography.caption(context).copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
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

          // Error message if any
          if (_validationError != null || inspectState.errorMessage != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 16, color: colors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _validationError ?? inspectState.errorMessage ?? '',
                      style: AppTypography.caption(context).copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Category Auto-Detection Badge
          if (_detectedPlatform != MediaPlatform.unsupported) ...[
            const SizedBox(height: 12),
            Center(
              child: CategoryBadge(
                category: _platformToCategory(_detectedPlatform),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // ─── 3) Save Orb Hero Control (A3: 32dp above, 24dp below) ────────
          Center(
            child: SaveOrb(
              state: orbState,
              progress: activeDownload.progress?.progress ?? 0.0,
              speedText: activeDownload.progress != null
                  ? Formatters.formatSpeed(activeDownload.progress!.speedBytesPerSecond)
                  : null,
              onTap: () {
                if (activeDownload.isDownloading) {
                  setState(() => _currentTab = 3);
                } else if (_urlController.text.trim().isNotEmpty) {
                  _inspectAndDownload();
                } else if (_clipboardDetectedUrl != null) {
                  _urlController.text = _clipboardDetectedUrl!;
                  _inspectAndDownload();
                } else {
                  _pasteFromClipboard();
                }
              },
            ),
          ),

          const SizedBox(height: 24),

          // ─── 4) Category Chips (A4: 40dp height, 8dp dot, 12dp spacing) ───
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildQuickChip(context, MediaCategory.video, 'Video'),
              const SizedBox(width: 12),
              _buildQuickChip(context, MediaCategory.clips, 'Clips'),
              const SizedBox(width: 12),
              _buildQuickChip(context, MediaCategory.music, 'Music'),
            ],
          ),

          const SizedBox(height: 16),

          // ─── 5) Full-Width Tonal "Open Watch" Button (A5: 52dp tall) ───────
          Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: AppRadii.r16,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppRadii.r16,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _currentTab = 1);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.play_circle_rounded, size: 22, color: colors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Open Watch',
                          style: AppTypography.subtitle(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 20, color: colors.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── Active Downloads Section ────────────────────────────────────
          if (activeDownload.isDownloading && activeDownload.item != null) ...[
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Active Download',
              trailing: Text(
                activeDownload.progress != null
                    ? Formatters.formatSpeed(activeDownload.progress!.speedBytesPerSecond)
                    : '',
                style: AppTypography.tabularFigures(context, color: colors.primary),
              ),
            ),
            const SizedBox(height: 12),
            ProgressCard(
              title: activeDownload.item!.title,
              thumbnailUrl: activeDownload.item!.thumbnailUrl,
              category: _platformToCategory(activeDownload.item!.platform),
              progress: activeDownload.progress?.progress ?? 0.0,
              speedText: activeDownload.progress != null
                  ? Formatters.formatSpeed(activeDownload.progress!.speedBytesPerSecond)
                  : 'Downloading...',
              etaText: activeDownload.progress != null
                  ? Formatters.formatEta(activeDownload.progress!.etaSeconds)
                  : '',
              downloadedSizeText: Formatters.formatBytes(activeDownload.progress?.downloadedBytes ?? 0),
              onPauseResume: () => ref.read(downloadControllerProvider.notifier).cancelDownload(),
              onCancel: () => ref.read(downloadControllerProvider.notifier).cancelDownload(),
            ),
          ],

          const SizedBox(height: 24),

          // ─── 6) Recently Saved Section (A6: 156dp width, 16:10 thumbnail) ─
          SectionHeader(
            title: 'Recently Saved',
            actionLabel: completedDownloads.isNotEmpty ? 'See all' : null,
            onAction: () => setState(() => _currentTab = 3),
          ),
          const SizedBox(height: 12),

          if (recentDownloads.isEmpty) ...[
            const EmptyState(
              title: 'Paste your first link',
              description: 'Save videos, short clips, music and status media quickly from any link.',
            ),
          ] else ...[
            SizedBox(
              height: 156,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(right: 12),
                itemCount: recentDownloads.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = recentDownloads[index];
                  final category = _platformToCategory(item.platform);

                  return SizedBox(
                    width: 156,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              SizedBox(
                                width: 156,
                                height: 98, // 16:10 aspect ratio
                                child: item.thumbnailUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: item.thumbnailUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) => Container(
                                          color: colors.surfaceAlt,
                                          child: Icon(CategoryBadge.getIcon(category), color: colors.textSecondary),
                                        ),
                                      )
                                    : Container(
                                        color: colors.surfaceAlt,
                                        child: Icon(CategoryBadge.getIcon(category), color: colors.textSecondary),
                                      ),
                              ),
                              Positioned(
                                bottom: 6,
                                right: 6,
                                child: Material(
                                  color: colors.accent,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: () => MediaLauncher.openFile(item.filePath),
                                    customBorder: const CircleBorder(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Icon(Icons.play_arrow_rounded, size: 14, color: colors.onAccent),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(context).copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickChip(BuildContext context, MediaCategory category, String label) {
    final colors = AppColors.of(context);
    final isSelected = _selectedCategoryFilter == category;
    final categoryColor = CategoryBadge.getColor(context, category);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedCategoryFilter = isSelected ? MediaCategory.all : category;
        });
      },
      borderRadius: AppRadii.rPill,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? categoryColor.withValues(alpha: 0.15) : colors.surface,
          borderRadius: AppRadii.rPill,
          border: Border.all(
            color: isSelected ? categoryColor : colors.outline,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 8dp Category Dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: categoryColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            // Tinted Icon
            Icon(
              CategoryBadge.getIcon(category),
              size: 16,
              color: categoryColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.caption(context).copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? categoryColor : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
