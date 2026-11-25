import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:media_saver/core/errors/app_exceptions.dart';
import 'package:media_saver/core/services/twitter_inspector.dart';
import 'package:media_saver/core/utils/url_validator.dart';
import 'package:media_saver/features/inspect/data/video_inspector.dart';

void main() {
  group('TwitterInspector URL & Model Tests', () {
    test('extracts Twitter and X media info accurately', () {
      final info = UrlValidator.extractTwitterInfo('https://x.com/elonmusk/status/1785501867891241108?t=abc');
      expect(info, isNotNull);
      expect(info!.tweetId, equals('1785501867891241108'));
      expect(info.username, equals('elonmusk'));
      expect(info.platform, equals(MediaPlatform.twitterVideo));
    });

    test('TwitterVideoVersion calculates quality labels properly', () {
      const v1080 = TwitterVideoVersion(url: 'https://video.twimg.com/1080.mp4', height: 1080, width: 1920);
      expect(v1080.label, equals('1080p Full HD'));

      const v720 = TwitterVideoVersion(url: 'https://video.twimg.com/720.mp4', height: 720, width: 1280);
      expect(v720.label, equals('720p HD'));

      const v480 = TwitterVideoVersion(url: 'https://video.twimg.com/480.mp4', height: 480, width: 854);
      expect(v480.label, equals('480p SD'));

      const v360 = TwitterVideoVersion(url: 'https://video.twimg.com/360.mp4', height: 360, width: 640);
      expect(v360.label, equals('360p (Data Saver)'));
    });
  });

  group('TwitterInspector Tier 1 & 2 (FxTwitter API) Tests', () {
    test('successfully parses tweet with multiple video resolutions', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'api.fxtwitter.com') {
          final payload = {
            'code': 200,
            'message': 'OK',
            'tweet': {
              'url': 'https://x.com/testuser/status/123456789',
              'id': '123456789',
              'text': 'Exciting new product launch video! Check it out.',
              'author': {
                'name': 'Test Creator',
                'screen_name': 'testuser',
                'avatar_url': 'https://pbs.twimg.com/avatar.jpg',
              },
              'media': {
                'videos': [
                  {
                    'url': 'https://video.twimg.com/vid_720.mp4',
                    'width': 1280,
                    'height': 720,
                    'duration': 45.2,
                    'thumbnail_url': 'https://pbs.twimg.com/thumb_720.jpg',
                  },
                  {
                    'url': 'https://video.twimg.com/vid_1080.mp4',
                    'width': 1920,
                    'height': 1080,
                    'duration': 45.2,
                    'thumbnail_url': 'https://pbs.twimg.com/thumb_1080.jpg',
                  },
                  {
                    'url': 'https://video.twimg.com/vid_480.mp4',
                    'width': 854,
                    'height': 480,
                    'duration': 45.2,
                    'thumbnail_url': 'https://pbs.twimg.com/thumb_480.jpg',
                  },
                ],
                'photos': [],
              },
            },
          };
          return http.Response(jsonEncode(payload), 200, headers: {'content-type': 'application/json'});
        }

        // Mock probe content length HEAD / GET requests
        if (request.url.host == 'video.twimg.com') {
          return http.Response('', 200, headers: {'content-length': '15728640'}); // 15 MB
        }

        return http.Response('Not found', 404);
      });

      final inspector = TwitterInspector(mockClient);
      final result = await inspector.inspect('https://x.com/testuser/status/123456789');

      expect(result.tweetId, equals('123456789'));
      expect(result.author, equals('Test Creator'));
      expect(result.authorUsername, equals('testuser'));
      expect(result.duration.inSeconds, equals(45));
      expect(result.videoVersions.length, equals(3));

      // Sorted descending: 1080p, 720p, 480p
      expect(result.videoVersions[0].height, equals(1080));
      expect(result.videoVersions[0].label, equals('1080p Full HD'));
      expect(result.videoVersions[0].fileSizeBytes, equals(15728640));

      expect(result.videoVersions[1].height, equals(720));
      expect(result.videoVersions[1].label, equals('720p HD'));

      expect(result.videoVersions[2].height, equals(480));
      expect(result.videoVersions[2].label, equals('480p SD'));
    });

    test('falls back to Tier 2 (FixupX) when Tier 1 fails', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'api.fxtwitter.com') {
          return http.Response('Rate limited', 429);
        }
        if (request.url.host == 'api.fixupx.com') {
          final payload = {
            'code': 200,
            'message': 'OK',
            'tweet': {
              'url': 'https://x.com/mirror/status/987654',
              'id': '987654',
              'text': 'FixupX mirror working!',
              'author': {'name': 'Mirror User', 'screen_name': 'mirror'},
              'media': {
                'videos': [
                  {
                    'url': 'https://video.twimg.com/mirror_720.mp4',
                    'width': 1280,
                    'height': 720,
                  }
                ]
              }
            }
          };
          return http.Response(jsonEncode(payload), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('', 200, headers: {'content-length': '8388608'});
      });

      final inspector = TwitterInspector(mockClient);
      final result = await inspector.inspect('https://twitter.com/mirror/status/987654');

      expect(result.tweetId, equals('987654'));
      expect(result.author, equals('Mirror User'));
      expect(result.videoVersions.length, equals(1));
      expect(result.videoVersions.first.url, equals('https://video.twimg.com/mirror_720.mp4'));
    });
  });

  group('VideoInspector Twitter Integration Tests', () {
    test('inspects Twitter URL and maps options into StreamOptions with audio extraction', () async {
      final mockClient = MockClient((request) async {
        final payload = {
          'code': 200,
          'message': 'OK',
          'tweet': {
            'url': 'https://x.com/artist/status/55555',
            'id': '55555',
            'text': 'Check out my animation clip with music sound',
            'author': {'name': 'Artist', 'screen_name': 'artist'},
            'media': {
              'videos': [
                {
                  'url': 'https://video.twimg.com/anim_1080.mp4',
                  'width': 1920,
                  'height': 1080,
                }
              ]
            }
          }
        };
        return http.Response(jsonEncode(payload), 200, headers: {'content-type': 'application/json'});
      });

      final twitterInspector = TwitterInspector(mockClient);
      final videoInspector = VideoInspector(twitter: twitterInspector);

      final result = await videoInspector.inspect('https://x.com/artist/status/55555');

      expect(result.isTwitter, isTrue);
      expect(result.platform, equals(MediaPlatform.twitterVideo));
      expect(result.platformBadgeText, equals('X Video'));
      expect(result.videoId, equals('55555'));

      // Should have 1 video option and 1 Audio-Only option
      expect(result.options.length, equals(2));

      final videoOpt = result.options.firstWhere((o) => !o.isAudioOnly);
      expect(videoOpt.container, equals('mp4'));
      expect(videoOpt.label, equals('1080p Full HD'));
      expect(videoOpt.directUrl, equals('https://video.twimg.com/anim_1080.mp4'));

      final audioOpt = result.options.firstWhere((o) => o.isAudioOnly);
      expect(audioOpt.container, equals('m4a'));
      expect(audioOpt.label, equals('Audio Only (M4A)'));
      expect(audioOpt.directUrl, equals('https://video.twimg.com/anim_1080.mp4'));
    });

    test('throws VideoUnavailableException when no media exists in tweet', () async {
      final mockClient = MockClient((request) async {
        final payload = {
          'code': 200,
          'message': 'OK',
          'tweet': {
            'url': 'https://x.com/textonly/status/11111',
            'id': '11111',
            'text': 'Just a plain text tweet without any attachments.',
            'author': {'name': 'Text', 'screen_name': 'textonly'},
            'media': {'videos': [], 'photos': []}
          }
        };
        return http.Response(jsonEncode(payload), 200, headers: {'content-type': 'application/json'});
      });

      final twitterInspector = TwitterInspector(mockClient);
      final videoInspector = VideoInspector(twitter: twitterInspector);

      expect(
        () async => await videoInspector.inspect('https://x.com/textonly/status/11111'),
        throwsA(isA<VideoUnavailableException>()),
      );
    });
  });
}
