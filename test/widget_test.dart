import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_saver/app/app.dart';
import 'package:media_saver/core/storage/preferences_service.dart';

void main() {
  testWidgets('MediaSaverApp launches smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'legal_disclaimer_accepted': true,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MediaSaverApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Media Saver'), findsOneWidget);
    expect(find.text('Download Video or Reel'), findsOneWidget);
    expect(find.text('Check Video'), findsOneWidget);
  });

  testWidgets('Quick theme toggle switches theme in AppBar', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'legal_disclaimer_accepted': true,
      'app_theme_mode': 'dark',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MediaSaverApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify dark mode toggle tooltip is visible
    expect(find.byTooltip('Switch to Light Mode'), findsOneWidget);

    // Tap toggle
    await tester.tap(find.byTooltip('Switch to Light Mode'));
    await tester.pumpAndSettle();

    // Now it should be light mode
    expect(find.byTooltip('Switch to Dark Mode'), findsOneWidget);
    expect(prefs.getString('app_theme_mode'), 'light');
  });

  testWidgets('SettingsScreen allows selecting Light and Dark mode', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'legal_disclaimer_accepted': true,
      'app_theme_mode': 'dark',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MediaSaverApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Open settings screen
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('Theme Mode'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsNothing);

    // Tap Light mode option
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(prefs.getString('app_theme_mode'), 'light');

    // Tap Dark mode option
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(prefs.getString('app_theme_mode'), 'dark');
  });
}
