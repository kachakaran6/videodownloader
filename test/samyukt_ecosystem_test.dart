import 'package:flutter_test/flutter_test.dart';
import 'package:media_saver/features/samyukt_ecosystem/data/samyukt_catalog_service.dart';
import 'package:media_saver/features/samyukt_ecosystem/models/samyukt_app.dart';

void main() {
  group('Samyukt Ecosystem Standard — Status & Filtering', () {
    test('admissions: production, published, and coming_soon are allowed', () {
      expect(SamyuktAppStatus.fromRaw('production'), SamyuktAppStatus.production);
      expect(SamyuktAppStatus.fromRaw('PRODUCTION'), SamyuktAppStatus.production);
      expect(SamyuktAppStatus.fromRaw(' published '), SamyuktAppStatus.published);
      expect(SamyuktAppStatus.fromRaw('coming_soon'), SamyuktAppStatus.comingSoon);
    });

    test('exclusions: draft, in_progress, closed_testing, and unknown are rejected', () {
      expect(SamyuktAppStatus.fromRaw('draft'), isNull);
      expect(SamyuktAppStatus.fromRaw('in_progress'), isNull);
      expect(SamyuktAppStatus.fromRaw('closed_testing'), isNull);
      expect(SamyuktAppStatus.fromRaw('internal_test'), isNull);
      expect(SamyuktAppStatus.fromRaw(''), isNull);
      expect(SamyuktAppStatus.fromRaw(null), isNull);
    });
  });

  group('Samyukt Ecosystem Standard — Icon URL Resolution', () {
    test('resolves relative paths to official GitHub raw asset base', () {
      const expected =
          'https://raw.githubusercontent.com/kachakaran6/Application-json/main/images/vaultx.png';

      expect(SamyuktApp.resolveIconUrl('/images/vaultx.png'), expected);
      expect(SamyuktApp.resolveIconUrl('images/vaultx.png'), expected);
      expect(SamyuktApp.resolveIconUrl('vaultx.png'), expected);
    });

    test('preserves and upgrades https URLs', () {
      expect(
        SamyuktApp.resolveIconUrl('https://samyukt.pro/assets/icon.png'),
        'https://samyukt.pro/assets/icon.png',
      );
      expect(
        SamyuktApp.resolveIconUrl('http://samyukt.pro/assets/icon.png'),
        'https://samyukt.pro/assets/icon.png',
      );
    });

    test('handles empty or null gracefully', () {
      expect(SamyuktApp.resolveIconUrl(''), '');
      expect(SamyuktApp.resolveIconUrl('   '), '');
      expect(SamyuktApp.resolveIconUrl(null), '');
    });
  });

  group('Samyukt Ecosystem Standard — Registry Parsing & Strict Filtering', () {
    final service = SamyuktCatalogService();

    test('parses eligible apps and strictly ignores websites', () {
      const mockJson = '''
      {
        "version": "2.0.0",
        "websites": [
          {
            "id": "site1",
            "name": "Should Never Appear",
            "status": "production"
          }
        ],
        "apps": [
          {
            "id": "com.vaultx.vault_x",
            "appName": "Vault X",
            "packageName": "com.vaultx.vault_x",
            "playStoreUrl": "https://play.google.com/store/apps/details?id=com.vaultx.vault_x",
            "iconUrl": "/images/vaultx.png",
            "status": "production",
            "description": "Secure link vault."
          },
          {
            "id": "com.internal.test",
            "appName": "Internal Testing App",
            "packageName": "com.internal.test",
            "status": "closed_testing",
            "description": "Should be excluded."
          },
          {
            "id": "com.draft.app",
            "appName": "Draft App",
            "status": "draft"
          },
          {
            "id": "com.taskmitra.application",
            "appName": "TaskMitra",
            "packageName": "com.taskmitra.application",
            "iconUrl": "/images/taskmitra.png",
            "status": "coming_soon",
            "description": "Organize tasks."
          }
        ]
      }
      ''';

      final results = service.parseRegistryJson(mockJson);

      expect(results.length, 2);
      expect(results[0].appName, 'Vault X');
      expect(results[0].status, SamyuktAppStatus.production);
      expect(results[0].status.isAvailable, true);
      expect(
        results[0].iconUrl,
        'https://raw.githubusercontent.com/kachakaran6/Application-json/main/images/vaultx.png',
      );

      expect(results[1].appName, 'TaskMitra');
      expect(results[1].status, SamyuktAppStatus.comingSoon);
      expect(results[1].status.isAvailable, false);
      expect(results[1].status.displayLabel, 'Coming Soon');
    });

    test('handles malformed JSON and corrupted payloads safely without crashing', () {
      expect(service.parseRegistryJson(''), isEmpty);
      expect(service.parseRegistryJson('{malformed: json'), isEmpty);
      expect(service.parseRegistryJson('{"apps": "not_a_list"}'), isEmpty);
      expect(service.parseRegistryJson('[]'), isEmpty);
    });
  });
}
