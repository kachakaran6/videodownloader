import 'dart:io';
import 'package:flutter/services.dart';

class MediaMuxerService {
  static const _channel = MethodChannel('app.mediaurl.applicaiton/muxer');

  /// Combines separate video and audio files into a single playable media file.
  /// Returns the merged [File] if successful, or null if muxing was not supported or failed.
  static Future<File?> muxMedia({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMethod<String>('muxMedia', {
        'videoPath': videoPath,
        'audioPath': audioPath,
        'outputPath': outputPath,
      });
      if (res != null) {
        final f = File(res);
        if (f.existsSync() && f.lengthSync() > 0) {
          return f;
        }
      }
    } catch (_) {
      // Silently fall back to video-only file if muxing fails
    }
    return null;
  }
}
