import 'package:flutter/services.dart';

class AudioMetadata {
  final String title;
  final String artist;
  final String? album;
  final String? thumbnailUrl;
  final int? trackNumber;
  final int? year;
  final int? durationSeconds;

  const AudioMetadata({
    required this.title,
    required this.artist,
    this.album,
    this.thumbnailUrl,
    this.trackNumber,
    this.year,
    this.durationSeconds,
  });

  Map<String, dynamic> toMap(String filePath) {
    return {
      'filePath': filePath,
      'title': title,
      'artist': artist,
      if (album != null && album!.isNotEmpty) 'album': album,
      if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) 'thumbnailUrl': thumbnailUrl,
      if (trackNumber != null) 'trackNumber': trackNumber,
      if (year != null) 'year': year,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
    };
  }
}

class Mp3MetadataService {
  static const MethodChannel _channel = MethodChannel('app.mediaurl.applicaiton/muxer');

  /// Writes ID3v2 tags (Title, Artist, Album, Year, Track number, Cover Art)
  /// directly into the MP3/audio file using native Kotlin byte manipulation.
  static Future<bool> writeMetadata({
    required String filePath,
    required AudioMetadata metadata,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'writeAudioMetadata',
        metadata.toMap(filePath),
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
