import 'package:flutter/foundation.dart';

/// Supported mobile app release statuses in the Samyukt catalog.
enum AppReleaseStatus {
  production,
  published,
  comingSoon;

  static AppReleaseStatus? fromString(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    switch (normalized) {
      case 'production':
        return AppReleaseStatus.production;
      case 'published':
        return AppReleaseStatus.published;
      case 'coming_soon':
      case 'comingsoon':
        return AppReleaseStatus.comingSoon;
      default:
        // Explicitly exclude 'draft', 'in_progress', 'closed_testing', etc.
        return null;
    }
  }

  String get label {
    switch (this) {
      case AppReleaseStatus.production:
      case AppReleaseStatus.published:
        return 'Available';
      case AppReleaseStatus.comingSoon:
        return 'Coming Soon';
    }
  }

  bool get isAvailable => this == AppReleaseStatus.production || this == AppReleaseStatus.published;
}

/// Represents a verified mobile application entry from the Samyukt registry.
@immutable
class AppRegistryItem {
  final String id;
  final String appName;
  final String? packageName;
  final String? playStoreUrl;
  final String rawIconUrl;
  final AppReleaseStatus status;
  final String? category;
  final String? tagline;
  final String? description;
  final bool featured;

  const AppRegistryItem({
    required this.id,
    required this.appName,
    this.packageName,
    this.playStoreUrl,
    required this.rawIconUrl,
    required this.status,
    this.category,
    this.tagline,
    this.description,
    this.featured = false,
  });

  static const String assetBaseUrl = 'https://raw.githubusercontent.com/kachakaran6/Application-json/main/images/';

  /// Resolves the icon URL safely against the asset base or validates absolute HTTPS URLs.
  String get iconUrl {
    final trimmed = rawIconUrl.trim();
    if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) {
      return trimmed;
    }

    // Relative paths like "/images/vaultx.png", "images/vaultx.png", or "vaultx.png"
    var cleanPath = trimmed;
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }
    if (cleanPath.startsWith('images/')) {
      cleanPath = cleanPath.substring('images/'.length);
    }
    return '$assetBaseUrl$cleanPath';
  }

  /// Parses a single item from registry JSON. Returns null if invalid or excluded.
  static AppRegistryItem? fromJson(Map<String, dynamic> json) {
    try {
      final appName = json['appName'] as String?;
      final rawStatus = json['status'] as String?;
      final status = AppReleaseStatus.fromString(rawStatus);

      // Must have valid name and eligible status (production, published, coming_soon)
      if (appName == null || appName.trim().isEmpty || status == null) {
        return null;
      }

      final id = (json['id'] as String?) ?? (json['packageName'] as String?) ?? appName;
      final rawIcon = (json['iconUrl'] as String?) ?? '';

      return AppRegistryItem(
        id: id,
        appName: appName.trim(),
        packageName: json['packageName'] as String?,
        playStoreUrl: json['playStoreUrl'] as String?,
        rawIconUrl: rawIcon,
        status: status,
        category: json['category'] as String?,
        tagline: json['tagline'] as String?,
        description: json['description'] as String?,
        featured: json['featured'] is bool ? json['featured'] as bool : false,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appName': appName,
      'packageName': packageName,
      'playStoreUrl': playStoreUrl,
      'iconUrl': rawIconUrl,
      'status': status == AppReleaseStatus.comingSoon ? 'coming_soon' : 'production',
      'category': category,
      'tagline': tagline,
      'description': description,
      'featured': featured,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppRegistryItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
