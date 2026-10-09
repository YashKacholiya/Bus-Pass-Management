import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_settings_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_settings_screen.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_dashboard.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_state.dart';
import 'package:icem_bus/services/storage/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthController extends AuthController {
  @override
  AuthState build() {
    return AuthState(
      user: UserEntity(
        uid: 'admin123',
        fullName: 'Test Admin',
        email: 'testadmin@icem.edu',
        role: 'Administrator',
        isEmailVerified: true,
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 9, 12),
      ),
    );
  }

  @override
  Future<bool> updateProfile({
    required String fullName,
    String? mobile,
    String? department,
  }) async {
    state = state.copyWith(
      user: UserEntity(
        uid: 'admin123',
        fullName: fullName,
        email: 'testadmin@icem.edu',
        role: 'Administrator',
        isEmailVerified: true,
        mobile: mobile,
        department: department,
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime.now(),
      ),
    );
    return true;
  }
}

void main() {
  testWidgets('AdminSettingsTab renders all modules and profile correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;

    SharedPreferences.setMockInitialValues({'language': 'english'});
    final sharedPreferences = await SharedPreferences.getInstance();
    final storageService = StorageService(sharedPreferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
          authControllerProvider.overrideWith(() => FakeAuthController()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AdminSettingsTab(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Console Settings'), findsOneWidget);

    // 1. Admin Profile
    expect(find.text('Admin Profile'), findsOneWidget);
    expect(find.text('Test Admin'), findsOneWidget);
    expect(find.text('testadmin@icem.edu'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.text('Edit Profile Details'), findsOneWidget);

    // 2. Appearance
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Theme Mode'), findsOneWidget);
    expect(find.text('Compact UI Density'), findsOneWidget);

    // 3. Notification Settings
    expect(find.text('Notification Settings'), findsOneWidget);
    expect(find.text('Enable Notifications'), findsOneWidget);
    expect(find.text('Application Updates'), findsOneWidget);
    expect(find.text('New Bus Pass Applications'), findsOneWidget);
    expect(find.text('Payment Notifications'), findsOneWidget);

    // 4. Security
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Password Reset Email'), findsOneWidget);

    // 5. Session / Login Security
    expect(find.text('Session & Login Security'), findsOneWidget);
    expect(find.text('Last Sign-In Timestamp'), findsOneWidget);

    // 6. Application Settings (scroll into view)
    await tester.scrollUntilVisible(find.text('Application Settings'), 300);
    expect(find.text('Application Settings'), findsOneWidget);
    expect(find.text('ICEM Smart Bus Pass'), findsWidgets);
    expect(find.text('Clear Local Cache'), findsOneWidget);

    // 7. System Status
    await tester.scrollUntilVisible(find.text('System Status'), 300);
    expect(find.text('System Status'), findsOneWidget);
    expect(find.text('Firebase Authentication'), findsOneWidget);
    expect(find.text('Cloud Firestore'), findsOneWidget);

    // 8. Admin Data Management
    await tester.scrollUntilVisible(find.text('Admin Data Management'), 300);
    expect(find.text('Admin Data Management'), findsOneWidget);
    expect(find.text('Refresh Data'), findsOneWidget);

    // 9. About ICEM
    await tester.scrollUntilVisible(find.text('About ICEM'), 300);
    expect(find.text('About ICEM'), findsOneWidget);
    expect(find.text('Indira College of Engineering & Management'), findsOneWidget);

    // 10. Help & Support
    await tester.scrollUntilVisible(find.text('Help & Support'), 300);
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Report an Issue'), findsOneWidget);
    expect(find.text('Admin FAQ'), findsOneWidget);

    // 11. Danger Zone
    await tester.scrollUntilVisible(find.text('Danger Zone'), 300);
    expect(find.text('Danger Zone'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);

    // Scroll back to top to test Edit Profile Dialog trigger
    await tester.scrollUntilVisible(find.text('Edit Profile Details'), -100);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Profile Details'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Administrator Profile'), findsOneWidget);

    // Reset physical size after test
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('AdminSettingsScreen renders correctly with AppBar and AdminSettingsTab', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;

    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final storageService = StorageService(sharedPreferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
          authControllerProvider.overrideWith(() => FakeAuthController()),
        ],
        child: const MaterialApp(
          home: AdminSettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Console Settings'), findsOneWidget);
    expect(find.text('Test Admin'), findsOneWidget);

    // Reset physical size after test
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Theme switching changes global settings and persists to StorageService', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1.0;

    SharedPreferences.setMockInitialValues({'theme_mode': 'system'});
    final sharedPreferences = await SharedPreferences.getInstance();
    final storageService = StorageService(sharedPreferences);

    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
          authControllerProvider.overrideWith(() => FakeAuthController()),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            capturedRef = ref;
            final settings = ref.watch(settingsNotifierProvider);
            return MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: settings.themeMode,
              home: const Scaffold(
                body: AdminSettingsTab(),
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Initial state should be System
    expect(capturedRef.read(settingsNotifierProvider).themeMode, equals(ThemeMode.system));

    // Tap "Dark" pill
    final darkPillFinder = find.widgetWithText(InkWell, 'Dark');
    expect(darkPillFinder, findsOneWidget);
    await tester.tap(darkPillFinder);
    await tester.pumpAndSettle();

    // Verify Riverpod state updated to Dark
    expect(capturedRef.read(settingsNotifierProvider).themeMode, equals(ThemeMode.dark));
    // Verify persisted in storage
    expect(storageService.getString('themeMode'), equals('dark'));

    // Tap "Light" pill
    final lightPillFinder = find.widgetWithText(InkWell, 'Light');
    expect(lightPillFinder, findsOneWidget);
    await tester.tap(lightPillFinder);
    await tester.pumpAndSettle();

    // Verify Riverpod state updated to Light
    expect(capturedRef.read(settingsNotifierProvider).themeMode, equals(ThemeMode.light));
    // Verify persisted in storage
    expect(storageService.getString('themeMode'), equals('light'));

    // Tap "System" pill
    final systemPillFinder = find.widgetWithText(InkWell, 'System');
    expect(systemPillFinder, findsOneWidget);
    await tester.tap(systemPillFinder);
    await tester.pumpAndSettle();

    // Verify Riverpod state updated to System
    expect(capturedRef.read(settingsNotifierProvider).themeMode, equals(ThemeMode.system));
    // Verify persisted in storage
    expect(storageService.getString('themeMode'), equals('system'));

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('AdminSettingsTab scrolls smoothly from top to bottom and back on mobile screen size', (WidgetTester tester) async {
    // Physical size corresponding to Realme 15 (1280x2800 at density 476 / ratio 2.975 -> ~430x941)
    tester.view.physicalSize = const Size(430, 941);
    tester.view.devicePixelRatio = 1.0;

    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final storageService = StorageService(sharedPreferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
          authControllerProvider.overrideWith(() => FakeAuthController()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AdminSettingsTab(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Console Settings'), findsOneWidget);

    // Verify sections reachable in order from top to bottom
    await tester.scrollUntilVisible(find.text('Admin Profile'), 200);
    expect(find.text('Admin Profile'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Appearance'), 200);
    expect(find.text('Appearance'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Notification Settings'), 200);
    expect(find.text('Notification Settings'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Security'), 200);
    expect(find.text('Security'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Session & Login Security'), 200);
    expect(find.text('Session & Login Security'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Application Settings'), 200);
    expect(find.text('Application Settings'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('System Status'), 200);
    expect(find.text('System Status'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Admin Data Management'), 200);
    expect(find.text('Admin Data Management'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('About ICEM'), 200);
    expect(find.text('About ICEM'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Help & Support'), 200);
    expect(find.text('Help & Support'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Danger Zone'), 200);
    expect(find.text('Danger Zone'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);

    // Scroll back from BOTTOM to TOP
    await tester.scrollUntilVisible(find.text('Console Settings'), -200);
    expect(find.text('Console Settings'), findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('AdminDashboardScreen tab 8 renders and scrolls completely on Realme 15 dimensions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 941);
    tester.view.devicePixelRatio = 1.0;

    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final storageService = StorageService(sharedPreferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
          authControllerProvider.overrideWith(() => FakeAdminDashboardAuthController()),
          adminTabProvider.overrideWith((ref) => 8),
        ],
        child: const MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Console Settings'), findsOneWidget);

    // Scroll to Danger Zone at the very bottom
    await tester.scrollUntilVisible(find.text('Danger Zone'), 200);
    expect(find.text('Danger Zone'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);

    // Scroll back to top
    await tester.scrollUntilVisible(find.text('Console Settings'), -200);
    expect(find.text('Console Settings'), findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}

class FakeAdminDashboardAuthController extends AuthController {
  @override
  AuthState build() {
    return AuthState(
      user: UserEntity(
        uid: 'admin123',
        fullName: 'Test Admin',
        email: 'testadmin@icem.edu',
        role: 'Admin',
        isEmailVerified: true,
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 9, 12),
      ),
    );
  }
}


