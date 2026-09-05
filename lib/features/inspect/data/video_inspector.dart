import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide VideoUnavailableException;
import '../../../core/errors/app_exceptions.dart';
import '../../../core/services/youtube_clients.dart';
import '../../../core/services/instagram_inspector.dart';
import '../../../core/services/spotify_inspector.dart';
import '../../../core/utils/url_validator.dart';

class StreamOption {
  final String id;
  final String label;
  final String container;
  final bool hasAudio;
  final int? fileSizeBytes;
  final bool isRecommended;
  final bool isAudioOnly;
  final StreamInfo? streamInfo;
  final StreamInfo? audioStreamInfo;
  final String? directUrl;

  const StreamOption({
    required this.id,
    required this.label,
    required this.container,
    required this.hasAudio,
    required this.fileSizeBytes,
    required this.isRecommended,
    required this.isAudioOnly,
    this.streamInfo,
    this.audioStreamInfo,
    this.directUrl,
  });

  bool get isDirectStream => directUrl != null;

  String get summaryText {
    final sizeStr = fileSizeBytes != null
        ? '~${(fileSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB'
        : 'Size calculated during download';
    final typeStr = isAudioOnly ? 'Audio only' : 'Video + audio';
    return '$label · ${container.toUpperCase()} · $typeStr · $sizeStr';
  }
}

class VideoInspectionResult {
  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final Duration duration;
  final List<StreamOption> options;
  final MediaPlatform platform;

  const VideoInspectionResult({
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.duration,
    required this.options,
    this.platform = MediaPlatform.youtube,
  });

  bool get isInstagram =>
      platform == MediaPlatform.instagramReel ||
      platform == MediaPlatform.instagramPost ||
      platform == MediaPlatform.instagramStory;

  bool get isYouTube => platform == MediaPlatform.youtube;
  bool get isSpotify => platform == MediaPlatform.spotifyTrack;

  String get platformBadgeText {
    switch (platform) {
      case MediaPlatform.instagramReel:
        return 'Instagram Reel';
      case MediaPlatform.instagramPost:
        return 'Instagram Video';
      case MediaPlatform.instagramStory:
        return 'Instagram Story';
      case MediaPlatform.youtube:
        return 'YouTube';
      case MediaPlatform.spotifyTrack:
        return 'Spotify Track';
      case MediaPlatform.unsupported:
        return 'Video';
    }
  }
}

class VideoInspector {
  final YoutubeExplode _yt;
  final InstagramInspector _instagram;
  final SpotifyInspector _spotify;

  VideoInspector({
    YoutubeExplode? yt,
    InstagramInspector? instagram,
    SpotifyInspector? spotify,
  })  : _yt = yt ?? YoutubeExplode(),
        _instagram = instagram ?? InstagramInspector(),
        _spotify = spotify ?? SpotifyInspector(yt: yt);

  static String _formatResolutionLabel(int height) {
    switch (height) {
      case 2160:
        return '4K Ultra HD (2160p)';
      case 1440:
        return '2K QHD (1440p)';
      case 1080:
        return '1080p Full HD';
      case 720:
        return '720p HD';
      case 480:
        return '480p';
      case 360:
        return '360p (Data Saver)';
      case 240:
        return '240p';
      case 144:
        return '144p (Low Data)';
      default:
        return '${height}p';
    }
  }

  Future<VideoInspectionResult> inspect(String rawUrl) async {
    final platform = UrlValidator.detectPlatform(rawUrl);

    switch (platform) {
      case MediaPlatform.youtube:
        return await _inspectYouTube(rawUrl);
      case MediaPlatform.instagramReel:
      case MediaPlatform.instagramPost:
      case MediaPlatform.instagramStory:
        return await _inspectInstagram(rawUrl, platform);
      case MediaPlatform.spotifyTrack:
        return await _spotify.inspect(rawUrl);
      case MediaPlatform.unsupported:
        throw const InvalidUrlException();
    }
  }

  Future<VideoInspectionResult> _inspectInstagram(
    String rawUrl,
    MediaPlatform platform,
  ) async {
    final igRes = await _instagram.inspect(rawUrl);

    final options = <StreamOption>[];
    for (int i = 0; i < igRes.videoVersions.length; i++) {
      final v = igRes.videoVersions[i];
      options.add(
        StreamOption(
          id: 'ig_${igRes.shortcode}_$i',
          label: v.label,
          container: 'mp4',
          hasAudio: igRes.hasAudio,
          fileSizeBytes: v.fileSizeBytes,
          isRecommended: i == 0,
          isAudioOnly: false,
          directUrl: v.url,
        ),
      );
    }

    if (options.isEmpty) {
      throw const AppException('No downloadable video stream available for this Instagram media.');
    }

    return VideoInspectionResult(
      videoId: igRes.shortcode,
      title: igRes.title,
      author: igRes.author,
      thumbnailUrl: igRes.thumbnailUrl,
      duration: igRes.duration,
      options: options,
      platform: platform,
    );
  }

  Future<VideoInspectionResult> _inspectYouTube(String rawUrl) async {
    final videoId = UrlValidator.extractVideoId(rawUrl);
    if (videoId == null) {
      throw const InvalidUrlException();
    }

    try {
      final video = await _yt.videos.get(videoId);
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: AppYoutubeClients.defaultClients,
      );

      final options = <StreamOption>[];
      final bestAudio = manifest.audioOnly.isNotEmpty
          ? manifest.audioOnly.withHighestBitrate()
          : null;

      // Filter compatible audio streams for native MP4 / WebM muxing
      final mp4Audios = manifest.audioOnly
          .where((a) =>
              a.container.name.toLowerCase() == 'mp4' ||
              a.container.name.toLowerCase() == 'm4a')
          .toList();
      final bestMp4Audio = mp4Audios.isNotEmpty ? mp4Audios.withHighestBitrate() : bestAudio;

      final webmAudios = manifest.audioOnly
          .where((a) => a.container.name.toLowerCase() == 'webm')
          .toList();
      final bestWebmAudio = webmAudios.isNotEmpty ? webmAudios.withHighestBitrate() : bestAudio;

      // 1. Gather all unique available resolution heights across muxed & adaptive video streams
      final heights = <int>{};
      for (final stream in manifest.muxed) {
        heights.add(stream.videoResolution.height);
      }
      for (final stream in manifest.videoOnly) {
        heights.add(stream.videoResolution.height);
      }

      // Sort descending (highest resolution first: 4K down to 144p)
      final sortedHeights = heights.toList()..sort((a, b) => b.compareTo(a));

      for (final height in sortedHeights) {
        // If a pre-muxed (video+audio) stream exists for this resolution, prioritize it
        final muxedForHeight =
            manifest.muxed.where((s) => s.videoResolution.height == height).toList();
        if (muxedForHeight.isNotEmpty) {
          final stream = muxedForHeight.first;
          options.add(
            StreamOption(
              id: 'opt_${height}_${stream.container.name}',
              label: _formatResolutionLabel(height),
              container: stream.container.name,
              hasAudio: true,
              fileSizeBytes: stream.size.totalBytes > 0 ? stream.size.totalBytes : null,
              isRecommended: false,
              isAudioOnly: false,
              streamInfo: stream,
            ),
          );
          continue;
        }

        // Otherwise pick the best video-only stream (prefer MP4 container, fallback to WebM)
        final videoStreams =
            manifest.videoOnly.where((s) => s.videoResolution.height == height).toList();
        if (videoStreams.isEmpty) continue;

        // Prioritize AVC/H.264 streams because Android's native MediaMuxer (MPEG4Writer) strictly rejects AV1 (video/av01)
        final avcStreams = videoStreams.where((s) {
          final codec = s.videoCodec.toLowerCase();
          return s.container.name.toLowerCase() == 'mp4' &&
              (codec.startsWith('avc') || codec.startsWith('h264'));
        }).toList();

        final mp4NonAv1Streams = videoStreams.where((s) {
          final codec = s.videoCodec.toLowerCase();
          return s.container.name.toLowerCase() == 'mp4' && !codec.startsWith('av01');
        }).toList();

        final stream = avcStreams.isNotEmpty
            ? avcStreams.first
            : (mp4NonAv1Streams.isNotEmpty
                ? mp4NonAv1Streams.first
                : videoStreams.first);

        final isMp4 = stream.container.name.toLowerCase() == 'mp4';
        final matchingAudio = isMp4 ? bestMp4Audio : bestWebmAudio;

        final totalBytes = (stream.size.totalBytes > 0 ? stream.size.totalBytes : 0) +
            ((matchingAudio != null && matchingAudio.size.totalBytes > 0)
                ? matchingAudio.size.totalBytes
                : 0);

        options.add(
          StreamOption(
            id: 'opt_${height}_${stream.container.name}',
            label: _formatResolutionLabel(height),
            container: stream.container.name,
            hasAudio: matchingAudio != null,
            fileSizeBytes: totalBytes > 0 ? totalBytes : null,
            isRecommended: false,
            isAudioOnly: false,
            streamInfo: stream,
            audioStreamInfo: matchingAudio,
          ),
        );
      }

      // Recommend 1080p if available, else 720p, else highest available
      int recIdx = options.indexWhere((o) => o.label.startsWith('1080p'));
      if (recIdx == -1) {
        recIdx = options.indexWhere((o) => o.label.startsWith('720p'));
      }
      if (recIdx == -1 && options.isNotEmpty) {
        recIdx = 0;
      }
      if (recIdx != -1) {
        final rec = options[recIdx];
        options[recIdx] = StreamOption(
          id: rec.id,
          label: rec.label,
          container: rec.container,
          hasAudio: rec.hasAudio,
          fileSizeBytes: rec.fileSizeBytes,
          isRecommended: true,
          isAudioOnly: rec.isAudioOnly,
          streamInfo: rec.streamInfo,
          audioStreamInfo: rec.audioStreamInfo,
        );
      }

      // 2. Add Best Audio-only track
      if (bestAudio != null) {
        options.add(
          StreamOption(
            id: 'opt_audio_${bestAudio.container.name}',
            label: 'Audio Only (${bestAudio.bitrate.kiloBitsPerSecond.round()} kbps)',
            container: bestAudio.container.name,
            hasAudio: true,
            fileSizeBytes: bestAudio.size.totalBytes > 0 ? bestAudio.size.totalBytes : null,
            isRecommended: options.isEmpty,
            isAudioOnly: true,
            streamInfo: bestAudio,
          ),
        );
      }

      if (options.isEmpty) {
        throw const AppException('No downloadable video streams available for this video.');
      }

      // Best thumbnail
      final thumb = video.thumbnails.highResUrl.isNotEmpty
          ? video.thumbnails.highResUrl
          : (video.thumbnails.mediumResUrl.isNotEmpty
              ? video.thumbnails.mediumResUrl
              : video.thumbnails.lowResUrl);

      return VideoInspectionResult(
        videoId: videoId,
        title: video.title,
        author: video.author,
        thumbnailUrl: thumb,
        duration: video.duration ?? Duration.zero,
        options: options,
        platform: MediaPlatform.youtube,
      );
    } on VideoUnplayableException catch (e) {
      throw VideoUnavailableException(e.message);
    } on AppException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        throw const NetworkException();
      }
      throw AppException('Failed to inspect video: ${e.toString()}');
    }
  }

  void close() {
    _yt.close();
    _instagram.close();
  }
}
