import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/admin/presentation/views/staff_dashboard.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_dashboard.dart';
import 'package:icem_bus/features/auth/presentation/views/login_screen.dart';
import 'package:icem_bus/features/auth/presentation/views/onboarding_screen.dart';
import 'package:icem_bus/features/auth/presentation/views/register_screen.dart';
import 'package:icem_bus/features/auth/presentation/views/splash_screen.dart';
import 'package:icem_bus/features/student/presentation/views/student_dashboard.dart';
import 'package:icem_bus/features/student/presentation/views/student_sub_screens.dart';
import 'package:icem_bus/features/admin/presentation/views/application_detail_screen.dart';
import 'package:icem_bus/shared/error_screen.dart';
import 'package:icem_bus/shared/loading_screen.dart';
import 'package:icem_bus/features/driver/presentation/views/driver_management_screen.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_settings_screen.dart';

class AppRoutes {
  AppRoutes._();

  // Route Paths
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String studentDashboard = '/student_dashboard';
  static const String staffDashboard = '/staff_dashboard';
  static const String adminDashboard = '/admin_dashboard';
  static const String loading = '/loading';
  static const String error = '/error';
  static const String applicationDetail = '/admin/application/:id';
  static const String driverManagement = '/admin/drivers';
  static const String adminSettings = '/admin/settings';

  // Student Sub routes
  static const String studentApply = '/student/apply';
  static const String studentRenew = '/student/renew';
  static const String studentDigitalPass = '/student/digital-pass';
  static const String studentPaymentHistory = '/student/payment-history';
  static const String studentPayment = '/student/payment';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    redirect: (BuildContext context, GoRouterState state) {
      final String path = state.uri.path;

      // Determine if it's an auth-related public page
      final bool isPublicPath = path == splash ||
          path == onboarding ||
          path == login ||
          path == register;

      // Check Firebase Auth status synchronously
      User? firebaseUser;
      try {
        firebaseUser = FirebaseAuth.instance.currentUser;
      } catch (_) {
        // Fallback for tests/environments where Firebase is not initialized
      }

      if (firebaseUser == null) {
        // If not logged in, they can only access public pages
        if (!isPublicPath) {
          return login;
        }
        return null;
      }

      // User is logged in. Check Riverpod state for loaded Firestore profile
      final container = ProviderScope.containerOf(context);
      final authState = container.read(authControllerProvider);
      final user = authState.user;

      // If user profile is not loaded yet in state, we let the app load the page (or splash)
      if (user == null) {
        return null;
      }

      final String role = user.role;

      if (isPublicPath) {
        // Prevent showing login/register/onboarding again if already logged in
        if (role == 'Admin') {
          return adminDashboard;
        } else if (role == 'Staff') {
          return staffDashboard;
        } else {
          return studentDashboard;
        }
      }

      // Guard Admin pages
      if (path == adminDashboard || path.startsWith('/admin/')) {
        if (role != 'Admin') {
          Future.microtask(() {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Access Denied'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          });
          return studentDashboard;
        }
      }

      // Guard Staff pages
      if (path == staffDashboard) {
        if (role != 'Staff') {
          Future.microtask(() {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Access Denied'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          });
          return studentDashboard;
        }
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: splash,
        builder: (BuildContext context, GoRouterState state) {
          return const SplashScreen();
        },
      ),
      GoRoute(
        path: onboarding,
        builder: (BuildContext context, GoRouterState state) {
          return const OnboardingScreen();
        },
      ),
      GoRoute(
        path: login,
        builder: (BuildContext context, GoRouterState state) {
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: register,
        builder: (BuildContext context, GoRouterState state) {
          return const RegisterScreen();
        },
      ),
      GoRoute(
        path: studentDashboard,
        builder: (BuildContext context, GoRouterState state) {
          return const StudentDashboardScreen();
        },
      ),
      GoRoute(
        path: staffDashboard,
        builder: (BuildContext context, GoRouterState state) {
          return const StaffDashboardScreen();
        },
      ),
      GoRoute(
        path: adminDashboard,
        builder: (BuildContext context, GoRouterState state) {
          return const AdminDashboardScreen();
        },
      ),
      GoRoute(
        path: driverManagement,
        builder: (BuildContext context, GoRouterState state) {
          return const DriverManagementScreen();
        },
      ),
      GoRoute(
        path: '/admin/application/:id',
        builder: (BuildContext context, GoRouterState state) {
          final applicationId = state.pathParameters['id'] ?? '';
          return ApplicationDetailScreen(applicationId: applicationId);
        },
      ),
      GoRoute(
        path: adminSettings,
        builder: (BuildContext context, GoRouterState state) {
          return const AdminSettingsScreen();
        },
      ),
      GoRoute(
        path: studentApply,
        builder: (BuildContext context, GoRouterState state) {
          return const ApplyPassScreen();
        },
      ),
      GoRoute(
        path: studentRenew,
        builder: (BuildContext context, GoRouterState state) {
          return const RenewPassScreen();
        },
      ),
      GoRoute(
        path: studentDigitalPass,
        builder: (BuildContext context, GoRouterState state) {
          return const DigitalPassScreen();
        },
      ),
      GoRoute(
        path: studentPaymentHistory,
        builder: (BuildContext context, GoRouterState state) {
          return const PaymentHistoryScreen();
        },
      ),
      GoRoute(
        path: studentPayment,
        builder: (BuildContext context, GoRouterState state) {
          return const StudentPaymentScreen();
        },
      ),
      GoRoute(
        path: loading,
        builder: (BuildContext context, GoRouterState state) {
          return const LoadingScreen();
        },
      ),
      GoRoute(
        path: error,
        builder: (BuildContext context, GoRouterState state) {
          return ErrorScreen(
            onRetry: () {
              context.go(login);
            },
            onBack: () {
              context.go(login);
            },
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('No route defined for ${state.uri.path}'),
      ),
    ),
  );
}
