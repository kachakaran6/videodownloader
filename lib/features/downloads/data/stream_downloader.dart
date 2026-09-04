import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../core/errors/app_exceptions.dart';

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

    // Delete incomplete file
    if (_activeFile != null && _activeFile!.existsSync()) {
      try {
        _activeFile!.deleteSync();
      } catch (_) {}
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

  Future<File> downloadStream({
    required StreamInfo streamInfo,
    required String title,
    required void Function(DownloadProgress) onProgress,
  }) async {
    _isCancelled = false;
    final downloadDir = await getSafeDownloadDirectory();
    final ext = streamInfo.container.name;
    final filename = sanitizeFileName(title, ext);
    final targetPath = p.join(downloadDir, filename);

    // If file with same name exists, append timestamp
    var finalPath = targetPath;
    var file = File(finalPath);
    if (file.existsSync()) {
      final base = p.basenameWithoutExtension(targetPath);
      final uniqueName = '${base}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      finalPath = p.join(downloadDir, uniqueName);
      file = File(finalPath);
    }

    _activeFile = file;
    _sink = file.openWrite();

    final totalBytes = streamInfo.size.totalBytes;
    var downloadedBytes = 0;

    final stopwatch = Stopwatch()..start();
    var lastSampleTime = 0;
    var lastSampleBytes = 0;
    var currentSpeed = 0.0;

    final completer = Completer<File>();

    try {
      final stream = _yt.videos.streamsClient.get(streamInfo);

      onProgress(DownloadProgress(
        downloadedBytes: 0,
        totalBytes: totalBytes,
        progress: 0.0,
        speedBytesPerSecond: 0,
        etaSeconds: 0,
        stage: 'Connecting to media stream...',
      ));

      _subscription = stream.listen(
        (chunk) {
          if (_isCancelled) return;

          _sink?.add(chunk);
          downloadedBytes += chunk.length;

          final elapsedMs = stopwatch.elapsedMilliseconds;
          if (elapsedMs - lastSampleTime >= 400) {
            final timeDeltaSec = (elapsedMs - lastSampleTime) / 1000.0;
            final bytesDelta = downloadedBytes - lastSampleBytes;
            if (timeDeltaSec > 0) {
              currentSpeed = bytesDelta / timeDeltaSec;
            }

            lastSampleTime = elapsedMs;
            lastSampleBytes = downloadedBytes;

            final pct = totalBytes > 0
                ? (downloadedBytes / totalBytes).clamp(0.0, 1.0)
                : 0.5;

            var eta = 0;
            if (currentSpeed > 0 && totalBytes > downloadedBytes) {
              eta = ((totalBytes - downloadedBytes) / currentSpeed).round();
            }

            onProgress(DownloadProgress(
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytes,
              progress: pct,
              speedBytesPerSecond: currentSpeed,
              etaSeconds: eta,
              stage: 'Downloading directly from source...',
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
            if (file.existsSync()) file.deleteSync();
            completer.completeError(const DownloadCancelledException());
          } else {
            onProgress(DownloadProgress(
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytes,
              progress: 1.0,
              speedBytesPerSecond: 0,
              etaSeconds: 0,
              stage: 'Saved successfully!',
            ));
            completer.complete(file);
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      _sink?.close();
      if (file.existsSync()) file.deleteSync();
      throw AppException('Failed to start download: $e');
    }

    return completer.future;
  }
}
