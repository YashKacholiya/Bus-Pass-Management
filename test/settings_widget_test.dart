import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_settings_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_settings_screen.dart';
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

    // 6. Application Settings
    expect(find.text('Application Settings'), findsOneWidget);
    expect(find.text('ICEM Smart Bus Pass'), findsWidgets);
    expect(find.text('Clear Local Cache'), findsOneWidget);

    // 7. System Status
    expect(find.text('System Status'), findsOneWidget);
    expect(find.text('Firebase Authentication'), findsOneWidget);
    expect(find.text('Cloud Firestore'), findsOneWidget);

    // 8. Admin Data Management
    expect(find.text('Admin Data Management'), findsOneWidget);
    expect(find.text('Refresh Data'), findsOneWidget);

    // 9. About ICEM
    expect(find.text('About ICEM'), findsOneWidget);
    expect(find.text('Indira College of Engineering & Management'), findsOneWidget);

    // 10. Help & Support
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Report an Issue'), findsOneWidget);
    expect(find.text('Admin FAQ'), findsOneWidget);

    // 11. Danger Zone
    expect(find.text('Danger Zone'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);

    // Test Edit Profile Dialog trigger
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
}
