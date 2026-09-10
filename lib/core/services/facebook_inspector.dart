import 'package:http/http.dart' as http;
import '../errors/app_exceptions.dart';
import '../utils/url_validator.dart';

class FacebookVideoVersion {
  final String url;
  final String quality; // 'hd' or 'sd'
  final String label;
  final int? fileSizeBytes;

  const FacebookVideoVersion({
    required this.url,
    required this.quality,
    required this.label,
    this.fileSizeBytes,
  });

  FacebookVideoVersion copyWith({
    String? url,
    String? quality,
    String? label,
    int? fileSizeBytes,
  }) {
    return FacebookVideoVersion(
      url: url ?? this.url,
      quality: quality ?? this.quality,
      label: label ?? this.label,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }
}

class FacebookMediaResult {
  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final Duration duration;
  final List<FacebookVideoVersion> videoVersions;
  final bool isReel;
  final bool hasAudio;

  const FacebookMediaResult({
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.duration,
    required this.videoVersions,
    this.isReel = false,
    this.hasAudio = true,
  });
}

class FacebookInspector {
  final http.Client _client;

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  FacebookInspector([http.Client? client]) : _client = client ?? http.Client();

  /// Resolves any shortlink or share redirect (e.g. fb.watch or facebook.com/share/*)
  Future<String> resolveRedirects(String rawUrl) async {
    try {
      final uri = Uri.parse(rawUrl);
      final req = http.Request('GET', uri)
        ..followRedirects = true
        ..maxRedirects = 5
        ..headers['User-Agent'] = _defaultUserAgent
        ..headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';

      final streamedRes = await _client.send(req).timeout(const Duration(seconds: 8));
      final finalUrl = streamedRes.request?.url.toString() ?? rawUrl;
      return finalUrl;
    } catch (_) {
      return rawUrl;
    }
  }

  /// Probes the direct CDN URL via HEAD / Range request to determine file size in bytes
  Future<int?> probeContentLength(String url) async {
    try {
      final uri = Uri.parse(url);
      final headReq = http.Request('HEAD', uri)
        ..headers['User-Agent'] = _defaultUserAgent
        ..headers['Accept'] = '*/*';

      final headRes = await _client.send(headReq).timeout(const Duration(milliseconds: 3500));
      final clHeader = headRes.headers['content-length'];
      if (clHeader != null) {
        final parsed = int.tryParse(clHeader);
        if (parsed != null && parsed > 0) return parsed;
      }
      if (headRes.contentLength != null && headRes.contentLength! > 0) {
        return headRes.contentLength;
      }

      final rangeReq = http.Request('GET', uri)
        ..headers['User-Agent'] = _defaultUserAgent
        ..headers['Range'] = 'bytes=0-0';
      final rangeRes = await _client.send(rangeReq).timeout(const Duration(milliseconds: 3500));
      final contentRange = rangeRes.headers['content-range'];
      if (contentRange != null) {
        final match = RegExp(r'\/(\d+)').firstMatch(contentRange);
        if (match != null) {
          return int.tryParse(match.group(1)!);
        }
      }
      if (rangeRes.contentLength != null && rangeRes.contentLength! > 1) {
        return rangeRes.contentLength;
      }
    } catch (_) {}
    return null;
  }

  /// Inspects a Facebook Video, Reel, Watch link or Post and extracts media streams.
  Future<FacebookMediaResult> inspect(String rawUrl) async {
    final info = UrlValidator.extractFacebookInfo(rawUrl);
    if (info == null) {
      throw const InvalidUrlException('Please enter a valid Facebook video or reel link.');
    }

    // Step 1: If it's a shortlink (fb.watch or /share/), resolve redirect
    String targetUrl = rawUrl.trim();
    if (targetUrl.contains('fb.watch') || targetUrl.contains('/share/')) {
      targetUrl = await resolveRedirects(targetUrl);
    }

    // Step 2: Attempt direct web extraction
    FacebookMediaResult? result;
    try {
      result = await _inspectDirectWeb(targetUrl, info);
    } catch (e) {
      // If direct web extraction threw network exception, bubble it
      if (e is NetworkException) rethrow;
    }

    // Step 3: If direct extraction found no streams or failed, use Facebook Embed Player fallback
    if (result == null || result.videoVersions.isEmpty) {
      result = await _inspectViaEmbed(targetUrl, info);
    }

    if (result == null || result.videoVersions.isEmpty) {
      throw const VideoUnavailableException(
        'Could not extract video stream from this Facebook post. It may be private, age-restricted, or removed.',
      );
    }

    return result;
  }

  Future<FacebookMediaResult?> _inspectDirectWeb(String targetUrl, FacebookMediaInfo info) async {
    http.Response resp;
    try {
      resp = await _client.get(
        Uri.parse(targetUrl),
        headers: {
          'User-Agent': _defaultUserAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Sec-Fetch-Mode': 'navigate',
        },
      ).timeout(const Duration(seconds: 12));
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        throw const NetworkException();
      }
      return null;
    }

    if (resp.statusCode != 200) {
      return null;
    }

    final html = resp.body;

    // Check if redirected to login page without content
    if (html.contains('/login/?next=') && !html.contains('browser_native_hd_url') && !html.contains('playable_url')) {
      return null;
    }

    return await _parseFacebookHtml(html, info, targetUrl);
  }

  Future<FacebookMediaResult?> _inspectViaEmbed(String targetUrl, FacebookMediaInfo info) async {
    try {
      final embedUri = Uri.parse(
        'https://www.facebook.com/plugins/video.php?href=${Uri.encodeComponent(targetUrl)}&show_text=0&width=560',
      );

      final resp = await _client.get(
        embedUri,
        headers: {
          'User-Agent': _defaultUserAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return await _parseFacebookHtml(resp.body, info, targetUrl);
      }
    } catch (_) {}

    return null;
  }

  Future<FacebookMediaResult?> _parseFacebookHtml(
    String html,
    FacebookMediaInfo info,
    String sourceUrl,
  ) async {
    // 1. Extract HD stream URL
    String? hdUrl = _findStreamUrl(html, [
      r'"browser_native_hd_url"\s*:\s*"([^"]+)"',
      r'"playable_url_quality_hd"\s*:\s*"([^"]+)"',
      r'"hd_src"\s*:\s*"([^"]+)"',
      r'"hd_src_no_ratelimit"\s*:\s*"([^"]+)"',
      r"'browser_native_hd_url'\s*:\s*'([^']+)'",
      r"'playable_url_quality_hd'\s*:\s*'([^']+)'",
      r"'hd_src'\s*:\s*'([^']+)'",
    ]);

    // 2. Extract SD stream URL
    String? sdUrl = _findStreamUrl(html, [
      r'"browser_native_sd_url"\s*:\s*"([^"]+)"',
      r'"playable_url"\s*:\s*"([^"]+)"',
      r'"sd_src"\s*:\s*"([^"]+)"',
      r'"sd_src_no_ratelimit"\s*:\s*"([^"]+)"',
      r"'browser_native_sd_url'\s*:\s*'([^']+)'",
      r"'playable_url'\s*:\s*'([^']+)'",
      r"'sd_src'\s*:\s*'([^']+)'",
    ]);

    // 3. Fallback: OpenGraph og:video meta tags
    if (hdUrl == null && sdUrl == null) {
      final ogVideoMatch = RegExp(
        r'<meta\s+property="og:video(?::secure_url)?"\s+content="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(html) ??
      RegExp(
        r"<meta\s+property='og:video(?::secure_url)?'\s+content='([^']+)'",
        caseSensitive: false,
      ).firstMatch(html);
      if (ogVideoMatch != null) {
        sdUrl = _cleanUrl(ogVideoMatch.group(1)!);
      }
    }

    if (hdUrl == null && sdUrl == null) {
      return null;
    }

    // 4. Extract Thumbnail
    String thumbnailUrl = '';
    final ogImageMatch = RegExp(
      r'<meta\s+property="og:image(?::secure_url)?"\s+content="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html) ??
    RegExp(
      r"<meta\s+property='og:image(?::secure_url)?'\s+content='([^']+)'",
      caseSensitive: false,
    ).firstMatch(html);
    if (ogImageMatch != null) {
      thumbnailUrl = _cleanUrl(ogImageMatch.group(1)!);
    } else {
      final thumbMatch = RegExp(
        r'"(?:preferred_thumbnail|thumbnailUrl|image)"\s*:\s*\{[^}]*"uri"\s*:\s*"([^"]+)"',
      ).firstMatch(html);
      if (thumbMatch != null) {
        thumbnailUrl = _cleanUrl(thumbMatch.group(1)!);
      }
    }

    // 5. Extract Title and Author
    String title = '';
    String author = 'Facebook Creator';

    final ogTitleMatch = RegExp(
      r'<meta\s+property="og:title"\s+content="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html) ??
    RegExp(
      r"<meta\s+property='og:title'\s+content='([^']+)'",
      caseSensitive: false,
    ).firstMatch(html);

    if (ogTitleMatch != null) {
      final rawTitle = _decodeHtmlEntities(ogTitleMatch.group(1)!);
      final parsed = _parseTitleAndAuthor(rawTitle);
      title = parsed['title']!;
      if (parsed['author']!.isNotEmpty) {
        author = parsed['author']!;
      }
    }

    if (title.isEmpty) {
      final titleTagMatch = RegExp(r'<title>([^<]+)<\/title>', caseSensitive: false).firstMatch(html);
      if (titleTagMatch != null) {
        final rawTitle = _decodeHtmlEntities(titleTagMatch.group(1)!);
        final parsed = _parseTitleAndAuthor(rawTitle);
        title = parsed['title']!;
        if (parsed['author']!.isNotEmpty) {
          author = parsed['author']!;
        }
      }
    }

    if (title.isEmpty) {
      title = info.isReel ? 'Facebook Reel' : 'Facebook Video';
    }

    // 6. Build Stream Versions with file size probing
    final versions = <FacebookVideoVersion>[];

    if (hdUrl != null) {
      final hdSize = await probeContentLength(hdUrl);
      versions.add(
        FacebookVideoVersion(
          url: hdUrl,
          quality: 'hd',
          label: 'HD 720p/1080p (MP4)',
          fileSizeBytes: hdSize,
        ),
      );
    }

    if (sdUrl != null && sdUrl != hdUrl) {
      final sdSize = await probeContentLength(sdUrl);
      versions.add(
        FacebookVideoVersion(
          url: sdUrl,
          quality: 'sd',
          label: 'SD 360p/480p (MP4)',
          fileSizeBytes: sdSize,
        ),
      );
    }

    if (versions.isEmpty && sdUrl != null) {
      final sdSize = await probeContentLength(sdUrl);
      versions.add(
        FacebookVideoVersion(
          url: sdUrl,
          quality: 'sd',
          label: 'Standard Quality (MP4)',
          fileSizeBytes: sdSize,
        ),
      );
    }

    return FacebookMediaResult(
      videoId: info.videoId,
      title: title,
      author: author,
      thumbnailUrl: thumbnailUrl,
      duration: Duration.zero,
      videoVersions: versions,
      isReel: info.isReel,
      hasAudio: true,
    );
  }

  String? _findStreamUrl(String html, List<String> patterns) {
    for (final pattern in patterns) {
      final match = RegExp(pattern).firstMatch(html);
      if (match != null) {
        final url = _cleanUrl(match.group(1)!);
        if (url.startsWith('http://') || url.startsWith('https://')) {
          return url;
        }
      }
    }
    return null;
  }

  String _cleanUrl(String raw) {
    return raw
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u0026', '&')
        .replaceAll('&amp;', '&')
        .trim();
  }

  Map<String, String> _parseTitleAndAuthor(String raw) {
    // Facebook titles often look like:
    // "744K views · 2.3K shares | Video Description | CNN"
    // "Artist Name on Reels | Facebook"
    // "Video Title | Facebook"
    var text = raw.trim();

    // Strip trailing "| Facebook"
    text = text.replaceAll(RegExp(r'\s*\|\s*Facebook\s*$', caseSensitive: false), '');

    // Strip leading views/shares counter (e.g. "744K views · 2.3K shares | ")
    text = text.replaceAll(
      RegExp(r'^\s*[\d.,]+[KMB]?\s+(?:views|reactions|likes)?\s*(?:·|&#xb7;|&middot;)\s*[\d.,]+[KMB]?\s+(?:shares|views)?\s*\|\s*', caseSensitive: false),
      '',
    );

    String author = '';
    String title = text;

    if (text.contains('|')) {
      final parts = text.split('|').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        title = parts[0];
        author = parts.last;
      }
    } else if (text.contains(' on Reels')) {
      final idx = text.indexOf(' on Reels');
      author = text.substring(0, idx).trim();
      title = 'Reel by $author';
    }

    return {'title': title, 'author': author};
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&#xb7;', '·')
        .replaceAll('&middot;', '·')
        .replaceAll('&#x2014;', '—')
        .replaceAll('&mdash;', '—')
        .replaceAll('&#x2013;', '–')
        .replaceAll('&ndash;', '–')
        .replaceAll('&#x2019;', '’')
        .replaceAll('&rsquo;', '’')
        .replaceAll('&#x2018;', '‘')
        .replaceAll('&lsquo;', '‘')
        .replaceAll('&#x201c;', '“')
        .replaceAll('&ldquo;', '“')
        .replaceAll('&#x201d;', '”')
        .replaceAll('&rdquo;', '”')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}
