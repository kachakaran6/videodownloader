import 'dart:convert';
import 'package:http/http.dart' as http;
import '../errors/app_exceptions.dart';
import '../utils/url_validator.dart';

class TwitterVideoVersion {
  final String url;
  final int? width;
  final int? height;
  final int? bitrate;
  final int? fileSizeBytes;

  const TwitterVideoVersion({
    required this.url,
    this.width,
    this.height,
    this.bitrate,
    this.fileSizeBytes,
  });

  TwitterVideoVersion copyWith({
    String? url,
    int? width,
    int? height,
    int? bitrate,
    int? fileSizeBytes,
  }) {
    return TwitterVideoVersion(
      url: url ?? this.url,
      width: width ?? this.width,
      height: height ?? this.height,
      bitrate: bitrate ?? this.bitrate,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }

  String get label {
    if (height != null && height! > 0) {
      if (height! >= 1080) return '1080p Full HD';
      if (height! >= 720) return '720p HD';
      if (height! >= 480) return '480p SD';
      if (height! >= 360) return '360p (Data Saver)';
      if (height! >= 240) return '240p';
      return '${height}p';
    }
    if (width != null && width! > 0) {
      if (width! >= 1920) return '1080p Full HD';
      if (width! >= 1280) return '720p HD';
      if (width! >= 854) return '480p SD';
      if (width! >= 640) return '360p';
    }
    return 'High Quality (MP4)';
  }
}

class TwitterImageVersion {
  final String url;
  final int? width;
  final int? height;
  final int? fileSizeBytes;

  const TwitterImageVersion({
    required this.url,
    this.width,
    this.height,
    this.fileSizeBytes,
  });

  TwitterImageVersion copyWith({
    String? url,
    int? width,
    int? height,
    int? fileSizeBytes,
  }) {
    return TwitterImageVersion(
      url: url ?? this.url,
      width: width ?? this.width,
      height: height ?? this.height,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }

  String get label {
    if (width != null && height != null) {
      return 'Photo (${width}x$height)';
    }
    return 'High Quality Photo (JPG)';
  }
}

class TwitterMediaResult {
  final String tweetId;
  final String title;
  final String fullText;
  final String author;
  final String authorUsername;
  final String authorAvatarUrl;
  final String thumbnailUrl;
  final Duration duration;
  final List<TwitterVideoVersion> videoVersions;
  final List<TwitterImageVersion> imageVersions;
  final MediaPlatform platform;
  final bool hasAudio;

  const TwitterMediaResult({
    required this.tweetId,
    required this.title,
    required this.fullText,
    required this.author,
    required this.authorUsername,
    required this.authorAvatarUrl,
    required this.thumbnailUrl,
    required this.duration,
    required this.videoVersions,
    this.imageVersions = const [],
    this.platform = MediaPlatform.twitterVideo,
    this.hasAudio = true,
  });

  bool get isImageOnly => videoVersions.isEmpty && imageVersions.isNotEmpty;
}

class TwitterInspector {
  final http.Client _client;

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36';

  TwitterInspector([http.Client? client]) : _client = client ?? http.Client();

  /// Resolves any t.co shortlink or tracking redirect to its canonical destination.
  Future<String> resolveRedirects(String rawUrl) async {
    try {
      final uri = Uri.parse(rawUrl);
      final req = http.Request('GET', uri)
        ..followRedirects = true
        ..maxRedirects = 5
        ..headers['User-Agent'] = _defaultUserAgent
        ..headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';

      final streamedRes = await _client.send(req).timeout(const Duration(seconds: 8));
      return streamedRes.request?.url.toString() ?? rawUrl;
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

  /// Inspects a Twitter / X post and extracts high-bitrate video streams with multi-tier fallbacks.
  Future<TwitterMediaResult> inspect(String rawUrl) async {
    String targetUrl = rawUrl.trim();
    if (targetUrl.contains('t.co/')) {
      targetUrl = await resolveRedirects(targetUrl);
    }

    final info = UrlValidator.extractTwitterInfo(targetUrl);
    if (info == null) {
      throw const InvalidUrlException('Please enter a valid Twitter or X post link.');
    }

    // Step 1: Attempt Tier 1 (FxTwitter REST API)
    TwitterMediaResult? result;
    try {
      result = await _inspectViaFxTwitter('https://api.fxtwitter.com/i/status/${info.tweetId}', info);
    } catch (e) {
      if (e is NetworkException) rethrow;
    }

    // Step 2: Attempt Tier 2 (FixupX REST API mirror)
    if (result == null || (result.videoVersions.isEmpty && result.imageVersions.isEmpty)) {
      try {
        result = await _inspectViaFxTwitter('https://api.fixupx.com/i/status/${info.tweetId}', info);
      } catch (_) {}
    }

    // Step 3: Attempt Tier 3 (VxTwitter API)
    if (result == null || (result.videoVersions.isEmpty && result.imageVersions.isEmpty)) {
      try {
        result = await _inspectViaVxTwitter(info);
      } catch (_) {}
    }

    // Step 4: Attempt Tier 4 (Direct Media 302 Redirect)
    if (result == null || (result.videoVersions.isEmpty && result.imageVersions.isEmpty)) {
      try {
        result = await _inspectViaDirectRedirect(info);
      } catch (_) {}
    }

    // If still no result, throw user-friendly exception
    if (result == null || (result.videoVersions.isEmpty && result.imageVersions.isEmpty)) {
      throw const VideoUnavailableException(
        'Could not extract video stream from this X (Twitter) post. It may be private, deleted, or text-only.',
      );
    }

    // Step 5: Probe content length for video versions to populate accurate file sizes
    final enrichedVideos = await Future.wait(
      result.videoVersions.map((v) async {
        if (v.fileSizeBytes != null && v.fileSizeBytes! > 0) return v;
        final size = await probeContentLength(v.url);
        return v.copyWith(fileSizeBytes: size);
      }),
    );

    return TwitterMediaResult(
      tweetId: result.tweetId,
      title: result.title,
      fullText: result.fullText,
      author: result.author,
      authorUsername: result.authorUsername,
      authorAvatarUrl: result.authorAvatarUrl,
      thumbnailUrl: result.thumbnailUrl,
      duration: result.duration,
      videoVersions: enrichedVideos,
      imageVersions: result.imageVersions,
      platform: result.platform,
      hasAudio: result.hasAudio,
    );
  }

  /// Tier 1 & 2: Parses response from FxTwitter / FixupX JSON API
  Future<TwitterMediaResult?> _inspectViaFxTwitter(String apiUrl, TwitterMediaInfo info) async {
    try {
      final resp = await _client.get(
        Uri.parse(apiUrl),
        headers: {
          'User-Agent': _defaultUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200 || resp.body.isEmpty) {
        return null;
      }

      final json = jsonDecode(resp.body);
      if (json is! Map<String, dynamic>) return null;

      final tweet = json['tweet'] as Map<String, dynamic>?;
      if (tweet == null) return null;

      final tweetText = (tweet['text'] as String?)?.trim() ?? '';
      final authorData = tweet['author'] as Map<String, dynamic>?;
      final authorName = (authorData?['name'] as String?)?.trim() ?? info.username ?? 'X User';
      final authorScreenName = (authorData?['screen_name'] as String?)?.trim() ?? info.username ?? '';
      final authorAvatar = (authorData?['avatar_url'] as String?)?.trim() ?? '';

      final media = tweet['media'] as Map<String, dynamic>?;
      final videos = <TwitterVideoVersion>[];
      final images = <TwitterImageVersion>[];
      String thumbnailUrl = '';
      Duration duration = Duration.zero;

      if (media != null) {
        final videoList = media['videos'] as List<dynamic>?;
        if (videoList != null && videoList.isNotEmpty) {
          for (final v in videoList) {
            if (v is Map<String, dynamic>) {
              final videoUrl = v['url'] as String?;
              if (videoUrl == null || videoUrl.isEmpty) continue;

              final width = v['width'] as int?;
              final height = v['height'] as int?;
              final thumb = v['thumbnail_url'] as String?;
              final durationSec = v['duration'];
              if (thumb != null && thumb.isNotEmpty && thumbnailUrl.isEmpty) {
                thumbnailUrl = thumb;
              }
              if (durationSec is num && durationSec > 0 && duration == Duration.zero) {
                duration = Duration(milliseconds: (durationSec * 1000).toInt());
              }

              videos.add(
                TwitterVideoVersion(
                  url: videoUrl,
                  width: width,
                  height: height,
                ),
              );
            }
          }
        }

        final photoList = media['photos'] as List<dynamic>?;
        if (photoList != null && photoList.isNotEmpty) {
          for (final p in photoList) {
            if (p is Map<String, dynamic>) {
              final imgUrl = p['url'] as String?;
              if (imgUrl == null || imgUrl.isEmpty) continue;
              if (thumbnailUrl.isEmpty) thumbnailUrl = imgUrl;

              images.add(
                TwitterImageVersion(
                  url: imgUrl,
                  width: p['width'] as int?,
                  height: p['height'] as int?,
                ),
              );
            }
          }
        }
      }

      if (videos.isEmpty && images.isEmpty) return null;

      // Sort videos by resolution descending (highest quality first)
      videos.sort((a, b) {
        final hA = a.height ?? 0;
        final hB = b.height ?? 0;
        if (hA != hB) return hB.compareTo(hA);
        final wA = a.width ?? 0;
        final wB = b.width ?? 0;
        return wB.compareTo(wA);
      });

      final title = tweetText.isNotEmpty
          ? (tweetText.length > 100 ? '${tweetText.substring(0, 97)}...' : tweetText)
          : 'X Video by @$authorScreenName';

      return TwitterMediaResult(
        tweetId: info.tweetId,
        title: title,
        fullText: tweetText,
        author: authorName,
        authorUsername: authorScreenName,
        authorAvatarUrl: authorAvatar,
        thumbnailUrl: thumbnailUrl,
        duration: duration,
        videoVersions: videos,
        imageVersions: images,
      );
    } catch (_) {
      return null;
    }
  }

  /// Tier 3: Parses response from VxTwitter API
  Future<TwitterMediaResult?> _inspectViaVxTwitter(TwitterMediaInfo info) async {
    try {
      final apiUrl = 'https://api.vxtwitter.com/Twitter/status/${info.tweetId}';
      final resp = await _client.get(
        Uri.parse(apiUrl),
        headers: {
          'User-Agent': _defaultUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200 || resp.body.isEmpty) return null;

      final json = jsonDecode(resp.body);
      if (json is! Map<String, dynamic>) return null;

      final text = (json['text'] as String?)?.trim() ?? '';
      final authorName = (json['user_name'] as String?)?.trim() ?? info.username ?? 'X User';
      final authorScreenName = (json['user_screen_name'] as String?)?.trim() ?? info.username ?? '';
      final authorAvatar = (json['user_profile_image_url'] as String?)?.trim() ?? '';

      final videos = <TwitterVideoVersion>[];
      final images = <TwitterImageVersion>[];
      String thumbnailUrl = '';

      final mediaExtended = json['media_extended'] as List<dynamic>?;
      if (mediaExtended != null) {
        for (final m in mediaExtended) {
          if (m is Map<String, dynamic>) {
            final type = m['type'] as String?;
            final url = m['url'] as String?;
            final thumb = m['thumbnail_url'] as String?;
            if (url == null || url.isEmpty) continue;
            if (thumb != null && thumb.isNotEmpty && thumbnailUrl.isEmpty) {
              thumbnailUrl = thumb;
            }

            final size = m['size'] as Map<String, dynamic>?;
            final width = size?['w'] as int?;
            final height = size?['h'] as int?;

            if (type == 'video' || type == 'gif') {
              videos.add(
                TwitterVideoVersion(
                  url: url,
                  width: width,
                  height: height,
                ),
              );
            } else if (type == 'image') {
              images.add(
                TwitterImageVersion(
                  url: url,
                  width: width,
                  height: height,
                ),
              );
            }
          }
        }
      }

      if (videos.isEmpty) {
        final mediaUrls = json['mediaURLs'] as List<dynamic>?;
        if (mediaUrls != null) {
          for (final u in mediaUrls) {
            if (u is String && (u.contains('.mp4') || u.contains('video.twimg.com'))) {
              videos.add(TwitterVideoVersion(url: u));
            }
          }
        }
      }

      if (videos.isEmpty && images.isEmpty) return null;

      final title = text.isNotEmpty
          ? (text.length > 100 ? '${text.substring(0, 97)}...' : text)
          : 'X Video by @$authorScreenName';

      return TwitterMediaResult(
        tweetId: info.tweetId,
        title: title,
        fullText: text,
        author: authorName,
        authorUsername: authorScreenName,
        authorAvatarUrl: authorAvatar,
        thumbnailUrl: thumbnailUrl,
        duration: Duration.zero,
        videoVersions: videos,
        imageVersions: images,
      );
    } catch (_) {
      return null;
    }
  }

  /// Tier 4: Direct Media Redirection resolver (captures 302/redirect destination)
  Future<TwitterMediaResult?> _inspectViaDirectRedirect(TwitterMediaInfo info) async {
    final directEndpoints = [
      'https://d.fxtwitter.com/i/status/${info.tweetId}',
      'https://d.fixupx.com/i/status/${info.tweetId}',
    ];

    for (final endpoint in directEndpoints) {
      try {
        final req = http.Request('GET', Uri.parse(endpoint))
          ..followRedirects = false
          ..headers['User-Agent'] = _defaultUserAgent;

        final streamed = await _client.send(req).timeout(const Duration(seconds: 8));
        String? location = streamed.headers['location'];

        // If redirect wasn't stopped, look at request URL
        if (location == null && streamed.statusCode >= 300 && streamed.statusCode < 400) {
          location = streamed.headers['Location'];
        }

        if (location != null && location.isNotEmpty && (location.contains('.mp4') || location.contains('video.twimg.com'))) {
          // Fetch oembed for author details
          final oembed = await _fetchOembed(info.tweetId);

          return TwitterMediaResult(
            tweetId: info.tweetId,
            title: oembed?['title'] ?? 'X Video',
            fullText: oembed?['title'] ?? '',
            author: oembed?['author'] ?? info.username ?? 'X User',
            authorUsername: info.username ?? '',
            authorAvatarUrl: '',
            thumbnailUrl: '',
            duration: Duration.zero,
            videoVersions: [
              TwitterVideoVersion(url: location),
            ],
          );
        }
      } catch (_) {}
    }

    return null;
  }

  /// Helper to fetch clean oEmbed title & author from publish.x.com
  Future<Map<String, String>?> _fetchOembed(String tweetId) async {
    try {
      final oembedUrl = 'https://publish.x.com/oembed?url=https://x.com/i/status/$tweetId';
      final resp = await _client.get(
        Uri.parse(oembedUrl),
        headers: {'User-Agent': _defaultUserAgent},
      ).timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>?;
        if (json != null) {
          final authorName = (json['author_name'] as String?)?.trim() ?? '';
          final html = (json['html'] as String?) ?? '';
          final textMatch = RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true).firstMatch(html);
          final text = textMatch != null
              ? textMatch.group(1)!.replaceAll(RegExp(r'<[^>]*>'), '').trim()
              : '';

          return {
            'author': authorName,
            'title': text,
          };
        }
      }
    } catch (_) {}
    return null;
  }
}
