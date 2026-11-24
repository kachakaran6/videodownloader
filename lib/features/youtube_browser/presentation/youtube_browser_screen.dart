import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/url_validator.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../inspect/data/video_inspector.dart';
import '../../inspect/presentation/video_details_sheet.dart';

/// Neutral In-App Browser Screen with Lagoon & Amber styling.
///
/// Features:
/// - Pill address bar with back, forward, refresh
/// - Neutral start screen: "Search or paste a link", custom search bar, quick-start tiles (Video, Clips, Music)
/// - Floating amber "Save this" button with badge when media is detected
/// - 100dp bottom padding
class YouTubeBrowserScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  final String? initialQuery;
  final VoidCallback? onBackToHome;

  const YouTubeBrowserScreen({
    super.key,
    this.isEmbedded = false,
    this.initialQuery,
    this.onBackToHome,
  });

  @override
  ConsumerState<YouTubeBrowserScreen> createState() => _YouTubeBrowserScreenState();
}

typedef BrowserScreen = YouTubeBrowserScreen;

class _YouTubeBrowserScreenState extends ConsumerState<YouTubeBrowserScreen> {
  late final WebViewController _webController;
  final TextEditingController _urlInputController = TextEditingController();

  bool _isStartPage = true;
  bool _isLoading = false;
  double _loadProgress = 0.0;
  String? _detectedMediaUrl;
  String? _detectedMediaTitle;
  bool _isInspecting = false;
  bool _canGoBack = false;
  bool _canGoForward = false;

  final VideoInspector _videoInspector = VideoInspector();

  @override
  void initState() {
    super.initState();
    _initWebViewController();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _loadSearchOrUrl(widget.initialQuery!.trim());
    }
  }

  @override
  void dispose() {
    _urlInputController.dispose();
    super.dispose();
  }

  void _initWebViewController() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'AppChannel',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message) as Map<String, dynamic>;
            final url = data['url'] as String?;
            final title = data['title'] as String?;
            if (url != null && mounted) {
              _checkUrlForMedia(url);
              if (title != null && title.isNotEmpty) {
                setState(() {
                  _detectedMediaTitle = title.trim();
                });
              }
            }
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadProgress = progress / 100.0;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _urlInputController.text = url;
                _isStartPage = false;
              });
              _checkUrlForMedia(url);
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              final back = await _webController.canGoBack();
              final forward = await _webController.canGoForward();
              setState(() {
                _isLoading = false;
                _canGoBack = back;
                _canGoForward = forward;
              });
              _checkUrlForMedia(url);
              _injectMediaDetection();
            }
          },
        ),
      );
  }

  void _injectMediaDetection() {
    const script = '''
      (function() {
        var videos = document.querySelectorAll('video');
        if (videos.length > 0) {
          var src = videos[0].currentSrc || videos[0].src;
          if (src) {
            window.AppChannel && window.AppChannel.postMessage(JSON.stringify({url: window.location.href, title: document.title}));
          }
        }
      })();
    ''';
    _webController.runJavaScript(script);
  }

  void _checkUrlForMedia(String url) {
    if (UrlValidator.isValidUrl(url)) {
      final platform = UrlValidator.detectPlatform(url);
      if (platform != MediaPlatform.unsupported) {
        setState(() {
          _detectedMediaUrl = url;
        });
      }
    }
  }

  void _loadSearchOrUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    String target;
    if (UrlValidator.isValidUrl(trimmed)) {
      target = trimmed.startsWith('http://') || trimmed.startsWith('https://')
          ? trimmed
          : 'https://$trimmed';
    } else {
      target = 'https://duckduckgo.com/?q=${Uri.encodeComponent(trimmed)}';
    }

    _urlInputController.text = target;
    setState(() {
      _isStartPage = false;
      _isLoading = true;
      _detectedMediaUrl = null;
    });

    _webController.loadRequest(Uri.parse(target));
  }

  Future<void> _downloadCurrentMedia() async {
    final mediaUrl = _detectedMediaUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() => _isInspecting = true);

    try {
      final result = await _videoInspector.inspect(mediaUrl);
      if (mounted) {
        setState(() => _isInspecting = false);
        VideoDetailsSheet.show(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInspecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to inspect media: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (AppConfig.isPlayStoreBuild) {
      return _buildPlayStoreNotice(context);
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _buildBrowserAppBar(context),
      body: Stack(
        children: [
          // Browser view or Start Screen
          if (_isStartPage)
            _buildStartPage(context)
          else
            WebViewWidget(controller: _webController),

          // Loading Progress Bar
          if (_isLoading && !_isStartPage)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _loadProgress,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                minHeight: 2.5,
              ),
            ),

          // Floating Amber "Save this" Action Button
          if (_detectedMediaUrl != null && !_isStartPage)
            Positioned(
              bottom: 100, // Safe above 100dp bottom padding
              left: 20,
              right: 20,
              child: _buildFloatingDownloadButton(context),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildBrowserAppBar(BuildContext context) {
    final colors = AppColors.of(context);

    return AppBar(
      titleSpacing: 8,
      backgroundColor: colors.surface,
      elevation: 0,
      title: Container(
        height: 42,
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: AppRadii.rPill,
          border: Border.all(color: colors.outline),
        ),
        child: TextField(
          controller: _urlInputController,
          textInputAction: TextInputAction.go,
          style: AppTypography.body(context),
          decoration: InputDecoration(
            hintText: 'Search or paste a link...',
            hintStyle: AppTypography.body(context, color: colors.textTertiary),
            prefixIcon: Icon(Icons.search_rounded, size: 18, color: colors.primary),
            suffixIcon: _urlInputController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: () {
                      _urlInputController.clear();
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onSubmitted: _loadSearchOrUrl,
        ),
      ),
      actions: [
        if (!_isStartPage) ...[
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: _canGoBack ? colors.textPrimary : colors.textTertiary,
            ),
            tooltip: 'Back',
            onPressed: _canGoBack ? () => _webController.goBack() : null,
          ),
          IconButton(
            icon: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: _canGoForward ? colors.textPrimary : colors.textTertiary,
            ),
            tooltip: 'Forward',
            onPressed: _canGoForward ? () => _webController.goForward() : null,
          ),
          IconButton(
            icon: Icon(_isLoading ? Icons.close_rounded : Icons.refresh_rounded, size: 20),
            tooltip: _isLoading ? 'Stop' : 'Reload',
            onPressed: () {
              if (_isLoading) {
                _webController.runJavaScript('window.stop();');
                setState(() => _isLoading = false);
              } else {
                _webController.reload();
              }
            },
          ),
        ],
        IconButton(
          icon: Icon(
            _isStartPage ? Icons.language_rounded : Icons.home_rounded,
            size: 20,
            color: colors.primary,
          ),
          tooltip: 'Home',
          onPressed: () {
            setState(() {
              _isStartPage = true;
              _urlInputController.clear();
              _detectedMediaUrl = null;
            });
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildStartPage(BuildContext context) {
    final colors = AppColors.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          // Clean Geometric Vector Emblem
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.explore_rounded, size: 38, color: colors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'Search or paste a link',
            style: AppTypography.display(context).copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse public web pages or paste a media link directly.',
            textAlign: TextAlign.center,
            style: AppTypography.body(context, color: colors.textSecondary),
          ),
          const SizedBox(height: 24),

          // Central Search Input Card
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: colors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Search terms or paste URL...',
                    style: AppTypography.body(context, color: colors.textTertiary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _loadSearchOrUrl(_urlInputController.text.isNotEmpty ? _urlInputController.text : 'open source media'),
                  child: const Text('Go'),
                ),
              ],
            ),
            onTap: () => _loadSearchOrUrl('open source media'),
          ),

          const SizedBox(height: 28),

          // Quick-Start Tiles: Video, Clips, Music
          Text(
            'QUICK START',
            style: AppTypography.overline(context),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildQuickStartTile(
                  context: context,
                  label: 'Video',
                  icon: Icons.play_circle_outline_rounded,
                  color: colors.categoryVideo,
                  query: 'creative commons video',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickStartTile(
                  context: context,
                  label: 'Clips',
                  icon: Icons.movie_creation_outlined,
                  color: colors.categoryClips,
                  query: 'public short clips',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickStartTile(
                  context: context,
                  label: 'Music',
                  icon: Icons.music_note_rounded,
                  color: colors.categoryMusic,
                  query: 'royalty free music audio',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStartTile({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required String query,
  }) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _loadSearchOrUrl(query);
      },
      borderRadius: AppRadii.r20,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.r20,
          border: Border.all(color: colors.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: AppTypography.caption(context).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingDownloadButton(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.r20,
        border: Border.all(color: colors.accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Category badge or icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.download_rounded, color: colors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _detectedMediaTitle ?? 'Media Detected',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subtitle(context).copyWith(fontSize: 14),
                ),
                Text(
                  '1 downloadable item found',
                  style: AppTypography.caption(context).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppButton.accent(
            label: 'Save this',
            isLoading: _isInspecting,
            onPressed: _isInspecting ? null : _downloadCurrentMedia,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayStoreNotice(BuildContext context) {
    final colors = AppColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 48, color: colors.primary),
            const SizedBox(height: 16),
            Text('Web Browser Notice', style: AppTypography.title(context)),
            const SizedBox(height: 10),
            Text(
              'Web media extraction is compliant with distribution policies. Please use the Home tab to inspect links you have permission to download.',
              textAlign: TextAlign.center,
              style: AppTypography.body(context, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
