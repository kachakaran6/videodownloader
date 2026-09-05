import 'package:flutter_test/flutter_test.dart';
import 'package:media_saver/features/whatsapp_status/domain/whatsapp_status_item.dart';

void main() {
  group('WhatsAppStatusItem Model Tests', () {
    test('Correctly maps from Map with video and thumbnailPath', () {
      final map = {
        'path': '/storage/emulated/0/WhatsApp/Media/.Statuses/test_video.mp4',
        'fileName': 'test_video.mp4',
        'isVideo': true,
        'thumbnailPath': '/cache/whatsapp_thumbs/thumb_123.jpg',
        'fileSize': 1024 * 1024 * 5, // 5 MB
        'modifiedTime': 1700000000000,
        'appType': 'whatsapp',
      };

      final item = WhatsAppStatusItem.fromMap(map);

      expect(item.path, '/storage/emulated/0/WhatsApp/Media/.Statuses/test_video.mp4');
      expect(item.fileName, 'test_video.mp4');
      expect(item.isVideo, isTrue);
      expect(item.isImage, isFalse);
      expect(item.thumbnailPath, '/cache/whatsapp_thumbs/thumb_123.jpg');
      expect(item.sourceApp, WhatsAppAppType.whatsapp);
      expect(item.formattedSize, '5.0 MB');
      expect(item.extension, 'mp4');
    });

    test('Correctly maps photo item with null thumbnailPath', () {
      final map = {
        'path': '/storage/emulated/0/WhatsApp/Media/.Statuses/test_image.jpg',
        'fileName': 'test_image.jpg',
        'isVideo': false,
        'fileSize': 1024 * 500, // 500 KB
        'modifiedTime': 1700000000000,
        'appType': 'whatsappBusiness',
      };

      final item = WhatsAppStatusItem.fromMap(map);

      expect(item.isVideo, isFalse);
      expect(item.isImage, isTrue);
      expect(item.thumbnailPath, isNull);
      expect(item.sourceApp, WhatsAppAppType.whatsappBusiness);
      expect(item.extension, 'jpg');
    });

    test('copyWith updates thumbnailPath and isSaved properly', () {
      final item = WhatsAppStatusItem(
        path: '/path/video.mp4',
        fileName: 'video.mp4',
        isVideo: true,
        fileSize: 2048,
        modifiedTime: DateTime.now(),
        sourceApp: WhatsAppAppType.whatsapp,
      );

      expect(item.thumbnailPath, isNull);
      expect(item.isSaved, isFalse);

      final updated = item.copyWith(
        thumbnailPath: '/path/thumb.jpg',
        isSaved: true,
      );

      expect(updated.thumbnailPath, '/path/thumb.jpg');
      expect(updated.isSaved, isTrue);
      expect(updated.fileName, item.fileName);
    });

    test('StatusMediaTypeFilter labels and filtering behavior', () {
      expect(StatusMediaTypeFilter.all.label, 'All');
      expect(StatusMediaTypeFilter.photos.label, 'Photos');
      expect(StatusMediaTypeFilter.videos.label, 'Videos');

      final photo = WhatsAppStatusItem(
        path: '/img.jpg',
        fileName: 'img.jpg',
        isVideo: false,
        fileSize: 100,
        modifiedTime: DateTime.now(),
        sourceApp: WhatsAppAppType.whatsapp,
      );

      final video = WhatsAppStatusItem(
        path: '/vid.mp4',
        fileName: 'vid.mp4',
        isVideo: true,
        fileSize: 200,
        modifiedTime: DateTime.now(),
        sourceApp: WhatsAppAppType.whatsapp,
      );

      final list = [photo, video];

      expect(list.where((i) => i.isImage).length, 1);
      expect(list.where((i) => i.isVideo).length, 1);
      expect(list.where((i) => i.isImage).first.fileName, 'img.jpg');
      expect(list.where((i) => i.isVideo).first.fileName, 'vid.mp4');
    });
  });
}
