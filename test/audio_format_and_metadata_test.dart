import 'package:flutter_test/flutter_test.dart';
import 'package:media_saver/core/services/mp3_metadata_service.dart';
import 'package:media_saver/core/utils/media_launcher.dart';
import 'package:media_saver/features/downloads/data/stream_downloader.dart';

void main() {
  group('Audio Format & Metadata Verification', () {
    test('MediaLauncher maps m4a to audio/mp4 and mp3 to audio/mpeg', () {
      expect(MediaLauncher.getMimeType('song.m4a'), 'audio/mp4');
      expect(MediaLauncher.getMimeType('song.mp3'), 'audio/mpeg');
      expect(MediaLauncher.getMimeType('song.webm'), 'video/webm');
    });

    test('StreamDownloader sanitizes audio filenames properly with clean extensions', () {
      final nameM4a = StreamDownloader.sanitizeFileName('Blinding Lights (Official Audio) 🔥', 'm4a');
      expect(nameM4a, 'Blinding Lights (Official Audio).m4a');

      final nameMp3 = StreamDownloader.sanitizeFileName('Shape of You [Audio]', 'mp3');
      expect(nameMp3, 'Shape of You [Audio].mp3');
    });

    test('AudioMetadata properly serializes metadata with thumbnail for tagging', () {
      const meta = AudioMetadata(
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        thumbnailUrl: 'https://i.scdn.co/image/ab67616d0000b273',
        trackNumber: 1,
        year: 2020,
        durationSeconds: 200,
      );

      final map = meta.toMap('/storage/emulated/0/Download/song.mp3');
      expect(map['filePath'], '/storage/emulated/0/Download/song.mp3');
      expect(map['title'], 'Blinding Lights');
      expect(map['artist'], 'The Weeknd');
      expect(map['album'], 'After Hours');
      expect(map['thumbnailUrl'], 'https://i.scdn.co/image/ab67616d0000b273');
      expect(map['trackNumber'], 1);
      expect(map['year'], 2020);
      expect(map['durationSeconds'], 200);
    });

    test('Spotify downloads always sanitize to .mp3 extension', () {
      final fileName = StreamDownloader.sanitizeFileName('The Weeknd - Blinding Lights', 'mp3');
      expect(fileName, 'The Weeknd - Blinding Lights.mp3');
      expect(fileName.endsWith('.mp3'), isTrue);
      expect(fileName.endsWith('.m4a'), isFalse);
      expect(fileName.endsWith('.webm'), isFalse);
    });
  });
}
