import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../data/stream_downloader.dart';
import '../domain/download_item.dart';
import '../../inspect/data/video_inspector.dart';
import '../../../core/storage/history_repository.dart';

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
  }) async {
    final historyRepo = ref.read(historyRepositoryProvider);
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
      platform: video.isInstagram ? 'instagram' : 'youtube',
    );

    state = ActiveDownloadState(
      item: initialItem,
      isDownloading: true,
      progress: DownloadProgress(
        downloadedBytes: 0,
        totalBytes: option.fileSizeBytes ?? 0,
        progress: 0.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: video.isInstagram
            ? 'Connecting to Instagram CDN...'
            : 'Connecting to YouTube CDN...',
      ),
    );

    await historyRepo.saveItem(initialItem);

    final downloader = StreamDownloader();
    _currentDownloader = downloader;

    try {
      final savedFile = await downloader.downloadStream(
        streamInfo: option.streamInfo,
        audioStreamInfo: option.audioStreamInfo,
        directUrl: option.directUrl,
        container: option.container,
        title: video.title,
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

      await historyRepo.saveItem(completedItem);
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
        await historyRepo.saveItem(cancelledItem);
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
        await historyRepo.saveItem(failedItem);
      }
    } finally {
      _currentDownloader?.close();
      _currentDownloader = null;
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
