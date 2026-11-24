import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:media_saver/core/config/app_config.dart';
import 'package:media_saver/core/ecosystem/our_apps/app_registry_model.dart';
import 'package:media_saver/core/ecosystem/our_apps/app_registry_service.dart';
import 'package:media_saver/core/ecosystem/play_review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Samyukt Ecosystem — Registry Parsing & Strict Filtering', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Strict Filtering: Only includes eligible apps and ignores websites and ineligible statuses', () {
      final service = AppRegistryService(prefs: prefs);

      final mockPayload = {
        'version': '1.0.0',
        'websites': [
          {
            'id': 'web-1',
            'appName': 'Samyukt Portal',
            'status': 'production',
            'url': 'https://samyukt.pro',
          }
        ],
        'apps': [
          {
            'id': 'app-1',
            'appName': 'Vault X',
            'packageName': 'com.vaultx.app',
            'playStoreUrl': 'https://play.google.com/store/apps/details?id=com.vaultx.app',
            'iconUrl': '/images/vaultx.png',
            'status': 'production',
          },
          {
            'id': 'app-2',
            'appName': 'Habitly',
            'packageName': 'com.habitly.app',
            'iconUrl': 'images/habitly.png',
            'status': 'published',
          },
          {
            'id': 'app-3',
            'appName': 'Focus Wave',
            'iconUrl': 'focus.png',
            'status': 'coming_soon',
          },
          // Ineligible statuses that MUST be filtered out
          {
            'id': 'app-4',
            'appName': 'Draft App',
            'status': 'draft',
          },
          {
            'id': 'app-5',
            'appName': 'WIP App',
            'status': 'in_progress',
          },
          {
            'id': 'app-6',
            'appName': 'Alpha App',
            'status': 'closed_testing',
          },
          {
            'id': 'app-7',
            'appName': 'Unknown Status App',
            'status': 'internal_qa',
          },
          // Invalid entries (missing name)
          {
            'id': 'app-8',
            'status': 'production',
          }
        ]
      };

      final items = service.parseAndFilterApps(mockPayload);

      // Verify count: exactly 3 eligible apps (production, published, coming_soon)
      expect(items.length, 3);

      expect(items[0].appName, 'Vault X');
      expect(items[0].status, AppReleaseStatus.production);
      expect(items[0].status.isAvailable, true);
      expect(items[0].iconUrl, 'https://raw.githubusercontent.com/kachakaran6/Application-json/main/images/vaultx.png');

      expect(items[1].appName, 'Habitly');
      expect(items[1].status, AppReleaseStatus.published);
      expect(items[1].status.isAvailable, true);
      expect(items[1].iconUrl, 'https://raw.githubusercontent.com/kachakaran6/Application-json/main/images/habitly.png');

      expect(items[2].appName, 'Focus Wave');
      expect(items[2].status, AppReleaseStatus.comingSoon);
      expect(items[2].status.isAvailable, false);
      expect(items[2].iconUrl, 'https://raw.githubusercontent.com/kachakaran6/Application-json/main/images/focus.png');
    });

    test('Icon URL resolution handles relative and absolute HTTPS URLs', () {
      const relative1 = AppRegistryItem(
        id: '1',
        appName: 'Test 1',
        rawIconUrl: '/images/app1.png',
        status: AppReleaseStatus.production,
      );
      expect(relative1.iconUrl, 'https://raw.githubusercontent.com/kachakaran6/Application-json/main/images/app1.png');

      const relative2 = AppRegistryItem(
        id: '2',
        appName: 'Test 2',
        rawIconUrl: 'images/app2.png',
        status: AppReleaseStatus.production,
      );
      expect(relative2.iconUrl, 'https://raw.githubusercontent.com/kachakaran6/Application-json/main/images/app2.png');

      const relative3 = AppRegistryItem(
        id: '3',
        appName: 'Test 3',
        rawIconUrl: 'app3.png',
        status: AppReleaseStatus.production,
      );
      expect(relative3.iconUrl, 'https://raw.githubusercontent.com/kachakaran6/Application-json/main/images/app3.png');

      const absolute = AppRegistryItem(
        id: '4',
        appName: 'Test 4',
        rawIconUrl: 'https://cdn.example.com/icon.png',
        status: AppReleaseStatus.production,
      );
      expect(absolute.iconUrl, 'https://cdn.example.com/icon.png');
    });

    test('Offline resilience: Falls back cleanly to cached registry when network fails', () async {
      // 1. Prime cache with 1 valid app
      final cachedPayload = json.encode({
        'apps': [
          {
            'id': 'cached-app',
            'appName': 'Cached App',
            'status': 'production',
            'iconUrl': '/images/cached.png',
          }
        ]
      });
      await prefs.setString('samyukt_our_apps_cache_json', cachedPayload);
      await prefs.setInt('samyukt_our_apps_cache_time', DateTime.now().millisecondsSinceEpoch);

      // 2. Setup mock client returning 500 server error
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = AppRegistryService(client: mockClient, prefs: prefs);
      final items = await service.fetchCatalog(forceRefresh: true);

      expect(items.length, 1);
      expect(items.first.appName, 'Cached App');
    });

    test('Handles malformed JSON safely without throwing unhandled exceptions', () {
      final service = AppRegistryService(prefs: prefs);

      expect(service.parseAndFilterApps('not a map'), isEmpty);
      expect(service.parseAndFilterApps({'apps': 'not a list'}), isEmpty);
      expect(service.parseAndFilterApps({'apps': [1, 2, 'three', null]}), isEmpty);
    });
  });

  group('Samyukt Ecosystem — In-App Review Policy & Cooldown', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Engagement counter increments and respects threshold', () async {
      final service = PlayReviewService(prefs: prefs);

      // Initial state
      expect(prefs.getInt('play_review_engagement_counter'), null);

      // Record 1 engagement (below threshold 2)
      await service.recordEngagementAndConsiderReview();
      expect(prefs.getInt('play_review_engagement_counter'), 1);

      // Record 2nd engagement (meets threshold)
      await service.recordEngagementAndConsiderReview();
      expect(prefs.getInt('play_review_engagement_counter'), 2);
    });

    test('15-day cooldown strictly blocks premature review requests', () async {
      final service = PlayReviewService(prefs: prefs);

      // Simulate a review prompt that occurred 5 days ago
      final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5)).millisecondsSinceEpoch;
      await prefs.setInt('play_review_last_attempt_ms', fiveDaysAgo);

      final shouldPrompt = await service.maybeRequestReview(ignorePlatformCheckForTesting: true);
      // Must be false because 15 days have not elapsed
      expect(shouldPrompt, false);
    });

    test('Eligible after 15-day cooldown period expires', () async {
      final service = PlayReviewService(prefs: prefs);

      // Simulate a review prompt that occurred 16 days ago
      final sixteenDaysAgo = DateTime.now().subtract(const Duration(days: 16)).millisecondsSinceEpoch;
      await prefs.setInt('play_review_last_attempt_ms', sixteenDaysAgo);

      // Calling maybeRequestReview exercises cooldown check logic
      await service.maybeRequestReview(ignorePlatformCheckForTesting: true);

      final lastRecorded = prefs.getInt('play_review_last_attempt_ms');
      expect(DateTime.now().millisecondsSinceEpoch - lastRecorded!, lessThan(5000));
    });
  });

  group('Samyukt Ecosystem — Dynamic Share Metadata', () {
    test('Resolves correct dynamic application metadata format', () {
      const appName = AppConfig.appName;
      const tagline = AppConfig.appTagline;
      const packageName = 'app.mediaurl.applicaiton';
      final playStoreUrl = 'https://play.google.com/store/apps/details?id=$packageName';

      final message = '''Discover $appName — $tagline.

Explore the app and try it today:
$playStoreUrl

Made with care by Samyukt.''';

      expect(message, contains('Discover ClipVault'));
      expect(message, contains(tagline));
      expect(message, contains('https://play.google.com/store/apps/details?id=app.mediaurl.applicaiton'));
      expect(message, contains('Made with care by Samyukt.'));
    });
  });
}
