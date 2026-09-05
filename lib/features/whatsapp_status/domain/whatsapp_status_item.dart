import '../../../core/utils/formatters.dart';

enum WhatsAppAppType {
  whatsapp,
  whatsappBusiness;

  String get displayName {
    switch (this) {
      case WhatsAppAppType.whatsapp:
        return 'WhatsApp';
      case WhatsAppAppType.whatsappBusiness:
        return 'WA Business';
    }
  }

  String get nativeKey {
    switch (this) {
      case WhatsAppAppType.whatsapp:
        return 'whatsapp';
      case WhatsAppAppType.whatsappBusiness:
        return 'whatsappBusiness';
    }
  }
}

enum StatusMediaTypeFilter {
  all,
  photos,
  videos;

  String get label {
    switch (this) {
      case StatusMediaTypeFilter.all:
        return 'All';
      case StatusMediaTypeFilter.photos:
        return 'Photos';
      case StatusMediaTypeFilter.videos:
        return 'Videos';
    }
  }
}

class WhatsAppStatusItem {
  final String path;
  final String fileName;
  final bool isVideo;
  final String? thumbnailPath;
  final int fileSize;
  final DateTime modifiedTime;
  final WhatsAppAppType sourceApp;
  final bool isSaved;

  const WhatsAppStatusItem({
    required this.path,
    required this.fileName,
    required this.isVideo,
    this.thumbnailPath,
    required this.fileSize,
    required this.modifiedTime,
    required this.sourceApp,
    this.isSaved = false,
  });

  bool get isImage => !isVideo;

  String get formattedSize => Formatters.formatBytes(fileSize);

  String get extension => fileName.split('.').last.toLowerCase();

  factory WhatsAppStatusItem.fromMap(Map<dynamic, dynamic> map) {
    final appTypeStr = (map['appType'] as String?)?.toLowerCase() ?? 'whatsapp';
    final appType = appTypeStr.contains('business')
        ? WhatsAppAppType.whatsappBusiness
        : WhatsAppAppType.whatsapp;

    final modifiedMs = (map['modifiedTime'] as num?)?.toInt() ?? 0;
    final modified = modifiedMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(modifiedMs)
        : DateTime.now();

    final thumb = map['thumbnailPath'] as String?;

    return WhatsAppStatusItem(
      path: map['path'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      isVideo: map['isVideo'] as bool? ?? false,
      thumbnailPath: (thumb != null && thumb.isNotEmpty) ? thumb : null,
      fileSize: (map['fileSize'] as num?)?.toInt() ?? 0,
      modifiedTime: modified,
      sourceApp: appType,
      isSaved: false,
    );
  }

  WhatsAppStatusItem copyWith({
    String? path,
    String? fileName,
    bool? isVideo,
    String? thumbnailPath,
    int? fileSize,
    DateTime? modifiedTime,
    WhatsAppAppType? sourceApp,
    bool? isSaved,
  }) {
    return WhatsAppStatusItem(
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      isVideo: isVideo ?? this.isVideo,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      fileSize: fileSize ?? this.fileSize,
      modifiedTime: modifiedTime ?? this.modifiedTime,
      sourceApp: sourceApp ?? this.sourceApp,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhatsAppStatusItem &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}
