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
            role = data?['role'] as String?;
          }

          // Pre-initialize controller state so the user object is immediately available to downstream dashboard views
          await ref.read(authControllerProvider.notifier).checkCurrentUser();

          if (!mounted) return;
          
          const supportedRoles = {'Admin', 'Staff', 'Engineering Student', 'BCA Student', 'MCA Student'};

          if (role != null && supportedRoles.contains(role)) {
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryCrimson,
              AppColors.darkCrimson,
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background branding shapes (Subtle premium design)
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.03),
                ),
              ),
            ),
            
            // Central Logo and Title
            AnimatedBuilder(
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo Icon Wrapper (Crimson Shield/Bus Monogram mockup)
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Image.asset(
                        'assets/images/bus_logo.png',
                        width: 90,
                        height: 90,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // App Branding Titles
                  Text(
                    'ICEM SMART BUS',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pass Management System',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom Loading Indicator / Footer
            Positioned(
              bottom: 60,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppColors.accentGold,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Indira College of Engineering & Management',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
