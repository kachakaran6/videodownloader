import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../inspect/presentation/video_details_sheet.dart';
import '../../inspect/presentation/album_details_sheet.dart';
import 'watch_web_view_controller.dart';
import 'widgets/save_floating_button.dart';

/// Direct Video Site Tab ("Watch") Screen.
///
/// Features:
/// - Direct loading of mobile video site (https://m.youtube.com)
/// - Slim 48dp top bar with Back, Forward, Refresh, Copy link, and compact URL pill
/// - Thin Lagoon progress loading bar under status bar
/// - Full-screen video support (auto-rotate to landscape & immersive mode; restore on exit)
/// - SPA navigation detection via JS bridge (pushState, replaceState, popstate, yt-navigate-finish)
/// - Floating Amber "Save" pill button on downloadable pages (/watch, /shorts/, /live/, youtu.be/)
/// - Background metadata pre-fetching so Preview Sheet opens instantly
/// - Long-press link context menu ("Save this link")
/// - Friendly offline error screen with Retry
/// - 88dp bottom inset so elements are never covered by the floating nav bar
/// - System back button intercepts: goes back in WebView history first, then returns to Home tab
class WatchScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  final bool isActive;
  final VoidCallback onBackToHome;
  final VoidCallback? onNavigateToLibrary;

  const WatchScreen({
    super.key,
    this.isEmbedded = true,
    this.isActive = true,
    required this.onBackToHome,
    this.onNavigateToLibrary,
  });

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final WatchWebViewController _watchController;
  InAppWebViewController? _webViewController;
  PullToRefreshController? _pullToRefreshController;

  double _loadingProgress = 0.0;
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isFullscreen = false;

  static const String _initialUrl = 'https://m.youtube.com';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchController = WatchWebViewController();

    _pullToRefreshController = kIsWeb ||
            InAppWebViewPlatform.instance == null ||
            ![TargetPlatform.iOS, TargetPlatform.android]
                .contains(defaultTargetPlatform)
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(
              color: const Color(0xFF0A6B6B), // Lagoon primary
            ),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                _webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                _webViewController?.loadUrl(
                  urlRequest: URLRequest(url: await _webViewController?.getUrl()),
                );
              }
            },
          );
  }

  @override
  void didUpdateWidget(covariant WatchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the user navigates away from the Watch tab, pause media playback
    if (oldWidget.isActive && !widget.isActive) {
      _watchController.pauseMedia(_webViewController);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _watchController.pauseMedia(_webViewController);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restoreSystemUI();
    _watchController.dispose();
    super.dispose();
  }

  void _restoreSystemUI() {
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _isFullscreen = false;
    }
  }

  Future<void> _handleBackPress() async {
    if (_isFullscreen) {
      _restoreSystemUI();
      return;
    }

    if (_webViewController != null && await _webViewController!.canGoBack()) {
      await _webViewController!.goBack();
    } else {
      widget.onBackToHome();
    }
  }

  Future<void> _openSavePreview(String url) async {
    HapticFeedback.lightImpact();

    // Show brief feedback if loading
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    try {
      final inspection = await _watchController.getInspectionResult(url);

      if (!mounted) return;

      final isMultiTrack = (inspection.isAlbum || inspection.isPlaylist) &&
          ((inspection.spotifyTracks != null &&
                  inspection.spotifyTracks!.length > 1) ||
              (inspection.playlistVideos != null &&
                  inspection.playlistVideos!.length > 1));

      if (isMultiTrack) {
        await AlbumDetailsSheet.show(context, inspection);
      } else {
        await VideoDetailsSheet.show(context, inspection);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load preview. Please verify connection and retry.',
            style: AppTypography.caption(context).copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.of(context).error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showLinkContextMenu(String rawUrl) {
    if (!WatchWebViewController.isDownloadableUrl(rawUrl)) return;
    HapticFeedback.mediumImpact();

    final colors = AppColors.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.outline,
                    borderRadius: AppRadii.rPill,
                  ),
                ),
              ),
              Text(
                'Media Link Detected',
                style: AppTypography.subtitle(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                rawUrl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(context).copyWith(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.15),
                    borderRadius: AppRadii.r12,
                  ),
                  child: Icon(Icons.arrow_downward_rounded, color: colors.accent),
                ),
                title: Text(
                  'Save this link',
                  style: AppTypography.subtitle(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Choose quality and add to download queue',
                  style: AppTypography.caption(context),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openSavePreview(rawUrl);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: AppRadii.r12,
                  ),
                  child: Icon(Icons.copy_rounded, color: colors.textSecondary),
                ),
                title: Text(
                  'Copy link address',
                  style: AppTypography.subtitle(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Clipboard.setData(ClipboardData(text: rawUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link copied to clipboard'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = AppColors.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          top: !_isFullscreen,
          bottom: false,
          child: Stack(
            children: [
              // Full-screen WebView with 88dp bottom inset for floating navigation
              Padding(
                padding: EdgeInsets.only(bottom: _isFullscreen ? 0 : 88.0),
                child: InAppWebViewPlatform.instance == null
                    ? Container(
                        color: colors.surfaceAlt,
                        alignment: Alignment.center,
                        child: const Text('Watch'),
                      )
                    : InAppWebView(
                        initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        domStorageEnabled: true,
                        thirdPartyCookiesEnabled: true,
                        mediaPlaybackRequiresUserGesture: false,
                        allowsInlineMediaPlayback: true,
                        useHybridComposition: true,
                        transparentBackground: true,
                        useShouldOverrideUrlLoading: false,
                      ),
                      pullToRefreshController: _pullToRefreshController,
                      onWebViewCreated: (controller) {
                        _webViewController = controller;

                        // JavaScript bridge to receive SPA navigation events
                        controller.addJavaScriptHandler(
                          handlerName: 'onUrlChanged',
                          callback: (args) {
                            if (args.isNotEmpty && args[0] is String) {
                              final url = args[0] as String;
                              final title = args.length > 1 ? args[1] as String? : null;
                              _watchController.onUrlUpdated(url, title: title);
                            }
                          },
                        );
                      },
                      onLoadStart: (controller, url) {
                        setState(() {
                          _isLoading = true;
                          _hasError = false;
                        });
                        if (url != null) {
                          _watchController.onUrlUpdated(url.toString());
                        }
                      },
                      onLoadStop: (controller, url) async {
                        _pullToRefreshController?.endRefreshing();
                        setState(() {
                          _isLoading = false;
                        });

                        // Inject the SPA client-side history navigation bridge
                        await controller.evaluateJavascript(
                          source: WatchWebViewController.spaNavigationBridgeScript,
                        );

                        if (url != null) {
                          _watchController.onUrlUpdated(url.toString());
                        }
                      },
                      onProgressChanged: (controller, progress) {
                        if (progress == 100) {
                          _pullToRefreshController?.endRefreshing();
                        }
                        setState(() {
                          _loadingProgress = progress / 100.0;
                          _isLoading = progress < 100;
                        });
                      },
                      onUpdateVisitedHistory: (controller, url, isReload) {
                        if (url != null) {
                          _watchController.onUrlUpdated(url.toString());
                        }
                      },
                      onReceivedError: (controller, request, error) {
                        _pullToRefreshController?.endRefreshing();
                        if (request.isForMainFrame ?? true) {
                          setState(() {
                            _hasError = true;
                            _errorMessage = error.description;
                          });
                        }
                      },
                      onEnterFullscreen: (controller) {
                        setState(() => _isFullscreen = true);
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.landscapeLeft,
                          DeviceOrientation.landscapeRight,
                        ]);
                        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                      },
                      onExitFullscreen: (controller) {
                        setState(() => _isFullscreen = false);
                        _restoreSystemUI();
                      },
                      onLongPressHitTestResult: (controller, hitTestResult) {
                        final extra = hitTestResult.extra;
                        if (extra != null && WatchWebViewController.isDownloadableUrl(extra)) {
                          _showLinkContextMenu(extra);
                        }
                      },
                    ),
                  ),

                  // Offline / Connection Failure Overlay with Retry
                  if (_hasError)
                    Container(
                      color: colors.background,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.error.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.wifi_off_rounded, size: 40, color: colors.error),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Unable to load page',
                            style: AppTypography.title(context).copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage ?? 'Please check your internet connection and try again.',
                            textAlign: TextAlign.center,
                            style: AppTypography.body(context).copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: colors.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadii.r16,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry'),
                            onPressed: () {
                              setState(() {
                                _hasError = false;
                                _isLoading = true;
                              });
                              _webViewController?.reload();
                            },
                          ),
                        ],
                      ),
                    ),

                  // Thin loading progress indicator at top edge during web navigation
                  if (_isLoading && !_isFullscreen)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: _loadingProgress,
                        minHeight: 2.0,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                      ),
                    ),

                  // Floating Amber "Save" Pill Button
                  // Positioned 16dp above the floating nav bar (bottom: 104dp)
                  if (!_isFullscreen)
                    Positioned(
                      bottom: 104,
                      right: 20,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _watchController.isDownloadableNotifier,
                        builder: (context, isDownloadable, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: _watchController.isPrefetchingNotifier,
                            builder: (context, isPrefetching, _) {
                              return SaveFloatingButton(
                                isVisible: isDownloadable && !_hasError,
                                isPrefetching: isPrefetching,
                                onTap: () {
                                  final currentUrl = _watchController.currentUrlNotifier.value;
                                  if (currentUrl != null && currentUrl.isNotEmpty) {
                                    _openSavePreview(currentUrl);
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
  }
}
