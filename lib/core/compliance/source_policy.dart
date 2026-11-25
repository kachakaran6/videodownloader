import '../utils/url_validator.dart';

/// Status representing the policy classification of a content source.
enum SourcePolicyStatus {
  /// Content downloading and processing are fully supported for public authorized media.
  supported,

  /// Source is accessible only under strict operational boundaries (e.g. public only).
  restricted,

  /// Source requires explicit user declaration of ownership or lawful authorization.
  requiresAuthorization,

  /// Source is strictly prohibited and disabled in Google Play Store builds.
  playStoreDisabled,

  /// Source is completely disabled across all builds.
  disabled,
}

/// Source-specific compliance and policy metadata for each supported platform type.
class SourcePolicy {
  final MediaPlatform platform;
  final SourcePolicyStatus status;
  final String displayName;
  final String description;
  final String policyNotice;
  final bool isPermittedInPlayStore;
  final bool requiresExplicitConfirmation;

  const SourcePolicy({
    required this.platform,
    required this.status,
    required this.displayName,
    required this.description,
    required this.policyNotice,
    required this.isPermittedInPlayStore,
    required this.requiresExplicitConfirmation,
  });

  // ─── Static Notices ────────────────────────────────────────────────────────

  /// Standard fail-safe message when a source cannot be verified.
  static const String failSafeNotice =
      'This source or download method is not currently supported because the application '
      'cannot verify that the requested use is permitted.';

  /// Notice shown for video sources disabled in Play Store builds.
  /// Does not reference any specific platform by name.
  static const String youtubePlayStoreNotice =
      'Video downloading from this source is not available in this version. '
      'Please use the official app\'s download feature or only save content you own.';

  /// Standard professional Copyright & Acceptable Use notice.
  static const String acceptableUseNotice =
      'Only save content you own or have permission to download. You are responsible for how you use saved files.\n\n'
      'ClipVault is intended for lawful use only. Users may download or process content only '
      'when they own the content, have authorization from the copyright holder, or otherwise have a lawful right to do so. '
      'Users are solely responsible for ensuring that their use of saved content complies with applicable copyright laws.\n\n'
      'The application does not grant users any rights to third-party content and does not encourage unauthorized copying, '
      'redistribution, or infringement.';

  /// Confirmation prompt shown before downloading.
  static const String preDownloadConfirmationText =
      'I confirm that I own this content or have the necessary rights/permission to download and use it. '
      'I understand that I am responsible for complying with applicable copyright laws and the terms of the source platform.';

  // ─── Policy Resolver ───────────────────────────────────────────────────────

  /// Get the active policy for a given platform considering the build environment.
  static SourcePolicy getPolicy(
    MediaPlatform platform, {
    required bool isPlayStoreBuild,
  }) {
    switch (platform) {
      // ── Video (e.g. youtube / youtubePlaylist) ──────────────────────────────
      case MediaPlatform.youtube:
      case MediaPlatform.youtubePlaylist:
        if (isPlayStoreBuild) {
          return const SourcePolicy(
            platform: MediaPlatform.youtube,
            status: SourcePolicyStatus.playStoreDisabled,
            displayName: 'Video',
            description:
                'Video downloading from this source is disabled in this release to comply with distribution policies.',
            policyNotice: youtubePlayStoreNotice,
            isPermittedInPlayStore: false,
            requiresExplicitConfirmation: true,
          );
        }
        return const SourcePolicy(
          platform: MediaPlatform.youtube,
          status: SourcePolicyStatus.requiresAuthorization,
          displayName: 'Video',
          description:
              'Video media is only permitted for content you own or have explicit authorization to download.',
          policyNotice:
              'Ensure you own this media or hold valid authorization from the rights holder before proceeding.',
          isPermittedInPlayStore: false,
          requiresExplicitConfirmation: true,
        );

      // ── Music (e.g. spotifyTrack / spotifyAlbum / spotifyPlaylist) ──────────
      case MediaPlatform.spotifyTrack:
      case MediaPlatform.spotifyAlbum:
      case MediaPlatform.spotifyPlaylist:
        if (isPlayStoreBuild) {
          return const SourcePolicy(
            platform: MediaPlatform.spotifyTrack,
            status: SourcePolicyStatus.playStoreDisabled,
            displayName: 'Music',
            description:
                'Audio matching from this source is disabled in this release to comply with distribution policies.',
            policyNotice:
                'Music downloading from this source is not available in this version. '
                'Please use the source service\'s official offline listening features or download content '
                'for which you possess the required rights.',
            isPermittedInPlayStore: false,
            requiresExplicitConfirmation: true,
          );
        }
        return const SourcePolicy(
          platform: MediaPlatform.spotifyTrack,
          status: SourcePolicyStatus.requiresAuthorization,
          displayName: 'Music',
          description:
              'Audio from this source is restricted to authorized tracks where you own the content or have licensing rights.',
          policyNotice:
              'Only download music if you own the master rights or have acquired an explicit distribution license.',
          isPermittedInPlayStore: false,
          requiresExplicitConfirmation: true,
        );

      // ── Video Clip (e.g. facebookVideo) ────────────────────────────────────
      case MediaPlatform.facebookVideo:
        return const SourcePolicy(
          platform: MediaPlatform.facebookVideo,
          status: SourcePolicyStatus.supported,
          displayName: 'Video Clip',
          description:
              'Public video clips and reels from this source may be saved when authorized by the creator or permitted by law.',
          policyNotice:
              'Only download public media from this source that you have permission to store. Private session scraping is not supported.',
          isPermittedInPlayStore: true,
          requiresExplicitConfirmation: true,
        );

      // ── Reels & Clips (e.g. instagramReel / instagramPost / instagramStory) ─
      case MediaPlatform.instagramReel:
      case MediaPlatform.instagramPost:
      case MediaPlatform.instagramStory:
        return const SourcePolicy(
          platform: MediaPlatform.instagramReel,
          status: SourcePolicyStatus.supported,
          displayName: 'Reels & Clips',
          description:
              'Public reels and posts from this source may be saved when authorized by the creator or permitted by law.',
          policyNotice:
              'Only download public media that you have permission to store. Private accounts are strictly protected.',
          isPermittedInPlayStore: true,
          requiresExplicitConfirmation: true,
        );

      // ── X / Twitter Video (e.g. twitterVideo) ──────────────────────────────
      case MediaPlatform.twitterVideo:
        return const SourcePolicy(
          platform: MediaPlatform.twitterVideo,
          status: SourcePolicyStatus.supported,
          displayName: 'X Video',
          description:
              'Public videos and clips from this source may be saved when authorized by the creator or permitted by law.',
          policyNotice:
              'Only download public media from this source that you have permission to store. Private accounts are strictly protected.',
          isPermittedInPlayStore: true,
          requiresExplicitConfirmation: true,
        );

      // ── Unsupported ─────────────────────────────────────────────────────────
      case MediaPlatform.unsupported:
        return const SourcePolicy(
          platform: MediaPlatform.unsupported,
          status: SourcePolicyStatus.disabled,
          displayName: 'Unsupported Source',
          description: 'The provided URL is from an unrecognized or unsupported source.',
          policyNotice: failSafeNotice,
          isPermittedInPlayStore: false,
          requiresExplicitConfirmation: true,
        );
    }
  }
}
