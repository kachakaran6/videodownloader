class UrlValidator {
  static final RegExp _videoIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');

  /// Checks if a string is a valid single-video YouTube URL.
  static bool isValidYouTubeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final id = extractVideoId(url);
    return id != null && _videoIdRegex.hasMatch(id);
  }

  /// Extracts the 11-character YouTube video ID from a URL, or null if invalid.
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
          return _videoIdRegex.hasMatch(id) ? id : null;
        }
      }

      // Check youtube.com hosts
      if (host == 'youtube.com' ||
          host == 'www.youtube.com' ||
          host == 'm.youtube.com') {
        // Watch endpoint: /watch?v=<id>
        if (uri.path == '/watch') {
          final v = uri.queryParameters['v'];
          if (v != null && _videoIdRegex.hasMatch(v)) {
            return v;
          }
        }

        // Shorts endpoint: /shorts/<id>
        if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'shorts') {
          if (uri.pathSegments.length >= 2) {
            final id = uri.pathSegments[1];
            return _videoIdRegex.hasMatch(id) ? id : null;
          }
        }

        // Embed endpoint: /embed/<id>
        if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'embed') {
          if (uri.pathSegments.length >= 2) {
            final id = uri.pathSegments[1];
            return _videoIdRegex.hasMatch(id) ? id : null;
          }
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  /// Builds a canonical URL from video ID.
  static String getCanonicalUrl(String videoId) {
    return 'https://www.youtube.com/watch?v=$videoId';
  }
}
