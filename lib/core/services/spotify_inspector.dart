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

  const SpotifyTrackMetadata({
    required this.trackId,
    required this.title,
    required this.artist,
    this.album,
    required this.thumbnailUrl,
    this.previewUrl,
    this.duration,
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

  SpotifyInspector({
    http.Client? client,
    YoutubeExplode? yt,
  })  : _client = client ?? http.Client(),
        _yt = yt ?? YoutubeExplode();

  static String _extractBestImage(List? images) {
    if (images == null || images.isEmpty) return '';
    dynamic best = images.first;
    int maxWidth = 0;
    for (final img in images) {
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
    return '';
  }

  /// Fetches rich track metadata (exact title, real artist, album, HD cover, audio preview) from Spotify public endpoints
  Future<SpotifyTrackMetadata> fetchMetadata(String rawUrl) async {
    final trackId = UrlValidator.extractSpotifyTrackId(rawUrl);
    if (trackId == null) {
      throw const InvalidUrlException();
    }

    String title = '';
    String artist = '';
    String? album;
    String thumbnailUrl = '';
    String? previewUrl;
    Duration? duration;

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
          }
        }
      }
    } catch (_) {}

    // 2. Secondary Source: Spotify oEmbed API
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

    // 3. Third Source: OpenGraph tags on the track page to extract artist and album
    if (artist.isEmpty || title.isEmpty) {
      try {
        final canonicalUrl = 'https://open.spotify.com/track/$trackId';
        final pageResp = await _client.get(Uri.parse(canonicalUrl), headers: {
          'User-Agent': _defaultUserAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        }).timeout(const Duration(seconds: 5));

        if (pageResp.statusCode == 200) {
          final html = pageResp.body;
          if (title.isEmpty) {
            final titleMatch = RegExp(r'<meta\s+property="og:title"\s+content="([^"]+)"', caseSensitive: false).firstMatch(html);
            if (titleMatch != null) {
              title = titleMatch.group(1) ?? '';
            }
          }
          if (thumbnailUrl.isEmpty) {
            final imgMatch = RegExp(r'<meta\s+property="og:image"\s+content="([^"]+)"', caseSensitive: false).firstMatch(html);
            if (imgMatch != null) {
              thumbnailUrl = imgMatch.group(1) ?? '';
            }
          }
          final descMatch = RegExp(r'<meta\s+property="og:description"\s+content="([^"]+)"', caseSensitive: false).firstMatch(html);
          if (descMatch != null) {
            final desc = descMatch.group(1) ?? '';
            final parts = desc.split(RegExp(r'\s*[·•|-]\s*'));
            if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
              artist = parts[0].trim();
            }
            if (parts.length > 1 && parts[1].trim().isNotEmpty) {
              album = parts[1].trim();
            }
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
    );
  }

  /// Inspects a Spotify track, gathers high-quality audio options,
  /// and returns a VideoInspectionResult with download options.
  Future<VideoInspectionResult> inspect(String rawUrl) async {
    final meta = await fetchMetadata(rawUrl);

    final options = <StreamOption>[];

    // Option 1: Full Audio Matching via YouTube (Full original track)
    final queries = [
      '${meta.artist} - ${meta.title} official audio',
      '${meta.title} ${meta.artist}',
      '${meta.title} audio',
    ];

    Video? matchedVideo;
    for (final q in queries) {
      try {
        final searchResults = await _yt.search.search(q).timeout(const Duration(seconds: 6));
        if (searchResults.isNotEmpty) {
          matchedVideo = searchResults.first;
          break;
        }
      } catch (_) {}
    }

    if (matchedVideo != null) {
      try {
        final manifest = await _yt.videos.streamsClient.getManifest(
          matchedVideo.id,
          ytClients: AppYoutubeClients.defaultClients,
        );
        final audioStreams = manifest.audioOnly.sortByBitrate();

        if (audioStreams.isNotEmpty) {
          final bestAudio = manifest.audioOnly.withHighestBitrate();
          final kbps = bestAudio.bitrate.kiloBitsPerSecond.round();
          options.add(
            StreamOption(
              id: 'spotify_audio_full',
              label: 'Full Length Audio ($kbps kbps MP3)',
              container: 'mp3',
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
                  label: 'Standard Audio ($stdKbps kbps MP3)',
                  container: 'mp3',
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

    // Option 2: Fallback 30s preview clip from Spotify CDN (only recommended if no full match found)
    if (meta.previewUrl != null && meta.previewUrl!.isNotEmpty) {
      options.add(
        StreamOption(
          id: 'spotify_audio_preview',
          label: 'Spotify Preview Clip (30s Audio)',
          container: 'mp3',
          hasAudio: true,
          fileSizeBytes: 360000,
          isRecommended: options.isEmpty,
          isAudioOnly: true,
          directUrl: meta.previewUrl,
        ),
      );
    }

    if (options.isEmpty) {
      throw const AppException('Could not match audio stream for this Spotify track. Please try a direct YouTube link.');
    }

    final duration = meta.duration ?? matchedVideo?.duration ?? const Duration(minutes: 3, seconds: 30);
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
    );
  }

  /// Fetches rich album metadata (title, artist, HD cover art, full tracklist with durations & previews)
  Future<SpotifyAlbumMetadata> fetchAlbumMetadata(String rawUrl) async {
    final albumId = UrlValidator.extractSpotifyAlbumId(rawUrl) ??
        UrlValidator.extractSpotifyPlaylistId(rawUrl);
    if (albumId == null) {
      throw const InvalidUrlException();
    }

    String title = '';
    String artist = '';
    String thumbnailUrl = '';
    final tracks = <SpotifyTrackMetadata>[];

    // Primary Source: Spotify official embed with __NEXT_DATA__
    try {
      final isPlaylist = rawUrl.contains('/playlist/');
      final embedUrl = isPlaylist
          ? 'https://open.spotify.com/embed/playlist/$albumId'
          : 'https://open.spotify.com/embed/album/$albumId';

      final resp = await _client.get(Uri.parse(embedUrl), headers: {
        'User-Agent': _defaultUserAgent,
        'Accept': 'text/html,application/xhtml+xml',
      }).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final body = resp.body;
        final nextDataMatch = RegExp(r'<script\s+id="__NEXT_DATA__"\s+type="application/json">([^<]+)</script>').firstMatch(body);
        if (nextDataMatch != null) {
          final json = jsonDecode(nextDataMatch.group(1)!);
          final entity = json['props']?['pageProps']?['state']?['data']?['entity'];
          if (entity != null) {
            title = (entity['title'] ?? entity['name'])?.toString().trim() ?? '';
            artist = entity['subtitle']?.toString().trim() ?? '';

            final images = entity['visualIdentity']?['image'] as List?;
            final bestImg = _extractBestImage(images);
            if (bestImg.isNotEmpty) {
              thumbnailUrl = bestImg;
            }

            final trackList = entity['trackList'] as List?;
            if (trackList != null) {
              for (int i = 0; i < trackList.length; i++) {
                final t = trackList[i];
                if (t is Map) {
                  final uri = t['uri']?.toString() ?? '';
                  final tId = uri.contains(':') ? uri.split(':').last : 'track_$i';
                  final tTitle = t['title']?.toString().trim() ?? 'Track ${i + 1}';
                  final tArtist = (t['subtitle']?.toString().trim().isNotEmpty ?? false)
                      ? t['subtitle']!.toString().trim()
                      : (artist.isNotEmpty ? artist : 'Spotify Artist');
                  final durMs = (t['duration'] as num?)?.toInt() ?? 0;
                  final preview = t['audioPreview']?['url']?.toString();

                  tracks.add(
                    SpotifyTrackMetadata(
                      trackId: tId,
                      title: tTitle,
                      artist: tArtist,
                      album: title,
                      thumbnailUrl: thumbnailUrl,
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
        final canonicalUrl = 'https://open.spotify.com/album/$albumId';
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

    if (title.isEmpty) title = 'Spotify Album';
    if (artist.isEmpty) artist = 'Spotify Artist';

    if (tracks.isEmpty) {
      throw const AppException('No tracks could be found in this Spotify album. Please verify the link.');
    }

    return SpotifyAlbumMetadata(
      albumId: albumId,
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      tracks: tracks,
    );
  }

  /// Inspects a Spotify album, gathers track metadata, and returns a VideoInspectionResult.
  Future<VideoInspectionResult> inspectAlbum(String rawUrl) async {
    final album = await fetchAlbumMetadata(rawUrl);

    final options = <StreamOption>[
      const StreamOption(
        id: 'spotify_album_full',
        label: 'Full Length Audio (Original MP3)',
        container: 'mp3',
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
      platform: MediaPlatform.spotifyAlbum,
      spotifyTracks: album.tracks,
    );
  }
}
