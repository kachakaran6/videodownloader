import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../features/whatsapp_status/presentation/widgets/app_video_player_view.dart';
import '../services/media_export_service.dart';

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
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return null;
    }
  }

  /// Locates the actual file on storage, checking the primary path, public Downloads, Movies, and fallback directories.
  static Future<File?> resolveExistingFile(String filePath) async {
    if (filePath.trim().isEmpty) return null;

    final primary = File(filePath);
    if (primary.existsSync() && primary.lengthSync() > 0) {
      return primary;
    }

    // Native storage existence check (bypasses Scoped Storage POSIX sandbox restrictions)
    if (await MediaExportService.checkFileExists(filePath)) {
      return primary;
    }

    final filename = p.basename(filePath);
    final cleanFilename = filename
        .replaceAll(RegExp(r'[\\/*?:"<>|#]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final candidates = {filename, cleanFilename}.toList();

    for (final name in candidates) {
      if (name.isEmpty) continue;

      // Fallback 1: Standard public Download directory (/storage/emulated/0/Download)
      try {
        final publicDownload = File(p.join('/storage/emulated/0/Download', name));
        if (publicDownload.existsSync() && publicDownload.lengthSync() > 0) {
          return publicDownload;
        }
        if (await MediaExportService.checkFileExists(publicDownload.path)) {
          return publicDownload;
        }
      } catch (_) {}

      // Fallback 2: Public Download / VideoDownloader subfolder
      try {
        final subFolder = File(p.join('/storage/emulated/0/Download/VideoDownloader', name));
        if (subFolder.existsSync() && subFolder.lengthSync() > 0) {
          return subFolder;
        }
        if (await MediaExportService.checkFileExists(subFolder.path)) {
          return subFolder;
        }
      } catch (_) {}

      // Fallback 3: Standard public Movies / VideoDownloader directory
      try {
        final moviesFile = File(p.join('/storage/emulated/0/Movies/VideoDownloader', name));
        if (moviesFile.existsSync() && moviesFile.lengthSync() > 0) {
          return moviesFile;
        }
        if (await MediaExportService.checkFileExists(moviesFile.path)) {
          return moviesFile;
        }
      } catch (_) {}

      // Fallback 4: App external storage directory
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final fallback = File(p.join(extDir.path, name));
          if (fallback.existsSync() && fallback.lengthSync() > 0) {
            return fallback;
          }
        }
      } catch (_) {}

      // Fallback 5: App documents directory
      try {
        final appDocs = await getApplicationDocumentsDirectory();
        final fallback = File(p.join(appDocs.path, name));
        if (fallback.existsSync() && fallback.lengthSync() > 0) {
          return fallback;
        }
      } catch (_) {}
    }

    // Fallback 6: If path starts with public storage, assume valid public path
    if (filePath.startsWith('/storage/emulated/0/Download') ||
        filePath.startsWith('/storage/emulated/0/Movies')) {
      return primary;
    }

    return null;
  }

  /// Safely opens a media file using the system default player with explicit MIME type.
  /// Uses in-app video player by default for videos, with fallback to system player.
  static Future<bool> openMedia(
    BuildContext context,
    String filePath, {
    String? title,
    bool preferInApp = true,
  }) async {
    final resolvedFile = await resolveExistingFile(filePath);
    final displayName = title != null && title.isNotEmpty
        ? title
        : p.basename(filePath);

    if (resolvedFile == null) {
      if (context.mounted) {
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
    final mimeType = getMimeType(actualPath) ?? 'video/mp4';

    // In-app video playback first
    if (preferInApp &&
        context.mounted &&
        (mimeType.startsWith('video/') ||
            actualPath.endsWith('.mp4') ||
            actualPath.endsWith('.mkv') ||
            actualPath.endsWith('.webm'))) {
      await AppVideoPlayerView.showModal(
        context,
        filePath: actualPath,
        title: displayName,
      );
      return true;
    }

    // On Android, use 100% native FileProvider Intent chooser for external player launching
    if (Platform.isAndroid) {
      final nativeOpened = await MediaExportService.openWithSystemPlayer(
        filePath: actualPath,
        mimeType: mimeType,
      );
      if (nativeOpened) {
        return true;
      }
    }

    // Fallback: OpenFilex with explicit MIME type
    var result = await OpenFilex.open(actualPath, type: mimeType);
    if (result.type == ResultType.done) {
      return true;
    }

    // Fallback: OpenFilex without explicit type
    result = await OpenFilex.open(actualPath);
    if (result.type == ResultType.done) {
      return true;
    }

    if (result.type != ResultType.done && context.mounted) {
      final isImage = mimeType.startsWith('image/');
      final isAudio = mimeType.startsWith('audio/');
      final errorMsg = isImage
          ? 'Could not open image viewer. Please install a gallery or photo viewer app.'
          : (isAudio
              ? 'Could not open music player. Please install an audio player.'
              : 'Could not open media player. Please install VLC, MX Player, or a video player.');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  errorMsg,
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

  /// Convenience fallback to open any file directly
  static Future<bool> openFile(String filePath, {BuildContext? context, String? title}) async {
    if (context != null) {
      return openMedia(context, filePath, title: title);
    }
    final file = await resolveExistingFile(filePath);
    final targetPath = file?.path ?? filePath;

    if (Platform.isAndroid) {
      final mime = getMimeType(targetPath) ?? '*/*';
      final opened = await MediaExportService.openWithSystemPlayer(
        filePath: targetPath,
        mimeType: mime,
      );
      if (opened) return true;
    }

    final res = await OpenFilex.open(targetPath);
    return res.type == ResultType.done;
  }

  /// Share multiple files via system share sheet with native FileProvider fallback
  static Future<void> shareFiles(List<String> filePaths, {String? text}) async {
    if (filePaths.isEmpty) return;

    final resolvedPaths = <String>[];
    for (final fp in filePaths) {
      final resolved = await resolveExistingFile(fp);
      if (resolved != null && resolved.existsSync()) {
        resolvedPaths.add(resolved.path);
      } else if (File(fp).existsSync()) {
        resolvedPaths.add(fp);
      } else if (fp.isNotEmpty) {
        resolvedPaths.add(fp);
      }
    }

    if (resolvedPaths.isEmpty) return;

    // On Android, use native Intent.ACTION_SEND via FileProvider for 100% reliability
    if (Platform.isAndroid && resolvedPaths.length == 1) {
      final single = resolvedPaths.first;
      final mime = getMimeType(single) ?? '*/*';
      final nativeSuccess = await MediaExportService.shareWithSystem(
        filePath: single,
        mimeType: mime,
        title: text,
      );
      if (nativeSuccess) return;
    }

    try {
      final xfiles = resolvedPaths.map((f) => XFile(f)).toList();
      // ignore: deprecated_member_use
      await Share.shareXFiles(xfiles, text: text);
    } catch (_) {
      if (Platform.isAndroid && resolvedPaths.isNotEmpty) {
        final single = resolvedPaths.first;
        final mime = getMimeType(single) ?? '*/*';
        await MediaExportService.shareWithSystem(
          filePath: single,
          mimeType: mime,
          title: text,
        );
      }
    }
  }
}
