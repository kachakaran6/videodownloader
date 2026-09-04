import 'package:intl/intl.dart';

class Formatters {
  /// Formats byte count to human-readable string (e.g. 48.2 MB).
  static String formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Size unavailable';

    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(1)} GB';
    } else if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    } else if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }

  /// Formats duration (e.g. 03:45 or 01:22:15).
  static String formatDuration(Duration? duration) {
    if (duration == null || duration == Duration.zero) return '00:00';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hStr = hours.toString().padLeft(2, '0');
      return '$hStr:$mStr:$sStr';
    } else {
      return '$mStr:$sStr';
    }
  }

  /// Formats speed in bytes/sec to human readable (e.g. 4.8 MB/s).
  static String formatSpeed(double? bytesPerSecond) {
    if (bytesPerSecond == null || bytesPerSecond <= 0) return '0 KB/s';

    const kb = 1024.0;
    const mb = kb * 1024.0;

    if (bytesPerSecond >= mb) {
      return '${(bytesPerSecond / mb).toStringAsFixed(1)} MB/s';
    } else {
      return '${(bytesPerSecond / kb).toStringAsFixed(0)} KB/s';
    }
  }

  /// Formats ETA in seconds (e.g. 45s or 2m 15s).
  static String formatEta(int? seconds) {
    if (seconds == null || seconds <= 0) return '--';
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}m ${secs}s';
  }

  /// Formats date for history display.
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
