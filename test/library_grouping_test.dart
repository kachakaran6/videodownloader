import 'package:flutter_test/flutter_test.dart';
import 'package:media_saver/features/downloads/domain/download_item.dart';
import 'package:media_saver/features/history/domain/library_group.dart';

void main() {
  group('Library Grouping Verification', () {
    test('Single download items remain as individual single groups', () {
      final items = [
        DownloadItem(
          id: 'dl_1',
          videoId: 'yt_123',
          title: 'YouTube Video 1',
          author: 'Channel 1',
          thumbnailUrl: 'https://img.youtube.com/vi/yt_123/0.jpg',
          durationSeconds: 120,
          qualityLabel: '1080p',
          filePath: '/storage/video1.mp4',
          fileSizeBytes: 10485760, // 10MB
          status: DownloadStatus.completed,
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
          platform: 'youtube',
          groupId: 'dl_1',
        ),
        DownloadItem(
          id: 'dl_2',
          videoId: 'ig_456',
          title: 'Instagram Reel',
          author: 'Creator',
          thumbnailUrl: 'https://instagram.com/thumb.jpg',
          durationSeconds: 30,
          qualityLabel: 'Original',
          filePath: '/storage/reel.mp4',
          fileSizeBytes: 5242880, // 5MB
          status: DownloadStatus.completed,
          createdAt: DateTime.now(),
          platform: 'instagram',
          groupId: 'dl_2',
        ),
      ];

      final groups = groupDownloadItems(items);
      expect(groups.length, equals(2));
      expect(groups[0].isSingle, isTrue);
      expect(groups[1].isSingle, isTrue);
    });

    test('Multiple items with shared groupId collapse into a single collection', () {
      final now = DateTime.now();
      final tracks = List.generate(50, (index) {
        return DownloadItem(
          id: 'track_${index + 1}',
          videoId: 'spotify_track_${index + 1}',
          title: 'Track ${index + 1} - Artist',
          author: 'Artist',
          thumbnailUrl: 'https://i.scdn.co/image/pop_mix_cover.jpg',
          durationSeconds: 210,
          qualityLabel: 'Full Length Audio',
          filePath: '/storage/music/track_${index + 1}.mp3',
          fileSizeBytes: 4000000, // 4MB each
          status: DownloadStatus.completed,
          createdAt: now.add(Duration(seconds: index)),
          platform: 'spotify',
          groupId: 'album_pop_mix',
          groupTitle: 'Pop Mix (50 Songs)',
          groupThumbnailUrl: 'https://i.scdn.co/image/pop_mix_cover.jpg',
        );
      });

      final groups = groupDownloadItems(tracks);
      expect(groups.length, equals(1));
      expect(groups.first.isSingle, isFalse);
      expect(groups.first.itemCount, equals(50));
      expect(groups.first.title, equals('Pop Mix (50 Songs)'));
      expect(groups.first.totalSizeBytes, equals(50 * 4000000));
      expect(groups.first.categoryLabel, equals('Music'));
    });

    test('Fallback grouping collapses legacy downloads sharing identical thumbnail & platform', () {
      final now = DateTime.now();
      // Legacy items without groupId
      final legacyTracks = [
        DownloadItem(
          id: 'legacy_1',
          videoId: 'sp_1',
          title: 'Rockabye - Clean Bandit',
          author: 'Clean Bandit',
          thumbnailUrl: 'https://i.scdn.co/image/pop_mix.jpg',
          durationSeconds: 240,
          qualityLabel: 'Full Length Audio',
          filePath: '/storage/music/rockabye.mp3',
          fileSizeBytes: 4100000,
          status: DownloadStatus.completed,
          createdAt: now,
          platform: 'spotify',
        ),
        DownloadItem(
          id: 'legacy_2',
          videoId: 'sp_2',
          title: 'Gimme More - Britney Spears',
          author: 'Britney Spears',
          thumbnailUrl: 'https://i.scdn.co/image/pop_mix.jpg',
          durationSeconds: 250,
          qualityLabel: 'Full Length Audio',
          filePath: '/storage/music/gimme_more.mp3',
          fileSizeBytes: 4200000,
          status: DownloadStatus.completed,
          createdAt: now.add(const Duration(seconds: 1)),
          platform: 'spotify',
        ),
      ];

      final groups = groupDownloadItems(legacyTracks);
      expect(groups.length, equals(1));
      expect(groups.first.isSingle, isFalse);
      expect(groups.first.itemCount, equals(2));
      expect(groups.first.thumbnailUrl, equals('https://i.scdn.co/image/pop_mix.jpg'));
    });
  });
}
