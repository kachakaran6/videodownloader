import 'package:flutter_test/flutter_test.dart';
import 'package:media_saver/core/compliance/compliance_policy_engine.dart';
import 'package:media_saver/core/compliance/content_authorization.dart';
import 'package:media_saver/core/compliance/source_policy.dart';
import 'package:media_saver/core/utils/url_validator.dart';

void main() {
  group('CompliancePolicyEngine - Standard Build (Non-Play Store)', () {
    const engine = CompliancePolicyEngine(isPlayStoreBuild: false);

    test('verifies Facebook video inspection is allowed', () {
      final decision = engine.verifyInspectionPermission(
        MediaPlatform.facebookVideo,
        'https://www.facebook.com/watch/?v=123456789',
      );
      expect(decision.isAllowed, isTrue);
      expect(decision.policy.status, SourcePolicyStatus.supported);
    });

    test('verifies Instagram Reel inspection is allowed', () {
      final decision = engine.verifyInspectionPermission(
        MediaPlatform.instagramReel,
        'https://www.instagram.com/reel/C7xyz123/',
      );
      expect(decision.isAllowed, isTrue);
    });

    test('verifies YouTube inspection requires authorization in standard build', () {
      final decision = engine.verifyInspectionPermission(
        MediaPlatform.youtube,
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(decision.isAllowed, isTrue);
      expect(decision.policy.status, SourcePolicyStatus.requiresAuthorization);
    });

    test('fails safely on unsupported source URLs', () {
      expect(
        () => engine.verifyInspectionPermission(
          MediaPlatform.unsupported,
          'https://unknown-pirate-site.com/video.mp4',
        ),
        throwsA(isA<PolicyViolationException>().having(
          (e) => e.message,
          'message',
          SourcePolicy.failSafeNotice,
        )),
      );
    });

    test('requires policy acceptance before permitting any download', () {
      expect(
        () => engine.verifyDownloadPermission(
          platform: MediaPlatform.facebookVideo,
          authorizationType: ContentAuthorizationType.owner,
          hasAcceptedPolicy: false,
        ),
        throwsA(isA<PolicyViolationException>().having(
          (e) => e.message,
          'message',
          contains('accept the Copyright & Acceptable Use Policy'),
        )),
      );
    });

    test('permits download when user has accepted policy and declared authorization', () {
      final decision = engine.verifyDownloadPermission(
        platform: MediaPlatform.facebookVideo,
        authorizationType: ContentAuthorizationType.owner,
        hasAcceptedPolicy: true,
      );
      expect(decision.isAllowed, isTrue);
    });
  });

  group('CompliancePolicyEngine - Google Play Store Build', () {
    const playEngine = CompliancePolicyEngine(isPlayStoreBuild: true);

    test('strictly blocks YouTube inspection with the exact required policy message', () {
      expect(
        () => playEngine.verifyInspectionPermission(
          MediaPlatform.youtube,
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        throwsA(isA<PolicyViolationException>().having(
          (e) => e.message,
          'message',
          SourcePolicy.youtubePlayStoreNotice,
        )),
      );
    });

    test('strictly blocks YouTube playlist inspection in Play Store build', () {
      expect(
        () => playEngine.verifyInspectionPermission(
          MediaPlatform.youtubePlaylist,
          'https://www.youtube.com/playlist?list=PL12345',
        ),
        throwsA(isA<PolicyViolationException>().having(
          (e) => e.message,
          'message',
          SourcePolicy.youtubePlayStoreNotice,
        )),
      );
    });

    test('strictly blocks Spotify proxy downloading in Play Store build', () {
      expect(
        () => playEngine.verifyInspectionPermission(
          MediaPlatform.spotifyTrack,
          'https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT',
        ),
        throwsA(isA<PolicyViolationException>().having(
          (e) => e.message,
          'message',
          contains('Spotify media downloading is not available'),
        )),
      );
    });

    test('strictly blocks YouTube download even if user confirmed ownership', () {
      expect(
        () => playEngine.verifyDownloadPermission(
          platform: MediaPlatform.youtube,
          authorizationType: ContentAuthorizationType.owner,
          hasAcceptedPolicy: true,
        ),
        throwsA(isA<PolicyViolationException>().having(
          (e) => e.message,
          'message',
          SourcePolicy.youtubePlayStoreNotice,
        )),
      );
    });

    test('allows legitimate Facebook and Instagram downloads in Play Store build', () {
      final fbDecision = playEngine.verifyDownloadPermission(
        platform: MediaPlatform.facebookVideo,
        authorizationType: ContentAuthorizationType.licensee,
        hasAcceptedPolicy: true,
      );
      expect(fbDecision.isAllowed, isTrue);

      final igDecision = playEngine.verifyDownloadPermission(
        platform: MediaPlatform.instagramReel,
        authorizationType: ContentAuthorizationType.creativeCommons,
        hasAcceptedPolicy: true,
      );
      expect(igDecision.isAllowed, isTrue);
    });
  });
}
