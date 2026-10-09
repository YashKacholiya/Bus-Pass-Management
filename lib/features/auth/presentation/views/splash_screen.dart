// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/constants/app_constants.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/services/storage/storage_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
    _startNavigationTimer();
  }

  void _startNavigationTimer() {
    Timer(AppConstants.splashDuration, () async {
      if (!mounted) return;
      
      User? firebaseUser;
      try {
        firebaseUser = FirebaseAuth.instance.currentUser;
      } catch (_) {
        // Safe fallback for widget tests where Firebase is not initialized
      }
      
      if (firebaseUser != null) {
        try {
          // Query Firestore directly to bypass any asynchronous Riverpod race conditions on launch
          final doc = await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).get();
          if (!mounted) return;

          String? role;
          if (doc.exists) {
            final data = doc.data();
            role = UserEntity.normalizeRole(data?['role'] as String?);
          }

          // Pre-initialize controller state so the user object is immediately available to downstream dashboard views
          await ref.read(authControllerProvider.notifier).checkCurrentUser();

          if (!mounted) return;
          
          const supportedRoles = {'Admin', 'Staff', 'Engineering Student', 'BCA Student', 'MCA Student'};

          if (role != null && role.isNotEmpty && supportedRoles.contains(role)) {
            if (role == 'Admin') {
              context.go(AppRoutes.adminDashboard);
            } else if (role == 'Staff') {
              context.go(AppRoutes.staffDashboard);
            } else {
              context.go(AppRoutes.studentDashboard);
            }
          } else {
            await ref.read(authControllerProvider.notifier).logout();
            if (!mounted) return;
            context.go(AppRoutes.login);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User role not found. Contact the administrator.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } catch (_) {
          if (!mounted) return;
          // Fallback to login if check fails due to offline state
          context.go(AppRoutes.login);
        }
      } else {
        final storage = ref.read(storageServiceProvider);
        if (storage.isOnboardingCompleted) {
          context.go(AppRoutes.login);
        } else {
          context.go(AppRoutes.onboarding);
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient subtle crimson glow centered behind the logo/title
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryCrimson.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Safe Area with responsive centered composition
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. [ICEM LOGO] in a premium rounded container
                      Container(
                        width: 104,
                        height: 104,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppColors.primaryCrimson.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryCrimson.withValues(alpha: 0.22),
                              blurRadius: 28,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/bus_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // 2. [INDIRA COLLEGE OF ENGINEERING & MANAGEMENT] in a premium pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCrimson.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryCrimson.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'INDIRA COLLEGE OF ENGINEERING & MANAGEMENT',
                            style: TextStyle(
                              color: AppColors.primaryCrimson,
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                              letterSpacing: 1.0,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 3. [ICEM SMART BUS PASS] primary responsive title
                      const Text(
                        'ICEM',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: 2.0,
                          fontFamily: 'Outfit',
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'SMART BUS PASS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryCrimson,
                            letterSpacing: 1.4,
                            fontFamily: 'Outfit',
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4. [Secure Campus Mobility] subtitle
                      Text(
                        'Secure Campus Mobility',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary.withValues(alpha: 0.9),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 5. [Smart • Secure • Connected] tagline
                      const Text(
                        'Smart • Secure • Connected',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 6. Subtle loading spinner (never overlaps, clean spacing)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.primaryCrimson,
                          strokeWidth: 2.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
