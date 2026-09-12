import 'package:flutter_test/flutter_test.dart';
import 'package:media_saver/core/services/spotify_inspector.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  group('SpotifyInspector - cleanTrackTitle', () {
    test('removes featured artists in parentheses and brackets', () {
      expect(
        SpotifyInspector.cleanTrackTitle('Starboy (feat. Daft Punk)'),
        equals('Starboy'),
      );
      expect(
        SpotifyInspector.cleanTrackTitle('Levitating [feat. Daft Punk]'),
        equals('Levitating'),
      );
      expect(
        SpotifyInspector.cleanTrackTitle('STAY (with Justin Bieber)'),
        equals('STAY'),
      );
    });

    test('removes movie/soundtrack tags and quotes', () {
      expect(
        SpotifyInspector.cleanTrackTitle('Kesariya (From "Brahmastra")'),
        equals('Kesariya'),
      );
      expect(
        SpotifyInspector.cleanTrackTitle('Makhna (From "Drive")'),
        equals('Makhna'),
      );
    });

    test('removes remastered tags', () {
      expect(
        SpotifyInspector.cleanTrackTitle('In the End - 2020 Remaster'),
        equals('In the End'),
      );
      expect(
        SpotifyInspector.cleanTrackTitle('Hotel California (Remastered)'),
        equals('Hotel California'),
      );
    });

    test('removes trailing Spotify oEmbed titles', () {
      expect(
        SpotifyInspector.cleanTrackTitle('Blinding Lights | Spotify'),
        equals('Blinding Lights'),
      );
      expect(
        SpotifyInspector.cleanTrackTitle('Espresso - song and lyrics by Sabrina Carpenter | Spotify'),
        equals('Espresso'),
      );
    });
  });

  group('SpotifyInspector - cleanArtist', () {
    test('extracts primary artist from multiple artists', () {
      expect(
        SpotifyInspector.cleanArtist('Arijit Singh, Pritam, Amitabh Bhattacharya'),
        equals('Arijit Singh'),
      );
      expect(
        SpotifyInspector.cleanArtist('The Weeknd & Daft Punk'),
        equals('The Weeknd'),
      );
      expect(
        SpotifyInspector.cleanArtist('Sabrina Carpenter'),
        equals('Sabrina Carpenter'),
      );
    });
  });

  group('SpotifyInspector - findBestVideoMatch with live candidates', () {
    test('accurately selects full-length audio matching track duration', () async {
      final yt = YoutubeExplode();
      final results = await yt.search.search('Rick Astley Never Gonna Give You Up official audio');
      final candidates = results.take(10).toList();

      final matched = SpotifyInspector.findBestVideoMatch(
        candidates: candidates,
        targetTitle: 'Never Gonna Give You Up',
        targetArtist: 'Rick Astley',
        targetDuration: const Duration(seconds: 214),
      );

      expect(matched, isNotNull);
      expect(matched!.duration, isNotNull);
      // Confirmed: duration must be full length (around 214s), not a 20s short
      expect(matched.duration!.inSeconds, greaterThanOrEqualTo(180));
      expect((matched.duration!.inSeconds - 214).abs(), lessThanOrEqualTo(10));
      yt.close();
    }, timeout: const Timeout(Duration(seconds: 20)));
  });

  group('SpotifyInspector - Live Track Inspection', () {
    test('fetches full song and recommends full length audio option', () async {
      final inspector = SpotifyInspector();
      // Rick Astley - Never Gonna Give You Up
      const url = 'https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT';

      final res = await inspector.inspect(url);

      expect(res.videoId, startsWith('spotify_'));
      expect(res.title.toLowerCase(), contains('never gonna give you up'));
      expect(res.duration.inSeconds, greaterThanOrEqualTo(180));
      expect(res.options, isNotEmpty);

      final recommended = res.options.firstWhere((o) => o.isRecommended);
      expect(recommended.id, equals('spotify_audio_full'));
      expect(recommended.label, startsWith('Full Length Audio'));
      expect(recommended.isAudioOnly, isTrue);
      expect(recommended.streamInfo, isNotNull);
      expect(recommended.fileSizeBytes, greaterThan(1000000)); // Greater than 1 MB
    }, timeout: const Timeout(Duration(seconds: 25)));
  });
}
