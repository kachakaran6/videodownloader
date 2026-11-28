import '../../downloads/domain/download_item.dart';

/// Represents a download link or collection in the Library.
///
/// Can contain:
/// - A single downloaded file (e.g. 1 video from YouTube or Instagram).
/// - Multiple files downloaded from a single link (e.g. 50 tracks from a Spotify playlist/album, or multiple photos from a carousel).
class LibraryGroup {
  final String key;
  final String title;
  final String? thumbnailUrl;
  final String platform;
  final String? sourceUrl;
  final List<DownloadItem> items;
  final DateTime latestCreatedAt;

  const LibraryGroup({
    required this.key,
    required this.title,
    this.thumbnailUrl,
    required this.platform,
    this.sourceUrl,
    required this.items,
    required this.latestCreatedAt,
  });

  bool get isSingle => items.length == 1;
  DownloadItem get singleItem => items.first;
  int get totalSizeBytes => items.fold(0, (sum, i) => sum + i.fileSizeBytes);
  int get itemCount => items.length;

  bool get isSpotify => platform == 'spotify';
  bool get isInstagram => platform == 'instagram';
  bool get isFacebook => platform == 'facebook';
  bool get isYouTube => platform == 'youtube';

  String get categoryLabel {
    if (isSpotify) return 'Music';
    if (isFacebook) return 'Status';
    if (isInstagram) return 'Reels & Clips';
    return 'Video';
  }
}

/// Groups flat download items into structured link groups.
List<LibraryGroup> groupDownloadItems(List<DownloadItem> allItems) {
  final Map<String, List<DownloadItem>> bucketMap = {};

  for (final item in allItems) {
    String key;
    // 1. Explicit groupId if set
    if (item.groupId != null && item.groupId!.trim().isNotEmpty) {
      key = 'gid_${item.groupId!.trim()}';
    }
    // 2. Fallback: Spotify or media items with identical non-empty thumbnail
    else if (item.thumbnailUrl.trim().isNotEmpty && (item.isSpotify || item.isInstagram)) {
      key = 'thumb_${item.platform}_${item.thumbnailUrl.trim()}';
    }
    // 3. Fallback: sourceUrl
    else if (item.sourceUrl != null && item.sourceUrl!.trim().isNotEmpty) {
      key = 'src_${item.sourceUrl!.trim()}';
    }
    // 4. Default: single item
    else {
      key = 'single_${item.id}';
    }

    bucketMap.putIfAbsent(key, () => []).add(item);
  }

  final List<LibraryGroup> groups = [];
  for (final entry in bucketMap.entries) {
    final list = entry.value;
    if (list.isEmpty) continue;

    // Sort items within group
    list.sort((a, b) => a.title.compareTo(b.title));

    // Determine group title
    String groupTitle = '';
    for (final it in list) {
      if (it.groupTitle != null && it.groupTitle!.trim().isNotEmpty) {
        groupTitle = it.groupTitle!.trim();
        break;
      }
    }
    if (groupTitle.isEmpty) {
      if (list.length > 1 && list.first.isSpotify) {
        final firstAuthor = list.first.author;
        final allSameAuthor = list.every((i) => i.author == firstAuthor && firstAuthor.isNotEmpty);
        groupTitle = allSameAuthor
            ? '$firstAuthor Album (${list.length} Songs)'
            : 'Music Playlist (${list.length} Songs)';
      } else if (list.length > 1) {
        groupTitle = 'Collection (${list.length} Files)';
      } else {
        groupTitle = list.first.title;
      }
    }

    // Determine thumbnail
    String? thumb;
    for (final it in list) {
      if (it.groupThumbnailUrl != null && it.groupThumbnailUrl!.trim().isNotEmpty) {
        thumb = it.groupThumbnailUrl!.trim();
        break;
      }
      if (it.thumbnailUrl.trim().isNotEmpty) {
        thumb = it.thumbnailUrl.trim();
        break;
      }
    }

    // Determine sourceUrl
    String? srcUrl;
    for (final it in list) {
      if (it.sourceUrl != null && it.sourceUrl!.trim().isNotEmpty) {
        srcUrl = it.sourceUrl!.trim();
        break;
      }
    }

    // Latest createdAt
    DateTime latest = list.first.createdAt;
    for (final it in list) {
      if (it.createdAt.isAfter(latest)) {
        latest = it.createdAt;
      }
    }

    groups.add(LibraryGroup(
      key: entry.key,
      title: groupTitle,
      thumbnailUrl: thumb,
      platform: list.first.platform,
      sourceUrl: srcUrl,
      items: list,
      latestCreatedAt: latest,
    ));
  }

  return groups;
}
