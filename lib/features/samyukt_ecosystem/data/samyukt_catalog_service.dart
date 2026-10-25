import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/samyukt_app.dart';

/// Service responsible for fetching, filtering, and caching the Samyukt Apps catalog.
///
/// Strictly obeys the Samyukt Ecosystem Standard:
/// - Single Source of Truth: GitHub JSON registry.
/// - Parses only `apps[]` array (never `websites[]`).
/// - Only admits `production`, `published`, `coming_soon` statuses.
/// - Offline caching with graceful fallback.
class SamyuktCatalogService {
  static const String registryUrl =
      'https://raw.githubusercontent.com/kachakaran6/Application-json/main/app.json';
  static const String _cacheKey = 'samyukt_apps_registry_cache_v2';
  static const Duration _timeoutDuration = Duration(seconds: 10);

  final http.Client _client;

  SamyuktCatalogService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches apps from the remote registry, falling back to cached data if offline or unavailable.
  Future<List<SamyuktApp>> fetchApps({bool forceRefresh = false}) async {
    // 1. Try remote fetch if online / requested
    try {
      final response = await _client
          .get(Uri.parse(registryUrl))
          .timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final parsed = parseRegistryJson(response.body);
        if (parsed.isNotEmpty) {
          // Update cache with fresh valid response
          await _saveToCache(response.body);
          return parsed;
        }
      } else {
        debugPrint(
            '[SamyuktCatalog] HTTP ${response.statusCode} while fetching registry. Falling back to cache.');
      }
    } catch (e) {
      debugPrint('[SamyuktCatalog] Network error fetching registry: $e. Falling back to cache.');
    }

    // 2. Fall back to local persistent cache
    return await getCachedApps();
  }

  /// Parses the registry JSON string with strict validation and filtering rules.
  ///
  /// - Only parses the `apps[]` array.
  /// - Strictly ignores `websites[]`.
  /// - Excludes `draft`, `in_progress`, `closed_testing`, and unknown statuses.
  List<SamyuktApp> parseRegistryJson(String jsonString) {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return const [];
      }

      final dynamic appsRaw = decoded['apps'];
      if (appsRaw is! List) {
        return const [];
      }

      final List<SamyuktApp> results = [];
      for (final item in appsRaw) {
        if (item is Map<String, dynamic>) {
          final app = SamyuktApp.fromJson(item);
          if (app != null) {
            results.add(app);
          }
        }
      }

      return results;
    } catch (e) {
      debugPrint('[SamyuktCatalog] Failed to parse registry JSON: $e');
      return const [];
    }
  }

  /// Retrieves and parses the locally cached registry, if present.
  Future<List<SamyuktApp>> getCachedApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        return parseRegistryJson(cachedJson);
      }
    } catch (e) {
      debugPrint('[SamyuktCatalog] Error reading cache: $e');
    }
    return const [];
  }

  Future<void> _saveToCache(String jsonString) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonString);
    } catch (e) {
      debugPrint('[SamyuktCatalog] Error saving cache: $e');
    }
  }
}
