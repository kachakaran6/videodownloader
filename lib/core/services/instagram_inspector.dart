import 'dart:convert';
import 'package:http/http.dart' as http;
import '../errors/app_exceptions.dart';
import '../utils/url_validator.dart';

class InstagramVideoVersion {
  final String url;
  final int? width;
  final int? height;
  final int? type;
  final int? fileSizeBytes;

  const InstagramVideoVersion({
    required this.url,
    this.width,
    this.height,
    this.type,
    this.fileSizeBytes,
  });

  InstagramVideoVersion copyWith({
    String? url,
    int? width,
    int? height,
    int? type,
    int? fileSizeBytes,
  }) {
    return InstagramVideoVersion(
      url: url ?? this.url,
      width: width ?? this.width,
      height: height ?? this.height,
      type: type ?? this.type,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }

  String get label {
    if (width != null && height != null) {
      final minSide = width! < height! ? width! : height!;
      if (minSide >= 1080) return '1080p Full HD';
      if (minSide >= 720) return '720p HD';
      if (minSide >= 480) return '480p SD';
      return '${minSide}p';
    }
    if (type == 101) return 'High Quality (MP4)';
    if (type == 102) return 'Standard Quality (MP4)';
    if (type == 103) return 'Mobile Saver (MP4)';
    return 'MP4 Video';
  }
}

class InstagramImageVersion {
  final String url;
  final int? width;
  final int? height;
  final int? fileSizeBytes;

  const InstagramImageVersion({
    required this.url,
    this.width,
    this.height,
    this.fileSizeBytes,
  });

  InstagramImageVersion copyWith({
    String? url,
    int? width,
    int? height,
    int? fileSizeBytes,
  }) {
    return InstagramImageVersion(
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

class InstagramMediaResult {
  final String shortcode;
  final String title;
  final String author;
  final String authorUsername;
  final String thumbnailUrl;
  final Duration duration;
  final List<InstagramVideoVersion> videoVersions;
  final List<InstagramImageVersion> imageVersions;
  final MediaPlatform platform;
  final bool hasAudio;

  const InstagramMediaResult({
    required this.shortcode,
    required this.title,
    required this.author,
    required this.authorUsername,
    required this.thumbnailUrl,
    required this.duration,
    required this.videoVersions,
    this.imageVersions = const [],
    required this.platform,
    this.hasAudio = true,
  });

  bool get isImageOnly => videoVersions.isEmpty && imageVersions.isNotEmpty;
}

class InstagramInspector {
  final http.Client _client;
  final Map<String, String> _cookieJar = {};

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36';

  InstagramInspector([http.Client? client]) : _client = client ?? http.Client();

  void _updateCookies(http.Response res) {
    final rawCookie = res.headers['set-cookie'];
    if (rawCookie != null) {
      for (final cookie in rawCookie.split(',')) {
        final part = cookie.split(';').first.trim();
        final eq = part.indexOf('=');
        if (eq != -1) {
          final k = part.substring(0, eq).trim();
          final v = part.substring(eq + 1).trim();
          if (k.isNotEmpty) _cookieJar[k] = v;
        }
      }
    }
  }

  String _cookieHeader() {
    return _cookieJar.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Future<void> _ensureSession() async {
    if (_cookieJar.containsKey('csrftoken') || _cookieJar.containsKey('mid')) {
      return;
    }
    try {
      final homeResp = await _client.get(
        Uri.parse('https://www.instagram.com/'),
        headers: {
          'User-Agent': _defaultUserAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Sec-Fetch-Mode': 'navigate',
        },
      );
      _updateCookies(homeResp);
    } catch (_) {
      // Continue even if home handshake fails
    }
  }

  /// Probes the direct CDN URL to determine the exact file size in bytes
  Future<int?> probeContentLength(String url) async {
    try {
      final uri = Uri.parse(url);
      final headReq = http.Request('HEAD', uri)
        ..headers['User-Agent'] = _defaultUserAgent
        ..headers['Accept'] = '*/*';
      final headRes = await _client.send(headReq).timeout(const Duration(milliseconds: 3000));
      if (headRes.contentLength != null && headRes.contentLength! > 0) {
        return headRes.contentLength;
      }

      final rangeReq = http.Request('GET', uri)
        ..headers['User-Agent'] = _defaultUserAgent
        ..headers['Range'] = 'bytes=0-0';
      final rangeRes = await _client.send(rangeReq).timeout(const Duration(milliseconds: 3000));
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

  Future<InstagramMediaResult> inspect(String rawUrl) async {
    final info = UrlValidator.extractInstagramInfo(rawUrl);
    if (info == null) {
      throw const InvalidUrlException();
    }

    if (info.isStory) {
      return await _inspectStory(info);
    }

    return await _inspectPostOrReel(info);
  }

  Future<InstagramMediaResult> _inspectPostOrReel(InstagramMediaInfo info) async {
    await _ensureSession();

    final targetUrl = 'https://www.instagram.com/p/${info.shortcode}/';
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
          if (_cookieJar.isNotEmpty) 'Cookie': _cookieHeader(),
        },
      );
      _updateCookies(resp);
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        throw const NetworkException();
      }
      throw AppException('Failed to connect to Instagram: $e');
    }

    final html = resp.body;

    // Check for login redirection or private restriction
    if (resp.isRedirect ||
        html.contains('login_required') ||
        html.contains('/accounts/login/')) {
      if (!html.contains('xig_polaris_media')) {
        throw const AppException(
          'This Instagram Reel or post is private, age-restricted, or removed.',
        );
      }
    }

    // Step 1: Parse <script data-sjs> payloads
    final sjsMatches =
        RegExp(r'<script\b[^>]+\bdata-sjs>(\{.+?\})<\/script>').allMatches(html);

    Map<String, dynamic>? targetPolaris;

    void findPolaris(dynamic obj) {
      if (targetPolaris != null) return;
      if (obj is Map<String, dynamic>) {
        if (obj.containsKey('xig_polaris_media')) {
          targetPolaris = obj['xig_polaris_media'] as Map<String, dynamic>?;
          return;
        }
        for (final val in obj.values) {
          findPolaris(val);
        }
      } else if (obj is List) {
        for (final val in obj) {
          findPolaris(val);
        }
      }
    }

    for (final m in sjsMatches) {
      final scriptContent = m.group(1);
      if (scriptContent != null && scriptContent.contains('xig_polaris_media')) {
        try {
          final decoded = jsonDecode(scriptContent);
          findPolaris(decoded);
          if (targetPolaris != null) break;
        } catch (_) {}
      }
    }

    if (targetPolaris != null) {
      final item = (targetPolaris!['if_not_gated_logged_out'] as Map<String, dynamic>?) ??
          targetPolaris!;
      final user = item['user'] as Map<String, dynamic>?;
      final caption = item['caption'] as Map<String, dynamic>?;
      final rawVideoVersions = item['video_versions'] as List?;
      final displayUri = item['display_uri']?.toString() ?? '';
      final hasAudio = item['has_audio'] as bool? ?? true;

      final username = user?['username']?.toString() ?? 'instagram_user';
      final authorName = user?['full_name']?.toString() ?? username;

      String title = caption?['text']?.toString().trim() ?? '';
      if (title.contains('\n')) {
        title = title.split('\n').first.trim();
      }
      if (title.isEmpty) {
        title = 'Instagram ${info.isReel ? "Reel" : "Video"} by @$username';
      }

      // Collect video versions
      final versions = <InstagramVideoVersion>[];
      if (rawVideoVersions != null) {
        for (final v in rawVideoVersions) {
          if (v is Map<String, dynamic>) {
            final url = v['url']?.toString();
            if (url != null && url.isNotEmpty) {
              versions.add(InstagramVideoVersion(
                url: url,
                width: v['width'] as int?,
                height: v['height'] as int?,
                type: v['type'] as int?,
              ));
            }
          }
        }
      }

      // Check single video_url fallback
      if (versions.isEmpty && item['video_url'] != null) {
        versions.add(InstagramVideoVersion(url: item['video_url'].toString()));
      }

      // Collect image versions (photos / carousels)
      final imageVersions = <InstagramImageVersion>[];
      final rawImageCandidates = (item['image_versions2'] as Map<String, dynamic>?)?['candidates'] as List?;
      if (rawImageCandidates != null) {
        for (final img in rawImageCandidates) {
          if (img is Map<String, dynamic>) {
            final url = img['url']?.toString();
            if (url != null && url.isNotEmpty) {
              imageVersions.add(InstagramImageVersion(
                url: url,
                width: img['width'] as int?,
                height: img['height'] as int?,
              ));
            }
          }
        }
      }

      // Check carousel media (multi-photo / multi-video post)
      final carouselMedia = item['carousel_media'] as List?;
      if (carouselMedia != null) {
        for (final cItem in carouselMedia) {
          if (cItem is Map<String, dynamic>) {
            final cVideos = cItem['video_versions'] as List?;
            if (cVideos != null) {
              for (final cv in cVideos) {
                if (cv is Map<String, dynamic> && cv['url'] != null) {
                  versions.add(InstagramVideoVersion(
                    url: cv['url'].toString(),
                    width: cv['width'] as int?,
                    height: cv['height'] as int?,
                  ));
                }
              }
            }
            final cImgs = (cItem['image_versions2'] as Map<String, dynamic>?)?['candidates'] as List?;
            if (cImgs != null && cImgs.isNotEmpty) {
              final topImg = cImgs.first;
              if (topImg is Map<String, dynamic> && topImg['url'] != null) {
                imageVersions.add(InstagramImageVersion(
                  url: topImg['url'].toString(),
                  width: topImg['width'] as int?,
                  height: topImg['height'] as int?,
                ));
              }
            } else if (cItem['display_uri'] != null) {
              imageVersions.add(InstagramImageVersion(url: cItem['display_uri'].toString()));
            }
          }
        }
      }

      // Fallback to displayUri if no specific candidates
      if (imageVersions.isEmpty && displayUri.isNotEmpty) {
        imageVersions.add(InstagramImageVersion(url: displayUri));
      }

      // If video exists, return video media result
      if (versions.isNotEmpty) {
        final durationSeconds = (item['video_duration'] as num?)?.toDouble() ??
            (item['duration'] as num?)?.toDouble() ??
            0.0;
        final mediaDuration = durationSeconds > 0
            ? Duration(milliseconds: (durationSeconds * 1000).round())
            : Duration.zero;

        final resolvedVersions = await Future.wait(
          versions.map((v) async {
            int? size = await probeContentLength(v.url);
            if (size == null && durationSeconds > 0) {
              final minSide = (v.width != null && v.height != null)
                  ? (v.width! < v.height! ? v.width! : v.height!)
                  : (v.type == 101 ? 1080 : (v.type == 102 ? 720 : 480));
              final bytesPerSec = minSide >= 1080
                  ? 400000
                  : (minSide >= 720 ? 225000 : 112500);
              size = (durationSeconds * bytesPerSec).round();
            }
            return v.copyWith(fileSizeBytes: size);
          }),
        );

        return InstagramMediaResult(
          shortcode: info.shortcode,
          title: title,
          author: '$authorName (@$username)',
          authorUsername: username,
          thumbnailUrl: displayUri,
          duration: mediaDuration,
          videoVersions: resolvedVersions,
          imageVersions: imageVersions,
          platform: info.platform,
          hasAudio: hasAudio,
        );
      }

      // If photo/image only, return image media result
      if (imageVersions.isNotEmpty) {
        final resolvedImages = await Future.wait(
          imageVersions.map((img) async {
            final size = await probeContentLength(img.url);
            return img.copyWith(fileSizeBytes: size);
          }),
        );

        return InstagramMediaResult(
          shortcode: info.shortcode,
          title: title.isEmpty ? 'Instagram Photo by @$username' : title,
          author: '$authorName (@$username)',
          authorUsername: username,
          thumbnailUrl: displayUri.isNotEmpty ? displayUri : imageVersions.first.url,
          duration: Duration.zero,
          videoVersions: const [],
          imageVersions: resolvedImages,
          platform: info.platform,
          hasAudio: false,
        );
      }
    }

    // Fallback: Embed endpoint
    final embedResult = await _inspectEmbed(info);
    if (embedResult != null) {
      return embedResult;
    }

    // Fallback: OpenGraph tags from main page HTML
    final ogVideo = RegExp(r'<meta\s+property="og:video(?::secure_url)?"\s+content="([^"]+)"', caseSensitive: false).firstMatch(html)?.group(1);
    final ogImage = RegExp(r'<meta\s+property="og:image(?::secure_url)?"\s+content="([^"]+)"', caseSensitive: false).firstMatch(html)?.group(1) ??
        RegExp(r'<meta\s+name="twitter:image"\s+content="([^"]+)"', caseSensitive: false).firstMatch(html)?.group(1);

    if (ogVideo != null && ogVideo.isNotEmpty) {
      final clean = ogVideo.replaceAll('&amp;', '&');
      final size = await probeContentLength(clean);
      return InstagramMediaResult(
        shortcode: info.shortcode,
        title: 'Instagram ${info.isReel ? "Reel" : "Video"}',
        author: 'Instagram Creator',
        authorUsername: 'instagram',
        thumbnailUrl: ogImage?.replaceAll('&amp;', '&') ?? '',
        duration: Duration.zero,
        videoVersions: [InstagramVideoVersion(url: clean, fileSizeBytes: size)],
        platform: info.platform,
      );
    }

    if (ogImage != null && ogImage.isNotEmpty) {
      final clean = ogImage.replaceAll('&amp;', '&');
      final size = await probeContentLength(clean);
      return InstagramMediaResult(
        shortcode: info.shortcode,
        title: 'Instagram Photo',
        author: 'Instagram Creator',
        authorUsername: 'instagram',
        thumbnailUrl: clean,
        duration: Duration.zero,
        videoVersions: const [],
        imageVersions: [InstagramImageVersion(url: clean, fileSizeBytes: size)],
        platform: info.platform,
      );
    }

    throw const AppException(
      'Could not extract media stream from this Instagram post. It might be private or removed.',
    );
  }

  Future<InstagramMediaResult?> _inspectEmbed(InstagramMediaInfo info) async {
    try {
      final embedUrl = 'https://www.instagram.com/p/${info.shortcode}/embed/captioned/';
      final resp = await _client.get(
        Uri.parse(embedUrl),
        headers: {
          'User-Agent': _defaultUserAgent,
          'Accept': 'text/html,application/xhtml+xml',
        },
      );
      if (resp.statusCode == 200) {
        final body = resp.body;
        final videoMatch = RegExp(r'"video_url"\s*:\s*"([^"]+)"').firstMatch(body);
        final thumbMatch = RegExp(r'"display_url"\s*:\s*"([^"]+)"').firstMatch(body) ??
            RegExp(r'<img[^>]+class="[^"]*EmbeddedMediaImage[^"]*"[^>]+src="([^"]+)"').firstMatch(body) ??
            RegExp(r'<img[^>]+src="(https://[^"]*(?:cdninstagram|fbcdn)[^"]*)"').firstMatch(body);

        final cleanThumb = thumbMatch != null
            ? thumbMatch.group(1)!.replaceAll(r'\u0026', '&').replaceAll(r'\/', '/').replaceAll('&amp;', '&')
            : '';

        if (videoMatch != null) {
          final raw = videoMatch.group(1)!;
          final clean = raw.replaceAll(r'\u0026', '&').replaceAll(r'\/', '/');
          final size = await probeContentLength(clean);
          return InstagramMediaResult(
            shortcode: info.shortcode,
            title: 'Instagram ${info.isReel ? "Reel" : "Video"}',
            author: 'Instagram Creator',
            authorUsername: 'instagram',
            thumbnailUrl: cleanThumb,
            duration: Duration.zero,
            videoVersions: [InstagramVideoVersion(url: clean, fileSizeBytes: size)],
            platform: info.platform,
          );
        } else if (cleanThumb.isNotEmpty) {
          final size = await probeContentLength(cleanThumb);
          return InstagramMediaResult(
            shortcode: info.shortcode,
            title: 'Instagram Photo',
            author: 'Instagram Creator',
            authorUsername: 'instagram',
            thumbnailUrl: cleanThumb,
            duration: Duration.zero,
            videoVersions: const [],
            imageVersions: [InstagramImageVersion(url: cleanThumb, fileSizeBytes: size)],
            platform: info.platform,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<InstagramMediaResult> _inspectStory(InstagramMediaInfo info) async {
    await _ensureSession();
    // Attempt story fetch
    final storyUrl = info.canonicalUrl;
    try {
      final resp = await _client.get(
        Uri.parse(storyUrl),
        headers: {
          'User-Agent': _defaultUserAgent,
          'Accept': 'text/html,application/xhtml+xml',
          if (_cookieJar.isNotEmpty) 'Cookie': _cookieHeader(),
        },
      );

      final sjsMatches =
          RegExp(r'<script\b[^>]+\bdata-sjs>(\{.+?\})<\/script>').allMatches(resp.body);
      Map<String, dynamic>? targetPolaris;

      void findPolaris(dynamic obj) {
        if (targetPolaris != null) return;
        if (obj is Map<String, dynamic>) {
          if (obj.containsKey('xig_polaris_media')) {
            targetPolaris = obj['xig_polaris_media'] as Map<String, dynamic>?;
            return;
          }
          for (final val in obj.values) {
            findPolaris(val);
          }
        } else if (obj is List) {
          for (final val in obj) {
            findPolaris(val);
          }
        }
      }

      for (final m in sjsMatches) {
        final s = m.group(1);
        if (s != null && s.contains('xig_polaris_media')) {
          try {
            findPolaris(jsonDecode(s));
            if (targetPolaris != null) break;
          } catch (_) {}
        }
      }

      if (targetPolaris != null) {
        final item = (targetPolaris!['if_not_gated_logged_out'] as Map<String, dynamic>?) ??
            targetPolaris!;
        final rawVideoVersions = item['video_versions'] as List?;
        if (rawVideoVersions != null && rawVideoVersions.isNotEmpty) {
          final versions = rawVideoVersions
              .whereType<Map<String, dynamic>>()
              .map((v) => InstagramVideoVersion(
                    url: v['url'].toString(),
                    width: v['width'] as int?,
                    height: v['height'] as int?,
                  ))
              .toList();

          return InstagramMediaResult(
            shortcode: info.shortcode,
            title: 'Instagram Story by @${info.storyUsername ?? "user"}',
            author: '@${info.storyUsername ?? "user"}',
            authorUsername: info.storyUsername ?? 'user',
            thumbnailUrl: item['display_uri']?.toString() ?? '',
            duration: Duration.zero,
            videoVersions: versions,
            platform: MediaPlatform.instagramStory,
          );
        }

        // Photo story
        final displayUri = item['display_uri']?.toString() ?? '';
        final rawImgs = (item['image_versions2'] as Map<String, dynamic>?)?['candidates'] as List?;
        final imgUrl = (rawImgs != null && rawImgs.isNotEmpty && rawImgs.first is Map<String, dynamic>)
            ? (rawImgs.first['url']?.toString() ?? displayUri)
            : displayUri;

        if (imgUrl.isNotEmpty) {
          final size = await probeContentLength(imgUrl);
          return InstagramMediaResult(
            shortcode: info.shortcode,
            title: 'Instagram Story Photo by @${info.storyUsername ?? "user"}',
            author: '@${info.storyUsername ?? "user"}',
            authorUsername: info.storyUsername ?? 'user',
            thumbnailUrl: imgUrl,
            duration: Duration.zero,
            videoVersions: const [],
            imageVersions: [InstagramImageVersion(url: imgUrl, fileSizeBytes: size)],
            platform: MediaPlatform.instagramStory,
            hasAudio: false,
          );
        }
      }
    } catch (_) {}

    // When Instagram server enforces login wall for stories
    throw AppException(
      'Instagram Stories require an active login session.\n\n'
      'Instagram restricts anonymous access to Stories on user @${info.storyUsername ?? "unknown"}. '
      'Reels and regular public posts can be downloaded directly!',
    );
  }

  void close() {
    _client.close();
  }
}
