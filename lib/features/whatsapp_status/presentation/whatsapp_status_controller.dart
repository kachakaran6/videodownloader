import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/whatsapp_status_service.dart';
import '../domain/whatsapp_status_item.dart';

class WhatsAppStatusState {
  final List<WhatsAppStatusItem> items;
  final bool isLoading;
  final String? errorMessage;
  final WhatsAppAppType selectedApp;
  final StatusMediaTypeFilter selectedMediaType;
  final bool hasPermission;
  final bool needsFolderPermission;
  final bool isAppInstalled;
  final bool isSavingAll;
  final Set<String> savingPaths;
  final Set<String> savedPaths;

  const WhatsAppStatusState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedApp = WhatsAppAppType.whatsapp,
    this.selectedMediaType = StatusMediaTypeFilter.all,
    this.hasPermission = true,
    this.needsFolderPermission = false,
    this.isAppInstalled = true,
    this.isSavingAll = false,
    this.savingPaths = const {},
    this.savedPaths = const {},
  });

  List<WhatsAppStatusItem> get filteredItems {
    return items.where((item) {
      if (item.sourceApp != selectedApp) return false;
      switch (selectedMediaType) {
        case StatusMediaTypeFilter.all:
          return true;
        case StatusMediaTypeFilter.photos:
          return item.isImage;
        case StatusMediaTypeFilter.videos:
          return item.isVideo;
      }
    }).toList();
  }

  int countForApp(WhatsAppAppType app) {
    return items.where((i) => i.sourceApp == app).length;
  }

  WhatsAppStatusState copyWith({
    List<WhatsAppStatusItem>? items,
    bool? isLoading,
    String? errorMessage,
    WhatsAppAppType? selectedApp,
    StatusMediaTypeFilter? selectedMediaType,
    bool? hasPermission,
    bool? needsFolderPermission,
    bool? isAppInstalled,
    bool? isSavingAll,
    Set<String>? savingPaths,
    Set<String>? savedPaths,
  }) {
    return WhatsAppStatusState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedApp: selectedApp ?? this.selectedApp,
      selectedMediaType: selectedMediaType ?? this.selectedMediaType,
      hasPermission: hasPermission ?? this.hasPermission,
      needsFolderPermission: needsFolderPermission ?? this.needsFolderPermission,
      isAppInstalled: isAppInstalled ?? this.isAppInstalled,
      isSavingAll: isSavingAll ?? this.isSavingAll,
      savingPaths: savingPaths ?? this.savingPaths,
      savedPaths: savedPaths ?? this.savedPaths,
    );
  }
}

final whatsappStatusControllerProvider =
    NotifierProvider<WhatsAppStatusController, WhatsAppStatusState>(
  WhatsAppStatusController.new,
);

class WhatsAppStatusController extends Notifier<WhatsAppStatusState> {
  WhatsAppStatusService get _service => ref.read(whatsappStatusServiceProvider);

  @override
  WhatsAppStatusState build() {
    return const WhatsAppStatusState();
  }

  Future<void> loadStatuses({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      final hasPerm = await _service.checkPermissions();
      if (!hasPerm) {
        state = state.copyWith(
          isLoading: false,
          hasPermission: false,
        );
        return;
      }

      // Always attempt scanning all known directories & persisted SAF trees
      final items = await _service.scanStatuses(appType: 'all');
      final currentSaved = Set<String>.from(state.savedPaths);
      for (final item in items) {
        if (item.isSaved) {
          currentSaved.add(item.path);
        }
      }

      final hasFolder = await _service.hasFolderPermission(state.selectedApp);
      final hasItemsForSelectedApp = items.any((i) => i.sourceApp == state.selectedApp);
      final isInstalled = await _service.isWhatsAppInstalled(state.selectedApp);

      // App is definitively installed if items exist, folder permission is granted, or package is installed
      final effectiveInstalled = isInstalled || hasItemsForSelectedApp || hasFolder;

      // Only prompt for folder permission if app is installed, but folder is not accessible and 0 items found
      final needsFolder = effectiveInstalled && !hasFolder && !hasItemsForSelectedApp;

      state = state.copyWith(
        items: items,
        isLoading: false,
        hasPermission: true,
        needsFolderPermission: needsFolder,
        isAppInstalled: effectiveInstalled,
        errorMessage: null,
        savedPaths: currentSaved,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load statuses: $e',
      );
    }
  }

  Future<int> saveAllStatuses() async {
    final toSave = state.filteredItems
        .where((item) => !state.savedPaths.contains(item.path) && !item.isSaved)
        .toList();
    if (toSave.isEmpty) return 0;

    state = state.copyWith(isSavingAll: true);
    int savedCount = 0;
    for (final item in toSave) {
      final success = await saveStatus(item);
      if (success) savedCount++;
    }
    state = state.copyWith(isSavingAll: false);
    return savedCount;
  }

  Future<bool> requestPermission() async {
    state = state.copyWith(isLoading: true);
    final granted = await _service.requestPermissions();
    if (granted) {
      state = state.copyWith(hasPermission: true);
      await loadStatuses(showLoading: false);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        hasPermission: false,
        errorMessage: 'Storage permission is required to view and save WhatsApp statuses.',
      );
      return false;
    }
  }

  Future<bool> requestFolderPermission() async {
    state = state.copyWith(isLoading: true);
    final granted = await _service.requestFolderPermission(state.selectedApp);
    if (granted) {
      state = state.copyWith(needsFolderPermission: false);
      await loadStatuses(showLoading: false);
      return true;
    } else {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  void setApp(WhatsAppAppType app) async {
    if (state.selectedApp != app) {
      state = state.copyWith(selectedApp: app);
      await loadStatuses(showLoading: false);
    }
  }

  void setMediaType(StatusMediaTypeFilter filter) {
    if (state.selectedMediaType != filter) {
      state = state.copyWith(selectedMediaType: filter);
    }
  }

  Future<bool> saveStatus(WhatsAppStatusItem item) async {
    if (state.savingPaths.contains(item.path)) return false;

    final updatedSaving = Set<String>.from(state.savingPaths)..add(item.path);
    state = state.copyWith(savingPaths: updatedSaving);

    try {
      final savedPath = await _service.saveStatusMedia(item);
      final newSaving = Set<String>.from(state.savingPaths)..remove(item.path);

      if (savedPath != null && savedPath.isNotEmpty) {
        final newSaved = Set<String>.from(state.savedPaths)..add(item.path);
        final updatedItems = state.items.map((i) {
          if (i.path == item.path) {
            return i.copyWith(isSaved: true);
          }
          return i;
        }).toList();

        state = state.copyWith(
          savingPaths: newSaving,
          savedPaths: newSaved,
          items: updatedItems,
        );
        return true;
      } else {
        state = state.copyWith(savingPaths: newSaving);
        return false;
      }
    } catch (e) {
      final newSaving = Set<String>.from(state.savingPaths)..remove(item.path);
      state = state.copyWith(
        savingPaths: newSaving,
        errorMessage: 'Could not save status: $e',
      );
      return false;
    }
  }

  Future<void> shareStatus(WhatsAppStatusItem item) async {
    await _service.shareStatus(item);
  }

  Future<bool> openWhatsApp() async {
    return await _service.openWhatsApp(state.selectedApp);
  }

  Future<bool> openPlayStore() async {
    final isBusiness = state.selectedApp == WhatsAppAppType.whatsappBusiness;
    final pkg = isBusiness ? 'com.whatsapp.w4b' : 'com.whatsapp';
    return await _service.openPlayStore(pkg);
  }
}
