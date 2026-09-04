import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide VideoUnavailableException;
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/url_validator.dart';

class StreamOption {
  final String id;
  final String label;
  final String container;
  final bool hasAudio;
  final int? fileSizeBytes;
  final bool isRecommended;
  final bool isAudioOnly;
  final StreamInfo streamInfo;

  const StreamOption({
    required this.id,
    required this.label,
    required this.container,
    required this.hasAudio,
    required this.fileSizeBytes,
    required this.isRecommended,
    required this.isAudioOnly,
    required this.streamInfo,
  });

  String get summaryText {
    final sizeStr = fileSizeBytes != null
        ? '~${(fileSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB'
        : 'Size unavailable';
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

  const VideoInspectionResult({
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.duration,
    required this.options,
  });
}

class VideoInspector {
  final YoutubeExplode _yt;

  VideoInspector([YoutubeExplode? yt]) : _yt = yt ?? YoutubeExplode();

  Future<VideoInspectionResult> inspect(String rawUrl) async {
    final videoId = UrlValidator.extractVideoId(rawUrl);
    if (videoId == null) {
      throw const InvalidUrlException();
    }

    try {
      final video = await _yt.videos.get(videoId);
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      final options = <StreamOption>[];

      // 1. Process Muxed streams (Video + Audio in one stream)
      final muxedStreams = manifest.muxed.sortByVideoQuality();
      final seenHeights = <int>{};

      for (final stream in muxedStreams) {
        final height = stream.videoResolution.height;
        if (seenHeights.contains(height)) continue;
        seenHeights.add(height);

        final is720 = height == 720;
        final is360 = height == 360;

        String label = '${height}p';
        if (is720) {
          label = '720p HD';
        } else if (is360) {
          label = '360p (Data Saver)';
        }

        options.add(
          StreamOption(
            id: 'opt_${height}_${stream.container.name}',
            label: label,
            container: stream.container.name,
            hasAudio: true,
            fileSizeBytes: stream.size.totalBytes > 0 ? stream.size.totalBytes : null,
            isRecommended: is720 || (options.isEmpty && height >= 480),
            isAudioOnly: false,
            streamInfo: stream,
          ),
        );
      }

      // If no 720p was marked recommended, mark the highest available
      if (options.isNotEmpty && !options.any((o) => o.isRecommended)) {
        options.first = StreamOption(
          id: options.first.id,
          label: options.first.label,
          container: options.first.container,
          hasAudio: options.first.hasAudio,
          fileSizeBytes: options.first.fileSizeBytes,
          isRecommended: true,
          isAudioOnly: options.first.isAudioOnly,
          streamInfo: options.first.streamInfo,
        );
      }

      // 2. Add Best Audio-only track
      if (manifest.audioOnly.isNotEmpty) {
        final bestAudio = manifest.audioOnly.withHighestBitrate();
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
  }
}
