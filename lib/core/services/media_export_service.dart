import 'dart:io';
import 'package:flutter/services.dart';

class MediaExportService {
  MediaExportService._();

  static const _channel = MethodChannel('app.mediaurl.applicaiton/downloads');

  /// Exports a downloaded file to the public system "Downloads" directory on Android,
  /// triggering MediaStore registration and MediaScanner so it appears immediately
  /// in the device's native Downloads app, Files app, and Gallery.
  static Future<String?> exportToPublicDownloads({
    required String sourcePath,
    required String fileName,
    required String mimeType,
  }) async {
    if (!Platform.isAndroid) return sourcePath;
    try {
      final publicPath = await _channel.invokeMethod<String>('exportToPublicDownloads', {
        'sourcePath': sourcePath,
        'fileName': fileName,
        'mimeType': mimeType,
      });
      return (publicPath != null && publicPath.isNotEmpty) ? publicPath : sourcePath;
    } catch (_) {
      // Fallback gracefully to sourcePath if platform export is unavailable
      return sourcePath;
    }
  }

  /// Triggers a MediaStore scan so the file appears in the device's Gallery / Audio / Downloads.
  static Future<void> scanFile({
    required String filePath,
    required String mimeType,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('scanFile', {
        'filePath': filePath,
        'mimeType': mimeType,
      });
    } catch (_) {}
  }
}
