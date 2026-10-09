// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/shared/custom_button.dart';
import 'package:icem_bus/shared/glass_card.dart';

class StaffDashboardScreen extends ConsumerWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    
    final user = authState.user;
    
    // Permission Guard: Only Staff can access
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AppRoutes.login);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (user.role != 'Staff') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Denied'),
            backgroundColor: AppColors.error,
          ),
        );
        context.go(AppRoutes.studentDashboard);
      });
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad_rounded, size: 80, color: AppColors.primaryCrimson),
                const SizedBox(height: 24),
                Text(
                  'Access Denied',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Only Transport Staff are authorized to view this scanning console.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final String staffName = user.fullName;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: const Text('Staff Admin Portal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D1527),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.primaryCrimson),
            onPressed: () => _handleLogout(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Section
              Text(
                'Welcome, $staffName',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryCrimson,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Designation: ICEM Administrative Staff',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              // Mock Verification Scanner GlassCard
              const Text(
                'Verification Scanner',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => context.push(AppRoutes.qrVerification),
                borderRadius: BorderRadius.circular(16),
                child: GlassCard(
                  blur: 16,
                  borderColor: AppColors.accentGold,
                  opacity: 0.12,
                  color: AppColors.secondaryDark,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.accentGold,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'SCAN STUDENT PASS',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap to launch camera scanner and verify student bus passes in real-time.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        text: 'Launch Scanner',
                        icon: Icons.camera_alt_rounded,
                        onPressed: () => context.push(AppRoutes.qrVerification),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Admin statistics Mock
              const Text(
                'Today\'s Passenger Overview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      blur: 12,
                      borderColor: Colors.white10,
                      opacity: 0.05,
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('Passes Verified', style: TextStyle(fontSize: 12, color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text(
                            '142',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: AppColors.primaryCrimson,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GlassCard(
                      blur: 12,
                      borderColor: Colors.white10,
                      opacity: 0.05,
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('Active Buses', style: TextStyle(fontSize: 12, color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text(
                            '8 / 10',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: AppColors.accentGold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              // Direct logout
              SecondaryButton(
                text: 'Sign Out Portal',
                icon: Icons.logout_rounded,
                onPressed: () => _handleLogout(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Sign Out'),
        content: const Text('Are you sure you want to sign out from the scanning console?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.primaryCrimson)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
      context.go(AppRoutes.login);
    }
  }
}
