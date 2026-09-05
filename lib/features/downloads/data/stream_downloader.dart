import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/services/media_muxer_service.dart';
import '../../../core/services/media_export_service.dart';
import '../../../core/utils/media_launcher.dart';

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
  final http.Client _httpClient;
  StreamSubscription<List<int>>? _subscription;
  IOSink? _sink;
  File? _activeFile;
  File? _tempVideoFile;
  File? _tempAudioFile;
  Timer? _watchdogTimer;
  bool _isCancelled = false;

  StreamDownloader({YoutubeExplode? yt, http.Client? httpClient})
      : _yt = yt ?? YoutubeExplode(),
        _httpClient = httpClient ?? http.Client();

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
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

  Future<File> _exportToPublicStorage(File file) async {
    if (!Platform.isAndroid) return file;
    try {
      final mime = MediaLauncher.getMimeType(file.path) ??
          (file.path.endsWith('.mp3') || file.path.endsWith('.m4a')
              ? 'audio/mpeg'
              : 'video/mp4');
      final exportedPath = await MediaExportService.exportToPublicDownloads(
        sourcePath: file.path,
        fileName: p.basename(file.path),
        mimeType: mime,
      );
      if (exportedPath != null && exportedPath.isNotEmpty && exportedPath != file.path) {
        final exportedFile = File(exportedPath);
        final exists = await MediaExportService.checkFileExists(exportedPath);
        if (exists) {
          // Public file confirmed in Downloads; delete private cache duplicate
          if (file.existsSync()) {
            try {
              file.deleteSync();
            } catch (_) {}
          }
          return exportedFile;
        }
      }
    } catch (_) {}
    return file;
  }

  static Future<String> getSafeDownloadDirectory() async {
    // Download and muxing MUST always execute inside the app's private sandbox.
    // This completely prevents Scoped Storage transport endpoint errors, file-lock issues,
    // and permission failures. The completed file is then reliably exported to public Downloads.
    if (Platform.isAndroid) {
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          if (!extDir.existsSync()) {
            extDir.createSync(recursive: true);
          }
          return extDir.path;
        }
      } catch (_) {}
    }

    final appDocs = await getApplicationDocumentsDirectory();
    if (!appDocs.existsSync()) {
      appDocs.createSync(recursive: true);
    }
    return appDocs.path;
  }

  static String sanitizeFileName(String title, String ext) {
    // 1. Remove emojis and unusual Unicode symbols that fail on FAT/MediaStore
    var clean = title.replaceAll(
      RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true),
      '',
    );
    // 2. Clean out illegal filesystem chars
    clean = clean.replaceAll(RegExp(r'[\\/*?:"<>|#]'), ' ').trim();
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');
    // 3. Truncate safely without splitting surrogate pairs
    if (clean.runes.length > 60) {
      clean = String.fromCharCodes(clean.runes.take(60)).trim();
    }
    // 4. Clean trailing periods or dashes
    clean = clean.replaceAll(RegExp(r'[\.\s\-_]+$'), '').trim();
    if (clean.isEmpty) {
      clean = 'video_${DateTime.now().millisecondsSinceEpoch}';
    }
    final cleanExt = ext.replaceAll('.', '').toLowerCase();
    return '$clean.$cleanExt';
  }

  Future<void> _pipeHttpStream({
    required String url,
    required File destinationFile,
    required String stage,
    required Stopwatch stopwatch,
    required void Function(DownloadProgress) onProgress,
  }) async {
    _activeFile = destinationFile;
    _sink = destinationFile.openWrite();

    final request = http.Request('GET', Uri.parse(url));
    request.headers.addAll({
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
      'Accept': '*/*',
    });

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _httpClient.send(request);
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        throw const NetworkException();
      }
      throw AppException('Failed to connect to media CDN: $e');
    }

    if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 206) {
      throw AppException(
        'Server returned HTTP status ${streamedResponse.statusCode} while downloading video.',
      );
    }

    final totalBytes = streamedResponse.contentLength ?? 0;
    var currentDownloaded = 0;
    var lastSampleTime = stopwatch.elapsedMilliseconds;
    var lastSampleBytes = 0;
    var lastChunkTime = stopwatch.elapsedMilliseconds;
    var currentSpeed = 0.0;

    final completer = Completer<void>();

    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isCancelled || completer.isCompleted) {
        timer.cancel();
        return;
      }
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed - lastChunkTime > 25000) {
        timer.cancel();
        _subscription?.cancel();
        try {
          _sink?.close();
        } catch (_) {}
        if (!completer.isCompleted) {
          completer.completeError(
            const AppException('Download stalled: CDN server stopped sending data. Please retry.'),
          );
        }
        return;
      }
      if (elapsed - lastChunkTime > 1500 && currentSpeed > 0) {
        currentSpeed = 0.0;
        final pct =
            totalBytes > 0 ? (currentDownloaded / totalBytes).clamp(0.0, 1.0) : 0.5;
        onProgress(DownloadProgress(
          downloadedBytes: currentDownloaded,
          totalBytes: totalBytes,
          progress: pct,
          speedBytesPerSecond: 0.0,
          etaSeconds: 0,
          stage: stage,
        ));
      }
    });

    _subscription = streamedResponse.stream.listen(
      (chunk) {
        if (_isCancelled) return;
        _sink?.add(chunk);
        currentDownloaded += chunk.length;
        lastChunkTime = stopwatch.elapsedMilliseconds;

        final elapsedMs = stopwatch.elapsedMilliseconds;
        if (elapsedMs - lastSampleTime >= 400) {
          final timeDeltaSec = (elapsedMs - lastSampleTime) / 1000.0;
          final bytesDelta = currentDownloaded - lastSampleBytes;
          if (timeDeltaSec > 0) {
            currentSpeed = bytesDelta / timeDeltaSec;
          }
          lastSampleTime = elapsedMs;
          lastSampleBytes = currentDownloaded;

          final pct =
              totalBytes > 0 ? (currentDownloaded / totalBytes).clamp(0.0, 1.0) : 0.5;

          var eta = 0;
          if (currentSpeed > 0 && totalBytes > currentDownloaded) {
            eta = ((totalBytes - currentDownloaded) / currentSpeed).round();
          }

          onProgress(DownloadProgress(
            downloadedBytes: currentDownloaded,
            totalBytes: totalBytes,
            progress: pct,
            speedBytesPerSecond: currentSpeed,
            etaSeconds: eta,
            stage: stage,
          ));
        }
      },
      onError: (error) {
        _watchdogTimer?.cancel();
        _watchdogTimer = null;
        _sink?.close();
        if (_isCancelled) {
          completer.completeError(const DownloadCancelledException());
        } else {
          completer.completeError(AppException('Download stream error: $error'));
        }
      },
      onDone: () async {
        _watchdogTimer?.cancel();
        _watchdogTimer = null;
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

    try {
      await completer.future;
    } finally {
      _watchdogTimer?.cancel();
      _watchdogTimer = null;
    }
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
    var lastChunkTime = stopwatch.elapsedMilliseconds;
    var currentSpeed = 0.0;

    final stream = _yt.videos.streamsClient.get(streamInfo);
    final completer = Completer<void>();

    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isCancelled || completer.isCompleted) {
        timer.cancel();
        return;
      }
      final elapsed = stopwatch.elapsedMilliseconds;
      // If no chunk has arrived for 25 seconds, report stall timeout
      if (elapsed - lastChunkTime > 25000) {
        timer.cancel();
        _subscription?.cancel();
        try {
          _sink?.close();
        } catch (_) {}
        if (!completer.isCompleted) {
          completer.completeError(
            const AppException('Download stalled: YouTube CDN stopped responding. Please retry.'),
          );
        }
        return;
      }
      // If data has paused for >1.5s, decay speed to 0.0 in UI so it doesn't appear frozen
      if (elapsed - lastChunkTime > 1500 && currentSpeed > 0) {
        currentSpeed = 0.0;
        final pct = grandTotalBytes > 0
            ? (currentDownloaded / grandTotalBytes).clamp(0.0, 1.0)
            : 0.5;
        onProgress(DownloadProgress(
          downloadedBytes: currentDownloaded,
          totalBytes: grandTotalBytes,
          progress: pct,
          speedBytesPerSecond: 0.0,
          etaSeconds: 0,
          stage: stage,
        ));
      }
    });

    _subscription = stream.listen(
      (chunk) {
        if (_isCancelled) return;
        _sink?.add(chunk);
        currentDownloaded += chunk.length;
        lastChunkTime = stopwatch.elapsedMilliseconds;

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
        _watchdogTimer?.cancel();
        _watchdogTimer = null;
        _sink?.close();
        if (_isCancelled) {
          completer.completeError(const DownloadCancelledException());
        } else {
          completer.completeError(AppException('Download stream error: $error'));
        }
      },
      onDone: () async {
        _watchdogTimer?.cancel();
        _watchdogTimer = null;
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

    try {
      await completer.future;
    } finally {
      _watchdogTimer?.cancel();
      _watchdogTimer = null;
    }
  }

  Future<File> downloadStream({
    StreamInfo? streamInfo,
    StreamInfo? audioStreamInfo,
    String? directUrl,
    required String title,
    String container = 'mp4',
    required void Function(DownloadProgress) onProgress,
  }) async {
    _isCancelled = false;
    final downloadDir = await getSafeDownloadDirectory();
    final ext = streamInfo?.container.name ?? container;
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

    // Direct CDN stream branch (e.g. Instagram Reels, Posts, Stories)
    if (directUrl != null) {
      final stopwatch = Stopwatch()..start();
      onProgress(DownloadProgress(
        downloadedBytes: 0,
        totalBytes: 0,
        progress: 0.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Connecting directly to CDN stream...',
      ));

      await _pipeHttpStream(
        url: directUrl,
        destinationFile: file,
        stage: 'Downloading media stream...',
        stopwatch: stopwatch,
        onProgress: onProgress,
      );

      final totalBytes = file.existsSync() ? file.lengthSync() : 0;
      file = await _exportToPublicStorage(file);
      onProgress(DownloadProgress(
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
        progress: 1.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Saved to Downloads folder!',
      ));
      return file;
    }

    if (streamInfo == null) {
      throw const AppException('No valid stream source provided for download.');
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

      file = await _exportToPublicStorage(file);
      onProgress(DownloadProgress(
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
        progress: 1.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Saved to Downloads folder!',
      ));
      return file;
    }

    // Case 2: Adaptive Video + Companion Audio
    final base = p.basenameWithoutExtension(finalPath);
    final tempVideoPath = p.join(downloadDir, '${base}_tmp_video.$ext');
    final tempAudioPath =
        p.join(downloadDir, '${base}_tmp_audio.${audioStreamInfo.container.name}');

    _tempVideoFile = File(tempVideoPath);
    _tempAudioFile = File(tempAudioPath);

    try {
      // Step A: Download Video Track
      await _pipeStream(
        streamInfo: streamInfo,
        destinationFile: _tempVideoFile!,
        initialBytes: 0,
        grandTotalBytes: totalBytes,
        stage:
            'Downloading video stream (${streamInfo.size.totalMegaBytes.toStringAsFixed(1)} MB)...',
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
        stage:
            'Downloading audio stream (${audioStreamInfo.size.totalMegaBytes.toStringAsFixed(1)} MB)...',
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
        // Fallback: If native muxing fails, move video track to final destination
        if (_tempVideoFile!.existsSync()) {
          final destFile = File(finalPath);
          if (destFile.existsSync()) {
            try {
              destFile.deleteSync();
            } catch (_) {}
          }
          try {
            _tempVideoFile!.renameSync(finalPath);
          } catch (_) {
            _tempVideoFile!.copySync(finalPath);
            try {
              _tempVideoFile!.deleteSync();
            } catch (_) {}
          }
          file = File(finalPath);
        }
      }

      if (!file.existsSync() || file.lengthSync() == 0) {
        throw const AppException('Failed to finalize video file. Please try downloading again.');
      }

      file = await _exportToPublicStorage(file);
      onProgress(DownloadProgress(
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
        progress: 1.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Saved to Downloads folder!',
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

  void close() {
    cancel();
    _yt.close();
    _httpClient.close();
  }
}
