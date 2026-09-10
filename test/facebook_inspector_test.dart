import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:media_saver/core/errors/app_exceptions.dart';
import 'package:media_saver/core/services/facebook_inspector.dart';
import 'package:media_saver/features/inspect/data/video_inspector.dart';

void main() {
  group('FacebookInspector', () {
    test('extracts HD and SD stream options from direct HTML payload', () async {
      const mockHtml = '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta property="og:title" content="744K views &#xb7; 2.3K shares | Amazing Space Discoveries | NASA" />
          <meta property="og:image" content="https://scontent.xx.fbcdn.net/v/thumb.jpg?_nc_cat=105&amp;ccb=1-7" />
        </head>
        <body>
          <script>
            var data = {
              "browser_native_hd_url": "https:\\/\\/video.xx.fbcdn.net\\/v\\/hd_stream.mp4?_nc_cat=101\\u0026oe=123",
              "browser_native_sd_url": "https:\\/\\/video.xx.fbcdn.net\\/v\\/sd_stream.mp4?_nc_cat=102\\u0026oe=456"
            };
          </script>
        </body>
        </html>
      ''';

      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') {
          if (request.url.toString().contains('hd_stream.mp4')) {
            return http.Response('', 200, headers: {'content-length': '15728640'}); // 15 MB
          }
          return http.Response('', 200, headers: {'content-length': '5242880'}); // 5 MB
        }
        return http.Response(mockHtml, 200);
      });

      final inspector = FacebookInspector(mockClient);
      final result = await inspector.inspect('https://www.facebook.com/watch/?v=10155529876156509');

      expect(result.videoId, equals('10155529876156509'));
      expect(result.title, equals('Amazing Space Discoveries'));
      expect(result.author, equals('NASA'));
      expect(result.thumbnailUrl, contains('https://scontent.xx.fbcdn.net/v/thumb.jpg'));
      expect(result.videoVersions.length, equals(2));

      final hd = result.videoVersions.firstWhere((v) => v.quality == 'hd');
      expect(hd.url, equals('https://video.xx.fbcdn.net/v/hd_stream.mp4?_nc_cat=101&oe=123'));
      expect(hd.fileSizeBytes, equals(15728640));

      final sd = result.videoVersions.firstWhere((v) => v.quality == 'sd');
      expect(sd.url, equals('https://video.xx.fbcdn.net/v/sd_stream.mp4?_nc_cat=102&oe=456'));
      expect(sd.fileSizeBytes, equals(5242880));
    });

    test('extracts from OpenGraph video tags as fallback', () async {
      const mockOgHtml = '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta property="og:title" content="Nature Documentary Highlights | BBC Earth" />
          <meta property="og:video" content="https://video.xx.fbcdn.net/v/nature_doc.mp4?tag=1&amp;token=abc" />
          <meta property="og:image" content="https://scontent.xx.fbcdn.net/v/nature_thumb.jpg" />
        </head>
        <body>
        </body>
        </html>
      ''';

      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') {
          return http.Response('', 200, headers: {'content-length': '8388608'});
        }
        return http.Response(mockOgHtml, 200);
      });

      final inspector = FacebookInspector(mockClient);
      final result = await inspector.inspect('https://www.facebook.com/bbc/videos/1234567890/');

      expect(result.title, equals('Nature Documentary Highlights'));
      expect(result.author, equals('BBC Earth'));
      expect(result.videoVersions.length, equals(1));
      expect(result.videoVersions.first.url, equals('https://video.xx.fbcdn.net/v/nature_doc.mp4?tag=1&token=abc'));
    });

    test('falls back to embed endpoint when direct web has no streams', () async {
      const loginHtml = '<html><head><title>Log in to Facebook</title></head><body>Login required</body></html>';
      const embedHtml = '''
        <html>
        <body>
          <script>
            var data = {
              "playable_url_quality_hd": "https:\\/\\/video.xx.fbcdn.net\\/v\\/embed_hd.mp4",
              "playable_url": "https:\\/\\/video.xx.fbcdn.net\\/v\\/embed_sd.mp4"
            };
          </script>
          <meta property="og:title" content="Reel Creator on Reels | Facebook" />
        </body>
        </html>
      ''';

      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('plugins/video.php')) {
          return http.Response(embedHtml, 200);
        }
        if (request.method == 'HEAD') {
          return http.Response('', 200, headers: {'content-length': '10485760'});
        }
        return http.Response(loginHtml, 200);
      });

      final inspector = FacebookInspector(mockClient);
      final result = await inspector.inspect('https://www.facebook.com/reel/987654321');

      expect(result.videoId, equals('987654321'));
      expect(result.isReel, isTrue);
      expect(result.videoVersions.length, equals(2));
      expect(result.videoVersions[0].url, equals('https://video.xx.fbcdn.net/v/embed_hd.mp4'));
    });

    test('throws InvalidUrlException on invalid or non-Facebook URL', () async {
      final inspector = FacebookInspector();
      expect(
        () => inspector.inspect('https://google.com'),
        throwsA(isA<InvalidUrlException>()),
      );
    });

    test('integrates with VideoInspector to produce HD, SD and Audio options', () async {
      const mockHtml = '''
        <html>
        <head>
          <meta property="og:title" content="Live Performance | Music Band" />
          <meta property="og:image" content="https://scontent.xx.fbcdn.net/v/band.jpg" />
        </head>
        <body>
          <script>
            var x = {
              "browser_native_hd_url": "https:\\/\\/video.xx.fbcdn.net\\/hd.mp4",
              "browser_native_sd_url": "https:\\/\\/video.xx.fbcdn.net\\/sd.mp4"
            };
          </script>
        </body>
        </html>
      ''';

      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') {
          return http.Response('', 200, headers: {'content-length': '20971520'});
        }
        return http.Response(mockHtml, 200);
      });

      final fbInspector = FacebookInspector(mockClient);
      final videoInspector = VideoInspector(facebook: fbInspector);

      final inspected = await videoInspector.inspect('https://www.facebook.com/watch/?v=999888777');

      expect(inspected.isFacebook, isTrue);
      expect(inspected.platformBadgeText, equals('Facebook Video'));
      expect(inspected.options.length, equals(3)); // HD, SD, Audio

      final hdOpt = inspected.options[0];
      expect(hdOpt.label, contains('HD'));
      expect(hdOpt.isRecommended, isTrue);
      expect(hdOpt.container, equals('mp4'));

      final sdOpt = inspected.options[1];
      expect(sdOpt.label, contains('SD'));
      expect(sdOpt.container, equals('mp4'));

      final audioOpt = inspected.options[2];
      expect(audioOpt.isAudioOnly, isTrue);
      expect(audioOpt.container, equals('m4a'));
    });
  });
}
