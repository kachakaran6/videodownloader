import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/whatsapp_status_item.dart';

final whatsappStatusServiceProvider = Provider<WhatsAppStatusService>((ref) {
  return WhatsAppStatusService();
});

class WhatsAppStatusService {
  static const _channel = MethodChannel('app.mediaurl.applicaiton/whatsapp');

  /// Checks if media/storage permissions are granted
  Future<bool> checkPermissions() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('checkPermissions');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests runtime storage / media permissions from Android
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermissions');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Scans for statuses from WhatsApp and/or WhatsApp Business
  Future<List<WhatsAppStatusItem>> scanStatuses({String appType = 'all'}) async {
    if (!Platform.isAndroid) return [];

    try {
      final List<dynamic>? rawList = await _channel.invokeMethod<List<dynamic>>(
        'scanStatuses',
        {'appType': appType},
      );

      if (rawList != null && rawList.isNotEmpty) {
        final items = <WhatsAppStatusItem>[];
        for (final raw in rawList) {
          if (raw is Map) {
            final item = WhatsAppStatusItem.fromMap(raw);
            if (item.path.isNotEmpty) {
              final isSaved = await isStatusSaved(item.fileName, item.isVideo);
              items.add(item.copyWith(isSaved: isSaved));
            }
          }
        }
        return items;
      }
    } catch (_) {}

    // Fallback: Direct Dart file scanning of known standard paths
    return _scanDirectDartPaths(appType);
  }

  /// Fallback direct file scanner using dart:io Directory
  Future<List<WhatsAppStatusItem>> _scanDirectDartPaths(String appType) async {
    final items = <WhatsAppStatusItem>[];
    final visited = <String>{};

    final dirs = <MapEntry<String, WhatsAppAppType>>[];
    if (appType == 'all' || appType == 'whatsapp') {
      dirs.add(const MapEntry(
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
        WhatsAppAppType.whatsapp,
      ));
      dirs.add(const MapEntry(
        '/storage/emulated/0/WhatsApp/Media/.Statuses',
        WhatsAppAppType.whatsapp,
      ));
    }
    if (appType == 'all' || appType == 'whatsappBusiness') {
      dirs.add(const MapEntry(
        '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses',
        WhatsAppAppType.whatsappBusiness,
      ));
      dirs.add(const MapEntry(
        '/storage/emulated/0/WhatsApp Business/Media/.Statuses',
        WhatsAppAppType.whatsappBusiness,
      ));
    }

    for (final entry in dirs) {
      try {
        final dir = Directory(entry.key);
        if (await dir.exists()) {
          final entities = dir.listSync();
          for (final file in entities) {
            if (file is File) {
              final path = file.path;
              final name = path.split(Platform.pathSeparator).last;
              if (name.startsWith('.nomedia')) continue;
              final ext = name.split('.').last.toLowerCase();
              if (ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'mp4') {
                if (visited.add(path)) {
                  final stat = file.statSync();
                  final isSaved = await isStatusSaved(name, ext == 'mp4');
                  items.add(WhatsAppStatusItem(
                    path: path,
                    fileName: name,
                    isVideo: ext == 'mp4',
                    fileSize: stat.size,
                    modifiedTime: stat.modified,
                    sourceApp: entry.value,
                    isSaved: isSaved,
                  ));
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    items.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
    return items;
  }

  /// Saves a status to the user's Public Gallery & Downloads folder
  Future<String?> saveStatusMedia(WhatsAppStatusItem item) async {
    if (!Platform.isAndroid) return null;
    try {
      final savedPath = await _channel.invokeMethod<String>('saveStatusMedia', {
        'sourcePath': item.path,
        'fileName': item.fileName,
        'isVideo': item.isVideo,
      });
      return savedPath;
    } catch (_) {
      return null;
    }
  }

  /// Checks if this status is already saved in the user's Gallery / Downloads
  Future<bool> isStatusSaved(String fileName, bool isVideo) async {
    if (!Platform.isAndroid) return false;
    try {
      final saved = await _channel.invokeMethod<bool>('isStatusSaved', {
        'fileName': fileName,
        'isVideo': isVideo,
      });
      return saved ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if WhatsApp or WhatsApp Business is installed
  Future<bool> isWhatsAppInstalled(WhatsAppAppType appType) async {
    if (!Platform.isAndroid) return false;
    try {
      final installed = await _channel.invokeMethod<bool>('isWhatsAppInstalled', {
        'appType': appType.nativeKey,
      });
      return installed ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Launches WhatsApp or WhatsApp Business
  Future<bool> openWhatsApp(WhatsAppAppType appType) async {
    if (!Platform.isAndroid) return false;
    try {
      final opened = await _channel.invokeMethod<bool>('openWhatsAppApp', {
        'appType': appType.nativeKey,
      });
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if folder permission is already granted via direct access or SAF tree
  Future<bool> hasFolderPermission(WhatsAppAppType appType) async {
    if (!Platform.isAndroid) return true;
    try {
      final hasPerm = await _channel.invokeMethod<bool>('hasFolderPermission', {
        'appType': appType.nativeKey,
      });
      return hasPerm ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests folder access via Android Storage Access Framework (SAF)
  Future<bool> requestFolderPermission(WhatsAppAppType appType) async {
    if (!Platform.isAndroid) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('requestFolderPermission', {
        'appType': appType.nativeKey,
      });
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Shares status file via standard share sheet
  Future<void> shareStatus(WhatsAppStatusItem item) async {
    final xFile = XFile(item.path, mimeType: item.isVideo ? 'video/mp4' : 'image/jpeg');
    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [xFile],
      text: 'Saved with Video Downloader',
    );
  }
}
