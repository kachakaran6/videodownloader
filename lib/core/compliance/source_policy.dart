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

/// Source-specific compliance and policy metadata for each platform.
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

  /// Standard fail-safe message when a source cannot be verified.
  static const String failSafeNotice =
      'This source or download method is not currently supported because the application '
      'cannot verify that the requested use is permitted.';

  /// Standard YouTube notice for Google Play Store builds.
  static const String youtubePlayStoreNotice =
      "YouTube downloading is not available in this version. Please use YouTube's official "
      "download/offline functionality or download content for which you have the necessary rights.";

  /// Standard professional Copyright & Acceptable Use notice.
  static const String acceptableUseNotice =
      'Media Downloader is intended for lawful use only. Users may download or process content only '
      'when they own the content, have authorization from the copyright holder, or otherwise have a lawful right to do so. '
      'Users are solely responsible for ensuring that their use of downloaded content complies with applicable copyright '
      'laws, licenses, and the terms of the source service.\n\n'
      'The application does not grant users any rights to third-party content and does not encourage unauthorized copying, '
      'redistribution, or infringement.';

  /// Confirmation prompt shown before downloading.
  static const String preDownloadConfirmationText =
      'I confirm that I own this content or have the necessary rights/permission to download and use it. '
      'I understand that I am responsible for complying with applicable copyright laws and the terms of the source platform.';

  /// Get the active policy for a given platform considering the build environment.
  static SourcePolicy getPolicy(
    MediaPlatform platform, {
    required bool isPlayStoreBuild,
  }) {
    switch (platform) {
      case MediaPlatform.youtube:
      case MediaPlatform.youtubePlaylist:
        if (isPlayStoreBuild) {
          return const SourcePolicy(
            platform: MediaPlatform.youtube,
            status: SourcePolicyStatus.playStoreDisabled,
            displayName: 'YouTube',
            description:
                'YouTube downloading is disabled in this release to comply with Google Play policies.',
            policyNotice: youtubePlayStoreNotice,
            isPermittedInPlayStore: false,
            requiresExplicitConfirmation: true,
          );
        }
        return const SourcePolicy(
          platform: MediaPlatform.youtube,
          status: SourcePolicyStatus.requiresAuthorization,
          displayName: 'YouTube',
          description:
              'YouTube media is only permitted for content you own or have explicit authorization to download.',
          policyNotice:
              'Ensure you own this media or hold valid authorization from the rights holder before proceeding.',
          isPermittedInPlayStore: false,
          requiresExplicitConfirmation: true,
        );

      case MediaPlatform.spotifyTrack:
      case MediaPlatform.spotifyAlbum:
      case MediaPlatform.spotifyPlaylist:
        if (isPlayStoreBuild) {
          return const SourcePolicy(
            platform: MediaPlatform.spotifyTrack,
            status: SourcePolicyStatus.playStoreDisabled,
            displayName: 'Spotify',
            description:
                'Spotify audio matching is disabled in this release to comply with Google Play policies.',
            policyNotice:
                "Spotify media downloading is not available in this version. Please use Spotify's official "
                'offline listening features or download content for which you possess the required rights.',
            isPermittedInPlayStore: false,
            requiresExplicitConfirmation: true,
          );
        }
        return const SourcePolicy(
          platform: MediaPlatform.spotifyTrack,
          status: SourcePolicyStatus.requiresAuthorization,
          displayName: 'Spotify',
          description:
              'Spotify audio is restricted to authorized tracks where you own the content or have licensing rights.',
          policyNotice:
              'Only download music if you own the master rights or have acquired an explicit distribution license.',
          isPermittedInPlayStore: false,
          requiresExplicitConfirmation: true,
        );

      case MediaPlatform.facebookVideo:
        return const SourcePolicy(
          platform: MediaPlatform.facebookVideo,
          status: SourcePolicyStatus.supported,
          displayName: 'Facebook',
          description:
              'Public Facebook videos and reels may be saved when authorized by the creator or permitted by law.',
          policyNotice:
              'Only download public Facebook media that you have permission to store. Private session scraping is not supported.',
          isPermittedInPlayStore: true,
          requiresExplicitConfirmation: true,
        );

      case MediaPlatform.instagramReel:
      case MediaPlatform.instagramPost:
      case MediaPlatform.instagramStory:
        return const SourcePolicy(
          platform: MediaPlatform.instagramReel,
          status: SourcePolicyStatus.supported,
          displayName: 'Instagram',
          description:
              'Public Instagram reels and posts may be saved when authorized by the creator or permitted by law.',
          policyNotice:
              'Only download public Instagram media that you have permission to store. Private accounts are strictly protected.',
          isPermittedInPlayStore: true,
          requiresExplicitConfirmation: true,
        );

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
