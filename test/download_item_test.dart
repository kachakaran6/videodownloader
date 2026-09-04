import 'package:flutter_test/flutter_test.dart';
import 'package:media_saver/features/downloads/domain/download_item.dart';

void main() {
  group('DownloadItem', () {
    test('serialization and deserialization preserves properties', () {
      final item = DownloadItem(
        id: 'test_123',
        videoId: 'dQw4w9WgXcQ',
        title: 'Rick Astley - Never Gonna Give You Up',
        author: 'Rick Astley',
        thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        durationSeconds: 212,
        qualityLabel: '720p HD',
        filePath: '/storage/emulated/0/Download/test.mp4',
        fileSizeBytes: 24500000,
        status: DownloadStatus.completed,
        createdAt: DateTime(2026, 9, 4, 12, 0),
        completedAt: DateTime(2026, 9, 4, 12, 1),
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
    });
  });
}
