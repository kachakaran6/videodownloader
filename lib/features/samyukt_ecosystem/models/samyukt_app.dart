/// Supported publication statuses in the Samyukt Ecosystem mobile catalog.
enum SamyuktAppStatus {
  production,
  published,
  comingSoon;

  static const List<String> eligibleRawStatuses = [
    'production',
    'published',
    'coming_soon',
  ];

  static SamyuktAppStatus? fromRaw(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'production':
        return SamyuktAppStatus.production;
      case 'published':
        return SamyuktAppStatus.published;
      case 'coming_soon':
        return SamyuktAppStatus.comingSoon;
      default:
        return null; // Excludes draft, in_progress, closed_testing, etc.
    }
  }

  bool get isAvailable =>
      this == SamyuktAppStatus.production || this == SamyuktAppStatus.published;

  String get displayLabel {
    switch (this) {
      case SamyuktAppStatus.production:
      case SamyuktAppStatus.published:
        return 'Available';
      case SamyuktAppStatus.comingSoon:
        return 'Coming Soon';
    }
  }
}

/// Represents an application in the Samyukt ecosystem registry.
class SamyuktApp {
  final String id;
  final String appName;
  final String packageName;
  final String playStoreUrl;
  final String iconUrl;
  final SamyuktAppStatus status;
  final String? category;
  final String? tagline;
  final String description;
  final bool featured;
  final List<String> highlights;

  const SamyuktApp({
    required this.id,
    required this.appName,
    required this.packageName,
    required this.playStoreUrl,
    required this.iconUrl,
    required this.status,
    this.category,
    this.tagline,
    required this.description,
    this.featured = false,
    this.highlights = const [],
  });

  /// Base URL for resolving relative image assets in the Samyukt registry.
  static const String assetBaseUrl =
      'https://raw.githubusercontent.com/kachakaran6/Application-json/main/images/';

  /// Resolves the raw iconUrl to an absolute HTTPS URL safely.
  static String resolveIconUrl(String? rawIconUrl) {
    if (rawIconUrl == null || rawIconUrl.trim().isEmpty) {
      return '';
    }
    final trimmed = rawIconUrl.trim();
    if (trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('http://')) {
      return trimmed.replaceFirst('http://', 'https://');
    }

    // Handle registry-relative paths like "/images/vaultx.png" or "images/vaultx.png" or "vaultx.png"
    var cleanPath = trimmed;
    if (cleanPath.startsWith('/images/')) {
      cleanPath = cleanPath.substring('/images/'.length);
    } else if (cleanPath.startsWith('images/')) {
      cleanPath = cleanPath.substring('images/'.length);
    } else if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    return '$assetBaseUrl$cleanPath';
  }

  /// Parses an app entry strictly from registry JSON map.
  /// Returns null if status is ineligible or required fields are missing.
  static SamyuktApp? fromJson(Map<String, dynamic> json) {
    final status = SamyuktAppStatus.fromRaw(json['status']?.toString());
    if (status == null) {
      // Ineligible status (draft, in_progress, closed_testing, or unknown)
      return null;
    }

    final appName = json['appName']?.toString().trim();
    if (appName == null || appName.isEmpty) return null;

    final id = json['id']?.toString().trim() ?? appName;
    final packageName = json['packageName']?.toString().trim() ?? id;
    final rawPlayStoreUrl = json['playStoreUrl']?.toString().trim() ?? '';
    final resolvedPlayStoreUrl = rawPlayStoreUrl.isNotEmpty
        ? rawPlayStoreUrl
        : 'https://play.google.com/store/apps/details?id=$packageName';

    final rawIcon = json['iconUrl']?.toString();
    final resolvedIcon = resolveIconUrl(rawIcon);

    final description = json['description']?.toString().trim() ??
        json['tagline']?.toString().trim() ??
        '';

    final highlightsList = <String>[];
    if (json['highlights'] is List) {
      for (final h in json['highlights'] as List) {
        if (h != null && h.toString().trim().isNotEmpty) {
          highlightsList.add(h.toString().trim());
        }
      }
    }

    return SamyuktApp(
      id: id,
      appName: appName,
      packageName: packageName,
      playStoreUrl: resolvedPlayStoreUrl,
      iconUrl: resolvedIcon,
      status: status,
      category: json['category']?.toString().trim(),
      tagline: json['tagline']?.toString().trim(),
      description: description,
      featured: json['featured'] == true,
      highlights: highlightsList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'appName': appName,
        'packageName': packageName,
        'playStoreUrl': playStoreUrl,
        'iconUrl': iconUrl,
        'status': status.name,
        'category': category,
        'tagline': tagline,
        'description': description,
        'featured': featured,
        'highlights': highlights,
      };
}
