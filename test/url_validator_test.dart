import 'package:flutter_test/flutter_test.dart';
import 'package:media_saver/core/utils/url_validator.dart';

void main() {
  group('UrlValidator - YouTube', () {
    test('validates standard watch URLs', () {
      expect(
        UrlValidator.isValidYouTubeUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        isTrue,
      );
      expect(
        UrlValidator.extractVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        UrlValidator.detectPlatform('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        equals(MediaPlatform.youtube),
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
      expect(
        UrlValidator.detectPlatform('https://youtu.be/dQw4w9WgXcQ'),
        equals(MediaPlatform.youtube),
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
      expect(
        UrlValidator.detectPlatform('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        equals(MediaPlatform.youtube),
      );
    });

    test('rejects playlist URLs in MVP', () {
      expect(
        UrlValidator.isValidYouTubeUrl(
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PL123456789'),
        isFalse,
      );
    });
  });

  group('UrlValidator - Instagram', () {
    test('validates and detects Instagram Reel URLs', () {
      const url = 'https://www.instagram.com/reel/DEvjGZhzJ5k/?igsh=abc123';
      expect(UrlValidator.isValidInstagramUrl(url), isTrue);
      expect(UrlValidator.detectPlatform(url), equals(MediaPlatform.instagramReel));
      expect(UrlValidator.extractInstagramShortcode(url), equals('DEvjGZhzJ5k'));
    });

    test('validates and detects Instagram Post / Video URLs', () {
      const url = 'https://instagram.com/p/C-xyz789_12/?utm_source=ig_web';
      expect(UrlValidator.isValidInstagramUrl(url), isTrue);
      expect(UrlValidator.detectPlatform(url), equals(MediaPlatform.instagramPost));
      expect(UrlValidator.extractInstagramShortcode(url), equals('C-xyz789_12'));
    });

    test('validates and detects Instagram Story URLs', () {
      const url = 'https://www.instagram.com/stories/natgeo/3123456789012345678/';
      expect(UrlValidator.isValidInstagramUrl(url), isTrue);
      expect(UrlValidator.detectPlatform(url), equals(MediaPlatform.instagramStory));
      expect(UrlValidator.extractInstagramShortcode(url), equals('3123456789012345678'));
    });

    test('validates Instagram Share URLs', () {
      const url = 'https://www.instagram.com/share/reel/DEvjGZhzJ5k';
      expect(UrlValidator.isValidInstagramUrl(url), isTrue);
      expect(UrlValidator.detectPlatform(url), equals(MediaPlatform.instagramReel));
      expect(UrlValidator.extractInstagramShortcode(url), equals('DEvjGZhzJ5k'));
    });

    test('rejects non-Instagram domains and garbage', () {
      expect(UrlValidator.isValidInstagramUrl('https://vimeo.com/123456'), isFalse);
      expect(UrlValidator.isValidInstagramUrl('https://google.com'), isFalse);
      expect(UrlValidator.isValidInstagramUrl(''), isFalse);
      expect(UrlValidator.isValidInstagramUrl('not a url'), isFalse);
      expect(UrlValidator.detectPlatform('not a url'), equals(MediaPlatform.unsupported));
    });
  });
}
