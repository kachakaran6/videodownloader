import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../data/stream_downloader.dart';
import '../domain/download_item.dart';
import '../../inspect/data/video_inspector.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/services/play_update_service.dart';
import '../../../core/services/spotify_inspector.dart';
import '../../../core/services/youtube_clients.dart';
import '../../../core/services/mp3_metadata_service.dart';
import '../../../core/compliance/compliance_policy_engine.dart';
import '../../../core/compliance/compliance_audit_service.dart';
import '../../../core/compliance/content_authorization.dart';
import '../../../core/storage/preferences_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide VideoUnavailableException;

class ActiveDownloadState {
  final DownloadItem? item;
  final DownloadProgress? progress;
  final bool isDownloading;
  final bool isCompleted;
  final String? errorMessage;

  const ActiveDownloadState({
    this.item,
    this.progress,
    this.isDownloading = false,
    this.isCompleted = false,
    this.errorMessage,
  });

  ActiveDownloadState copyWith({
    DownloadItem? item,
    DownloadProgress? progress,
    bool? isDownloading,
    bool? isCompleted,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ActiveDownloadState(
      item: item ?? this.item,
      progress: progress ?? this.progress,
      isDownloading: isDownloading ?? this.isDownloading,
      isCompleted: isCompleted ?? this.isCompleted,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DownloadController extends Notifier<ActiveDownloadState> {
  StreamDownloader? _currentDownloader;

  @override
  ActiveDownloadState build() => const ActiveDownloadState();

  Future<void> startDownload({
    required VideoInspectionResult video,
    required StreamOption option,
    ContentAuthorizationType authorizationType = ContentAuthorizationType.owner,
  }) async {
    if (state.isDownloading) return;

    final prefs = ref.read(preferencesServiceProvider);
    final compliance = ref.read(compliancePolicyEngineProvider);
    final auditService = ref.read(complianceAuditServiceProvider);

    try {
      compliance.verifyDownloadPermission(
        platform: video.platform,
        authorizationType: authorizationType,
        hasAcceptedPolicy: prefs.hasAcceptedPolicy,
      );
    } catch (e) {
      final cleanMsg = e.toString().replaceFirst(RegExp(r'^(PolicyViolationException|AppException|Exception):\s*'), '');
      unawaited(auditService.recordEvent(
        platform: video.platform,
        action: 'download',
        decision: 'denied',
        authorizationType: authorizationType,
        reason: cleanMsg,
      ));
      state = state.copyWith(
        isDownloading: false,
        isCompleted: false,
        errorMessage: cleanMsg,
      );
      return;
    }

    unawaited(auditService.recordEvent(
      platform: video.platform,
      action: 'download',
      decision: 'permitted',
      authorizationType: authorizationType,
    ));

    final itemId = 'dl_${DateTime.now().millisecondsSinceEpoch}';
    final initialItem = DownloadItem(
      id: itemId,
      videoId: video.videoId,
      title: video.title,
      author: video.author,
      thumbnailUrl: video.thumbnailUrl,
      durationSeconds: video.duration.inSeconds,
      qualityLabel: option.label,
      filePath: '',
      fileSizeBytes: option.fileSizeBytes ?? 0,
      status: DownloadStatus.downloading,
      createdAt: DateTime.now(),
      platform: video.isSpotify
          ? 'spotify'
          : (video.isFacebook
              ? 'facebook'
              : (video.isInstagram ? 'instagram' : 'youtube')),
    );

    final initialStage = video.isSpotify
        ? 'Connecting to Spotify...'
        : (video.isFacebook
            ? 'Connecting to Facebook CDN...'
            : (video.isInstagram
                ? (option.container == 'jpg' || option.container == 'png'
                    ? 'Connecting to Instagram photo CDN...'
                    : 'Connecting to Instagram CDN...')
                : 'Connecting to YouTube CDN...'));

    state = ActiveDownloadState(
      item: initialItem,
      isDownloading: true,
      progress: DownloadProgress(
        downloadedBytes: 0,
        totalBytes: option.fileSizeBytes ?? 0,
        progress: 0.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: initialStage,
      ),
    );

    await ref.read(downloadHistoryProvider.notifier).saveItem(initialItem);

    final downloader = StreamDownloader();
    _currentDownloader = downloader;

    try {
      final isAudio = option.isAudioOnly || option.container == 'mp3' || option.container == 'm4a';
      final audioMeta = isAudio
          ? AudioMetadata(
              title: video.title,
              artist: video.author,
              thumbnailUrl: video.thumbnailUrl,
              durationSeconds: video.duration.inSeconds,
            )
          : null;

      final savedFile = await downloader.downloadStream(
        streamInfo: option.streamInfo,
        audioStreamInfo: option.audioStreamInfo,
        directUrl: option.directUrl,
        container: option.container,
        platform: initialItem.platform,
        title: video.title,
        metadata: audioMeta,
        onProgress: (p) {
          state = state.copyWith(progress: p);
        },
      );

      final completedItem = initialItem.copyWith(
        status: DownloadStatus.completed,
        filePath: savedFile.path,
        fileSizeBytes: savedFile.existsSync() ? savedFile.lengthSync() : 0,
        completedAt: DateTime.now(),
      );

      state = state.copyWith(
        item: completedItem,
        isDownloading: false,
        isCompleted: true,
      );

      await ref.read(downloadHistoryProvider.notifier).saveItem(completedItem);

      // Trigger Google Play native In-App Review after genuine positive moment
      // (Internal cooldown & action threshold handled natively by InAppReviewHelper)
      unawaited(PlayUpdateService.recordSuccessfulAction());
      unawaited(PlayUpdateService.tryRequestReview());
    } catch (e) {
      if (downloader.isCancelled) {
        final cancelledItem = initialItem.copyWith(
          status: DownloadStatus.cancelled,
          errorMessage: 'Download was cancelled.',
        );
        state = state.copyWith(
          item: cancelledItem,
          isDownloading: false,
          isCompleted: false,
          errorMessage: 'Download cancelled.',
        );
        await ref.read(downloadHistoryProvider.notifier).saveItem(cancelledItem);
      } else {
        final cleanMsg = e.toString().replaceFirst(RegExp(r'^(AppException|Exception):\s*'), '');
        final failedItem = initialItem.copyWith(
          status: DownloadStatus.failed,
          errorMessage: cleanMsg,
        );
        state = state.copyWith(
          item: failedItem,
          isDownloading: false,
          isCompleted: false,
          errorMessage: cleanMsg,
        );
        await ref.read(downloadHistoryProvider.notifier).saveItem(failedItem);
      }
    } finally {
      _currentDownloader = null;
    }
  }

  Future<void> startBulkAlbumDownload({
    required VideoInspectionResult album,
    required List<SpotifyTrackMetadata> selectedTracks,
    bool preferMasterQuality = false,
    bool previewOnly = false,
    ContentAuthorizationType authorizationType = ContentAuthorizationType.owner,
  }) async {
    if (state.isDownloading || selectedTracks.isEmpty) return;

    final prefs = ref.read(preferencesServiceProvider);
    final compliance = ref.read(compliancePolicyEngineProvider);
    final auditService = ref.read(complianceAuditServiceProvider);

    try {
      compliance.verifyDownloadPermission(
        platform: album.platform,
        authorizationType: authorizationType,
        hasAcceptedPolicy: prefs.hasAcceptedPolicy,
      );
    } catch (e) {
      final cleanMsg = e.toString().replaceFirst(RegExp(r'^(PolicyViolationException|AppException|Exception):\s*'), '');
      unawaited(auditService.recordEvent(
        platform: album.platform,
        action: 'bulk_album_download',
        decision: 'denied',
        authorizationType: authorizationType,
        reason: cleanMsg,
      ));
      state = state.copyWith(
        isDownloading: false,
        isCompleted: false,
        errorMessage: cleanMsg,
      );
      return;
    }

    unawaited(auditService.recordEvent(
      platform: album.platform,
      action: 'bulk_album_download',
      decision: 'permitted',
      authorizationType: authorizationType,
    ));

    final isPreviewOnly = previewOnly;
    final totalTracks = selectedTracks.length;
    final albumTitle = album.title;

    final initialItem = DownloadItem(
      id: 'bulk_${DateTime.now().millisecondsSinceEpoch}',
      videoId: album.videoId,
      title: '$albumTitle ($totalTracks Songs)',
      author: album.author,
      thumbnailUrl: album.thumbnailUrl,
      durationSeconds: album.duration.inSeconds,
      qualityLabel: isPreviewOnly ? '30s Preview Clips' : 'Full Length Original MP3',
      filePath: '',
      fileSizeBytes: 0,
      status: DownloadStatus.downloading,
      createdAt: DateTime.now(),
      platform: 'spotify',
    );

    state = ActiveDownloadState(
      item: initialItem,
      isDownloading: true,
      progress: DownloadProgress(
        downloadedBytes: 0,
        totalBytes: totalTracks * 4000000,
        progress: 0.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Starting album download (0/$totalTracks completed)...',
      ),
    );

    int completedCount = 0;
    String lastSavedPath = '';
    final bulkYt = YoutubeExplode();

    try {
      for (int i = 0; i < selectedTracks.length; i++) {
        if (_currentDownloader?.isCancelled == true) break;

        final track = selectedTracks[i];
        final trackNum = i + 1;
        final songTitle = '${track.title} - ${track.artist}';

        final downloader = StreamDownloader();
        _currentDownloader = downloader;

        final trackItem = DownloadItem(
          id: 'track_${track.trackId}_${DateTime.now().millisecondsSinceEpoch}',
          videoId: track.trackId,
          title: songTitle,
          author: track.artist,
          thumbnailUrl: track.thumbnailUrl.isNotEmpty ? track.thumbnailUrl : album.thumbnailUrl,
          durationSeconds: track.duration?.inSeconds ?? 0,
          qualityLabel: isPreviewOnly ? '30s Preview Clip' : 'Full Length Audio',
          filePath: '',
          fileSizeBytes: 0,
          status: DownloadStatus.downloading,
          createdAt: DateTime.now(),
          platform: 'spotify',
        );

        await ref.read(downloadHistoryProvider.notifier).saveItem(trackItem);

        state = state.copyWith(
          item: trackItem,
          progress: DownloadProgress(
            downloadedBytes: completedCount,
            totalBytes: totalTracks,
            progress: completedCount / totalTracks,
            speedBytesPerSecond: 0,
            etaSeconds: 0,
            stage: 'Downloading $trackNum of $totalTracks: "${track.title}"...',
          ),
        );

        try {
          StreamInfo? matchedStream;
          String? directUrl;
          Video? matchedVideo;

          if (isPreviewOnly) {
            directUrl = track.previewUrl;
          } else {
            // Priority 1: Match full original track on YouTube with smart candidate scoring
            final cleanTitle = SpotifyInspector.cleanTrackTitle(track.title);
            final primaryArtist = SpotifyInspector.cleanArtist(track.artist);
            final queries = [
              '$primaryArtist $cleanTitle official audio',
              '$primaryArtist $cleanTitle',
              '$cleanTitle $primaryArtist',
            ];

            final candidates = <Video>[];
            for (final query in queries) {
              try {
                final searchResults = await bulkYt.search.search(query).timeout(const Duration(seconds: 8));
                for (final v in searchResults.take(6)) {
                  if (!candidates.any((c) => c.id == v.id)) {
                    candidates.add(v);
                  }
                }
                if (candidates.length >= 10) break;
              } catch (_) {}
            }

            matchedVideo = SpotifyInspector.findBestVideoMatch(
              candidates: candidates,
              targetTitle: track.title,
              targetArtist: track.artist,
              targetDuration: track.duration,
            );

            if (matchedVideo != null) {
              try {
                final manifest = await bulkYt.videos.streamsClient.getManifest(
                  matchedVideo.id,
                  ytClients: AppYoutubeClients.defaultClients,
                );
                if (manifest.audioOnly.isNotEmpty) {
                  final mp4Audios = manifest.audioOnly
                      .where((s) => s.container.name.toLowerCase() == 'mp4' || s.container.name.toLowerCase() == 'm4a')
                      .toList();
                  matchedStream = mp4Audios.isNotEmpty
                      ? mp4Audios.withHighestBitrate()
                      : manifest.audioOnly.withHighestBitrate();
                }
              } catch (_) {}
            }

            // Reject silent fallback to 30s preview clip when full audio is requested
            if (matchedStream == null) {
              throw AppException('Could not match full length audio stream for "${track.title}".');
            }
          }

          final resolvedArtist = (track.artist.isNotEmpty && track.artist != 'Spotify Artist')
              ? track.artist
              : (matchedVideo?.author.replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '').trim() ?? 'Spotify Artist');

          final resolvedThumb = (track.thumbnailUrl.isNotEmpty && track.thumbnailUrl != album.thumbnailUrl)
              ? track.thumbnailUrl
              : (matchedVideo?.thumbnails.highResUrl.isNotEmpty == true
                  ? matchedVideo!.thumbnails.highResUrl
                  : (track.thumbnailUrl.isNotEmpty ? track.thumbnailUrl : album.thumbnailUrl));

          final finalSongTitle = '${track.title} - $resolvedArtist';

          final audioMeta = AudioMetadata(
            title: track.title,
            artist: resolvedArtist,
            album: track.album ?? album.title,
            thumbnailUrl: resolvedThumb,
            trackNumber: trackNum,
            durationSeconds: track.duration?.inSeconds ?? matchedVideo?.duration?.inSeconds,
          );

          File? savedFile;
          if (matchedStream != null) {
            final matchExt = (matchedStream.container.name.toLowerCase() == 'mp4' || matchedStream.container.name.toLowerCase() == 'm4a')
                ? 'm4a'
                : matchedStream.container.name.toLowerCase();
            savedFile = await downloader.downloadStream(
              streamInfo: matchedStream,
              container: matchExt,
              platform: 'spotify',
              title: finalSongTitle,
              metadata: audioMeta,
              onProgress: (p) {
                state = state.copyWith(
                  progress: DownloadProgress(
                    downloadedBytes: p.downloadedBytes,
                    totalBytes: p.totalBytes,
                    progress: ((completedCount + p.progress) / totalTracks).clamp(0.0, 1.0),
                    speedBytesPerSecond: p.speedBytesPerSecond,
                    etaSeconds: p.etaSeconds,
                    stage: 'Downloading $trackNum of $totalTracks: "${track.title}" (${(p.progress * 100).toInt()}%)',
                  ),
                );
              },
            );
          } else if (directUrl != null && directUrl.isNotEmpty) {
            savedFile = await downloader.downloadStream(
              directUrl: directUrl,
              container: 'mp3',
              platform: 'spotify',
              title: finalSongTitle,
              metadata: audioMeta,
              onProgress: (p) {
                state = state.copyWith(
                  progress: DownloadProgress(
                    downloadedBytes: p.downloadedBytes,
                    totalBytes: p.totalBytes,
                    progress: ((completedCount + p.progress) / totalTracks).clamp(0.0, 1.0),
                    speedBytesPerSecond: p.speedBytesPerSecond,
                    etaSeconds: p.etaSeconds,
                    stage: 'Downloading $trackNum of $totalTracks: "${track.title}" (${(p.progress * 100).toInt()}%)',
                  ),
                );
              },
            );
          } else {
            throw const AppException('No audio stream or preview found for track.');
          }

          if (savedFile.existsSync() && savedFile.lengthSync() > 1024) {
            completedCount++;
            lastSavedPath = savedFile.path;
            final completedTrack = trackItem.copyWith(
              title: finalSongTitle,
              author: resolvedArtist,
              thumbnailUrl: resolvedThumb,
              status: DownloadStatus.completed,
              filePath: savedFile.path,
              fileSizeBytes: savedFile.lengthSync(),
              completedAt: DateTime.now(),
            );
            await ref.read(downloadHistoryProvider.notifier).saveItem(completedTrack);
          } else {
            final failedTrack = trackItem.copyWith(
              status: DownloadStatus.failed,
              errorMessage: 'File incomplete or empty.',
            );
            await ref.read(downloadHistoryProvider.notifier).saveItem(failedTrack);
          }
        } catch (e) {
          final failedTrack = trackItem.copyWith(
            status: DownloadStatus.failed,
            errorMessage: e.toString().replaceFirst(RegExp(r'^(AppException|Exception):\s*'), ''),
          );
          await ref.read(downloadHistoryProvider.notifier).saveItem(failedTrack);
        }
      }
    } finally {
      bulkYt.close();
    }

    final finalStatus = completedCount > 0 ? DownloadStatus.completed : DownloadStatus.failed;
    final finalItem = initialItem.copyWith(
      status: finalStatus,
      filePath: lastSavedPath,
      completedAt: DateTime.now(),
    );

    state = state.copyWith(
      item: finalItem,
      isDownloading: false,
      isCompleted: completedCount > 0,
      errorMessage: completedCount == 0 ? 'Failed to download tracks in album.' : null,
      progress: DownloadProgress(
        downloadedBytes: completedCount,
        totalBytes: totalTracks,
        progress: 1.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Album download complete! ($completedCount/$totalTracks songs saved)',
      ),
    );

    await ref.read(downloadHistoryProvider.notifier).saveItem(finalItem);
    if (completedCount > 0) {
      unawaited(PlayUpdateService.recordSuccessfulAction());
      unawaited(PlayUpdateService.tryRequestReview());
    }
  }

  Future<void> startBulkYouTubePlaylistDownload({
    required VideoInspectionResult playlist,
    required List<VideoInspectionResult> selectedVideos,
    ContentAuthorizationType authorizationType = ContentAuthorizationType.owner,
  }) async {
    if (state.isDownloading || selectedVideos.isEmpty) return;

    final prefs = ref.read(preferencesServiceProvider);
    final compliance = ref.read(compliancePolicyEngineProvider);
    final auditService = ref.read(complianceAuditServiceProvider);

    try {
      compliance.verifyDownloadPermission(
        platform: playlist.platform,
        authorizationType: authorizationType,
        hasAcceptedPolicy: prefs.hasAcceptedPolicy,
      );
    } catch (e) {
      final cleanMsg = e.toString().replaceFirst(RegExp(r'^(PolicyViolationException|AppException|Exception):\s*'), '');
      unawaited(auditService.recordEvent(
        platform: playlist.platform,
        action: 'bulk_playlist_download',
        decision: 'denied',
        authorizationType: authorizationType,
        reason: cleanMsg,
      ));
      state = state.copyWith(
        isDownloading: false,
        isCompleted: false,
        errorMessage: cleanMsg,
      );
      return;
    }

    unawaited(auditService.recordEvent(
      platform: playlist.platform,
      action: 'bulk_playlist_download',
      decision: 'permitted',
      authorizationType: authorizationType,
    ));

    final totalVideos = selectedVideos.length;
    final playlistTitle = playlist.title;

    final initialItem = DownloadItem(
      id: 'yt_playlist_${DateTime.now().millisecondsSinceEpoch}',
      videoId: playlist.videoId,
      title: '$playlistTitle ($totalVideos Songs)',
      author: playlist.author,
      thumbnailUrl: playlist.thumbnailUrl,
      durationSeconds: playlist.duration.inSeconds,
      qualityLabel: 'Full Length MP3',
      filePath: '',
      fileSizeBytes: 0,
      status: DownloadStatus.downloading,
      createdAt: DateTime.now(),
      platform: 'youtube',
    );

    state = ActiveDownloadState(
      item: initialItem,
      isDownloading: true,
      progress: DownloadProgress(
        downloadedBytes: 0,
        totalBytes: totalVideos * 4000000,
        progress: 0.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Starting playlist download (0/$totalVideos completed)...',
      ),
    );

    int completedCount = 0;
    String lastSavedPath = '';

    for (int i = 0; i < selectedVideos.length; i++) {
      if (_currentDownloader?.isCancelled == true) break;

      final video = selectedVideos[i];
      final videoNum = i + 1;
      final songTitle = video.title;

      final downloader = StreamDownloader();
      _currentDownloader = downloader;

      final trackItem = DownloadItem(
        id: 'yt_vid_${video.videoId}_${DateTime.now().millisecondsSinceEpoch}',
        videoId: video.videoId,
        title: songTitle,
        author: video.author,
        thumbnailUrl: video.thumbnailUrl,
        durationSeconds: video.duration.inSeconds,
        qualityLabel: 'Full Length MP3',
        filePath: '',
        fileSizeBytes: 0,
        status: DownloadStatus.downloading,
        createdAt: DateTime.now(),
        platform: 'youtube',
      );

      await ref.read(downloadHistoryProvider.notifier).saveItem(trackItem);

      state = state.copyWith(
        item: trackItem,
        progress: DownloadProgress(
          downloadedBytes: completedCount,
          totalBytes: totalVideos,
          progress: completedCount / totalVideos,
          speedBytesPerSecond: 0,
          etaSeconds: 0,
          stage: 'Downloading $videoNum of $totalVideos: "$songTitle"...',
        ),
      );

      try {
        final yt = YoutubeExplode();
        final manifest = await yt.videos.streamsClient.getManifest(
          video.videoId,
          ytClients: AppYoutubeClients.defaultClients,
        );

        if (manifest.audioOnly.isEmpty) {
          throw const AppException('No audio streams available for this video.');
        }

        final mp4Audios = manifest.audioOnly
            .where((s) => s.container.name.toLowerCase() == 'mp4' || s.container.name.toLowerCase() == 'm4a')
            .toList();
        final bestAudio = mp4Audios.isNotEmpty
            ? mp4Audios.withHighestBitrate()
            : manifest.audioOnly.withHighestBitrate();

        final audioMeta = AudioMetadata(
          title: video.title,
          artist: video.author,
          album: playlistTitle,
          thumbnailUrl: video.thumbnailUrl,
          trackNumber: videoNum,
          durationSeconds: video.duration.inSeconds,
        );

        final savedFile = await downloader.downloadStream(
          streamInfo: bestAudio,
          container: 'mp3',
          platform: 'youtube',
          title: songTitle,
          metadata: audioMeta,
          onProgress: (p) {
            state = state.copyWith(
              progress: DownloadProgress(
                downloadedBytes: p.downloadedBytes,
                totalBytes: p.totalBytes,
                progress: ((completedCount + p.progress) / totalVideos).clamp(0.0, 1.0),
                speedBytesPerSecond: p.speedBytesPerSecond,
                etaSeconds: p.etaSeconds,
                stage: 'Downloading $videoNum of $totalVideos: "$songTitle" (${(p.progress * 100).toInt()}%)',
              ),
            );
          },
        );

        if (savedFile.existsSync() && savedFile.lengthSync() > 1024) {
          completedCount++;
          lastSavedPath = savedFile.path;
          final completedTrack = trackItem.copyWith(
            status: DownloadStatus.completed,
            filePath: savedFile.path,
            fileSizeBytes: savedFile.lengthSync(),
            completedAt: DateTime.now(),
          );
          await ref.read(downloadHistoryProvider.notifier).saveItem(completedTrack);
        } else {
          final failedTrack = trackItem.copyWith(
            status: DownloadStatus.failed,
            errorMessage: 'File incomplete or empty.',
          );
          await ref.read(downloadHistoryProvider.notifier).saveItem(failedTrack);
        }
      } catch (e) {
        final failedTrack = trackItem.copyWith(
          status: DownloadStatus.failed,
          errorMessage: e.toString().replaceFirst(RegExp(r'^(AppException|Exception):\s*'), ''),
        );
        await ref.read(downloadHistoryProvider.notifier).saveItem(failedTrack);
      }
    }

    final finalStatus = completedCount > 0 ? DownloadStatus.completed : DownloadStatus.failed;
    final finalItem = initialItem.copyWith(
      status: finalStatus,
      filePath: lastSavedPath,
      completedAt: DateTime.now(),
    );

    state = state.copyWith(
      item: finalItem,
      isDownloading: false,
      isCompleted: completedCount > 0,
      errorMessage: completedCount == 0 ? 'Failed to download videos in playlist.' : null,
      progress: DownloadProgress(
        downloadedBytes: completedCount,
        totalBytes: totalVideos,
        progress: 1.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Playlist download complete! ($completedCount/$totalVideos songs saved)',
      ),
    );

    await ref.read(downloadHistoryProvider.notifier).saveItem(finalItem);
    if (completedCount > 0) {
      unawaited(PlayUpdateService.recordSuccessfulAction());
      unawaited(PlayUpdateService.tryRequestReview());
    }
  }

  void cancelDownload() {
    _currentDownloader?.cancel();
  }

  Future<OpenResult> openFile(String filePath) async {
    return await OpenFilex.open(filePath);
  }

  Future<void> shareFile(String filePath, String title) async {
    if (File(filePath).existsSync()) {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(filePath)],
        text: title,
      );
    }
  }

  void reset() {
    state = const ActiveDownloadState();
  }
}

final downloadControllerProvider =
    NotifierProvider<DownloadController, ActiveDownloadState>(DownloadController.new);
