import 'package:flutter_test/flutter_test.dart';
import 'package:media_saver/core/utils/url_validator.dart';

void main() {
  group('UrlValidator', () {
    test('validates standard watch URLs', () {
      expect(
        UrlValidator.isValidYouTubeUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        isTrue,
      );
      expect(
        UrlValidator.extractVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
    });

    test('validates youtu.be short URLs', () {
      expect(
        UrlValidator.isValidYouTubeUrl('https://youtu.be/dQw4w9WgXcQ'),
        isTrue,
      );
      expect(
        UrlValidator.extractVideoId('https://youtu.be/dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
    });

    test('validates YouTube Shorts URLs', () {
      expect(
        UrlValidator.isValidYouTubeUrl('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        isTrue,
      );
      expect(
        UrlValidator.extractVideoId('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
    });

    test('rejects playlist URLs in MVP', () {
      expect(
        UrlValidator.isValidYouTubeUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PL123456789'),
        isFalse,
      );
    });

    test('rejects non-YouTube domains and garbage', () {
      expect(UrlValidator.isValidYouTubeUrl('https://vimeo.com/123456'), isFalse);
      expect(UrlValidator.isValidYouTubeUrl('https://google.com'), isFalse);
      expect(UrlValidator.isValidYouTubeUrl(''), isFalse);
      expect(UrlValidator.isValidYouTubeUrl('not a url'), isFalse);
    });
  });
}
