import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../inspect/data/video_inspector.dart';

/// Navigation state and SPA bridge controller for the Watch WebView.
class WatchWebViewController {
  final VideoInspector _videoInspector;
  final Map<String, VideoInspectionResult> _prefetchedCache = {};

  final ValueNotifier<String?> currentUrlNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<bool> isDownloadableNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPrefetchingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> pageTitleNotifier = ValueNotifier<String?>(null);

  WatchWebViewController({VideoInspector? videoInspector})
      : _videoInspector = videoInspector ?? VideoInspector();

  /// Script injected into the WebView to detect SPA client-side navigations.
  static const String spaNavigationBridgeScript = '''
(function() {
  function notifyFlutter() {
    try {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('onUrlChanged', window.location.href, document.title || '');
      }
    } catch(e) {}
  }

  // Intercept pushState & replaceState for single-page navigations
  var origPushState = history.pushState;
  history.pushState = function() {
    var res = origPushState.apply(this, arguments);
    notifyFlutter();
    return res;
  };

  var origReplaceState = history.replaceState;
  history.replaceState = function() {
    var res = origReplaceState.apply(this, arguments);
    notifyFlutter();
    return res;
  };

  window.addEventListener('popstate', notifyFlutter);
  window.addEventListener('yt-navigate-finish', notifyFlutter);
  window.addEventListener('yt-page-data-updated', notifyFlutter);
  document.addEventListener('DOMContentLoaded', notifyFlutter);

  // Periodic poll fallback for rapid AJAX navigations
  var lastHref = window.location.href;
  setInterval(function() {
    if (window.location.href !== lastHref) {
      lastHref = window.location.href;
      notifyFlutter();
    }
  }, 800);
})();
''';

  /// Evaluates whether a given URL is a downloadable video, short, or live stream.
  static bool isDownloadableUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return false;
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    // Check YouTube / m.youtube / youtu.be
    final isYouTubeDomain = host.contains('youtube.com') || host.contains('youtu.be');
    if (!isYouTubeDomain) return false;

    // Direct video watch paths
    if (path.startsWith('/watch') ||
        path.startsWith('/shorts/') ||
        path.startsWith('/live/') ||
        host.contains('youtu.be')) {
      return true;
    }

    // Query parameter watch?v=...
    if (uri.queryParameters.containsKey('v') && (uri.queryParameters['v']?.isNotEmpty ?? false)) {
      return true;
    }

    return false;
  }

  /// Handles incoming URL updates from JavaScript or WebView navigation delegates.
  void onUrlUpdated(String url, {String? title}) {
    if (url.isEmpty) return;
    currentUrlNotifier.value = url;
    if (title != null && title.isNotEmpty) {
      pageTitleNotifier.value = title;
    }

    final downloadable = isDownloadableUrl(url);
    isDownloadableNotifier.value = downloadable;

    if (downloadable) {
      _prefetchMetadata(url);
    }
  }

  /// Asynchronously pre-fetches metadata so the Preview Sheet opens instantly when Save is tapped.
  Future<void> _prefetchMetadata(String url) async {
    if (_prefetchedCache.containsKey(url)) return;

    isPrefetchingNotifier.value = true;
    try {
      final result = await _videoInspector.inspect(url);
      _prefetchedCache[url] = result;
    } catch (_) {
      // Ignored: full inspector will handle and show user errors upon manual save tap
    } finally {
      isPrefetchingNotifier.value = false;
    }
  }

  /// Gets cached inspection result, or inspects on demand if not yet cached.
  Future<VideoInspectionResult> getInspectionResult(String url) async {
    if (_prefetchedCache.containsKey(url)) {
      return _prefetchedCache[url]!;
    }
    final result = await _videoInspector.inspect(url);
    _prefetchedCache[url] = result;
    return result;
  }

  /// Pauses all playing HTML5 media elements in the WebView.
  Future<void> pauseMedia(InAppWebViewController? controller) async {
    if (controller == null) return;
    try {
      await controller.evaluateJavascript(
        source: 'document.querySelectorAll("video, audio").forEach(function(el) { el.pause(); });',
      );
    } catch (_) {}
  }

  void dispose() {
    currentUrlNotifier.dispose();
    isDownloadableNotifier.dispose();
    isPrefetchingNotifier.dispose();
    pageTitleNotifier.dispose();
  }
}
