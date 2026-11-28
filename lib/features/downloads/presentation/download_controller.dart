import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
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
import '../../../core/utils/media_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/services/download_notification_service.dart';
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
  final Set<StreamDownloader> _activeDownloaders = {};
  bool _isCancelled = false;

  @override
  ActiveDownloadState build() => const ActiveDownloadState();

  Future<void> startDownload({
    required VideoInspectionResult video,
    required StreamOption option,
    ContentAuthorizationType authorizationType = ContentAuthorizationType.owner,
  }) async {
    if (state.isDownloading) return;

    _isCancelled = false;
    _currentDownloader = null;
    _activeDownloaders.clear();

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
      groupId: itemId,
      groupTitle: video.title,
      groupThumbnailUrl: video.thumbnailUrl,
      sourceUrl: video.videoId,
    );

    final initialStage = video.isSpotify
        ? 'Connecting to audio stream...'
        : (video.isFacebook
            ? 'Connecting to video stream...'
            : (video.isInstagram
                ? (option.container == 'jpg' || option.container == 'png'
                    ? 'Connecting to image server...'
                    : 'Connecting to media server...')
                : 'Connecting to media server...'));

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

    // Initialize Foreground Service & Notifications for background persistence
    unawaited(DownloadNotificationService.requestPermission());
    unawaited(DownloadNotificationService.start(
      title: initialItem.title,
      subtitle: initialStage,
    ));

    final downloader = StreamDownloader();
    _currentDownloader = downloader;

    try {
      final isAudio = option.isAudioOnly || option.container == 'mp3' || option.container == 'm4a';
      final cleanTitle = video.isSpotify && video.spotifyTracks != null && video.spotifyTracks!.isNotEmpty
          ? video.spotifyTracks!.first.title
          : (video.isSpotify
              ? video.title.split(RegExp(r'\s*-\s*')).first.trim()
              : video.title);
      final resolvedArtist = video.isSpotify && video.spotifyTracks != null && video.spotifyTracks!.isNotEmpty
          ? video.spotifyTracks!.first.artist
          : video.author;
      final resolvedAlbum = video.isSpotify && video.spotifyTracks != null && video.spotifyTracks!.isNotEmpty
          ? video.spotifyTracks!.first.album ?? video.album
          : video.album;
      final resolvedTrackNumber = video.isSpotify && video.spotifyTracks != null && video.spotifyTracks!.isNotEmpty
          ? video.spotifyTracks!.first.trackNumber ?? video.trackNumber
          : video.trackNumber;
      final resolvedYear = video.isSpotify && video.spotifyTracks != null && video.spotifyTracks!.isNotEmpty
          ? video.spotifyTracks!.first.year ?? video.year
          : video.year;

      final audioMeta = isAudio
          ? AudioMetadata(
              title: cleanTitle,
              artist: resolvedArtist,
              album: resolvedAlbum,
              trackNumber: resolvedTrackNumber,
              year: resolvedYear,
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
          final percent = (p.progress * 100).toInt();
          final status = '$percent% • ${Formatters.formatBytes(p.downloadedBytes)} / ${Formatters.formatBytes(p.totalBytes)} • ${Formatters.formatSpeed(p.speedBytesPerSecond)}';
          DownloadNotificationService.updateProgress(
            title: initialItem.title,
            progress: percent,
            statusText: status,
          );
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

      unawaited(DownloadNotificationService.complete(
        title: completedItem.title,
        statusText: 'Download Complete • Saved to Downloads',
      ));

      // Trigger Google Play native In-App Review after genuine positive moment
      // (Internal cooldown & action threshold handled natively by InAppReviewHelper)
      unawaited(PlayUpdateService.recordSuccessfulAction());
      unawaited(PlayUpdateService.tryRequestReview());
    } catch (e) {
      unawaited(DownloadNotificationService.stop());
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
      _activeDownloaders.clear();
      _isCancelled = false;
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

    _isCancelled = false;
    _currentDownloader = null;
    _activeDownloaders.clear();

    final albumGroupId = 'album_${album.videoId.isNotEmpty ? album.videoId : DateTime.now().millisecondsSinceEpoch}';
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
      groupId: albumGroupId,
      groupTitle: '$albumTitle ($totalTracks Songs)',
      groupThumbnailUrl: album.thumbnailUrl,
      sourceUrl: album.videoId,
    );

    // Concurrency: Use user preference (default 3, range 2 to 4)
    final concurrency = prefs.concurrentDownloads.clamp(2, 4);

    // Initialize Foreground Service & Notifications for background album persistence
    unawaited(DownloadNotificationService.requestPermission());
    unawaited(DownloadNotificationService.start(
      title: initialItem.title,
      subtitle: 'Starting parallel download ($totalTracks songs)...',
    ));

    state = ActiveDownloadState(
      item: initialItem,
      isDownloading: true,
      progress: DownloadProgress(
        downloadedBytes: 0,
        totalBytes: totalTracks * 4000000,
        progress: 0.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Starting parallel download ($totalTracks songs)...',
      ),
    );

    int completedCount = 0;
    String lastSavedPath = '';
    String? lastError;
    final bulkYt = YoutubeExplode();
    int nextTrackIndex = 0;
    final Map<int, double> trackProgressMap = {};
    final Map<int, double> trackSpeedMap = {};

    void updateAggregateProgress() {
      if (_isCancelled) return;
      double inProgressSum = 0.0;
      double totalSpeed = 0.0;
      for (final p in trackProgressMap.values) {
        inProgressSum += p;
      }
      for (final s in trackSpeedMap.values) {
        totalSpeed += s;
      }
      final aggregateProgress = ((completedCount + inProgressSum) / totalTracks).clamp(0.0, 1.0);
      final remainingBytes = ((1.0 - aggregateProgress) * totalTracks * 4000000).toInt();
      final eta = totalSpeed > 0 ? (remainingBytes / totalSpeed).toInt() : 0;
      final pct = (aggregateProgress * 100).toInt();
      final stageStr = 'Downloading $concurrency songs in parallel • $completedCount of $totalTracks completed ($pct%)';

      DownloadNotificationService.updateProgress(
        title: initialItem.title,
        progress: pct,
        statusText: '$pct% • $completedCount of $totalTracks completed • ${Formatters.formatSpeed(totalSpeed)}',
      );

      state = state.copyWith(
        progress: DownloadProgress(
          downloadedBytes: (aggregateProgress * totalTracks * 4000000).toInt(),
          totalBytes: totalTracks * 4000000,
          progress: aggregateProgress,
          speedBytesPerSecond: totalSpeed,
          etaSeconds: eta,
          stage: stageStr,
        ),
      );
    }

    Future<void> runWorker() async {
      while (!_isCancelled) {
        if (nextTrackIndex >= totalTracks) break;
        final trackIndex = nextTrackIndex++;
        final track = selectedTracks[trackIndex];
        final trackNum = trackIndex + 1;
        final songTitle = '${track.title} - ${track.artist}';

        final downloader = StreamDownloader();
        _activeDownloaders.add(downloader);
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
          groupId: initialItem.groupId,
          groupTitle: initialItem.groupTitle,
          groupThumbnailUrl: initialItem.groupThumbnailUrl,
          sourceUrl: initialItem.sourceUrl,
        );

        await ref.read(downloadHistoryProvider.notifier).saveItem(trackItem);

        try {
          if (_isCancelled) break;

          StreamInfo? matchedStream;
          String? directUrl;
          Video? matchedVideo;

          if (isPreviewOnly) {
            directUrl = track.previewUrl;
          } else {
            final cleanTitle = SpotifyInspector.cleanTrackTitle(track.title);
            final primaryArtist = SpotifyInspector.cleanArtist(track.artist);
            final candidates = <Video>[];

            // Priority query 1: Official audio search (fast 5s timeout)
            try {
              final searchResults = await bulkYt.search
                  .search('$primaryArtist $cleanTitle official audio')
                  .timeout(const Duration(seconds: 5));
              for (final v in searchResults.take(6)) {
                if (!candidates.any((c) => c.id == v.id)) {
                  candidates.add(v);
                }
              }
            } catch (_) {}

            // Fallback query if no candidate found
            if (candidates.isEmpty && !_isCancelled) {
              try {
                final fallbackResults = await bulkYt.search
                    .search('$cleanTitle $primaryArtist')
                    .timeout(const Duration(seconds: 4));
                for (final v in fallbackResults.take(6)) {
                  if (!candidates.any((c) => c.id == v.id)) {
                    candidates.add(v);
                  }
                }
              } catch (_) {}
            }

            if (_isCancelled) break;

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

            if (matchedStream == null && !_isCancelled) {
              throw AppException('Could not match audio stream for "${track.title}".');
            }
          }

          if (_isCancelled) break;

          final resolvedArtist = (track.artist.isNotEmpty && track.artist != 'Unknown Artist')
              ? track.artist
              : (matchedVideo?.author.replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '').trim() ?? 'Unknown Artist');

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
                trackProgressMap[trackIndex] = p.progress;
                trackSpeedMap[trackIndex] = p.speedBytesPerSecond;
                updateAggregateProgress();
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
                trackProgressMap[trackIndex] = p.progress;
                trackSpeedMap[trackIndex] = p.speedBytesPerSecond;
                updateAggregateProgress();
              },
            );
          }

          trackProgressMap.remove(trackIndex);
          trackSpeedMap.remove(trackIndex);

          if (_isCancelled) break;

          if (savedFile != null && savedFile.existsSync() && savedFile.lengthSync() > 1024) {
            completedCount++;
            lastSavedPath = savedFile.path;
            updateAggregateProgress();

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
        } catch (e, stack) {
          trackProgressMap.remove(trackIndex);
          trackSpeedMap.remove(trackIndex);
          if (!_isCancelled) {
            final cleanError = e.toString().replaceFirst(RegExp(r'^(AppException|Exception):\s*'), '');
            lastError = cleanError;
            debugPrint('[AlbumDownload] Error downloading ${track.title}: $e\n$stack');
            final failedTrack = trackItem.copyWith(
              status: DownloadStatus.failed,
              errorMessage: cleanError,
            );
            await ref.read(downloadHistoryProvider.notifier).saveItem(failedTrack);
          }
        } finally {
          _activeDownloaders.remove(downloader);
        }
      }
    }

    try {
      final workerCount = concurrency.clamp(1, totalTracks);
      final workers = List.generate(workerCount, (_) => runWorker());
      await Future.wait(workers);
    } finally {
      bulkYt.close();
      _activeDownloaders.clear();
      _currentDownloader = null;
    }

    if (_isCancelled) {
      unawaited(DownloadNotificationService.stop());
      final cancelledItem = initialItem.copyWith(
        status: DownloadStatus.failed,
        filePath: lastSavedPath,
        completedAt: DateTime.now(),
      );
      state = state.copyWith(
        item: cancelledItem,
        isDownloading: false,
        isCompleted: false,
        errorMessage: 'Download cancelled.',
        progress: DownloadProgress(
          downloadedBytes: completedCount,
          totalBytes: totalTracks,
          progress: completedCount / totalTracks,
          speedBytesPerSecond: 0,
          etaSeconds: 0,
          stage: 'Download cancelled ($completedCount/$totalTracks saved)',
        ),
      );
      _isCancelled = false;
      return;
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
      errorMessage: completedCount == 0 ? (lastError ?? 'Failed to download tracks in album.') : null,
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
      unawaited(DownloadNotificationService.complete(
        title: finalItem.title,
        statusText: '$completedCount tracks saved to Downloads/Music',
      ));
      unawaited(PlayUpdateService.recordSuccessfulAction());
      unawaited(PlayUpdateService.tryRequestReview());
    } else {
      unawaited(DownloadNotificationService.stop());
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

    _isCancelled = false;
    _currentDownloader = null;
    _activeDownloaders.clear();

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

    try {
      for (int i = 0; i < selectedVideos.length; i++) {
        if (_isCancelled || _currentDownloader?.isCancelled == true) break;

        final video = selectedVideos[i];
        final videoNum = i + 1;
        final songTitle = video.title;

        final downloader = StreamDownloader();
        _activeDownloaders.add(downloader);
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
        } finally {
          _activeDownloaders.remove(downloader);
        }
      }
    } finally {
      _activeDownloaders.clear();
      _currentDownloader = null;
    }

    if (_isCancelled) {
      unawaited(DownloadNotificationService.stop());
      final cancelledItem = initialItem.copyWith(
        status: DownloadStatus.failed,
        filePath: lastSavedPath,
        completedAt: DateTime.now(),
      );
      state = state.copyWith(
        item: cancelledItem,
        isDownloading: false,
        isCompleted: false,
        errorMessage: 'Download cancelled.',
        progress: DownloadProgress(
          downloadedBytes: completedCount,
          totalBytes: totalVideos,
          progress: completedCount / totalVideos,
          speedBytesPerSecond: 0,
          etaSeconds: 0,
          stage: 'Download cancelled ($completedCount/$totalVideos saved)',
        ),
      );
      _isCancelled = false;
      return;
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
      unawaited(DownloadNotificationService.complete(
        title: finalItem.title,
        statusText: '$completedCount tracks saved to Downloads/Music',
      ));
      unawaited(PlayUpdateService.recordSuccessfulAction());
      unawaited(PlayUpdateService.tryRequestReview());
    } else {
      unawaited(DownloadNotificationService.stop());
    }
  }

  void cancelDownload() {
    unawaited(DownloadNotificationService.stop());
    _isCancelled = true;
    _currentDownloader?.cancel();
    for (final d in _activeDownloaders.toList()) {
      try {
        d.cancel();
      } catch (_) {}
    }
    _activeDownloaders.clear();
    state = state.copyWith(
      isDownloading: false,
      isCompleted: false,
      errorMessage: 'Download cancelled.',
      progress: const DownloadProgress(
        downloadedBytes: 0,
        totalBytes: 0,
        progress: 0.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Download cancelled.',
      ),
    );
  }

  Future<OpenResult> openFile(String filePath) async {
    return await OpenFilex.open(filePath);
  }

  Future<void> shareFile(String filePath, String title) async {
    await MediaLauncher.shareFiles([filePath], text: title);
  }

  void reset() {
    state = const ActiveDownloadState();
  }
}

final downloadControllerProvider =
    NotifierProvider<DownloadController, ActiveDownloadState>(DownloadController.new);
