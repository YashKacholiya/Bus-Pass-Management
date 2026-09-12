import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icem_bus/app/app.dart';
import 'package:icem_bus/services/storage/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App starts on Splash Screen and navigates to Onboarding Screen', (WidgetTester tester) async {
    // Setup Mock SharedPreferences for storage service
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final storageService = StorageService(sharedPreferences);

    // Build the main app with Riverpod providers overridden for test environment
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
        ],
        child: const MyApp(),
      ),
    );

    // 1. Verify that the Splash Screen elements are rendered initially
    expect(find.text('ICEM SMART BUS'), findsOneWidget);
    expect(find.text('Pass Management System'), findsOneWidget);

    // 2. Advance the timer to let the splash navigation execute
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle(); // Wait for route transition animation

    // 3. Verify that we have automatically transitioned to the Onboarding Screen
    expect(find.text('Smart Digital Pass'), findsOneWidget);
    expect(find.text('Next Route'), findsOneWidget);
  });
}
