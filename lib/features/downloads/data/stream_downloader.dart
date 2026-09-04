import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/services/media_muxer_service.dart';

class DownloadProgress {
  final int downloadedBytes;
  final int totalBytes;
  final double progress; // 0.0 to 1.0
  final double speedBytesPerSecond;
  final int etaSeconds;
  final String stage;

  const DownloadProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.progress,
    required this.speedBytesPerSecond,
    required this.etaSeconds,
    required this.stage,
  });
}

class StreamDownloader {
  final YoutubeExplode _yt;
  StreamSubscription<List<int>>? _subscription;
  IOSink? _sink;
  File? _activeFile;
  File? _tempVideoFile;
  File? _tempAudioFile;
  bool _isCancelled = false;

  StreamDownloader([YoutubeExplode? yt]) : _yt = yt ?? YoutubeExplode();

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
    _subscription?.cancel();
    _subscription = null;
    try {
      _sink?.flush();
      _sink?.close();
    } catch (_) {}
    _sink = null;

    // Delete incomplete files
    for (final f in [_activeFile, _tempVideoFile, _tempAudioFile]) {
      if (f != null && f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  }

  static Future<String> getSafeDownloadDirectory() async {
    // Attempt standard Android public Downloads folder
    if (Platform.isAndroid) {
      final publicDownloads = Directory('/storage/emulated/0/Download');
      if (publicDownloads.existsSync()) {
        return publicDownloads.path;
      }
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        return extDir.path;
      }
    }
    final appDocs = await getApplicationDocumentsDirectory();
    return appDocs.path;
  }

  static String sanitizeFileName(String title, String ext) {
    var safe = title.replaceAll(RegExp(r'[\\/*?:"<>|]'), '_').trim();
    safe = safe.replaceAll(RegExp(r'\s+'), ' ');
    if (safe.length > 70) {
      safe = safe.substring(0, 70).trim();
    }
    if (safe.isEmpty) safe = 'video_${DateTime.now().millisecondsSinceEpoch}';
    final cleanExt = ext.replaceAll('.', '').toLowerCase();
    return '$safe.$cleanExt';
  }

  Future<void> _pipeStream({
    required StreamInfo streamInfo,
    required File destinationFile,
    required int initialBytes,
    required int grandTotalBytes,
    required String stage,
    required Stopwatch stopwatch,
    required void Function(DownloadProgress) onProgress,
  }) async {
    _activeFile = destinationFile;
    _sink = destinationFile.openWrite();

    var currentDownloaded = initialBytes;
    var lastSampleTime = stopwatch.elapsedMilliseconds;
    var lastSampleBytes = initialBytes;
    var currentSpeed = 0.0;

    final stream = _yt.videos.streamsClient.get(streamInfo);
    final completer = Completer<void>();

    _subscription = stream.listen(
      (chunk) {
        if (_isCancelled) return;
        _sink?.add(chunk);
        currentDownloaded += chunk.length;

        final elapsedMs = stopwatch.elapsedMilliseconds;
        if (elapsedMs - lastSampleTime >= 400) {
          final timeDeltaSec = (elapsedMs - lastSampleTime) / 1000.0;
          final bytesDelta = currentDownloaded - lastSampleBytes;
          if (timeDeltaSec > 0) {
            currentSpeed = bytesDelta / timeDeltaSec;
          }
          lastSampleTime = elapsedMs;
          lastSampleBytes = currentDownloaded;

          final pct = grandTotalBytes > 0
              ? (currentDownloaded / grandTotalBytes).clamp(0.0, 1.0)
              : 0.5;

          var eta = 0;
          if (currentSpeed > 0 && grandTotalBytes > currentDownloaded) {
            eta = ((grandTotalBytes - currentDownloaded) / currentSpeed).round();
          }

          onProgress(DownloadProgress(
            downloadedBytes: currentDownloaded,
            totalBytes: grandTotalBytes,
            progress: pct,
            speedBytesPerSecond: currentSpeed,
            etaSeconds: eta,
            stage: stage,
          ));
        }
      },
      onError: (error) {
        _sink?.close();
        if (_isCancelled) {
          completer.completeError(const DownloadCancelledException());
        } else {
          completer.completeError(AppException('Download stream error: $error'));
        }
      },
      onDone: () async {
        await _sink?.flush();
        await _sink?.close();
        _sink = null;
        if (_isCancelled) {
          completer.completeError(const DownloadCancelledException());
        } else {
          completer.complete();
        }
      },
      cancelOnError: true,
    );

    await completer.future;
  }

  Future<File> downloadStream({
    required StreamInfo streamInfo,
    StreamInfo? audioStreamInfo,
    required String title,
    required void Function(DownloadProgress) onProgress,
  }) async {
    _isCancelled = false;
    final downloadDir = await getSafeDownloadDirectory();
    final ext = streamInfo.container.name;
    final filename = sanitizeFileName(title, ext);
    final targetPath = p.join(downloadDir, filename);

    var finalPath = targetPath;
    var file = File(finalPath);
    if (file.existsSync()) {
      final base = p.basenameWithoutExtension(targetPath);
      final uniqueName = '${base}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      finalPath = p.join(downloadDir, uniqueName);
      file = File(finalPath);
    }

    final totalBytes = streamInfo.size.totalBytes + (audioStreamInfo?.size.totalBytes ?? 0);
    final stopwatch = Stopwatch()..start();

    onProgress(DownloadProgress(
      downloadedBytes: 0,
      totalBytes: totalBytes,
      progress: 0.0,
      speedBytesPerSecond: 0,
      etaSeconds: 0,
      stage: 'Connecting to YouTube CDN...',
    ));

    // Case 1: Single stream (Pre-muxed video+audio or Audio-only)
    if (audioStreamInfo == null) {
      await _pipeStream(
        streamInfo: streamInfo,
        destinationFile: file,
        initialBytes: 0,
        grandTotalBytes: totalBytes,
        stage: 'Downloading directly from source...',
        stopwatch: stopwatch,
        onProgress: onProgress,
      );

      onProgress(DownloadProgress(
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
        progress: 1.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Saved successfully!',
      ));
      return file;
    }

    // Case 2: Adaptive Video + Companion Audio
    final base = p.basenameWithoutExtension(finalPath);
    final tempVideoPath = p.join(downloadDir, '${base}_tmp_video.$ext');
    final tempAudioPath = p.join(downloadDir, '${base}_tmp_audio.${audioStreamInfo.container.name}');

    _tempVideoFile = File(tempVideoPath);
    _tempAudioFile = File(tempAudioPath);

    try {
      // Step A: Download Video Track
      await _pipeStream(
        streamInfo: streamInfo,
        destinationFile: _tempVideoFile!,
        initialBytes: 0,
        grandTotalBytes: totalBytes,
        stage: 'Downloading video stream (${streamInfo.size.totalMegaBytes.toStringAsFixed(1)} MB)...',
        stopwatch: stopwatch,
        onProgress: onProgress,
      );

      if (_isCancelled) throw const DownloadCancelledException();

      // Step B: Download Audio Track
      final videoBytesDone = streamInfo.size.totalBytes;
      await _pipeStream(
        streamInfo: audioStreamInfo,
        destinationFile: _tempAudioFile!,
        initialBytes: videoBytesDone,
        grandTotalBytes: totalBytes,
        stage: 'Downloading audio stream (${audioStreamInfo.size.totalMegaBytes.toStringAsFixed(1)} MB)...',
        stopwatch: stopwatch,
        onProgress: onProgress,
      );

      if (_isCancelled) throw const DownloadCancelledException();

      // Step C: Mux Video + Audio
      onProgress(DownloadProgress(
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
        progress: 0.98,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Combining video & audio with native muxer...',
      ));

      final muxedFile = await MediaMuxerService.muxMedia(
        videoPath: _tempVideoFile!.path,
        audioPath: _tempAudioFile!.path,
        outputPath: finalPath,
      );

      // Clean up temporary audio file
      if (_tempAudioFile!.existsSync()) {
        try {
          _tempAudioFile!.deleteSync();
        } catch (_) {}
      }

      if (muxedFile != null && muxedFile.existsSync()) {
        // Clean up temporary video file
        if (_tempVideoFile!.existsSync()) {
          try {
            _tempVideoFile!.deleteSync();
          } catch (_) {}
        }
        file = muxedFile;
      } else {
        // Fallback: If native muxing fails, rename video track to final destination
        if (_tempVideoFile!.existsSync()) {
          _tempVideoFile!.renameSync(finalPath);
          file = File(finalPath);
        }
      }

      onProgress(DownloadProgress(
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
        progress: 1.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Saved successfully!',
      ));

      return file;
    } catch (e) {
      // Clean up on error
      if (_tempVideoFile?.existsSync() ?? false) {
        try {
          _tempVideoFile!.deleteSync();
        } catch (_) {}
      }
      if (_tempAudioFile?.existsSync() ?? false) {
        try {
          _tempAudioFile!.deleteSync();
        } catch (_) {}
      }
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
      rethrow;
    }
  }
}
