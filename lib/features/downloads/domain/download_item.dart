enum DownloadStatus {
  preparing,
  downloading,
  completed,
  failed,
  cancelled,
}

class DownloadItem {
  final String id;
  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final int durationSeconds;
  final String qualityLabel;
  final String filePath;
  final int fileSizeBytes;
  final DownloadStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final String platform; // 'youtube' | 'instagram'

  const DownloadItem({
    required this.id,
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.qualityLabel,
    required this.filePath,
    required this.fileSizeBytes,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
    this.platform = 'youtube',
  });

  bool get isInstagram => platform == 'instagram';
  bool get isYouTube => platform == 'youtube';
  bool get isSpotify => platform == 'spotify';

  bool get isImage {
    final path = filePath.toLowerCase();
    final q = qualityLabel.toLowerCase();
    final t = title.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        q.contains('photo') ||
        q.contains('jpg') ||
        q.contains('png') ||
        q.contains('image') ||
        t.contains('instagram photo');
  }

  bool get isAudio {
    if (isImage) return false;
    final path = filePath.toLowerCase();
    final q = qualityLabel.toLowerCase();
    return isSpotify ||
        path.endsWith('.mp3') ||
        path.endsWith('.m4a') ||
        path.endsWith('.aac') ||
        path.endsWith('.wav') ||
        path.endsWith('.opus') ||
        q.contains('audio') ||
        q.contains('kbps');
  }

  DownloadItem copyWith({
    String? id,
    String? videoId,
    String? title,
    String? author,
    String? thumbnailUrl,
    int? durationSeconds,
    String? qualityLabel,
    String? filePath,
    int? fileSizeBytes,
    DownloadStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? errorMessage,
    String? platform,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      author: author ?? this.author,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      qualityLabel: qualityLabel ?? this.qualityLabel,
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      platform: platform ?? this.platform,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoId': videoId,
      'title': title,
      'author': author,
      'thumbnailUrl': thumbnailUrl,
      'durationSeconds': durationSeconds,
      'qualityLabel': qualityLabel,
      'filePath': filePath,
      'fileSizeBytes': fileSizeBytes,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'errorMessage': errorMessage,
      'platform': platform,
    };
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] as String,
      videoId: json['videoId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      author: json['author'] as String? ?? 'Unknown',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      qualityLabel: json['qualityLabel'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.failed,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      errorMessage: json['errorMessage'] as String?,
      platform: json['platform'] as String? ?? 'youtube',
    );
  }
}
