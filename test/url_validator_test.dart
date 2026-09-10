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

  group('UrlValidator - extractFirstSupportedUrl', () {
    test('extracts YouTube watch URL embedded in shared text', () {
      const shared = 'Check out this awesome video: https://www.youtube.com/watch?v=dQw4w9WgXcQ! It is incredible.';
      expect(
        UrlValidator.extractFirstSupportedUrl(shared),
        equals('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      );
    });

    test('extracts youtu.be short URL from YouTube app share', () {
      const shared = 'Watch "Music Track" on YouTube: https://youtu.be/dQw4w9WgXcQ?si=abc123xyz';
      expect(
        UrlValidator.extractFirstSupportedUrl(shared),
        equals('https://youtu.be/dQw4w9WgXcQ?si=abc123xyz'),
      );
    });

    test('extracts Instagram Reel URL from Instagram app share', () {
      const shared = 'https://www.instagram.com/reel/DEvjGZhzJ5k/?igsh=MWFqZ2Y4bHlrcHRrMw==';
      expect(
        UrlValidator.extractFirstSupportedUrl(shared),
        equals('https://www.instagram.com/reel/DEvjGZhzJ5k/?igsh=MWFqZ2Y4bHlrcHRrMw=='),
      );
    });

    test('returns null for text without valid media link', () {
      expect(UrlValidator.extractFirstSupportedUrl('Hello how are you?'), isNull);
      expect(UrlValidator.extractFirstSupportedUrl('Check this out: https://google.com/search?q=cats'), isNull);
      expect(UrlValidator.extractFirstSupportedUrl(''), isNull);
      expect(UrlValidator.extractFirstSupportedUrl(null), isNull);
    });
  });

  group('UrlValidator - Spotify', () {
    test('validates standard track URL', () {
      const url = 'https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT';
      expect(UrlValidator.isValidSpotifyUrl(url), isTrue);
      expect(UrlValidator.detectPlatform(url), equals(MediaPlatform.spotifyTrack));
      expect(UrlValidator.extractSpotifyTrackId(url), equals('4cOdK2wGLETKBW3PvgPWqT'));
    });

    test('validates internationalized track URL with query params', () {
      const url = 'https://open.spotify.com/intl-de/track/4cOdK2wGLETKBW3PvgPWqT?si=abc123xyz';
      expect(UrlValidator.isValidSpotifyUrl(url), isTrue);
      expect(UrlValidator.detectPlatform(url), equals(MediaPlatform.spotifyTrack));
      expect(UrlValidator.extractSpotifyTrackId(url), equals('4cOdK2wGLETKBW3PvgPWqT'));
    });

    test('extracts Spotify track link from Spotify app share text', () {
      const shared = 'Check out Never Gonna Give You Up by Rick Astley on Spotify: https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT?si=abc123xyz';
      expect(
        UrlValidator.extractFirstSupportedUrl(shared),
        equals('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT?si=abc123xyz'),
      );
    });

    test('validates standard album URL', () {
      const url = 'https://open.spotify.com/album/1DFixLWuPkv3KT3TnV35m3';
      expect(UrlValidator.isValidSpotifyUrl(url), isTrue);
      expect(UrlValidator.detectPlatform(url), equals(MediaPlatform.spotifyAlbum));
      expect(UrlValidator.extractSpotifyAlbumId(url), equals('1DFixLWuPkv3KT3TnV35m3'));
    });

    test('validates internationalized album URL with query params', () {
      const url = 'https://open.spotify.com/intl-de/album/1DFixLWuPkv3KT3TnV35m3?si=xyz123';
      expect(UrlValidator.isValidSpotifyUrl(url), isTrue);
      expect(UrlValidator.detectPlatform(url), equals(MediaPlatform.spotifyAlbum));
      expect(UrlValidator.extractSpotifyAlbumId(url), equals('1DFixLWuPkv3KT3TnV35m3'));
    });

    test('validates playlist URL', () {
      const url = 'https://open.spotify.com/playlist/37i9dQZF1DXcBWYjo7Z5yd';
      expect(UrlValidator.isValidSpotifyUrl(url), isTrue);
      expect(UrlValidator.detectPlatform(url), equals(MediaPlatform.spotifyPlaylist));
      expect(UrlValidator.extractSpotifyPlaylistId(url), equals('37i9dQZF1DXcBWYjo7Z5yd'));
    });

    test('rejects non-track Spotify URLs or invalid URLs', () {
      expect(UrlValidator.isValidSpotifyUrl('https://open.spotify.com/user/123'), isFalse);
      expect(UrlValidator.isValidSpotifyUrl('https://spotify.com'), isFalse);
      expect(UrlValidator.isValidSpotifyUrl('https://apple.com/music'), isFalse);
    });
  });
}
