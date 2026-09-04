class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, [this.code]);

  @override
  String toString() => message;
}

class InvalidUrlException extends AppException {
  const InvalidUrlException([
    super.message = 'Please enter a valid YouTube video URL.',
    super.code = 'INVALID_URL',
  ]);
}

class PlaylistNotSupportedException extends AppException {
  const PlaylistNotSupportedException([
    super.message = 'Playlists are not supported in MVP. Please paste a single video link.',
    super.code = 'PLAYLIST_UNSUPPORTED',
  ]);
}

class VideoUnavailableException extends AppException {
  const VideoUnavailableException([
    super.message = 'This video is unavailable, private, or age-restricted.',
    super.code = 'VIDEO_UNAVAILABLE',
  ]);
}

class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Network connection failed. Please check your internet connection and try again.',
    super.code = 'NETWORK_ERROR',
  ]);
}

class StorageException extends AppException {
  const StorageException([
    super.message = 'Storage error: could not write file to device storage.',
    super.code = 'STORAGE_ERROR',
  ]);
}

class DownloadCancelledException extends AppException {
  const DownloadCancelledException([
    super.message = 'Download was cancelled.',
    super.code = 'DOWNLOAD_CANCELLED',
  ]);
}
