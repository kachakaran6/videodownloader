import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide VideoUnavailableException;
import '../../../core/errors/app_exceptions.dart';
import '../../../core/services/youtube_clients.dart';
import '../../../core/services/instagram_inspector.dart';
import '../../../core/services/spotify_inspector.dart';
import '../../../core/services/facebook_inspector.dart';
import '../../../core/utils/url_validator.dart';
import '../../../core/compliance/compliance_policy_engine.dart';

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
  final List<SpotifyTrackMetadata>? spotifyTracks;
  final List<VideoInspectionResult>? playlistVideos;

  const VideoInspectionResult({
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.duration,
    required this.options,
    this.platform = MediaPlatform.youtube,
    this.spotifyTracks,
    this.playlistVideos,
  });

  bool get isInstagram =>
      platform == MediaPlatform.instagramReel ||
      platform == MediaPlatform.instagramPost ||
      platform == MediaPlatform.instagramStory;

  bool get isYouTube =>
      platform == MediaPlatform.youtube ||
      platform == MediaPlatform.youtubePlaylist;
  bool get isSpotify =>
      platform == MediaPlatform.spotifyTrack ||
      platform == MediaPlatform.spotifyAlbum ||
      platform == MediaPlatform.spotifyPlaylist;
  bool get isFacebook => platform == MediaPlatform.facebookVideo;
  bool get isAlbum =>
      platform == MediaPlatform.spotifyAlbum ||
      platform == MediaPlatform.spotifyPlaylist ||
      platform == MediaPlatform.youtubePlaylist ||
      (spotifyTracks != null && spotifyTracks!.isNotEmpty);
  bool get isPlaylist =>
      platform == MediaPlatform.youtubePlaylist ||
      (playlistVideos != null && playlistVideos!.isNotEmpty);

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
      case MediaPlatform.youtubePlaylist:
        return 'YouTube Playlist';
      case MediaPlatform.spotifyTrack:
        return 'Spotify Track';
      case MediaPlatform.spotifyPlaylist:
        return 'Spotify Playlist';
      case MediaPlatform.spotifyAlbum:
        return 'Spotify Album';
      case MediaPlatform.facebookVideo:
        return 'Facebook Video';
      case MediaPlatform.unsupported:
        return 'Video';
    }
  }
}

class VideoInspector {
  final YoutubeExplode _yt;
  final InstagramInspector _instagram;
  final SpotifyInspector _spotify;
  final FacebookInspector _facebook;
  final CompliancePolicyEngine _compliance;

  VideoInspector({
    YoutubeExplode? yt,
    InstagramInspector? instagram,
    SpotifyInspector? spotify,
    FacebookInspector? facebook,
    CompliancePolicyEngine? compliance,
  })  : _yt = yt ?? YoutubeExplode(),
        _instagram = instagram ?? InstagramInspector(),
        _spotify = spotify ?? SpotifyInspector(yt: yt),
        _facebook = facebook ?? FacebookInspector(),
        _compliance = compliance ?? const CompliancePolicyEngine();

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

    // Enforce source-specific compliance and Google Play restrictions
    _compliance.verifyInspectionPermission(platform, rawUrl);

    switch (platform) {
      case MediaPlatform.youtube:
        return await _inspectYouTube(rawUrl);
      case MediaPlatform.youtubePlaylist:
        return await _inspectYouTubePlaylist(rawUrl);
      case MediaPlatform.instagramReel:
      case MediaPlatform.instagramPost:
      case MediaPlatform.instagramStory:
        return await _inspectInstagram(rawUrl, platform);
      case MediaPlatform.spotifyTrack:
        return await _spotify.inspect(rawUrl);
      case MediaPlatform.spotifyPlaylist:
      case MediaPlatform.spotifyAlbum:
        return await _spotify.inspectAlbum(rawUrl);
      case MediaPlatform.facebookVideo:
        return await _inspectFacebook(rawUrl);
      case MediaPlatform.unsupported:
        throw const InvalidUrlException();
    }
  }

  Future<VideoInspectionResult> _inspectFacebook(String rawUrl) async {
    final fbRes = await _facebook.inspect(rawUrl);

    final options = <StreamOption>[];
    for (int i = 0; i < fbRes.videoVersions.length; i++) {
      final v = fbRes.videoVersions[i];
      options.add(
        StreamOption(
          id: 'fb_${fbRes.videoId}_$i',
          label: v.label,
          container: 'mp4',
          hasAudio: fbRes.hasAudio,
          fileSizeBytes: v.fileSizeBytes,
          isRecommended: i == 0,
          isAudioOnly: false,
          directUrl: v.url,
        ),
      );
    }

    // Add Audio-only extraction option if streams exist
    if (fbRes.videoVersions.isNotEmpty && fbRes.hasAudio) {
      final bestStream = fbRes.videoVersions.first;
      options.add(
        StreamOption(
          id: 'fb_${fbRes.videoId}_audio',
          label: 'Audio Only (M4A)',
          container: 'm4a',
          hasAudio: true,
          fileSizeBytes: bestStream.fileSizeBytes != null ? (bestStream.fileSizeBytes! ~/ 4) : null,
          isRecommended: false,
          isAudioOnly: true,
          directUrl: bestStream.url,
        ),
      );
    }

    if (options.isEmpty) {
      throw const AppException('No downloadable media stream available for this Facebook post.');
    }

    return VideoInspectionResult(
      videoId: fbRes.videoId,
      title: fbRes.title,
      author: fbRes.author,
      thumbnailUrl: fbRes.thumbnailUrl,
      duration: fbRes.duration,
      options: options,
      platform: MediaPlatform.facebookVideo,
    );
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

    for (int i = 0; i < igRes.imageVersions.length; i++) {
      final img = igRes.imageVersions[i];
      options.add(
        StreamOption(
          id: 'ig_${igRes.shortcode}_img_$i',
          label: igRes.imageVersions.length > 1
              ? 'Photo ${i + 1} (${img.width != null ? "${img.width}x${img.height}" : "JPG"})'
              : img.label,
          container: 'jpg',
          hasAudio: false,
          fileSizeBytes: img.fileSizeBytes,
          isRecommended: options.isEmpty && i == 0,
          isAudioOnly: false,
          directUrl: img.url,
        ),
      );
    }

    if (options.isEmpty) {
      throw const AppException('No downloadable media stream or photo available for this Instagram post.');
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

      // 2. Add Best Audio-only track (prioritize MP4/M4A AAC for native music player compatibility)
      final chosenAudio = bestMp4Audio ?? bestAudio;
      if (chosenAudio != null) {
        final isAac = chosenAudio.container.name.toLowerCase() == 'mp4' ||
            chosenAudio.container.name.toLowerCase() == 'm4a';
        final formatLabel = isAac ? 'M4A' : chosenAudio.container.name.toUpperCase();
        options.add(
          StreamOption(
            id: 'opt_audio_${chosenAudio.container.name}',
            label: 'Audio Only (${chosenAudio.bitrate.kiloBitsPerSecond.round()} kbps $formatLabel)',
            container: isAac ? 'm4a' : chosenAudio.container.name,
            hasAudio: true,
            fileSizeBytes: chosenAudio.size.totalBytes > 0 ? chosenAudio.size.totalBytes : null,
            isRecommended: options.isEmpty,
            isAudioOnly: true,
            streamInfo: chosenAudio,
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

  Future<VideoInspectionResult> _inspectYouTubePlaylist(String rawUrl) async {
    final playlistId = UrlValidator.extractPlaylistId(rawUrl);
    if (playlistId == null) {
      throw const InvalidUrlException();
    }

    try {
      final playlist = await _yt.playlists.get(playlistId);
      final videoStream = _yt.playlists.getVideos(playlistId);
      final videos = await videoStream.take(150).toList();

      if (videos.isEmpty) {
        throw const AppException('No videos found in this YouTube playlist.');
      }

      int totalDurationMs = 0;
      final tracks = <SpotifyTrackMetadata>[];
      final playlistVideos = <VideoInspectionResult>[];

      for (int i = 0; i < videos.length; i++) {
        final v = videos[i];
        final dur = v.duration ?? Duration.zero;
        totalDurationMs += dur.inMilliseconds;
        final thumb = v.thumbnails.highResUrl.isNotEmpty
            ? v.thumbnails.highResUrl
            : 'https://i.ytimg.com/vi/${v.id.value}/hqdefault.jpg';

        tracks.add(
          SpotifyTrackMetadata(
            trackId: v.id.value,
            title: v.title,
            artist: v.author,
            album: playlist.title,
            thumbnailUrl: thumb,
            duration: dur,
          ),
        );

        playlistVideos.add(
          VideoInspectionResult(
            videoId: v.id.value,
            title: v.title,
            author: v.author,
            thumbnailUrl: thumb,
            duration: dur,
            options: const [],
            platform: MediaPlatform.youtube,
          ),
        );
      }

      final thumb = playlist.thumbnails.highResUrl.isNotEmpty
          ? playlist.thumbnails.highResUrl
          : (tracks.isNotEmpty ? tracks.first.thumbnailUrl : '');

      final options = <StreamOption>[
        const StreamOption(
          id: 'yt_playlist_audio',
          label: 'Full Length Audio (Original MP3)',
          container: 'mp3',
          hasAudio: true,
          fileSizeBytes: null,
          isRecommended: true,
          isAudioOnly: true,
        ),
      ];

      return VideoInspectionResult(
        videoId: playlist.id.value,
        title: playlist.title,
        author: playlist.author.isNotEmpty ? playlist.author : 'YouTube Playlist',
        thumbnailUrl: thumb,
        duration: Duration(milliseconds: totalDurationMs),
        options: options,
        platform: MediaPlatform.youtubePlaylist,
        spotifyTracks: tracks,
        playlistVideos: playlistVideos,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        throw const NetworkException();
      }
      throw AppException('Failed to inspect YouTube playlist: ${e.toString()}');
    }
  }

  void close() {
    _yt.close();
    _instagram.close();
  }
}
