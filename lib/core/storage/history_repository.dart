import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/downloads/domain/download_item.dart';
import 'preferences_service.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return HistoryRepository(prefs);
});

final downloadHistoryProvider =
    NotifierProvider<DownloadHistoryNotifier, List<DownloadItem>>(() {
  return DownloadHistoryNotifier();
});

class DownloadHistoryNotifier extends Notifier<List<DownloadItem>> {
  @override
  List<DownloadItem> build() {
    final repo = ref.watch(historyRepositoryProvider);
    return repo.getHistory();
  }

  Future<void> saveItem(DownloadItem item) async {
    final repo = ref.read(historyRepositoryProvider);
    await repo.saveItem(item);
    state = repo.getHistory();
  }

  Future<void> deleteItem(String id, {bool deleteFile = true}) async {
    final repo = ref.read(historyRepositoryProvider);
    await repo.deleteItem(id, deleteFile: deleteFile);
    state = repo.getHistory();
  }

  Future<void> clearHistory({bool deleteFiles = false}) async {
    final repo = ref.read(historyRepositoryProvider);
    await repo.clearHistory(deleteFiles: deleteFiles);
    state = [];
  }

  void refresh() {
    final repo = ref.read(historyRepositoryProvider);
    state = repo.getHistory();
  }
}

class HistoryRepository {
  final SharedPreferences _prefs;
  static const _historyKey = 'media_saver_download_history';

  HistoryRepository(this._prefs);

  List<DownloadItem> getHistory() {
    final rawList = _prefs.getStringList(_historyKey) ?? [];
    return rawList.map((str) {
      try {
        final map = jsonDecode(str) as Map<String, dynamic>;
        return DownloadItem.fromJson(map);
      } catch (_) {
        return null;
      }
    }).whereType<DownloadItem>().toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveItem(DownloadItem item) async {
    final history = getHistory();
    final index = history.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      history[index] = item;
    } else {
      history.insert(0, item);
    }
    await _persist(history);
  }

  Future<void> deleteItem(String id, {bool deleteFile = true}) async {
    final history = getHistory();
    final item = history.firstWhere(
      (i) => i.id == id,
      orElse: () => throw Exception('Item not found'),
    );

    if (deleteFile && item.filePath.isNotEmpty) {
      try {
        final file = File(item.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    history.removeWhere((i) => i.id == id);
    await _persist(history);
  }

  Future<void> clearHistory({bool deleteFiles = false}) async {
    if (deleteFiles) {
      final history = getHistory();
      for (final item in history) {
        if (item.filePath.isNotEmpty) {
          try {
            final file = File(item.filePath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {}
        }
      }
    }
    await _prefs.remove(_historyKey);
  }

  Future<void> _persist(List<DownloadItem> history) async {
    final encoded = history.map((item) => jsonEncode(item.toJson())).toList();
    await _prefs.setStringList(_historyKey, encoded);
  }
}
