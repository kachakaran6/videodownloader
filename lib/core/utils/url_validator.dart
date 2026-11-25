// ─── MediaPlatform Enum ────────────────────────────────────────────────────────
// Enum values are internal code identifiers and are intentionally kept as-is.
// User-visible names are provided via the [MediaPlatformDisplayName] extension below.
enum MediaPlatform {
  youtube,
  youtubePlaylist,
  instagramReel,
  instagramPost,
  instagramStory,
  spotifyTrack,
  spotifyPlaylist,
  spotifyAlbum,
  facebookVideo,
  twitterVideo,
  unsupported,
}

// ─── MediaPlatform Display Name Extension ─────────────────────────────────────
/// Maps internal [MediaPlatform] enum values to neutral, brand-free display labels
/// shown to the user in snackbars, badges, sheets and other UI surfaces.
extension MediaPlatformDisplayName on MediaPlatform {
  /// User-facing neutral label for this platform type.
  String get displayName {
    switch (this) {
      case MediaPlatform.youtube:
      case MediaPlatform.youtubePlaylist:
        return 'Video';
      case MediaPlatform.spotifyTrack:
      case MediaPlatform.spotifyAlbum:
      case MediaPlatform.spotifyPlaylist:
        return 'Music';
      case MediaPlatform.instagramReel:
      case MediaPlatform.instagramPost:
      case MediaPlatform.instagramStory:
        return 'Reels & Clips';
      case MediaPlatform.facebookVideo:
        return 'Video Clip';
      case MediaPlatform.twitterVideo:
        return 'X Video';
      case MediaPlatform.unsupported:
        return 'Unknown';
    }
  }
}

// ─── Twitter / X Media Info ─────────────────────────────────────────────────────
class TwitterMediaInfo {
  final MediaPlatform platform;
  final String tweetId;
  final String? username;
  final String canonicalUrl;

  const TwitterMediaInfo({
    this.platform = MediaPlatform.twitterVideo,
    required this.tweetId,
    this.username,
    required this.canonicalUrl,
  });
}

// ─── Instagram Media Info ──────────────────────────────────────────────────────
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

// ─── Facebook Media Info ───────────────────────────────────────────────────────
class FacebookMediaInfo {
  final MediaPlatform platform;
  final String videoId;
  final String canonicalUrl;
  final bool isReel;

  const FacebookMediaInfo({
    this.platform = MediaPlatform.facebookVideo,
    required this.videoId,
    required this.canonicalUrl,
    this.isReel = false,
  });
}

// ─── Spotify Media Info ────────────────────────────────────────────────────────
class SpotifyMediaInfo {
  final MediaPlatform platform;
  final String id;

  const SpotifyMediaInfo({
    required this.platform,
    required this.id,
  });

  bool get isTrack => platform == MediaPlatform.spotifyTrack;
  bool get isPlaylist => platform == MediaPlatform.spotifyPlaylist;
  bool get isAlbum => platform == MediaPlatform.spotifyAlbum;
}

// ─── URL Validator ─────────────────────────────────────────────────────────────
class UrlValidator {
  static final RegExp _ytVideoIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
  static final RegExp _igShortcodeRegex = RegExp(r'^[a-zA-Z0-9_-]{5,}$');

  /// Detects the media platform of a given URL.
  static MediaPlatform detectPlatform(String? url) {
    if (url == null || url.trim().isEmpty) return MediaPlatform.unsupported;
    // Check playlist BEFORE single video — playlist URLs also contain a video id
    if (extractPlaylistId(url) != null) return MediaPlatform.youtubePlaylist;
    if (isValidYouTubeUrl(url)) return MediaPlatform.youtube;
    final twitterInfo = extractTwitterInfo(url);
    if (twitterInfo != null) return twitterInfo.platform;
    final igInfo = extractInstagramInfo(url);
    if (igInfo != null) return igInfo.platform;
    final spotifyInfo = extractSpotifyInfo(url);
    if (spotifyInfo != null) return spotifyInfo.platform;
    final fbInfo = extractFacebookInfo(url);
    if (fbInfo != null) return fbInfo.platform;
    return MediaPlatform.unsupported;
  }

  /// Extracts YouTube playlist ID from a URL containing a `list=` parameter.
  /// e.g. https://www.youtube.com/playlist?list=PLxxx
  ///      https://www.youtube.com/watch?v=xxx&list=PLxxx
  static String? extractPlaylistId(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(rawUrl.trim());
      final host = uri.host.toLowerCase();
      final isYtHost = host == 'youtube.com' ||
          host == 'www.youtube.com' ||
          host == 'm.youtube.com' ||
          host == 'youtu.be' ||
          host.endsWith('.youtube.com');
      if (!isYtHost) return null;
      final listId = uri.queryParameters['list'];
      if (listId != null && listId.isNotEmpty) return listId;
    } catch (_) {}
    return null;
  }

  /// Checks if a string is a valid Spotify track URL.
  static bool isValidSpotifyUrl(String? url) {
    return extractSpotifyInfo(url) != null;
  }

  /// Extracts Spotify media info (Track, Playlist, Album) from URLs such as:
  /// - https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT
  /// - https://open.spotify.com/playlist/37i9dQZF1DXcBWYjo7Z5yd
  /// - https://open.spotify.com/album/4cOdK2wGLETKBW3PvgPWqT
  static SpotifyMediaInfo? extractSpotifyInfo(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final trimmed = rawUrl.trim();

    try {
      final uri = Uri.parse(trimmed);
      final host = uri.host.toLowerCase();
      if (!host.contains('spotify.com') && !host.contains('spotify.link')) {
        return null;
      }

      final highlight = uri.queryParameters['highlight'];
      if (highlight != null && highlight.contains('track:')) {
        final tid = highlight.split(':').last.trim();
        if (tid.isNotEmpty) {
          return SpotifyMediaInfo(platform: MediaPlatform.spotifyTrack, id: tid);
        }
      }

      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) return null;

      final trackIndex = segments.indexOf('track');
      if (trackIndex != -1 && trackIndex + 1 < segments.length) {
        return SpotifyMediaInfo(platform: MediaPlatform.spotifyTrack, id: segments[trackIndex + 1]);
      }

      final playlistIndex = segments.indexOf('playlist');
      if (playlistIndex != -1 && playlistIndex + 1 < segments.length) {
        return SpotifyMediaInfo(platform: MediaPlatform.spotifyPlaylist, id: segments[playlistIndex + 1]);
      }

      final albumIndex = segments.indexOf('album');
      if (albumIndex != -1 && albumIndex + 1 < segments.length) {
        return SpotifyMediaInfo(platform: MediaPlatform.spotifyAlbum, id: segments[albumIndex + 1]);
      }

      // Handle spotify.link shortlinks (e.g. https://spotify.link/Abc123xyz)
      if (host.contains('spotify.link')) {
        return SpotifyMediaInfo(platform: MediaPlatform.spotifyTrack, id: segments.last);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Extracts the Spotify track ID from URLs such as:
  /// - https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT
  /// - https://open.spotify.com/intl-de/track/4cOdK2wGLETKBW3PvgPWqT?si=abc
  /// - https://spotify.link/Abc123xyz
  static String? extractSpotifyTrackId(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final trimmed = rawUrl.trim();

    try {
      final uri = Uri.parse(trimmed);
      final host = uri.host.toLowerCase();
      if (!host.contains('spotify.com') && !host.contains('spotify.link')) {
        return null;
      }

      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final trackIndex = segments.indexOf('track');
      if (trackIndex != -1 && trackIndex + 1 < segments.length) {
        final id = segments[trackIndex + 1];
        return id.isNotEmpty ? id : null;
      }
      if (host.contains('spotify.link') && segments.isNotEmpty) {
        return segments.last;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Extracts the Spotify album ID from URLs such as:
  /// - https://open.spotify.com/album/1DFixLWuPkv3KT3TnV35m3
  /// - https://open.spotify.com/intl-de/album/1DFixLWuPkv3KT3TnV35m3?si=abc
  static String? extractSpotifyAlbumId(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final trimmed = rawUrl.trim();

    try {
      final uri = Uri.parse(trimmed);
      final host = uri.host.toLowerCase();
      if (!host.contains('spotify.com') && !host.contains('spotify.link')) {
        return null;
      }

      final segments = uri.pathSegments;
      final albumIndex = segments.indexOf('album');
      if (albumIndex != -1 && albumIndex + 1 < segments.length) {
        final id = segments[albumIndex + 1];
        return id.isNotEmpty ? id : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Extracts the Spotify playlist ID from URLs such as:
  /// - https://open.spotify.com/playlist/37i9dQZF1DXcBWYjo7Z5yd
  static String? extractSpotifyPlaylistId(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final trimmed = rawUrl.trim();

    try {
      final uri = Uri.parse(trimmed);
      final host = uri.host.toLowerCase();
      if (!host.contains('spotify.com') && !host.contains('spotify.link')) {
        return null;
      }

      final segments = uri.pathSegments;
      final plIndex = segments.indexOf('playlist');
      if (plIndex != -1 && plIndex + 1 < segments.length) {
        final id = segments[plIndex + 1];
        return id.isNotEmpty ? id : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Checks if a string is a valid URL supported by the application.
  static bool isValidUrl(String? url) {
    return detectPlatform(url) != MediaPlatform.unsupported;
  }

  /// Extracts the first supported URL from any shared text snippet.
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

  /// Checks if a string is a valid single-video URL (not a playlist).
  static bool isValidYouTubeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    // Playlist URLs are handled separately
    if (extractPlaylistId(url) != null) return false;
    final id = extractVideoId(url);
    return id != null && _ytVideoIdRegex.hasMatch(id);
  }

  /// Checks if a string is a valid Instagram URL.
  static bool isValidInstagramUrl(String? url) {
    return extractInstagramInfo(url ?? '') != null;
  }

  /// Checks if a string is a valid Facebook URL.
  static bool isValidFacebookUrl(String? url) {
    return extractFacebookInfo(url) != null;
  }

  /// Extracts Facebook media details (Watch, Reels, Videos, Shares, Stories).
  static FacebookMediaInfo? extractFacebookInfo(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final trimmed = rawUrl.trim();

    try {
      final uri = Uri.parse(trimmed);
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return null;
      }

      final host = uri.host.toLowerCase();
      final isFacebookHost = host == 'facebook.com' ||
          host == 'www.facebook.com' ||
          host == 'm.facebook.com' ||
          host == 'web.facebook.com' ||
          host == 'touch.facebook.com' ||
          host == 'fb.watch' ||
          host == 'www.fb.watch' ||
          host == 'fb.com' ||
          host == 'www.fb.com' ||
          host.endsWith('.facebook.com');

      if (!isFacebookHost) return null;

      // Check query parameter ?v= (e.g. /watch/?v=123, /video.php?v=123)
      final vParam = uri.queryParameters['v'];
      if (vParam != null && vParam.isNotEmpty) {
        return FacebookMediaInfo(
          videoId: vParam,
          canonicalUrl: 'https://www.facebook.com/watch/?v=$vParam',
          isReel: false,
        );
      }

      // Check query parameter ?story_fbid=
      final storyFbid = uri.queryParameters['story_fbid'];
      if (storyFbid != null && storyFbid.isNotEmpty) {
        return FacebookMediaInfo(
          videoId: storyFbid,
          canonicalUrl: trimmed,
          isReel: false,
        );
      }

      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) return null;

      // Shortlink fb.watch/<codeId>
      if (host == 'fb.watch' || host == 'www.fb.watch') {
        return FacebookMediaInfo(
          videoId: segments[0],
          canonicalUrl: trimmed,
          isReel: false,
        );
      }

      final first = segments[0].toLowerCase();

      // Reel: /reel/<id> or /reels/<id>
      if ((first == 'reel' || first == 'reels') && segments.length >= 2) {
        final id = segments[1];
        return FacebookMediaInfo(
          videoId: id,
          canonicalUrl: 'https://www.facebook.com/reel/$id',
          isReel: true,
        );
      }

      // Share links: /share/r/<id> or /share/v/<id> or /share/p/<id> or /share/<id>
      if (first == 'share' && segments.length >= 2) {
        final isReel = segments.length >= 3 && segments[1].toLowerCase() == 'r';
        final vidId = segments.length >= 3 ? segments[2] : segments[1];
        return FacebookMediaInfo(
          videoId: vidId,
          canonicalUrl: trimmed,
          isReel: isReel,
        );
      }

      // Page video endpoint: /<user>/videos/<id>
      final videosIndex = segments.indexOf('videos');
      if (videosIndex != -1 && videosIndex + 1 < segments.length) {
        final id = segments[videosIndex + 1];
        return FacebookMediaInfo(
          videoId: id,
          canonicalUrl: 'https://www.facebook.com/watch/?v=$id',
          isReel: false,
        );
      }

      // Post endpoint: /<user>/posts/<id>
      final postsIndex = segments.indexOf('posts');
      if (postsIndex != -1 && postsIndex + 1 < segments.length) {
        final id = segments[postsIndex + 1];
        return FacebookMediaInfo(
          videoId: id,
          canonicalUrl: trimmed,
          isReel: false,
        );
      }

      // Generic watch endpoint: /watch/
      if (first == 'watch') {
        return FacebookMediaInfo(
          videoId: segments.length >= 2 ? segments[1] : 'watch_video',
          canonicalUrl: trimmed,
          isReel: false,
        );
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  /// Extracts Facebook video ID from URL if available.
  static String? extractFacebookVideoId(String? rawUrl) {
    return extractFacebookInfo(rawUrl)?.videoId;
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

      // Reject pure playlist URLs (handled by extractPlaylistId)
      // But allow watch?v=xxx&list=xxx — extract just the video id for single-video context
      // The playlist detection happens via extractPlaylistId() called first in detectPlatform().

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

  /// Checks if a string is a valid Twitter or X status URL.
  static bool isValidTwitterUrl(String? url) {
    return extractTwitterInfo(url) != null;
  }

  /// Extracts Twitter / X status details (Tweet ID and username).
  ///
  /// Supports:
  /// - https://twitter.com/user/status/1234567890
  /// - https://x.com/user/status/1234567890
  /// - https://mobile.twitter.com/user/status/1234567890
  /// - https://mobile.x.com/user/status/1234567890
  /// - https://twitter.com/i/status/1234567890
  /// - https://x.com/i/status/1234567890
  /// - https://t.co/shortlink
  static TwitterMediaInfo? extractTwitterInfo(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final trimmed = rawUrl.trim();

    try {
      final uri = Uri.parse(trimmed);
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return null;
      }

      final host = uri.host.toLowerCase();
      final isTwitterHost = host == 'twitter.com' ||
          host == 'www.twitter.com' ||
          host == 'mobile.twitter.com' ||
          host == 'm.twitter.com' ||
          host == 'x.com' ||
          host == 'www.x.com' ||
          host == 'mobile.x.com' ||
          host == 'm.x.com' ||
          host == 'fxtwitter.com' ||
          host == 'vxtwitter.com' ||
          host == 'fixupx.com' ||
          host == 't.co';

      if (!isTwitterHost) return null;

      // Special handling for t.co shortlink: will be resolved during inspection
      if (host == 't.co') {
        final path = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (path.isNotEmpty) {
          return TwitterMediaInfo(
            tweetId: path.first,
            canonicalUrl: trimmed,
          );
        }
        return null;
      }

      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) return null;

      // Case 1: /<username>/status/<tweet_id>
      // e.g. /jack/status/20
      final statusIdx = segments.indexOf('status');
      if (statusIdx != -1 && statusIdx + 1 < segments.length) {
        final tweetId = segments[statusIdx + 1].split(RegExp(r'[^0-9]')).first;
        if (tweetId.isNotEmpty && RegExp(r'^\d+$').hasMatch(tweetId)) {
          final username = statusIdx > 0 ? segments[statusIdx - 1] : null;
          return TwitterMediaInfo(
            tweetId: tweetId,
            username: username == 'i' ? null : username,
            canonicalUrl: 'https://x.com/${username ?? "i"}/status/$tweetId',
          );
        }
      }

      // Case 2: /i/web/status/<tweet_id>
      final webIdx = segments.indexOf('web');
      if (webIdx != -1 && webIdx + 2 < segments.length && segments[webIdx + 1] == 'status') {
        final tweetId = segments[webIdx + 2].split(RegExp(r'[^0-9]')).first;
        if (tweetId.isNotEmpty && RegExp(r'^\d+$').hasMatch(tweetId)) {
          return TwitterMediaInfo(
            tweetId: tweetId,
            canonicalUrl: 'https://x.com/i/status/$tweetId',
          );
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  /// Builds a canonical video URL from video ID (YouTube format).
  static String getCanonicalUrl(String videoId) {
    return 'https://www.youtube.com/watch?v=$videoId';
  }

  /// Builds a canonical playlist URL from playlist ID (YouTube format).
  static String getPlaylistUrl(String playlistId) {
    return 'https://www.youtube.com/playlist?list=$playlistId';
  }
}
