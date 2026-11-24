import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/services/media_muxer_service.dart';
import '../../../core/services/media_export_service.dart';
import '../../../core/services/mp3_metadata_service.dart';
import '../../../core/utils/media_launcher.dart';

// ---------------------------------------------------------------------------
// DownloadProgress — extended with real-time speed (MB/s) and ETA
// ---------------------------------------------------------------------------
class DownloadProgress {
  final int downloadedBytes;
  final int totalBytes;
  final double progress; // 0.0 to 1.0
  final double speedBytesPerSecond;
  final int etaSeconds;
  final String stage;

  /// Convenience getter: speed in MB/s.
  double get speedMBps => speedBytesPerSecond / (1024 * 1024);

  const DownloadProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.progress,
    required this.speedBytesPerSecond,
    required this.etaSeconds,
    required this.stage,
  });
}

// ---------------------------------------------------------------------------
// StreamDownloader — multi-connection segmented download engine
// ---------------------------------------------------------------------------
class StreamDownloader {
  final YoutubeExplode _yt;
  final http.Client _httpClient;

  // Single-stream state (legacy path)
  StreamSubscription<List<int>>? _subscription;
  IOSink? _sink;
  File? _activeFile;
  File? _tempVideoFile;
  File? _tempAudioFile;
  Timer? _watchdogTimer;

  // Shared Dio instance for segmented downloads
  late final Dio _dio;

  bool _isCancelled = false;

  StreamDownloader({YoutubeExplode? yt, http.Client? httpClient})
      : _yt = yt ?? YoutubeExplode(),
        _httpClient = httpClient ?? http.Client() {
    _dio = _buildDio();
  }

  bool get isCancelled => _isCancelled;

  // ---------------------------------------------------------------------------
  // Dio configuration
  // ---------------------------------------------------------------------------
  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(minutes: 10),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Accept-Encoding': 'gzip, deflate, br',
          'Connection': 'keep-alive',
        },
        // 64 KB receive buffer equivalent (Dio uses receiveDataWhenStatusError)
        receiveDataWhenStatusError: false,
      ),
    );
    return dio;
  }

  // ---------------------------------------------------------------------------
  // Cancel — stop all ongoing downloads
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Public utility helpers
  // ---------------------------------------------------------------------------
  Future<File> _exportToPublicStorage(File file) async {
    if (!Platform.isAndroid) return file;
    try {
      final mime = MediaLauncher.getMimeType(file.path) ??
          (file.path.endsWith('.mp3')
              ? 'audio/mpeg'
              : (file.path.endsWith('.m4a') ? 'audio/mp4' : 'video/mp4'));
      final exportedPath = await MediaExportService.exportToPublicDownloads(
        sourcePath: file.path,
        fileName: p.basename(file.path),
        mimeType: mime,
      );
      if (exportedPath != null &&
          exportedPath.isNotEmpty &&
          exportedPath != file.path) {
        final exportedFile = File(exportedPath);
        final exists = await MediaExportService.checkFileExists(exportedPath);
        if (exists) {
          if (file.existsSync()) {
            try {
              file.deleteSync();
            } catch (_) {}
          }
          unawaited(MediaExportService.scanFile(
            filePath: exportedPath,
            mimeType: mime,
          ));
          return exportedFile;
        }
      }
    } catch (_) {}
    return file;
  }

  static void _validateDownloadedFile(File file, {bool isImage = false}) {
    if (!file.existsSync()) {
      throw const AppException('Downloaded file was not found on device.');
    }
    final len = file.lengthSync();
    final minBytes = isImage ? 5 * 1024 : 40 * 1024;
    if (len < minBytes) {
      try {
        file.deleteSync();
      } catch (_) {}
      throw AppException(
        'Downloaded file is incomplete or corrupted ($len bytes). Please try again.',
      );
    }
  }

  static Future<String> getSafeDownloadDirectory() async {
    if (Platform.isAndroid) {
      try {
        final publicDownload = Directory('/storage/emulated/0/Download/ClipVault');
        if (!publicDownload.existsSync()) {
          publicDownload.createSync(recursive: true);
        }
        return publicDownload.path;
      } catch (_) {}
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final clipDir = Directory(p.join(extDir.path, 'ClipVault'));
          if (!clipDir.existsSync()) {
            clipDir.createSync(recursive: true);
          }
          return clipDir.path;
        }
      } catch (_) {}
    }
    final appDocs = await getApplicationDocumentsDirectory();
    final clipDocs = Directory(p.join(appDocs.path, 'ClipVault'));
    if (!clipDocs.existsSync()) {
      clipDocs.createSync(recursive: true);
    }
    return clipDocs.path;
  }

  static String sanitizeFileName(String title, String ext) {
    var clean = title.replaceAll(
      RegExp(
          r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
          unicode: true),
      '',
    );
    clean = clean.replaceAll(RegExp(r'[\\/*?:"<>|#]'), ' ').trim();
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');
    if (clean.runes.length > 60) {
      clean = String.fromCharCodes(clean.runes.take(60)).trim();
    }
    final cleanExt = ext.replaceAll('.', '').toLowerCase();
    if (clean.isEmpty) {
      final isImg = cleanExt == 'jpg' ||
          cleanExt == 'jpeg' ||
          cleanExt == 'png' ||
          cleanExt == 'webp';
      final isAud = cleanExt == 'mp3' ||
          cleanExt == 'm4a' ||
          cleanExt == 'wav' ||
          cleanExt == 'aac' ||
          cleanExt == 'opus';
      final prefix = isImg ? 'photo' : (isAud ? 'audio' : 'video');
      clean = '${prefix}_${DateTime.now().millisecondsSinceEpoch}';
    }
    return '$clean.$cleanExt';
  }

  // ---------------------------------------------------------------------------
  // Resume sidecar helpers
  // ---------------------------------------------------------------------------

  /// Returns the sidecar File for [filePath].
  static File _sidecarFile(String filePath) => File('$filePath.progress');

  /// Reads the number of confirmed downloaded bytes from the sidecar.
  static int _readSidecar(String filePath) {
    final f = _sidecarFile(filePath);
    if (!f.existsSync()) return 0;
    try {
      return int.tryParse(f.readAsStringSync().trim()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Writes the confirmed downloaded byte count to the sidecar.
  static void _writeSidecar(String filePath, int bytes) {
    try {
      _sidecarFile(filePath).writeAsStringSync(bytes.toString());
    } catch (_) {}
  }

  /// Removes the sidecar once a download is complete.
  static void _deleteSidecar(String filePath) {
    try {
      final f = _sidecarFile(filePath);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // downloadWithSegments — the new multi-connection entry point
  // ---------------------------------------------------------------------------
  /// Downloads [url] into [destinationPath] using [segments] parallel HTTP Range
  /// requests (segmented download). Falls back to single-stream if the server
  /// does not advertise `Accept-Ranges: bytes`.
  ///
  /// Supports resuming via a `.progress` sidecar file when [allowResume] is
  /// true.
  Future<File> downloadWithSegments({
    required String url,
    required String destinationPath,
    required void Function(DownloadProgress) onProgress,
    int segments = 4,
    Map<String, String>? headers,
    bool allowResume = true,
  }) async {
    _isCancelled = false;
    final dest = File(destinationPath);
    _activeFile = dest;

    // --- 1. HEAD request to determine content length & range support ----------
    int contentLength = 0;
    bool supportsRanges = false;

    try {
      final headResp = await _dio.head<dynamic>(
        url,
        options: Options(
          headers: headers,
          followRedirects: true,
          validateStatus: (s) => s != null && s < 400,
        ),
      );
      final cl = headResp.headers.value('content-length');
      contentLength = int.tryParse(cl ?? '') ?? 0;
      final ar = headResp.headers.value('accept-ranges') ?? '';
      supportsRanges = ar.toLowerCase() == 'bytes' && contentLength > 0;
    } catch (_) {
      supportsRanges = false;
    }

    if (!supportsRanges || segments <= 1 || contentLength < 1024 * 256) {
      // Fall back to single-stream download
      return _downloadSingleDio(
        url: url,
        dest: dest,
        startByte: allowResume ? _readSidecar(destinationPath) : 0,
        totalBytes: contentLength,
        onProgress: onProgress,
        stage: 'Downloading media stream...',
        headers: headers,
      );
    }

    // --- 2. Segmented parallel download ---------------------------------------
    int optimalSegments = segments;
    if (contentLength > 0) {
      if (contentLength < 10 * 1024 * 1024) {
        optimalSegments = 2;
      } else if (contentLength <= 50 * 1024 * 1024) {
        optimalSegments = 4;
      } else {
        optimalSegments = 8;
      }
    }
    final clampedSegments = optimalSegments.clamp(2, 8);
    final chunkSize = (contentLength / clampedSegments).ceil();

    // Check for a partial resume — we resume per-chunk via sidecar
    final resumeBytes =
        allowResume ? _readSidecar(destinationPath) : 0;

    final chunkFiles = <File>[];
    final chunkTasks = <Future<void>>[];

    // Shared progress tracking with 250ms throttle
    final chunkDownloaded = List<int>.filled(clampedSegments, 0);
    Timer? progressTimer;
    var lastEmittedMs = 0;

    // 1-second speed window
    var speedWindowBytes = 0;
    var speedWindowStart = DateTime.now().millisecondsSinceEpoch;
    var currentSpeed = 0.0;

    void emitProgress(String stage) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastEmittedMs < 250) return;
      lastEmittedMs = now;

      final total =
          chunkDownloaded.fold<int>(0, (s, b) => s + b) + resumeBytes;
      final pct =
          contentLength > 0 ? (total / contentLength).clamp(0.0, 1.0) : 0.5;

      // Update speed every 1s window
      speedWindowBytes +=
          chunkDownloaded.fold<int>(0, (s, b) => s + b) - (total - resumeBytes);
      final elapsed = now - speedWindowStart;
      if (elapsed >= 1000) {
        currentSpeed = speedWindowBytes / (elapsed / 1000.0);
        speedWindowBytes = 0;
        speedWindowStart = now;
      }

      var eta = 0;
      if (currentSpeed > 0 && contentLength > total) {
        eta = ((contentLength - total) / currentSpeed).round();
      }

      onProgress(DownloadProgress(
        downloadedBytes: total,
        totalBytes: contentLength,
        progress: pct,
        speedBytesPerSecond: currentSpeed,
        etaSeconds: eta,
        stage: stage,
      ));
    }

    final tmpDir = p.dirname(destinationPath);

    for (int i = 0; i < clampedSegments; i++) {
      final startByte = i * chunkSize;
      final endByte = math.min((i + 1) * chunkSize - 1, contentLength - 1);

      // Skip already-downloaded range (coarse resume: skip full chunks only)
      if (allowResume && resumeBytes >= endByte + 1) {
        chunkDownloaded[i] = endByte - startByte + 1;
        final chunkPath = p.join(tmpDir, '_chunk_${i}_${p.basename(destinationPath)}');
        chunkFiles.add(File(chunkPath));
        chunkTasks.add(Future.value());
        continue;
      }

      final chunkPath =
          p.join(tmpDir, '_chunk_${i}_${p.basename(destinationPath)}');
      final chunkFile = File(chunkPath);
      chunkFiles.add(chunkFile);

      final chunkIndex = i;
      chunkTasks.add(_downloadChunk(
        url: url,
        dest: chunkFile,
        startByte: startByte,
        endByte: endByte,
        extraHeaders: headers,
        onChunkBytes: (bytes) {
          chunkDownloaded[chunkIndex] += bytes;
          emitProgress('Downloading (segment ${chunkIndex + 1}/$clampedSegments)...');
        },
      ));
    }

    // Throttled progress timer
    progressTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      emitProgress('Downloading in parallel...');
    });

    try {
      onProgress(DownloadProgress(
        downloadedBytes: resumeBytes,
        totalBytes: contentLength,
        progress: contentLength > 0 ? resumeBytes / contentLength : 0.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Starting segmented download ($clampedSegments connections)...',
      ));

      await Future.wait(chunkTasks);

      if (_isCancelled) {
        // Save how much we got for resume
        final done = chunkDownloaded.fold<int>(0, (s, b) => s + b) + resumeBytes;
        _writeSidecar(destinationPath, done);
        throw const DownloadCancelledException();
      }

      // --- 3. Merge chunks in order ------------------------------------------
      onProgress(DownloadProgress(
        downloadedBytes: contentLength,
        totalBytes: contentLength,
        progress: 0.99,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Merging segments...',
      ));

      final outSink = dest.openWrite();
      try {
        for (final chunk in chunkFiles) {
          if (chunk.existsSync()) {
            outSink.add(chunk.readAsBytesSync());
          }
        }
        await outSink.flush();
      } finally {
        await outSink.close();
      }
    } finally {
      progressTimer.cancel();
      // Clean up chunk temp files
      for (final chunk in chunkFiles) {
        try {
          if (chunk.existsSync()) chunk.deleteSync();
        } catch (_) {}
      }
    }

    _deleteSidecar(destinationPath);
    return dest;
  }

  // ---------------------------------------------------------------------------
  // _downloadChunk — downloads a single byte-range chunk via Dio
  // ---------------------------------------------------------------------------
  Future<void> _downloadChunk({
    required String url,
    required File dest,
    required int startByte,
    required int endByte,
    Map<String, String>? extraHeaders,
    required void Function(int bytes) onChunkBytes,
  }) async {
    final rangeHeader = 'bytes=$startByte-$endByte';
    final mergedHeaders = <String, String>{
      'Range': rangeHeader,
      ...?extraHeaders,
    };

    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: mergedHeaders,
          validateStatus: (s) => s == 206 || s == 200,
        ),
      );

      final sink = dest.openWrite();
      try {
        await for (final chunk in response.data!.stream) {
          if (_isCancelled) break;
          sink.add(chunk);
          onChunkBytes(chunk.length);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel || _isCancelled) return;
      throw AppException('Segment download failed: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // _downloadSingleDio — single-stream fallback using Dio (with resume)
  // ---------------------------------------------------------------------------
  Future<File> _downloadSingleDio({
    required String url,
    required File dest,
    required int startByte,
    required int totalBytes,
    required void Function(DownloadProgress) onProgress,
    required String stage,
    Map<String, String>? headers,
  }) async {
    IOSink? sink;
    var currentDownloaded = startByte;
    var lastEmitMs = 0;

    // 1-second speed window
    var speedWindowBytes = 0;
    var speedWindowStart = DateTime.now().millisecondsSinceEpoch;
    var currentSpeed = 0.0;

    final mergedHeaders = <String, String>{
      if (startByte > 0) 'Range': 'bytes=$startByte-',
      ...?headers,
    };

    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: mergedHeaders,
          validateStatus: (s) => s == 200 || s == 206,
        ),
      );

      sink = startByte > 0
          ? dest.openWrite(mode: FileMode.append)
          : dest.openWrite();

      await for (final chunk in response.data!.stream) {
        if (_isCancelled) break;
        sink.add(chunk);
        currentDownloaded += chunk.length;

        // Speed window
        speedWindowBytes += chunk.length;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - speedWindowStart >= 1000) {
          currentSpeed = speedWindowBytes / ((now - speedWindowStart) / 1000.0);
          speedWindowBytes = 0;
          speedWindowStart = now;
        }

        // Progress throttle: emit at most every 250ms
        if (now - lastEmitMs >= 250) {
          lastEmitMs = now;
          final pct = totalBytes > 0
              ? (currentDownloaded / totalBytes).clamp(0.0, 1.0)
              : 0.5;
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

          // Persist resume position every 250ms
          _writeSidecar(dest.path, currentDownloaded);
        }
      }

      await sink.flush();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel || _isCancelled) {
        throw const DownloadCancelledException();
      }
      throw AppException('Download failed: ${e.message}');
    } finally {
      await sink?.close();
    }

    if (_isCancelled) {
      _writeSidecar(dest.path, currentDownloaded);
      throw const DownloadCancelledException();
    }

    _deleteSidecar(dest.path);
    return dest;
  }

  // ---------------------------------------------------------------------------
  // _pipeHttpStream — legacy single-stream via http package (kept for backward
  // compat; used by older direct-URL code paths where Dio is not needed).
  // ---------------------------------------------------------------------------
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

    if (streamedResponse.statusCode != 200 &&
        streamedResponse.statusCode != 206) {
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
            const AppException(
                'Download stalled: CDN server stopped sending data. Please retry.'),
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
        if (elapsedMs - lastSampleTime >= 250) {
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

  // ---------------------------------------------------------------------------
  // _pipeStream — YouTube stream via youtube_explode_dart
  // ---------------------------------------------------------------------------
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
      if (elapsed - lastChunkTime > 25000) {
        timer.cancel();
        _subscription?.cancel();
        try {
          _sink?.close();
        } catch (_) {}
        if (!completer.isCompleted) {
          completer.completeError(
            const AppException(
                'Download stalled: CDN stopped responding. Please retry.'),
          );
        }
        return;
      }
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
        if (elapsedMs - lastSampleTime >= 250) {
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

  // ---------------------------------------------------------------------------
  // downloadStream — primary public method (unchanged signature)
  //
  // For direct-URL paths (Instagram, Facebook, audio CDN) it now attempts
  // segmented parallel download first, falling back to single-stream if the
  // server doesn't support ranges.
  // ---------------------------------------------------------------------------
  Future<File> downloadStream({
    StreamInfo? streamInfo,
    StreamInfo? audioStreamInfo,
    String? directUrl,
    required String title,
    String container = 'mp4',
    String platform = 'youtube',
    AudioMetadata? metadata,
    required void Function(DownloadProgress) onProgress,
  }) async {
    _isCancelled = false;
    final downloadDir = await getSafeDownloadDirectory();

    var ext = container.toLowerCase().replaceAll('.', '');
    if (streamInfo != null) {
      final sContainer = streamInfo.container.name.toLowerCase();
      if (streamInfo is AudioOnlyStreamInfo) {
        if (sContainer == 'mp4' || sContainer == 'm4a') {
          ext = 'm4a';
        } else if (sContainer == 'webm') {
          ext = 'webm';
        } else if (sContainer == 'mp3') {
          ext = 'mp3';
        } else {
          ext = 'm4a';
        }
      } else {
        ext = sContainer.isNotEmpty
            ? sContainer
            : container.toLowerCase().replaceAll('.', '');
      }
    } else if (directUrl != null) {
      ext = container.toLowerCase().replaceAll('.', '');
    }

    final filename = sanitizeFileName(title, ext);
    final targetPath = p.join(downloadDir, filename);

    var finalPath = targetPath;
    var file = File(finalPath);
    if (file.existsSync()) {
      final base = p.basenameWithoutExtension(targetPath);
      final uniqueName =
          '${base}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      finalPath = p.join(downloadDir, uniqueName);
      file = File(finalPath);
    }

    final isImage =
        ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp';

    // -------------------------------------------------------------------------
    // Direct CDN branch — try segmented first, fall back to single-stream
    // -------------------------------------------------------------------------
    if (directUrl != null) {
      final stopwatch = Stopwatch()..start();

      // Generic connecting stage (no brand names)
      final connectingStage = isImage
          ? 'Connecting to image CDN...'
          : 'Connecting to media CDN...';

      onProgress(DownloadProgress(
        downloadedBytes: 0,
        totalBytes: 0,
        progress: 0.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: connectingStage,
      ));

      try {
        // Try segmented download via Dio
        file = await downloadWithSegments(
          url: directUrl,
          destinationPath: finalPath,
          onProgress: onProgress,
          segments: 4,
          allowResume: true,
        );
      } catch (e) {
        if (_isCancelled) rethrow;
        // Fall back to legacy http single-stream
        final downloadStage = isImage
            ? 'Downloading photo...'
            : 'Downloading media stream...';
        file = File(finalPath);
        await _pipeHttpStream(
          url: directUrl,
          destinationFile: file,
          stage: downloadStage,
          stopwatch: stopwatch,
          onProgress: onProgress,
        );
      }

      // Embed metadata before export
      if (metadata != null && (ext == 'mp3' || ext == 'm4a')) {
        try {
          await Mp3MetadataService.writeMetadata(
            filePath: file.path,
            metadata: metadata,
          );
        } catch (_) {}
      }

      _validateDownloadedFile(file, isImage: isImage);
      final totalBytes = file.existsSync() ? file.lengthSync() : 0;
      file = await _exportToPublicStorage(file);

      // Generic saved stage (brand-free)
      final savedStage = isImage
          ? 'Saved photo to Gallery & Downloads!'
          : 'Saved to Downloads!';

      onProgress(DownloadProgress(
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
        progress: 1.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: savedStage,
      ));
      return file;
    }

    if (streamInfo == null) {
      throw const AppException(
          'No valid stream source provided for download.');
    }

    final totalBytes =
        streamInfo.size.totalBytes + (audioStreamInfo?.size.totalBytes ?? 0);
    final stopwatch = Stopwatch()..start();

    onProgress(DownloadProgress(
      downloadedBytes: 0,
      totalBytes: totalBytes,
      progress: 0.0,
      speedBytesPerSecond: 0,
      etaSeconds: 0,
      stage: 'Connecting to media CDN...',
    ));

    // -------------------------------------------------------------------------
    // Case 1: Single YouTube stream (pre-muxed or audio-only)
    // -------------------------------------------------------------------------
    if (audioStreamInfo == null) {
      await _pipeStream(
        streamInfo: streamInfo,
        destinationFile: file,
        initialBytes: 0,
        grandTotalBytes: totalBytes,
        stage: 'Downloading media stream...',
        stopwatch: stopwatch,
        onProgress: onProgress,
      );

      if (metadata != null && (ext == 'mp3' || ext == 'm4a')) {
        try {
          await Mp3MetadataService.writeMetadata(
            filePath: file.path,
            metadata: metadata,
          );
        } catch (_) {}
      }

      _validateDownloadedFile(file, isImage: isImage);
      file = await _exportToPublicStorage(file);
      onProgress(DownloadProgress(
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
        progress: 1.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Saved to Downloads!',
      ));
      return file;
    }

    // -------------------------------------------------------------------------
    // Case 2: Adaptive Video + Companion Audio — parallel download then mux
    // -------------------------------------------------------------------------
    final base = p.basenameWithoutExtension(finalPath);
    final tempVideoPath =
        p.join(downloadDir, '${base}_tmp_video.$ext');
    final tempAudioPath = p.join(
        downloadDir, '${base}_tmp_audio.${audioStreamInfo.container.name}');

    _tempVideoFile = File(tempVideoPath);
    _tempAudioFile = File(tempAudioPath);

    try {
      // Download video and audio tracks in parallel
      onProgress(DownloadProgress(
        downloadedBytes: 0,
        totalBytes: totalBytes,
        progress: 0.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Downloading video & audio in parallel...',
      ));

      // Shared progress accumulator for parallel streams
      var videoDone = 0;
      var audioDone = 0;
      final videoTotal = streamInfo.size.totalBytes;
      final audioTotal = audioStreamInfo.size.totalBytes;

      void parallelProgress(DownloadProgress p) {
        final combined = videoDone + audioDone;
        final pct = totalBytes > 0
            ? (combined / totalBytes).clamp(0.0, 1.0)
            : 0.5;
        onProgress(DownloadProgress(
          downloadedBytes: combined,
          totalBytes: totalBytes,
          progress: pct,
          speedBytesPerSecond: p.speedBytesPerSecond,
          etaSeconds: p.etaSeconds,
          stage: p.stage,
        ));
      }

      await Future.wait([
        () async {
          final sw = Stopwatch()..start();
          await _pipeStream(
            streamInfo: streamInfo,
            destinationFile: _tempVideoFile!,
            initialBytes: 0,
            grandTotalBytes: videoTotal,
            stage:
                'Downloading video (${streamInfo.size.totalMegaBytes.toStringAsFixed(1)} MB)...',
            stopwatch: sw,
            onProgress: (p) {
              videoDone = p.downloadedBytes;
              parallelProgress(p);
            },
          );
        }(),
        () async {
          final sw = Stopwatch()..start();
          await _pipeStream(
            streamInfo: audioStreamInfo,
            destinationFile: _tempAudioFile!,
            initialBytes: 0,
            grandTotalBytes: audioTotal,
            stage:
                'Downloading audio (${audioStreamInfo.size.totalMegaBytes.toStringAsFixed(1)} MB)...',
            stopwatch: sw,
            onProgress: (p) {
              audioDone = p.downloadedBytes;
              parallelProgress(p);
            },
          );
        }(),
      ]);

      if (_isCancelled) throw const DownloadCancelledException();

      // Mux
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

      // Clean up temp audio
      if (_tempAudioFile!.existsSync()) {
        try {
          _tempAudioFile!.deleteSync();
        } catch (_) {}
      }

      if (muxedFile != null && muxedFile.existsSync()) {
        if (_tempVideoFile!.existsSync()) {
          try {
            _tempVideoFile!.deleteSync();
          } catch (_) {}
        }
        file = muxedFile;
      } else {
        // Fallback: use video track only
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

      _validateDownloadedFile(file, isImage: false);
      file = await _exportToPublicStorage(file);
      onProgress(DownloadProgress(
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
        progress: 1.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Saved to Downloads!',
      ));

      return file;
    } catch (e) {
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

  // ---------------------------------------------------------------------------
  // close — dispose all resources
  // ---------------------------------------------------------------------------
  void close() {
    cancel();
    _yt.close();
    _httpClient.close();
    _dio.close(force: true);
  }
}
