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
    expect(find.text('Save YouTube Video'), findsOneWidget);
    expect(find.text('Check Video'), findsOneWidget);
  });
}
