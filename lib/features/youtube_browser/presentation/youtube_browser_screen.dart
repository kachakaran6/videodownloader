import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../inspect/data/video_inspector.dart';
import '../../inspect/presentation/video_details_sheet.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_validator.dart';

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

class _YouTubeBrowserScreenState extends ConsumerState<YouTubeBrowserScreen> {
  late final WebViewController _webController;

  bool _isLoading = true;
  double _loadProgress = 0.0;
  String? _detectedVideoUrl;
  String? _detectedVideoTitle;
  bool _isInspecting = false;
  bool _canGoBack = false;

  final VideoInspector _videoInspector = VideoInspector();

  static const String _homeUrl = 'https://m.youtube.com';

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  void _initWebViewController() {
    final startUrl = widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty
        ? 'https://m.youtube.com/results?search_query=${Uri.encodeComponent(widget.initialQuery!.trim())}'
        : _homeUrl;

    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'AppChannel',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message) as Map<String, dynamic>;
            final url = data['url'] as String?;
            final title = data['title'] as String?;
            if (url != null && mounted) {
              _checkUrlForVideo(url);
              if (title != null && title.isNotEmpty && title != 'YouTube') {
                setState(() {
                  _detectedVideoTitle = title.replaceAll(' - YouTube', '').trim();
                });
              }
              _updateNavState();
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
              });
              _checkUrlForVideo(url);
              _updateNavState();
              _injectUrlObserver();
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              _checkUrlForVideo(url);
              _updateNavState();
              _injectUrlObserver();
              try {
                final title = await _webController.getTitle();
                if (title != null && title.isNotEmpty && title != 'YouTube') {
                  setState(() {
                    _detectedVideoTitle = title.replaceAll(' - YouTube', '').trim();
                  });
                }
              } catch (_) {}
            }
          },
          onUrlChange: (UrlChange change) {
            if (mounted && change.url != null) {
              _checkUrlForVideo(change.url!);
              _updateNavState();
              _injectUrlObserver();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(startUrl));
  }

  void _injectUrlObserver() {
    const script = '''
(function() {
  try {
    var style = document.getElementById('app-clean-style');
    if (!style) {
      style = document.createElement('style');
      style.id = 'app-clean-style';
      style.innerHTML = `
        .open-app-button, 
        .upsell-dialog, 
        .pivot-w2w, 
        ytm-pivot-bar-renderer, 
        .mobile-topbar-header .open-app-button,
        a[href*="app.adjust.com"] { 
          display: none !important; 
        }
      `;
      document.head.appendChild(style);
    }
  } catch(e) {}

  if (window.__appObserverInjected) return;
  window.__appObserverInjected = true;

  var lastReported = "";
  function checkAndReport() {
    try {
      var currentUrl = window.location.href;
      var currentTitle = document.title || "";
      var signature = currentUrl + "||" + currentTitle;
      if (signature !== lastReported) {
        lastReported = signature;
        if (window.AppChannel) {
          window.AppChannel.postMessage(JSON.stringify({
            url: currentUrl,
            title: currentTitle
          }));
        }
      }
    } catch(e) {}
  }

  var origPush = history.pushState;
  history.pushState = function() {
    origPush.apply(this, arguments);
    setTimeout(checkAndReport, 150);
    setTimeout(checkAndReport, 600);
  };

  var origReplace = history.replaceState;
  history.replaceState = function() {
    origReplace.apply(this, arguments);
    setTimeout(checkAndReport, 150);
    setTimeout(checkAndReport, 600);
  };

  window.addEventListener('popstate', function() {
    setTimeout(checkAndReport, 150);
  });

  setInterval(checkAndReport, 600);
  checkAndReport();
})();
''';
    _webController.runJavaScript(script).catchError((_) {});
  }

  Future<void> _updateNavState() async {
    final canBack = await _webController.canGoBack();
    if (mounted) {
      setState(() {
        _canGoBack = canBack;
      });
    }
  }

  String _sanitizeYouTubeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.contains('watch') && uri.queryParameters.containsKey('v')) {
        final videoId = uri.queryParameters['v']!;
        return 'https://www.youtube.com/watch?v=$videoId';
      }
      if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'shorts') {
        final id = uri.pathSegments[1];
        return 'https://www.youtube.com/shorts/$id';
      }
    } catch (_) {}
    return url;
  }

  void _checkUrlForVideo(String url) {
    final sanitized = _sanitizeYouTubeUrl(url);
    final platform = UrlValidator.detectPlatform(sanitized);
    final isVideo = platform == MediaPlatform.youtube &&
        (sanitized.contains('/watch') || sanitized.contains('/shorts/') || sanitized.contains('youtu.be/'));

    if (isVideo) {
      if (_detectedVideoUrl != sanitized) {
        setState(() {
          _detectedVideoUrl = sanitized;
        });
      }
    } else {
      if (_detectedVideoUrl != null) {
        setState(() {
          _detectedVideoUrl = null;
          _detectedVideoTitle = null;
        });
      }
    }
  }

  Future<void> _downloadCurrentVideo() async {
    final url = _detectedVideoUrl;
    if (url == null || _isInspecting) return;

    setState(() {
      _isInspecting = true;
    });

    try {
      final result = await _videoInspector.inspect(url);
      if (mounted) {
        setState(() {
          _isInspecting = false;
        });
        await VideoDetailsSheet.show(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInspecting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Failed to parse video: $e',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _webController.canGoBack()) {
          _webController.goBack();
        } else if (widget.onBackToHome != null) {
          widget.onBackToHome!();
        } else if (!widget.isEmbedded && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
        body: Stack(
          children: [
            Column(
              children: [
                // YouTube Red Loading Progress Indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: _isLoading ? 2.5 : 0,
                  child: _isLoading
                      ? LinearProgressIndicator(
                          value: _loadProgress > 0 ? _loadProgress : null,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
                          minHeight: 2.5,
                        )
                      : const SizedBox.shrink(),
                ),

                // Fullscreen YouTube WebView Frame (Zero empty bottom space)
                Expanded(
                  child: WebViewWidget(controller: _webController),
                ),
              ],
            ),

            // Animated Floating Download Bar (appears directly above bottom nav bar when video is detected)
            if (_detectedVideoUrl != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: _buildFloatingDownloadBanner(context, isDark),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingDownloadBanner(BuildContext context, bool isDark) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _isInspecting ? null : _downloadCurrentVideo,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1A1635),
                Color(0xFF2D1040),
                Color(0xFF1A1635),
              ],
              stops: [0.0, 0.5, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFFF0000).withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF0000).withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Pulse Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF0000), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF0000).withValues(alpha: 0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(
                    begin: const Offset(0.96, 0.96),
                    end: const Offset(1.06, 1.06),
                    duration: 1000.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(width: 10),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _detectedVideoTitle ?? 'Video Ready',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'HD • MP4 • MP3',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w500,
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Download CTA
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF0000), Color(0xFFDC2626)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF0000).withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _isInspecting ? null : _downloadCurrentVideo,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      child: _isInspecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.download_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Save',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
