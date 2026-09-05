import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/media_launcher.dart';
import 'inspect_controller.dart';
import 'video_details_sheet.dart';
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
  String _selectedCategory = 'all'; // 'all', 'youtube', 'instagram'
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
      setState(() {
        _currentTab = 0; // Switch to Downloader tab
        _urlController.text = url;
        _detectedPlatform = UrlValidator.detectPlatform(url);
        _validationError = null;
      });

      final platformName = _detectedPlatform == MediaPlatform.youtube
          ? 'YouTube'
          : (_detectedPlatform == MediaPlatform.spotifyTrack
              ? 'Spotify'
              : (_detectedPlatform == MediaPlatform.instagramReel
                  ? 'Instagram Reel'
                  : 'Instagram'));

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
          backgroundColor: _detectedPlatform == MediaPlatform.spotifyTrack
              ? const Color(0xFF1DB954)
              : AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      _onCheckVideo();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Received shared link, but no supported YouTube, Instagram, or Spotify link was found.'),
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
    final allHistory = ref.watch(downloadHistoryProvider);
    final activeDownload = ref.watch(downloadControllerProvider);
    final isDark = AppColors.isDark(context);

    final allCompleted = allHistory
        .where((i) => i.status == DownloadStatus.completed)
        .toList();

    final recentDownloads = allCompleted.where((item) {
      if (_selectedCategory == 'youtube') return item.isYouTube;
      if (_selectedCategory == 'instagram') return item.isInstagram;
      if (_selectedCategory == 'spotify') return item.isSpotify;
      return true;
    }).take(6).toList();

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
        backgroundColor: AppColors.background(context),
        appBar: _currentTab == 1
            ? null
            : AppBar(
                titleSpacing: 16,
                title: _buildAppBarTitle(context),
                actions: _buildAppBarActions(context, isDark, allCompleted.isNotEmpty),
              ),
        body: SafeArea(
          child: _buildBody(
            context,
            inspectState,
            allCompleted,
            recentDownloads,
            activeDownload,
            isDark,
          ),
        ),
        bottomNavigationBar: _buildFloatingBottomNav(context),
      ),
    );
  }

  Widget _buildAppBarTitle(BuildContext context) {
    if (_currentTab == 2) {
      return Text(
        'WhatsApp Statuses',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: -0.4,
          color: AppColors.textPrimary(context),
        ),
      );
    }

    if (_currentTab == 3) {
      return Text(
        'Downloads',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: -0.4,
          color: AppColors.textPrimary(context),
        ),
      );
    }

    if (_currentTab == 4) {
      return Text(
        'Settings',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: -0.4,
          color: AppColors.textPrimary(context),
        ),
      );
    }

    // Default Tab 0: Downloader
    return Row(
      mainAxisSize: MainAxisSize.min,
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
          child: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'Video Downloader',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.4,
              color: AppColors.textPrimary(context),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            gradient: AppColors.violetGradient,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Text(
            'PRO',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, bool isDark, bool hasHistory) {
    return [
      // Quick Theme Toggle Button (Light / Dark)
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceElevatedDark
              : AppColors.surfaceElevatedLight,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.border(context),
            width: 1,
          ),
        ),
        child: IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => RotationTransition(
              turns: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(isDark),
              size: 19,
              color: isDark ? const Color(0xFFFBBF24) : AppColors.primary,
            ),
          ),
          tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          onPressed: () {
            HapticFeedback.lightImpact();
            ref.read(themeModeProvider.notifier).toggleTheme();
          },
        ),
      ),
      const SizedBox(width: 12),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        // ─── URL Input Field ───────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181C) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError ? AppColors.error : AppColors.border(context),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _urlController,
            focusNode: _focusNode,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
            ),
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintText: 'Paste YouTube, Instagram or Spotify link...',
              hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted(context)),
              prefixIcon: const Icon(Icons.link_rounded, size: 20, color: AppColors.primary),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_urlController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() {
                        _urlController.clear();
                        _detectedPlatform = MediaPlatform.unsupported;
                        _validationError = null;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted(context)),
                      ),
                    ),
                  GestureDetector(
                    onTap: _pasteFromClipboard,
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Paste',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
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
        ),

        // Error message
        if (hasError) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
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
        ],

        const SizedBox(height: 14),

        // ─── Inspect & Download Button ─────────────────────────────────────
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: inspectState.isLoading ? null : _onCheckVideo,
            child: inspectState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Inspect & Download',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        // ─── Active Download Card ──────────────────────────────────────────
        if (activeDownload.isDownloading && activeDownload.item != null) ...[
          const SizedBox(height: 20),
          _buildActiveDownloadCard(context, activeDownload),
        ],

        // ─── Recent Downloads ──────────────────────────────────────────────
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Downloads',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppColors.textPrimary(context),
              ),
            ),
            if (allCompleted.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _currentTab = 3),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),

        if (recentDownloads.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.download_for_offline_outlined,
                    size: 36,
                    color: AppColors.textMuted(context),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No downloads yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Paste a link above to get started',
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
          ...recentDownloads.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Column(
              children: [
                if (i > 0) Divider(height: 1, thickness: 1, color: AppColors.border(context)),
                _buildSimpleHistoryTile(context, item),
              ],
            );
          }),
      ],
    );
  }

  Widget _buildCategoryChip({
    required BuildContext context,
    required String id,
    required String label,
    required IconData icon,
    int? count,
  }) {
    final isSelected = _selectedCategory == id;
    final isDark = AppColors.isDark(context);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          _selectedCategory = id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.violetGradient : null,
          color: isSelected
              ? null
              : (isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.border(context),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : (id == 'youtube'
                      ? const Color(0xFFFF0033)
                      : (id == 'instagram'
                          ? AppColors.instagramPink
                          : AppColors.primary)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary(context),
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformShowcase(BuildContext context, bool isDark) {
    final platforms = [
      _PlatformCardData(
        title: 'YouTube Hub',
        subtitle: 'Videos & Shorts',
        badge: 'Browse',
        icon: Icons.play_arrow_rounded,
        gradient: AppColors.youtubeGradient,
        shadowColor: const Color(0xFFFF0033),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _currentTab = 1;
          });
        },
      ),
      _PlatformCardData(
        title: 'Instagram',
        subtitle: 'Reels & Stories',
        badge: 'Paste',
        icon: Icons.camera_alt_outlined,
        gradient: AppColors.instagramGradient,
        shadowColor: AppColors.instagramPink,
        onTap: () {
          HapticFeedback.selectionClick();
          _pasteFromClipboard();
        },
      ),
      _PlatformCardData(
        title: 'WhatsApp',
        subtitle: 'Status Saver',
        badge: 'Explore',
        icon: Icons.auto_awesome_motion_rounded,
        gradient: AppColors.whatsappGradient,
        shadowColor: const Color(0xFF10B981),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _currentTab = 2;
          });
        },
      ),
      _PlatformCardData(
        title: 'Spotify',
        subtitle: 'Music & Audio',
        badge: 'Inspect',
        icon: Icons.music_note_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFF1DB954), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shadowColor: const Color(0xFF1DB954),
        onTap: () {
          HapticFeedback.selectionClick();
          _pasteFromClipboard();
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Explore Platforms',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppColors.textPrimary(context),
                ),
              ),
              Text(
                'Tap to Open',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: platforms.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final p = platforms[index];
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: p.onTap,
                child: Container(
                  width: 138,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.border(context),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: p.shadowColor.withValues(alpha: isDark ? 0.22 : 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              gradient: p.gradient,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: p.shadowColor.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(p.icon, color: Colors.white, size: 15),
                          ),
                          Flexible(
                            child: Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: p.shadowColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p.badge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : p.shadowColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDetectedPlatformBadge(MediaPlatform platform) {
    final isIg = platform == MediaPlatform.instagramReel ||
        platform == MediaPlatform.instagramPost ||
        platform == MediaPlatform.instagramStory;
    final isSpotify = platform == MediaPlatform.spotifyTrack;

    final label = platform == MediaPlatform.spotifyTrack
        ? 'Spotify Track'
        : (platform == MediaPlatform.instagramReel
            ? 'Instagram Reel'
            : (platform == MediaPlatform.instagramStory
                ? 'Instagram Story'
                : (platform == MediaPlatform.instagramPost
                    ? 'Instagram Video'
                    : 'YouTube Video')));

    final Color? badgeColor = isSpotify
        ? const Color(0xFF1DB954)
        : (isIg ? null : const Color(0xFFFF0033));
    final Gradient? badgeGradient = isIg ? AppColors.instagramGradient : null;
    final Color shadowColor = isSpotify
        ? const Color(0xFF1DB954)
        : (isIg ? AppColors.instagramPink : Colors.red);
    final IconData badgeIcon = isSpotify
        ? Icons.music_note_rounded
        : (isIg ? Icons.camera_alt_outlined : Icons.play_arrow_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: badgeGradient,
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
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

  Widget _buildSimpleHistoryTile(BuildContext context, DownloadItem item) {
    final isDark = AppColors.isDark(context);
    final isAudio = item.isSpotify ||
        item.filePath.endsWith('.mp3') ||
        item.filePath.endsWith('.m4a');

    final Color platformColor = item.isSpotify
        ? const Color(0xFF1DB954)
        : (item.isInstagram ? AppColors.instagramPink : const Color(0xFFFF0033));
    final String platformLabel = item.isSpotify
        ? 'Spotify'
        : (item.isInstagram ? 'Instagram' : 'YouTube');

    return InkWell(
      onTap: () => MediaLauncher.openMedia(context, item.filePath, title: item.title),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 60,
                height: 60,
                child: item.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            _buildThumbnailFallback(context, isAudio),
                      )
                    : _buildThumbnailFallback(context, isAudio),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: platformColor.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          platformLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: platformColor,
                          ),
                        ),
                      ),
                      if (item.durationSeconds > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          Formatters.formatDuration(Duration(seconds: item.durationSeconds)),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ],
                      if (item.qualityLabel.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          item.qualityLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Play / Audio button
            GestureDetector(
              onTap: () => MediaLauncher.openMedia(context, item.filePath, title: item.title),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAudio ? Icons.music_note_rounded : Icons.play_arrow_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailFallback(BuildContext context, bool isAudio) {
    return Container(
      color: AppColors.surfaceElevated(context),
      child: Center(
        child: Icon(
          isAudio ? Icons.music_note_rounded : Icons.movie_outlined,
          size: 26,
          color: AppColors.textMuted(context),
        ),
      ),
    );
  }

  Widget _buildMetaPill(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isDark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBottomNav(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card(context).withValues(alpha: isDark ? 0.94 : 0.98),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: AppColors.border(context),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isDark ? 0.28 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              context: context,
              icon: Icons.download_rounded,
              label: 'Downloader',
              isActive: _currentTab == 0,
              onTap: () {
                setState(() {
                  _currentTab = 0;
                });
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.play_circle_fill_rounded,
              label: 'YouTube',
              isActive: _currentTab == 1,
              onTap: () {
                setState(() {
                  _currentTab = 1;
                });
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.auto_awesome_motion_rounded,
              label: 'Statuses',
              isActive: _currentTab == 2,
              onTap: () {
                setState(() {
                  _currentTab = 2;
                });
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.download_done_rounded,
              label: 'Downloads',
              isActive: _currentTab == 3,
              onTap: () {
                setState(() {
                  _currentTab = 3;
                });
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.settings_rounded,
              label: 'Settings',
              isActive: _currentTab == 4,
              onTap: () {
                setState(() {
                  _currentTab = 4;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: isActive ? 12 : 8, vertical: 8),
          decoration: BoxDecoration(
            gradient: isActive ? AppColors.violetGradient : null,
            borderRadius: BorderRadius.circular(22),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? Colors.white : AppColors.textMuted(context),
              ),
              if (isActive) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformCardData {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Gradient gradient;
  final Color shadowColor;
  final VoidCallback onTap;

  const _PlatformCardData({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.gradient,
    required this.shadowColor,
    required this.onTap,
  });
}

