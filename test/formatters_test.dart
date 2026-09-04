import 'package:flutter_test/flutter_test.dart';
import 'package:media_saver/core/utils/formatters.dart';

void main() {
  group('Formatters', () {
    test('formatBytes handles small, medium, and large values', () {
      expect(Formatters.formatBytes(null), equals('Size unavailable'));
      expect(Formatters.formatBytes(0), equals('Size unavailable'));
      expect(Formatters.formatBytes(500), equals('500 B'));
      expect(Formatters.formatBytes(1024), equals('1.0 KB'));
      expect(Formatters.formatBytes(15 * 1024 * 1024), equals('15.0 MB'));
      expect(Formatters.formatBytes((1.5 * 1024 * 1024 * 1024).round()), equals('1.5 GB'));
    });

    test('formatDuration formats MM:SS and HH:MM:SS', () {
      expect(Formatters.formatDuration(null), equals('00:00'));
      expect(Formatters.formatDuration(const Duration(seconds: 45)), equals('00:45'));
      expect(Formatters.formatDuration(const Duration(minutes: 3, seconds: 12)), equals('03:12'));
      expect(Formatters.formatDuration(const Duration(hours: 1, minutes: 23, seconds: 4)), equals('01:23:04'));
    });

    test('formatSpeed formats bytes per second', () {
      expect(Formatters.formatSpeed(null), equals('0 KB/s'));
      expect(Formatters.formatSpeed(512 * 1024), equals('512 KB/s'));
      expect(Formatters.formatSpeed(3.5 * 1024 * 1024), equals('3.5 MB/s'));
    });

    test('formatEta formats seconds into readable strings', () {
      expect(Formatters.formatEta(null), equals('--'));
      expect(Formatters.formatEta(0), equals('--'));
      expect(Formatters.formatEta(25), equals('25s'));
      expect(Formatters.formatEta(95), equals('1m 35s'));
    });
  });
}
