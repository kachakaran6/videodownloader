import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../storage/preferences_service.dart';
import 'app_registry_model.dart';

const String _kRegistryUrl = 'https://raw.githubusercontent.com/kachakaran6/Application-json/main/app.json';
const String _kCacheKeyJson = 'samyukt_our_apps_cache_json';
const String _kCacheKeyTimestamp = 'samyukt_our_apps_cache_time';

/// Service responsible for fetching, filtering, and caching the centralized Samyukt app registry.
class AppRegistryService {
  final http.Client _client;
  final SharedPreferences prefs;

  AppRegistryService({
    http.Client? client,
    required this.prefs,
  })  : _client = client ?? http.Client();

  /// Fetches eligible mobile apps from the remote registry, falling back to cache if offline.
  Future<List<AppRegistryItem>> fetchCatalog({bool forceRefresh = false}) async {
    // If not forcing refresh, attempt to load cached items first for instant display
    if (!forceRefresh) {
      final cached = getCachedCatalog();
      if (cached.isNotEmpty) {
        // Trigger background refresh if cache is older than 6 hours
        final lastFetched = prefs.getInt(_kCacheKeyTimestamp) ?? 0;
        final age = DateTime.now().millisecondsSinceEpoch - lastFetched;
        if (age < 6 * 3600 * 1000) {
          return cached;
        }
      }
    }

    try {
      final uri = Uri.parse(_kRegistryUrl);
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        final items = parseAndFilterApps(decoded);

        if (items.isNotEmpty) {
          // Persist raw response to cache
          await prefs.setString(_kCacheKeyJson, response.body);
          await prefs.setInt(_kCacheKeyTimestamp, DateTime.now().millisecondsSinceEpoch);
          return items;
        }
      }
    } catch (_) {
      // Network failure, timeout, or parsing error: fallback to local cache
    }

    final fallback = getCachedCatalog();
    if (fallback.isNotEmpty) {
      return fallback;
    }

    throw Exception('Unable to load applications catalog. Please check your internet connection.');
  }

  /// Parses and filters the registry payload with strict rules:
  /// 1. Only reads from 'apps' array (never 'websites').
  /// 2. Only includes statuses: 'production', 'published', 'coming_soon'.
  /// 3. Normalizes status strings and filters out draft, in_progress, closed_testing, etc.
  List<AppRegistryItem> parseAndFilterApps(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return const [];
    }

    final appsRaw = data['apps'];
    if (appsRaw is! List) {
      return const [];
    }

    final List<AppRegistryItem> results = [];
    for (final raw in appsRaw) {
      if (raw is Map<String, dynamic>) {
        final item = AppRegistryItem.fromJson(raw);
        if (item != null) {
          results.add(item);
        }
      }
    }

    return results;
  }

  /// Reads cached catalog data if available.
  List<AppRegistryItem> getCachedCatalog() {
    try {
      final cachedStr = prefs.getString(_kCacheKeyJson);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final decoded = json.decode(cachedStr);
        return parseAndFilterApps(decoded);
      }
    } catch (_) {}
    return const [];
  }
}

/// Riverpod provider for AppRegistryService
final appRegistryServiceProvider = Provider<AppRegistryService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppRegistryService(prefs: prefs);
});

/// State representation for Our Apps catalog
class OurAppsState {
  final bool isLoading;
  final List<AppRegistryItem> apps;
  final String? errorMessage;
  final bool isFromCache;

  const OurAppsState({
    this.isLoading = false,
    this.apps = const [],
    this.errorMessage,
    this.isFromCache = false,
  });

  OurAppsState copyWith({
    bool? isLoading,
    List<AppRegistryItem>? apps,
    String? errorMessage,
    bool? isFromCache,
  }) {
    return OurAppsState(
      isLoading: isLoading ?? this.isLoading,
      apps: apps ?? this.apps,
      errorMessage: errorMessage,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }
}

/// Riverpod Notifier for the Our Apps catalog UI
class OurAppsNotifier extends Notifier<OurAppsState> {
  @override
  OurAppsState build() {
    final service = ref.watch(appRegistryServiceProvider);
    final cached = service.getCachedCatalog();

    // Trigger asynchronous load
    Future.microtask(() => loadCatalog());

    if (cached.isNotEmpty) {
      return OurAppsState(isLoading: true, apps: cached, isFromCache: true);
    }
    return const OurAppsState(isLoading: true);
  }

  Future<void> loadCatalog({bool forceRefresh = false}) async {
    final service = ref.read(appRegistryServiceProvider);

    final cached = service.getCachedCatalog();
    if (cached.isNotEmpty && state.apps.isEmpty) {
      state = state.copyWith(apps: cached, isFromCache: true, isLoading: true);
    } else {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      final items = await service.fetchCatalog(forceRefresh: forceRefresh);
      state = state.copyWith(
        isLoading: false,
        apps: items,
        errorMessage: null,
        isFromCache: false,
      );
    } catch (e) {
      if (state.apps.isNotEmpty) {
        // Keep displaying cached items, turn off loader
        state = state.copyWith(isLoading: false, isFromCache: true);
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }
}

final ourAppsNotifierProvider = NotifierProvider<OurAppsNotifier, OurAppsState>(() {
  return OurAppsNotifier();
});
