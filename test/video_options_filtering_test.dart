import 'package:flutter_test/flutter_test.dart';
import 'package:media_saver/core/utils/url_validator.dart';
import 'package:media_saver/features/inspect/data/video_inspector.dart';

void main() {
  group('StreamOption and Video vs Audio filtering', () {
    test('Video with audio has distinct video and audio options', () {
      final options = [
        const StreamOption(
          id: 'v_1080',
          label: '1080p (MP4)',
          container: 'mp4',
          hasAudio: true,
          fileSizeBytes: 10485760,
          isRecommended: true,
          isAudioOnly: false,
        ),
        const StreamOption(
          id: 'v_720',
          label: '720p (MP4)',
          container: 'mp4',
          hasAudio: true,
          fileSizeBytes: 5242880,
          isRecommended: false,
          isAudioOnly: false,
        ),
        const StreamOption(
          id: 'a_m4a',
          label: 'Audio (M4A)',
          container: 'm4a',
          hasAudio: true,
          fileSizeBytes: 1048576,
          isRecommended: false,
          isAudioOnly: true,
        ),
        const StreamOption(
          id: 'a_mp3',
          label: 'Audio (MP3 320 kbps)',
          container: 'mp3',
          hasAudio: true,
          fileSizeBytes: 1048576,
          isRecommended: false,
          isAudioOnly: true,
        ),
      ];

      final videoOnly = options.where((o) => !o.isAudioOnly).toList();
      final audioOnly = options.where((o) => o.isAudioOnly).toList();

      expect(videoOnly.length, 2);
      expect(videoOnly.every((o) => !o.isAudioOnly), isTrue);
      expect(videoOnly.map((o) => o.label), containsAll(['1080p (MP4)', '720p (MP4)']));

      expect(audioOnly.length, 2);
      expect(audioOnly.every((o) => o.isAudioOnly), isTrue);
      expect(audioOnly.map((o) => o.label), containsAll(['Audio (M4A)', 'Audio (MP3 320 kbps)']));
    });

    test('UrlValidator correctly extracts clean video link from shared string with message', () {
      const sharedMessage = 'Hey check this out: https://www.instagram.com/reel/C8xyz123/?igsh=abc== it is amazing!';
      final extracted = UrlValidator.extractFirstSupportedUrl(sharedMessage);
      expect(extracted, isNotNull);
      expect(extracted, contains('instagram.com/reel/C8xyz123'));
    });

    test('UrlValidator correctly extracts YouTube Shorts and watch links from shared text', () {
      const ytShared = 'Watch this short: https://youtube.com/shorts/dQw4w9WgXcQ?si=test';
      final extracted = UrlValidator.extractFirstSupportedUrl(ytShared);
      expect(extracted, isNotNull);
      expect(extracted, contains('youtube.com/shorts/dQw4w9WgXcQ'));
    });
  });
}
