import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide VideoUnavailableException;
import '../errors/app_exceptions.dart';
import '../utils/url_validator.dart';
import '../../features/inspect/data/video_inspector.dart';
import 'youtube_clients.dart';

class SpotifyTrackMetadata {
  final String trackId;
  final String title;
  final String artist;
  final String? album;
  final String thumbnailUrl;
  final String? previewUrl;
  final Duration? duration;
  final int? trackNumber;
  final int? year;

  const SpotifyTrackMetadata({
    required this.trackId,
    required this.title,
    required this.artist,
    this.album,
    required this.thumbnailUrl,
    this.previewUrl,
    this.duration,
    this.trackNumber,
    this.year,
  });
}

class SpotifyAlbumMetadata {
  final String albumId;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final List<SpotifyTrackMetadata> tracks;

  const SpotifyAlbumMetadata({
    required this.albumId,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.tracks,
  });

  Duration get totalDuration {
    var ms = 0;
    for (final t in tracks) {
      if (t.duration != null) ms += t.duration!.inMilliseconds;
    }
    return Duration(milliseconds: ms);
  }
}

class SpotifyInspector {
  final http.Client _client;
  final YoutubeExplode _yt;

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36';
  static const String _crawlerUserAgent =
      'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)';

  SpotifyInspector({
    http.Client? client,
    YoutubeExplode? yt,
  })  : _client = client ?? http.Client(),
        _yt = yt ?? YoutubeExplode();

  static String _extractBestImage(dynamic images) {
    if (images == null) return '';
    if (images is String && images.startsWith('http')) return images.trim();
    if (images is Map) {
      if (images['url'] != null && images['url'].toString().startsWith('http')) {
        return images['url'].toString();
      }
      if (images['sources'] != null) return _extractBestImage(images['sources']);
      if (images['image'] != null) return _extractBestImage(images['image']);
      if (images['images'] != null) return _extractBestImage(images['images']);
    }
    if (images is List && images.isNotEmpty) {
      dynamic best = images.first;
      int maxWidth = 0;
      for (final img in images) {
        if (img is String && img.startsWith('http')) return img.trim();
        if (img is Map) {
          final w = (img['width'] as num?)?.toInt() ?? 0;
          if (w > maxWidth && img['url'] != null) {
            maxWidth = w;
            best = img;
          }
        }
      }
      if (best is Map && best['url'] != null) {
        return best['url'].toString();
      }
      if (best is String && best.startsWith('http')) {
        return best;
      }
    }
    return '';
  }

  static String _extractArtist(dynamic obj) {
    if (obj == null) return '';
    if (obj is String) return obj.trim();
    if (obj is List) {
      final names = <String>[];
      for (final item in obj) {
        if (item is String && item.trim().isNotEmpty) {
          names.add(item.trim());
        } else if (item is Map) {
          final n = (item['name'] ?? item['title'] ?? item['artistName'] ?? item['displayName'])?.toString().trim();
          if (n != null && n.isNotEmpty) {
            names.add(n);
          }
        }
      }
      return names.join(', ');
    }
    if (obj is Map) {
      if (obj['name'] != null && obj['name'].toString().trim().isNotEmpty) {
        return obj['name'].toString().trim();
      }
      if (obj['title'] != null && obj['title'].toString().trim().isNotEmpty) {
        return obj['title'].toString().trim();
      }
      if (obj['artistName'] != null && obj['artistName'].toString().trim().isNotEmpty) {
        return obj['artistName'].toString().trim();
      }
      if (obj['displayName'] != null && obj['displayName'].toString().trim().isNotEmpty) {
        return obj['displayName'].toString().trim();
      }
      if (obj['artists'] != null) return _extractArtist(obj['artists']);
    }
    return '';
  }

  /// Resolves shortlinks such as https://spotify.link/xxx to canonical Spotify URLs
  Future<String> resolveCanonicalUrl(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (!trimmed.contains('spotify.link')) return trimmed;
    try {
      final req = http.Request('HEAD', Uri.parse(trimmed))..followRedirects = true;
      final streamedResp = await _client.send(req).timeout(const Duration(seconds: 5));
      final finalUri = streamedResp.request?.url;
      if (finalUri != null && finalUri.toString().isNotEmpty) {
        return finalUri.toString();
      }
    } catch (_) {
      try {
        final resp = await _client.get(Uri.parse(trimmed), headers: {
          'User-Agent': _crawlerUserAgent,
        }).timeout(const Duration(seconds: 5));
        final finalUri = resp.request?.url;
        if (finalUri != null && finalUri.toString().isNotEmpty) {
          return finalUri.toString();
        }
      } catch (_) {}
    }
    return trimmed;
  }

  /// Cleans noise like (feat. ...), [feat. ...], (From "..."), - Remastered..., quotes
  static String cleanTrackTitle(String title) {
    var cleaned = title;
    // Strip trailing '| Spotify' or '- song by ... | Spotify' from oEmbed titles
    cleaned = cleaned.replaceAll(RegExp(r'\s*\|\s*Spotify.*$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*-\s*song(?: and lyrics)? by .*$', caseSensitive: false), '');
    // Strip featured artists: (feat. ...), [feat. ...], (ft. ...), [ft. ...]
    cleaned = cleaned.replaceAll(RegExp(r'[\(\[]\s*(?:feat\.?|ft\.?|with)\s+[^\]\)]+[\)\]]', caseSensitive: false), '');
    // Strip movie/soundtrack tags: (From "...") or [From "..."]
    cleaned = cleaned.replaceAll(RegExp(r'[\(\[]\s*From\s+["“][^"”]+["”][\)\]]', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'[\(\[]\s*From\s+[^\]\)]+[\)\]]', caseSensitive: false), '');
    // Strip remastered tags: (2020 Remaster), [Remastered 2011], - Remastered
    cleaned = cleaned.replaceAll(RegExp(r'[\(\[]\s*\d{4}\s*Remaster(?:ed)?\s*[\)\]]', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'[\(\[]\s*Remaster(?:ed)?(?:\s*\d{4})?\s*[\)\]]', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*-\s*(?:\d{4}\s*)?Remaster(?:ed)?.*$', caseSensitive: false), '');
    // Strip video/audio tags: (Official Video), (Official Audio), [Lyric Video]
    cleaned = cleaned.replaceAll(RegExp(r'[\(\[]\s*Official\s+(?:Audio|Video|Music Video|Lyric Video)\s*[\)\]]', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'[\(\[]\s*Lyric\s+Video\s*[\)\]]', caseSensitive: false), '');
    // Strip quotes and escaped quotes that break YouTube search queries
    cleaned = cleaned.replaceAll('"', '').replaceAll("'", '').replaceAll('“', '').replaceAll('”', '');
    // Normalize whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isNotEmpty ? cleaned : title;
  }

  /// Extracts primary artist name for clean search queries
  static String cleanArtist(String artist) {
    var primary = artist.split(RegExp(r'[,&]')).first.trim();
    primary = primary.replaceAll('"', '').replaceAll("'", '').trim();
    return primary.isNotEmpty ? primary : artist;
  }

  /// Scores YouTube video candidates against Spotify track metadata.
  /// Rejects YouTube Shorts (<60s) and multi-hour loops/jukeboxes.
  /// Prioritizes official audio and videos matching the exact track duration.
  static Video? findBestVideoMatch({
    required List<Video> candidates,
    required String targetTitle,
    required String targetArtist,
    Duration? targetDuration,
  }) {
    if (candidates.isEmpty) return null;

    final cleanTitleLower = cleanTrackTitle(targetTitle).toLowerCase();
    final primaryArtist = cleanArtist(targetArtist).toLowerCase();
    final targetSec = targetDuration?.inSeconds;

    Video? bestVideo;
    int bestScore = -9999;

    for (final v in candidates) {
      final durSec = v.duration?.inSeconds ?? 0;
      // Reject YouTube Shorts / preview snippets under 60s if track duration is >= 60s
      if (targetSec != null && targetSec >= 60 && durSec < 60) {
        continue;
      }
      // If target duration is unknown, still reject sub-60s videos as likely Shorts/teasers
      if (targetSec == null && durSec < 60) {
        continue;
      }
      // Reject extreme lengths (e.g. 1 hour loops, multi-song jukeboxes > 20 mins)
      if (durSec > 1200) {
        continue;
      }

      final vTitle = v.title.toLowerCase();
      final vAuthor = v.author.toLowerCase();
      int score = 0;

      // Duration proximity scoring
      if (targetSec != null && targetSec > 0) {
        final diff = (durSec - targetSec).abs();
        if (diff <= 3) {
          score += 120; // Near identical length
        } else if (diff <= 10) {
          score += 80;
        } else if (diff <= 25) {
          score += 50;
        } else if (diff <= 45) {
          score += 20;
        } else if (diff > 90) {
          score -= 60; // Major duration discrepancy
        }
      } else {
        // Reasonable standard song length between 1:30 and 6:00
        if (durSec >= 90 && durSec <= 360) {
          score += 30;
        }
      }

      // Title match
      if (vTitle.contains(cleanTitleLower)) {
        score += 40;
      }

      // Artist match
      if (vTitle.contains(primaryArtist) || vAuthor.contains(primaryArtist)) {
        score += 30;
      }

      // Official audio / official video / topic bonus
      if (vAuthor.contains('- topic') || vTitle.contains('official audio') || vTitle.contains('audio')) {
        score += 35;
      } else if (vTitle.contains('official video') || vTitle.contains('official music video')) {
        score += 20;
      }

      // Penalize unwanted versions if original track doesn't specify them
      if (vTitle.contains('cover') && !cleanTitleLower.contains('cover')) score -= 50;
      if (vTitle.contains('remix') && !cleanTitleLower.contains('remix')) score -= 40;
      if (vTitle.contains('mashup') && !cleanTitleLower.contains('mashup')) score -= 50;
      if (vTitle.contains('live') && !cleanTitleLower.contains('live')) score -= 30;
      if (vTitle.contains('slowed') || vTitle.contains('reverb')) score -= 50;
      if (vTitle.contains('teaser') || vTitle.contains('trailer') || vTitle.contains('#shorts')) score -= 100;
      if (vTitle.contains('1 hour') || vTitle.contains('loop') || vTitle.contains('jukebox')) score -= 80;

      if (score > bestScore) {
        bestScore = score;
        bestVideo = v;
      }
    }

    // Fallback: if no video passed threshold, pick first candidate with duration >= 60s
    if (bestVideo == null && candidates.isNotEmpty) {
      for (final v in candidates) {
        final dur = v.duration?.inSeconds ?? 0;
        if (dur >= 60 && dur <= 1200) {
          bestVideo = v;
          break;
        }
      }
    }

    return bestVideo;
  }

  /// Fetches rich track metadata (exact title, real artist, album, HD cover, audio preview) from Spotify public endpoints
  Future<SpotifyTrackMetadata> fetchMetadata(String rawUrl) async {
    final resolvedUrl = await resolveCanonicalUrl(rawUrl);
    final trackId = UrlValidator.extractSpotifyTrackId(resolvedUrl) ?? UrlValidator.extractSpotifyTrackId(rawUrl);
    if (trackId == null) {
      throw const InvalidUrlException();
    }

    String title = '';
    String artist = '';
    String? album;
    String thumbnailUrl = '';
    String? previewUrl;
    Duration? duration;
    int? trackNumber;
    int? year;

    // 1. Primary Source: Spotify official embed with __NEXT_DATA__
    try {
      final embedUri = Uri.parse('https://open.spotify.com/embed/track/$trackId');
      final embedResp = await _client.get(embedUri, headers: {
        'User-Agent': _defaultUserAgent,
        'Accept': 'text/html,application/xhtml+xml',
      }).timeout(const Duration(seconds: 6));

      if (embedResp.statusCode == 200) {
        final body = embedResp.body;
        final nextDataMatch = RegExp(r'<script\s+id="__NEXT_DATA__"\s+type="application/json">([^<]+)</script>').firstMatch(body);
        if (nextDataMatch != null) {
          final json = jsonDecode(nextDataMatch.group(1)!);
          final entity = json['props']?['pageProps']?['state']?['data']?['entity'];
          if (entity != null) {
            title = (entity['name'] ?? entity['title'])?.toString().trim() ?? '';
            final artistsList = entity['artists'] as List?;
            if (artistsList != null && artistsList.isNotEmpty) {
              artist = artistsList
                  .map((a) => a is Map ? a['name']?.toString() : null)
                  .where((n) => n != null && n.isNotEmpty)
                  .join(', ');
            }
            final durMs = (entity['duration'] as num?)?.toInt() ?? 0;
            if (durMs > 0) {
              duration = Duration(milliseconds: durMs);
            }
            final preview = entity['audioPreview']?['url']?.toString();
            if (preview != null && preview.isNotEmpty) {
              previewUrl = preview;
            }
            final images = entity['visualIdentity']?['image'] as List?;
            final bestImg = _extractBestImage(images);
            if (bestImg.isNotEmpty) {
              thumbnailUrl = bestImg;
            }
            if (entity['album'] != null && entity['album'] is Map) {
              final albName = (entity['album']['name'] ?? entity['album']['title'])?.toString().trim();
              if (albName != null && albName.isNotEmpty) {
                album = albName;
              }
              final albYear = (entity['album']['date']?['year'] as num?)?.toInt();
              if (albYear != null && albYear > 0) {
                year = albYear;
              }
            }
            final trkNum = (entity['trackNumber'] as num?)?.toInt();
            if (trkNum != null && trkNum > 0) {
              trackNumber = trkNum;
            }
          }
        }
      }
    } catch (_) {}

    // 2. Secondary Source: Social Crawler User-Agent (Facebook / Twitter bot gets 100% server-rendered og tags)
    if (artist.isEmpty || title.isEmpty || duration == null) {
      try {
        final canonicalUrl = 'https://open.spotify.com/track/$trackId';
        final pageResp = await _client.get(Uri.parse(canonicalUrl), headers: {
          'User-Agent': _crawlerUserAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        }).timeout(const Duration(seconds: 6));

        if (pageResp.statusCode == 200) {
          final html = pageResp.body;
          if (title.isEmpty) {
            final titleMatch = RegExp(r'<meta\s+(?:property|name)="og:title"\s+content="([^"]+)"', caseSensitive: false).firstMatch(html);
            if (titleMatch != null) {
              title = titleMatch.group(1) ?? '';
            }
          }
          if (thumbnailUrl.isEmpty) {
            final imgMatch = RegExp(r'<meta\s+(?:property|name)="og:image"\s+content="([^"]+)"', caseSensitive: false).firstMatch(html);
            if (imgMatch != null) {
              thumbnailUrl = imgMatch.group(1) ?? '';
            }
          }
          final descMatch = RegExp(r'<meta\s+(?:property|name)="og:description"\s+content="([^"]+)"', caseSensitive: false).firstMatch(html);
          if (descMatch != null) {
            final desc = descMatch.group(1) ?? '';
            final parts = desc.split(RegExp(r'\s*[·•|-]\s*'));
            if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
              artist = parts[0].trim();
            }
            if (parts.length > 1 && parts[1].trim().isNotEmpty && parts[1].trim().toLowerCase() != 'song') {
              album = parts[1].trim();
            }
          }
          if (duration == null) {
            final durMatch = RegExp(r'<meta\s+(?:property|name)="music:duration"\s+content="(\d+)"', caseSensitive: false).firstMatch(html);
            if (durMatch != null) {
              final sec = int.tryParse(durMatch.group(1)!);
              if (sec != null && sec > 0) {
                duration = Duration(seconds: sec);
              }
            }
          }
        }
      } catch (_) {}
    }

    // 3. Third Source: Spotify oEmbed API as fallback
    if (title.isEmpty || thumbnailUrl.isEmpty) {
      try {
        final canonicalUrl = 'https://open.spotify.com/track/$trackId';
        final oembedUri = Uri.parse('https://open.spotify.com/oembed?url=${Uri.encodeComponent(canonicalUrl)}');
        final oembedResp = await _client.get(oembedUri, headers: {
          'User-Agent': _defaultUserAgent,
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 5));

        if (oembedResp.statusCode == 200) {
          final data = jsonDecode(oembedResp.body) as Map<String, dynamic>;
          if (title.isEmpty) {
            title = (data['title'] as String?)?.trim() ?? '';
          }
          if (thumbnailUrl.isEmpty) {
            thumbnailUrl = (data['thumbnail_url'] as String?)?.trim() ?? '';
          }
        }
      } catch (_) {}
    }

    if (title.isEmpty) {
      title = 'Spotify Track $trackId';
    }
    if (artist.isEmpty) {
      artist = 'Spotify Artist';
    }

    return SpotifyTrackMetadata(
      trackId: trackId,
      title: title,
      artist: artist,
      album: album,
      thumbnailUrl: thumbnailUrl,
      previewUrl: previewUrl,
      duration: duration,
      trackNumber: trackNumber,
      year: year,
    );
  }

  /// Inspects a Spotify track, gathers full-length high-quality audio streams,
  /// and returns a VideoInspectionResult with download options.
  Future<VideoInspectionResult> inspect(String rawUrl) async {
    final meta = await fetchMetadata(rawUrl);

    final cleanTitle = cleanTrackTitle(meta.title);
    final primaryArtist = cleanArtist(meta.artist);

    final options = <StreamOption>[];

    // Priority queries using cleaned track title & primary artist
    final queries = [
      '$primaryArtist $cleanTitle official audio',
      '$primaryArtist $cleanTitle',
      '$cleanTitle $primaryArtist',
    ];

    final candidates = <Video>[];
    for (final q in queries) {
      try {
        final searchResults = await _yt.search.search(q).timeout(const Duration(seconds: 8));
        for (final v in searchResults.take(6)) {
          if (!candidates.any((c) => c.id == v.id)) {
            candidates.add(v);
          }
        }
        if (candidates.length >= 10) break;
      } catch (_) {}
    }

    final matchedVideo = findBestVideoMatch(
      candidates: candidates,
      targetTitle: meta.title,
      targetArtist: meta.artist,
      targetDuration: meta.duration,
    );

    if (matchedVideo != null) {
      try {
        final manifest = await _yt.videos.streamsClient.getManifest(
          matchedVideo.id,
          ytClients: AppYoutubeClients.defaultClients,
        );
        final mp4Audios = manifest.audioOnly
            .where((s) => s.container.name.toLowerCase() == 'mp4' || s.container.name.toLowerCase() == 'm4a')
            .sortByBitrate();
        final audioStreams = mp4Audios.isNotEmpty ? mp4Audios : manifest.audioOnly.sortByBitrate();

        if (audioStreams.isNotEmpty) {
          final bestAudio = audioStreams.withHighestBitrate();
          final kbps = bestAudio.bitrate.kiloBitsPerSecond.round();
          final audioExt = (bestAudio.container.name.toLowerCase() == 'mp4' || bestAudio.container.name.toLowerCase() == 'm4a')
              ? 'm4a'
              : bestAudio.container.name.toLowerCase();

          options.add(
            StreamOption(
              id: 'spotify_audio_full',
              label: 'Full Length Audio ($kbps kbps ${audioExt.toUpperCase()})',
              container: audioExt,
              hasAudio: true,
              fileSizeBytes: bestAudio.size.totalBytes,
              isRecommended: true,
              isAudioOnly: true,
              streamInfo: bestAudio,
            ),
          );

          if (audioStreams.length > 1) {
            final standardAudio = audioStreams[audioStreams.length ~/ 2];
            if (standardAudio.bitrate.kiloBitsPerSecond != bestAudio.bitrate.kiloBitsPerSecond) {
              final stdKbps = standardAudio.bitrate.kiloBitsPerSecond.round();
              options.add(
                StreamOption(
                  id: 'spotify_audio_std',
                  label: 'Standard Audio ($stdKbps kbps ${audioExt.toUpperCase()})',
                  container: audioExt,
                  hasAudio: true,
                  fileSizeBytes: standardAudio.size.totalBytes,
                  isRecommended: false,
                  isAudioOnly: true,
                  streamInfo: standardAudio,
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    // Only add preview option if full audio was NOT matched, and clearly label it
    if (options.isEmpty && meta.previewUrl != null && meta.previewUrl!.isNotEmpty) {
      options.add(
        StreamOption(
          id: 'spotify_audio_preview',
          label: 'Spotify Preview Snippet (30s Audio - Full Song Unavailable)',
          container: 'mp3',
          hasAudio: true,
          fileSizeBytes: 360000,
          isRecommended: true,
          isAudioOnly: true,
          directUrl: meta.previewUrl,
        ),
      );
    }

    if (options.isEmpty) {
      throw const AppException('Could not match full length audio stream for this Spotify track. Please try a direct YouTube link.');
    }

    final duration = (matchedVideo?.duration != null && matchedVideo!.duration!.inSeconds >= 60)
        ? matchedVideo.duration!
        : (meta.duration ?? const Duration(minutes: 3, seconds: 30));

    final displayThumb = meta.thumbnailUrl.isNotEmpty
        ? meta.thumbnailUrl
        : (matchedVideo?.thumbnails.highResUrl ?? '');

    return VideoInspectionResult(
      videoId: 'spotify_${meta.trackId}',
      title: '${meta.title} - ${meta.artist}',
      author: meta.artist,
      thumbnailUrl: displayThumb,
      duration: duration,
      options: options,
      platform: MediaPlatform.spotifyTrack,
      album: meta.album,
      trackNumber: meta.trackNumber,
      year: meta.year,
      spotifyTracks: [meta],
    );
  }

  /// Fetches rich album metadata (title, artist, HD cover art, full tracklist with durations & previews)
  Future<SpotifyAlbumMetadata> fetchAlbumMetadata(String rawUrl) async {
    final resolvedUrl = await resolveCanonicalUrl(rawUrl);
    final playlistId = UrlValidator.extractSpotifyPlaylistId(resolvedUrl) ?? UrlValidator.extractSpotifyPlaylistId(rawUrl);
    final albumId = UrlValidator.extractSpotifyAlbumId(resolvedUrl) ?? UrlValidator.extractSpotifyAlbumId(rawUrl);
    final entityId = playlistId ?? albumId;
    final isPlaylist = playlistId != null || resolvedUrl.contains('/playlist/') || rawUrl.contains('/playlist/');

    if (entityId == null) {
      throw const InvalidUrlException();
    }

    String title = '';
    String artist = '';
    String thumbnailUrl = '';
    final tracks = <SpotifyTrackMetadata>[];

    // Primary Source: Spotify official embed with __NEXT_DATA__
    try {
      final embedUrl = isPlaylist
          ? 'https://open.spotify.com/embed/playlist/$entityId'
          : 'https://open.spotify.com/embed/album/$entityId';

      final resp = await _client.get(Uri.parse(embedUrl), headers: {
        'User-Agent': _defaultUserAgent,
        'Accept': 'text/html,application/xhtml+xml',
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final body = resp.body;
        final nextDataMatch = RegExp(r'<script\s+id="__NEXT_DATA__"\s+type="application/json">([^<]+)</script>').firstMatch(body);
        if (nextDataMatch != null) {
          final json = jsonDecode(nextDataMatch.group(1)!);
          final stateData = json['props']?['pageProps']?['state']?['data'];
          final entity = stateData?['entity'] ?? stateData?['playlist'] ?? stateData?['album'] ?? json['props']?['pageProps'];
          if (entity != null) {
            title = (entity['title'] ?? entity['name'])?.toString().trim() ?? '';
            artist = _extractArtist(entity['subtitle']);
            if (artist.isEmpty) artist = _extractArtist(entity['artists']);
            if (artist.isEmpty) artist = _extractArtist(entity['artist']);
            if (artist.isEmpty) artist = _extractArtist(entity['owner']);
            if (artist.isEmpty) artist = _extractArtist(entity['by']);
            if (artist.isEmpty) artist = _extractArtist(entity['artistsText']);

            final images = (entity['visualIdentity'] ?? entity['images'] ?? entity['coverArt']) as dynamic;
            final bestImg = _extractBestImage(images);
            if (bestImg.isNotEmpty) {
              thumbnailUrl = bestImg;
            }

            final trackList = (entity['trackList'] ?? entity['tracks']?['items'] ?? entity['tracks']) as List?;
            if (trackList != null) {
              for (int i = 0; i < trackList.length; i++) {
                final t = trackList[i];
                if (t is Map) {
                  final trackObj = t['track'] is Map ? t['track'] as Map : t;
                  final uri = (trackObj['uri'] ?? trackObj['id'])?.toString() ?? '';
                  final tId = uri.contains(':') ? uri.split(':').last : 'track_$i';
                  final tTitle = (trackObj['title'] ?? trackObj['name'])?.toString().trim() ?? 'Track ${i + 1}';
                  
                  String tArtist = _extractArtist(trackObj['subtitle']);
                  if (tArtist.isEmpty) tArtist = _extractArtist(trackObj['artists']);
                  if (tArtist.isEmpty) tArtist = _extractArtist(trackObj['artist']);
                  if (tArtist.isEmpty) tArtist = _extractArtist(trackObj['artistsText']);
                  if (tArtist.isEmpty) tArtist = _extractArtist(trackObj['artistName']);
                  if (tArtist.isEmpty) tArtist = _extractArtist(trackObj['artist_name']);
                  if (tArtist.isEmpty) tArtist = _extractArtist(trackObj['by']);
                  if (tArtist.isEmpty) {
                    tArtist = artist.isNotEmpty ? artist : 'Spotify Artist';
                  }

                  final durMs = (trackObj['duration'] ?? trackObj['duration_ms'] as num?)?.toInt() ?? 0;
                  final preview = trackObj['audioPreview']?['url']?.toString() ?? trackObj['preview_url']?.toString();

                  String tThumb = _extractBestImage(trackObj['visualIdentity']);
                  if (tThumb.isEmpty) tThumb = _extractBestImage(trackObj['album']);
                  if (tThumb.isEmpty) tThumb = _extractBestImage(trackObj['images']);
                  if (tThumb.isEmpty) tThumb = _extractBestImage(trackObj['coverArt']);
                  if (tThumb.isEmpty) tThumb = _extractBestImage(trackObj['thumbnailUrl'] ?? trackObj['thumbnail_url']);
                  if (tThumb.isEmpty) tThumb = thumbnailUrl;

                  tracks.add(
                    SpotifyTrackMetadata(
                      trackId: tId,
                      title: tTitle,
                      artist: tArtist,
                      album: title,
                      thumbnailUrl: tThumb,
                      previewUrl: (preview != null && preview.isNotEmpty) ? preview : null,
                      duration: durMs > 0 ? Duration(milliseconds: durMs) : null,
                    ),
                  );
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    // Fallback: oEmbed API if title or cover art is missing
    if (title.isEmpty || thumbnailUrl.isEmpty) {
      try {
        final canonicalUrl = isPlaylist
            ? 'https://open.spotify.com/playlist/$entityId'
            : 'https://open.spotify.com/album/$entityId';
        final oembedUri = Uri.parse('https://open.spotify.com/oembed?url=${Uri.encodeComponent(canonicalUrl)}');
        final oembedResp = await _client.get(oembedUri, headers: {
          'User-Agent': _defaultUserAgent,
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 5));

        if (oembedResp.statusCode == 200) {
          final data = jsonDecode(oembedResp.body) as Map<String, dynamic>;
          if (title.isEmpty) title = (data['title'] as String?)?.trim() ?? '';
          if (thumbnailUrl.isEmpty) thumbnailUrl = (data['thumbnail_url'] as String?)?.trim() ?? '';
        }
      } catch (_) {}
    }

    if (title.isEmpty) title = isPlaylist ? 'Spotify Playlist' : 'Spotify Album';
    if (artist.isEmpty) artist = 'Spotify Artist';

    if (tracks.isEmpty) {
      throw const AppException('No tracks could be found in this Spotify playlist. Please verify the link or privacy settings.');
    }

    return SpotifyAlbumMetadata(
      albumId: entityId,
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      tracks: tracks,
    );
  }

  /// Inspects a Spotify album or playlist, gathers track metadata, and returns a VideoInspectionResult.
  Future<VideoInspectionResult> inspectAlbum(String rawUrl) async {
    final album = await fetchAlbumMetadata(rawUrl);
    final isPlaylist = rawUrl.contains('/playlist/') || UrlValidator.extractSpotifyPlaylistId(rawUrl) != null;

    // If an album/release contains only 1 track (single-song release), inspect it as a single track
    if (!isPlaylist && album.tracks.length == 1) {
      final singleTrack = album.tracks.first;
      return await inspect('https://open.spotify.com/track/${singleTrack.trackId}');
    }

    final options = <StreamOption>[
      const StreamOption(
        id: 'spotify_album_full',
        label: 'Full Length Audio (Original Audio)',
        container: 'm4a',
        hasAudio: true,
        fileSizeBytes: null,
        isRecommended: true,
        isAudioOnly: true,
      ),
      const StreamOption(
        id: 'spotify_album_preview',
        label: 'Fast Preview (30s Audio Clips)',
        container: 'mp3',
        hasAudio: true,
        fileSizeBytes: null,
        isRecommended: false,
        isAudioOnly: true,
      ),
    ];

    return VideoInspectionResult(
      videoId: album.albumId,
      title: album.title,
      author: album.artist,
      thumbnailUrl: album.thumbnailUrl,
      duration: album.totalDuration,
      options: options,
      platform: isPlaylist ? MediaPlatform.spotifyPlaylist : MediaPlatform.spotifyAlbum,
      spotifyTracks: album.tracks,
    );
  }
}
