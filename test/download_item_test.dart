import 'package:flutter_test/flutter_test.dart';
import 'package:media_saver/features/downloads/domain/download_item.dart';

void main() {
  group('DownloadItem', () {
    test('serialization and deserialization preserves properties including platform', () {
      final item = DownloadItem(
        id: 'test_123',
        videoId: 'DEvjGZhzJ5k',
        title: 'Amazing Reel',
        author: 'instagram_creator',
        thumbnailUrl: 'https://instagram.com/p/test.jpg',
        durationSeconds: 15,
        qualityLabel: '1080p HD',
        filePath: '/storage/emulated/0/Download/test.mp4',
        fileSizeBytes: 12500000,
        status: DownloadStatus.completed,
        createdAt: DateTime(2026, 9, 4, 12, 0),
        completedAt: DateTime(2026, 9, 4, 12, 1),
        platform: 'instagram',
      );

      final json = item.toJson();
      final restored = DownloadItem.fromJson(json);

      expect(restored.id, equals(item.id));
      expect(restored.videoId, equals(item.videoId));
      expect(restored.title, equals(item.title));
      expect(restored.author, equals(item.author));
      expect(restored.qualityLabel, equals(item.qualityLabel));
      expect(restored.filePath, equals(item.filePath));
      expect(restored.fileSizeBytes, equals(item.fileSizeBytes));
      expect(restored.status, equals(DownloadStatus.completed));
      expect(restored.createdAt, equals(item.createdAt));
      expect(restored.completedAt, equals(item.completedAt));
      expect(restored.platform, equals('instagram'));
      expect(restored.isInstagram, isTrue);
      expect(restored.isYouTube, isFalse);
    });

    test('defaults to youtube platform when deserializing legacy data without platform field', () {
      final legacyJson = {
        'id': 'legacy_1',
        'videoId': 'dQw4w9WgXcQ',
        'title': 'Legacy Video',
        'author': 'Legacy Author',
        'thumbnailUrl': 'https://i.ytimg.com/vi/test.jpg',
        'durationSeconds': 120,
        'qualityLabel': '720p HD',
        'filePath': '/storage/emulated/0/Download/legacy.mp4',
        'fileSizeBytes': 5000000,
        'status': 'completed',
        'createdAt': '2026-09-04T10:00:00.000',
      };

      final restored = DownloadItem.fromJson(legacyJson);
      expect(restored.platform, equals('youtube'));
      expect(restored.isYouTube, isTrue);
      expect(restored.isInstagram, isFalse);
    });
  });
}
