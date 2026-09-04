import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final shareReceiverServiceProvider = Provider<ShareReceiverService>((ref) {
  final service = ShareReceiverService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class ShareReceiverService {
  static const MethodChannel _channel = MethodChannel('app.mediaurl.applicaiton/share');

  final _shareStreamController = StreamController<String>.broadcast();
  Stream<String> get onShareReceived => _shareStreamController.stream;

  ShareReceiverService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShareReceived') {
        final text = call.arguments as String?;
        if (text != null && text.trim().isNotEmpty) {
          _shareStreamController.add(text.trim());
        }
      }
    });
  }

  /// Retrieves any shared text that was received upon cold launch
  Future<String?> getInitialSharedText() async {
    try {
      final initial = await _channel.invokeMethod<String>('getInitialSharedText');
      return initial;
    } catch (_) {
      return null;
    }
  }

  /// Clears stored shared text from native memory
  Future<void> clearSharedText() async {
    try {
      await _channel.invokeMethod('clearSharedText');
    } catch (_) {}
  }

  void dispose() {
    _shareStreamController.close();
  }
}
