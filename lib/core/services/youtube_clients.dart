import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Centralized YouTube client configurations tailored for high performance,
/// unthrottled streaming, and avoiding YouTube CDN 403 range cutoffs.
class AppYoutubeClients {
  /// VisionOS client provides full, unthrottled adaptive video streams
  /// across resolutions (720p, 1080p, 4K, HDR) that do not suffer from
  /// the ~20MB (byte 21,110,000) 403 Forbidden range cutoff.
  static const visionOs = YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'VISIONOS',
        'clientVersion': '1.02',
        'deviceMake': 'Apple',
        'deviceModel': 'RealityDevice17,1',
        'userAgent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15',
        'osName': 'visionOS',
        'osVersion': '26.5.23O471',
        'hl': 'en',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
      }
    },
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

  /// Fallback clients list prioritizing VisionOS for unrestricted streaming,
  /// followed by Android Sdkless for maximum compatibility across all video types.
  static final List<YoutubeApiClient> defaultClients = [
    visionOs,
    YoutubeApiClient.androidSdkless,
  ];
}
