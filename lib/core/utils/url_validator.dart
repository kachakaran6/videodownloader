enum MediaPlatform {
  youtube,
  instagramReel,
  instagramPost,
  instagramStory,
  unsupported,
}

class InstagramMediaInfo {
  final MediaPlatform platform;
  final String shortcode;
  final String? storyUsername;
  final String? storyId;

  const InstagramMediaInfo({
    required this.platform,
    required this.shortcode,
    this.storyUsername,
    this.storyId,
  });

  bool get isStory => platform == MediaPlatform.instagramStory;
  bool get isReel => platform == MediaPlatform.instagramReel;
  bool get isPost => platform == MediaPlatform.instagramPost;

  String get canonicalUrl {
    if (isStory && storyUsername != null && storyId != null) {
      return 'https://www.instagram.com/stories/$storyUsername/$storyId/';
    }
    if (isReel) {
      return 'https://www.instagram.com/reel/$shortcode/';
    }
    return 'https://www.instagram.com/p/$shortcode/';
  }
}

class UrlValidator {
  static final RegExp _ytVideoIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
  static final RegExp _igShortcodeRegex = RegExp(r'^[a-zA-Z0-9_-]{5,}$');

  /// Detects the media platform of a given URL.
  static MediaPlatform detectPlatform(String? url) {
    if (url == null || url.trim().isEmpty) return MediaPlatform.unsupported;
    if (isValidYouTubeUrl(url)) return MediaPlatform.youtube;
    final igInfo = extractInstagramInfo(url);
    if (igInfo != null) return igInfo.platform;
    return MediaPlatform.unsupported;
  }

  /// Checks if a string is a valid URL supported by the application.
  static bool isValidUrl(String? url) {
    return detectPlatform(url) != MediaPlatform.unsupported;
  }

  /// Extracts the first supported YouTube or Instagram URL from any shared text snippet.
  /// Handles text with surrounding messages, titles, quotes, and newlines.
  static String? extractFirstSupportedUrl(String? text) {
    if (text == null || text.trim().isEmpty) return null;

    final urlRegex = RegExp(r'https?://[^\s<>"{}|\\^`]+', caseSensitive: false);
    final matches = urlRegex.allMatches(text);

    for (final match in matches) {
      var candidate = match.group(0) ?? '';
      // Strip trailing punctuation like '.', ',', ')', '!', '?'
      candidate = candidate.replaceAll(RegExp(r'[.,)!?]+$'), '');

      if (isValidUrl(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  /// Checks if a string is a valid single-video YouTube URL.
  static bool isValidYouTubeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final id = extractVideoId(url);
    return id != null && _ytVideoIdRegex.hasMatch(id);
  }

  /// Checks if a string is a valid Instagram URL.
  static bool isValidInstagramUrl(String? url) {
    return extractInstagramInfo(url ?? '') != null;
  }

  /// Extracts YouTube video ID.
  static String? extractVideoId(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    try {
      final uri = Uri.parse(trimmed);
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return null;
      }

      final host = uri.host.toLowerCase();

      // Reject playlist parameters for single-video MVP
      if (uri.queryParameters.containsKey('list')) {
        return null;
      }

      // Check youtu.be/<id>
      if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
        final segments = uri.pathSegments;
        if (segments.isNotEmpty && segments[0].isNotEmpty) {
          final id = segments[0];
          return _ytVideoIdRegex.hasMatch(id) ? id : null;
        }
      }

      // Check youtube.com hosts
      if (host == 'youtube.com' ||
          host == 'www.youtube.com' ||
          host == 'm.youtube.com') {
        // Watch endpoint: /watch?v=<id>
        if (uri.path == '/watch') {
          final v = uri.queryParameters['v'];
          if (v != null && _ytVideoIdRegex.hasMatch(v)) {
            return v;
          }
        }

        // Shorts endpoint: /shorts/<id>
        if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'shorts') {
          if (uri.pathSegments.length >= 2) {
            final id = uri.pathSegments[1];
            return _ytVideoIdRegex.hasMatch(id) ? id : null;
          }
        }

        // Embed endpoint: /embed/<id>
        if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'embed') {
          if (uri.pathSegments.length >= 2) {
            final id = uri.pathSegments[1];
            return _ytVideoIdRegex.hasMatch(id) ? id : null;
          }
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  /// Extracts Instagram media details (Reels, Posts, Stories).
  static InstagramMediaInfo? extractInstagramInfo(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    try {
      final uri = Uri.parse(trimmed);
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return null;
      }

      final host = uri.host.toLowerCase();
      final isInstagramHost = host == 'instagram.com' ||
          host == 'www.instagram.com' ||
          host == 'm.instagram.com' ||
          host == 'instagr.am' ||
          host == 'www.instagr.am';

      if (!isInstagramHost) return null;

      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) return null;

      final first = segments[0].toLowerCase();

      // Reel: /reel/<shortcode> or /reels/<shortcode>
      if (first == 'reel' || first == 'reels') {
        if (segments.length >= 2) {
          final code = segments[1];
          if (_igShortcodeRegex.hasMatch(code)) {
            return InstagramMediaInfo(
              platform: MediaPlatform.instagramReel,
              shortcode: code,
            );
          }
        }
      }

      // Share links: /share/reel/<shortcode> or /share/p/<shortcode>
      if (first == 'share' && segments.length >= 3) {
        final sub = segments[1].toLowerCase();
        final code = segments[2];
        if (_igShortcodeRegex.hasMatch(code)) {
          if (sub == 'reel' || sub == 'reels') {
            return InstagramMediaInfo(
              platform: MediaPlatform.instagramReel,
              shortcode: code,
            );
          } else if (sub == 'p' || sub == 'tv') {
            return InstagramMediaInfo(
              platform: MediaPlatform.instagramPost,
              shortcode: code,
            );
          }
        }
      }

      // Post / Video: /p/<shortcode> or /tv/<shortcode>
      if (first == 'p' || first == 'tv') {
        if (segments.length >= 2) {
          final code = segments[1];
          if (_igShortcodeRegex.hasMatch(code)) {
            return InstagramMediaInfo(
              platform: MediaPlatform.instagramPost,
              shortcode: code,
            );
          }
        }
      }

      // Stories: /stories/<username>/<story_id>
      if (first == 'stories') {
        if (segments.length >= 2) {
          final username = segments[1];
          final storyId = segments.length >= 3 ? segments[2] : null;
          return InstagramMediaInfo(
            platform: MediaPlatform.instagramStory,
            shortcode: storyId ?? username,
            storyUsername: username,
            storyId: storyId,
          );
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  /// Extracts Instagram shortcode from URL if available.
  static String? extractInstagramShortcode(String rawUrl) {
    return extractInstagramInfo(rawUrl)?.shortcode;
  }

  /// Builds a canonical YouTube URL from video ID.
  static String getCanonicalUrl(String videoId) {
    return 'https://www.youtube.com/watch?v=$videoId';
  }
}
