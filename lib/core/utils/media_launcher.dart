import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaLauncher {
  MediaLauncher._();

  /// Maps standard media extensions to MIME types
  static String? getMimeType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    switch (ext) {
      case '.mp4':
        return 'video/mp4';
      case '.mkv':
        return 'video/x-matroska';
      case '.webm':
        return 'video/webm';
      case '.3gp':
        return 'video/3gpp';
      case '.mov':
        return 'video/quicktime';
      case '.mp3':
        return 'audio/mpeg';
      case '.m4a':
        return 'audio/mp4';
      case '.aac':
        return 'audio/aac';
      case '.wav':
        return 'audio/wav';
      case '.ogg':
      case '.opus':
        return 'audio/ogg';
      default:
        return null;
    }
  }

  /// Locates the actual file on storage, checking the primary path and fallback directories.
  static Future<File?> resolveExistingFile(String filePath) async {
    if (filePath.trim().isEmpty) return null;

    final primary = File(filePath);
    if (primary.existsSync() && primary.lengthSync() > 0) {
      return primary;
    }

    final filename = p.basename(filePath);

    // Fallback 1: App external storage directory
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final fallback = File(p.join(extDir.path, filename));
        if (fallback.existsSync() && fallback.lengthSync() > 0) {
          return fallback;
        }
      }
    } catch (_) {}

    // Fallback 2: App documents directory
    try {
      final appDocs = await getApplicationDocumentsDirectory();
      final fallback = File(p.join(appDocs.path, filename));
      if (fallback.existsSync() && fallback.lengthSync() > 0) {
        return fallback;
      }
    } catch (_) {}

    // Fallback 3: Standard public Download directory
    try {
      final publicDownload = File(p.join('/storage/emulated/0/Download', filename));
      if (publicDownload.existsSync() && publicDownload.lengthSync() > 0) {
        return publicDownload;
      }
    } catch (_) {}

    return null;
  }

  /// Safely opens a media file using the system default player with explicit MIME type.
  /// Shows clear SnackBar feedback if file is missing or no player is available.
  static Future<bool> openMedia(
    BuildContext context,
    String filePath, {
    String? title,
  }) async {
    final resolvedFile = await resolveExistingFile(filePath);

    if (resolvedFile == null) {
      if (context.mounted) {
        final displayName = title != null && title.isNotEmpty
            ? title
            : p.basename(filePath);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'File not found on device: "$displayName". It may have been deleted or moved. Please re-download.',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
 ),
 ],
 ),
 backgroundColor: Colors.redAccent.shade700,
 behavior: SnackBarBehavior.floating,
 duration: const Duration(seconds: 4),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 );
 }
 return false;
 }

 final actualPath = resolvedFile.path;
 final mimeType = getMimeType(actualPath);

 // Attempt 1: Open with explicit MIME type for exact player routing (VLC, Photos, MX Player)
 var result = await OpenFilex.open(actualPath, type: mimeType);

 // Attempt 2: If failed, fallback without explicit type (let system guess by extension)
 if (result.type != ResultType.done) {
 result = await OpenFilex.open(actualPath);
 }

 if (result.type != ResultType.done && context.mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Row(
 children: [
 const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 'Could not open media player (). Please install VLC or a video player.',
 style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
 ),
 ),
 ],
 ),
 backgroundColor: Colors.orange.shade800,
 behavior: SnackBarBehavior.floating,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 );
 return false;
 }

 return true;
 }
}
