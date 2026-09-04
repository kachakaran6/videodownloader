import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide VideoUnavailableException;
import '../errors/app_exceptions.dart';
import '../utils/url_validator.dart';
import '../../features/inspect/data/video_inspector.dart';

class SpotifyTrackMetadata {
  final String trackId;
  final String title;
  final String artist;
  final String? album;
  final String thumbnailUrl;

  const SpotifyTrackMetadata({
    required this.trackId,
    required this.title,
    required this.artist,
    this.album,
    required this.thumbnailUrl,
  });
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

  /// Fetches track metadata (title, artist, album, cover) from Spotify public endpoints
  Future<SpotifyTrackMetadata> fetchMetadata(String rawUrl) async {
    final trackId = UrlValidator.extractSpotifyTrackId(rawUrl);
    if (trackId == null) {
      throw const InvalidUrlException();
    }

    final canonicalUrl = 'https://open.spotify.com/track/$trackId';
    String title = '';
    String artist = 'Spotify Artist';
    String? album;
    String thumbnailUrl = '';

    // 1. Query Spotify oEmbed API (Fast & Reliable JSON)
    try {
      final oembedUri = Uri.parse('https://open.spotify.com/oembed?url=${Uri.encodeComponent(canonicalUrl)}');
      final oembedResp = await _client.get(oembedUri, headers: {
        'User-Agent': _defaultUserAgent,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 6));

      if (oembedResp.statusCode == 200) {
        final data = jsonDecode(oembedResp.body) as Map<String, dynamic>;
        title = (data['title'] as String?)?.trim() ?? '';
        thumbnailUrl = (data['thumbnail_url'] as String?)?.trim() ?? '';
      }
    } catch (_) {}

    // 2. Query OpenGraph tags on the track page to extract artist and album
    try {
      final pageResp = await _client.get(Uri.parse(canonicalUrl), headers: {
        'User-Agent': _defaultUserAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      }).timeout(const Duration(seconds: 6));

      if (pageResp.statusCode == 200) {
        final html = pageResp.body;

        // Extract og:title if oembed failed
        if (title.isEmpty) {
          final titleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(html);
          if (titleMatch != null) {
            title = titleMatch.group(1) ?? '';
          }
        }

        // Extract og:image if oembed thumbnail was empty
        if (thumbnailUrl.isEmpty) {
          final imgMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(html);
          if (imgMatch != null) {
            thumbnailUrl = imgMatch.group(1) ?? '';
          }
        }

        // og:description usually has format: "Artist · Album · Song · Year"
        final descMatch = RegExp(r'<meta property="og:description" content="([^"]+)"').firstMatch(html);
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

    if (title.isEmpty) {
      title = 'Spotify Track $trackId';
    }

    return SpotifyTrackMetadata(
      trackId: trackId,
      title: title,
      artist: artist,
      album: album,
      thumbnailUrl: thumbnailUrl,
    );
  }

  /// Inspects a Spotify track, searches YouTube Music for matching high-quality audio,
  /// and returns a VideoInspectionResult with download options.
  Future<VideoInspectionResult> inspect(String rawUrl) async {
    final meta = await fetchMetadata(rawUrl);

    // Search query for matching audio
    final query = '${meta.artist} - ${meta.title} official audio';
    final fallbackQuery = '${meta.title} ${meta.artist}';

    Video? matchedVideo;

    try {
      final searchResults = await _yt.search.search(query).timeout(const Duration(seconds: 8));
      if (searchResults.isNotEmpty) {
        matchedVideo = searchResults.first;
      }
    } catch (_) {}

    if (matchedVideo == null) {
      try {
        final fallbackResults = await _yt.search.search(fallbackQuery).timeout(const Duration(seconds: 8));
        if (fallbackResults.isNotEmpty) {
          matchedVideo = fallbackResults.first;
        }
      } catch (_) {}
    }

    if (matchedVideo == null) {
      throw const AppException('Could not match audio stream for this Spotify track. Please try a direct YouTube link.');
    }

    // Fetch streams for matched audio
    final manifest = await _yt.videos.streamsClient.getManifest(matchedVideo.id);
    final audioStreams = manifest.audioOnly.sortByBitrate();

    if (audioStreams.isEmpty) {
      throw const AppException('No audio streams available for matched track.');
    }

    final bestAudio = manifest.audioOnly.withHighestBitrate();
    final options = <StreamOption>[];

    // 1. Primary Audio Download Option (Recommended)
    final kbps = bestAudio.bitrate.kiloBitsPerSecond.round();
    final audioContainer = bestAudio.container.name.toLowerCase();
    options.add(
      StreamOption(
        id: 'spotify_audio_hq',
        label: 'High Quality Audio ($kbps kbps)',
        container: audioContainer == 'mp4' || audioContainer == 'm4a' ? 'm4a' : 'mp3',
        hasAudio: true,
        fileSizeBytes: bestAudio.size.totalBytes,
        isRecommended: true,
        isAudioOnly: true,
        streamInfo: bestAudio,
      ),
    );

    // 2. Standard Audio Option (if multiple bitrates available)
    if (audioStreams.length > 1) {
      final standardAudio = audioStreams[audioStreams.length ~/ 2];
      if (standardAudio.bitrate.kiloBitsPerSecond != bestAudio.bitrate.kiloBitsPerSecond) {
        final stdKbps = standardAudio.bitrate.kiloBitsPerSecond.round();
        options.add(
          StreamOption(
            id: 'spotify_audio_std',
            label: 'Standard Audio ($stdKbps kbps)',
            container: standardAudio.container.name.toLowerCase(),
            hasAudio: true,
            fileSizeBytes: standardAudio.size.totalBytes,
            isRecommended: false,
            isAudioOnly: true,
            streamInfo: standardAudio,
          ),
        );
      }
    }

    // 3. Optional Music Video Option (if muxed or adaptive video stream exists)
    final muxed = manifest.muxed.sortByBitrate();
    if (muxed.isNotEmpty) {
      final topMuxed = muxed.last;
      options.add(
        StreamOption(
          id: 'spotify_video',
          label: 'Music Video (${topMuxed.qualityLabel})',
          container: 'mp4',
          hasAudio: true,
          fileSizeBytes: topMuxed.size.totalBytes,
          isRecommended: false,
          isAudioOnly: false,
          streamInfo: topMuxed,
        ),
      );
    }

    final duration = matchedVideo.duration ?? const Duration(minutes: 3, seconds: 30);
    final displayThumb = meta.thumbnailUrl.isNotEmpty ? meta.thumbnailUrl : matchedVideo.thumbnails.highResUrl;

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
}
