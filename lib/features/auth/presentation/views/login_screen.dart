import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_state.dart';
import 'package:icem_bus/shared/app_card.dart';
import 'package:icem_bus/shared/app_text_field.dart';
import 'package:icem_bus/shared/custom_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    if (_formKey.currentState!.validate()) {
      ref.read(authControllerProvider.notifier).login(
            email: _emailController.text,
            password: _passwordController.text,
          );
    }
  }

  void _showForgotPasswordDialog() {
    final emailResetController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: PremiumCard(
                padding: const EdgeInsets.all(24),
                borderRadius: 24,
                borderColor: AppColors.borderSubtle,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryCrimson.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primaryCrimson.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              color: AppColors.primaryCrimson,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Reset Password',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Enter your registered college email address and we will send you a secure link to reset your password.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      AppTextField(
                        controller: emailResetController,
                        label: 'College Email',
                        hintText: 'student@indiraicem.ac.in',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (value) {
                          return ref.read(authControllerProvider.notifier).validateEmail(value ?? '');
                        },
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        text: 'Send Reset Link',
                        icon: Icons.send_rounded,
                        isLoading: isSubmitting,
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final email = emailResetController.text.trim();
                          
                          setModalState(() => isSubmitting = true);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(dialogContext);

                          final success = await ref.read(authControllerProvider.notifier).forgotPassword(email);
                          setModalState(() => isSubmitting = false);

                          if (success) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Password reset link sent to your email.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            navigator.pop();
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text(
                            'Back to Login',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // Listen for AuthState mutations (Success routes or Error messages)
    ref.listen<AuthState>(authControllerProvider, (previous, next) async {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(authControllerProvider.notifier).resetState();
      } else if (next.isSuccess && next.user != null) {
        final user = next.user!;
        final String role = UserEntity.normalizeRole(user.role);

        if (role == 'Admin') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome back, ${user.fullName}!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go(AppRoutes.adminDashboard);
          ref.read(authControllerProvider.notifier).resetState();
        } else if (role == 'Staff') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome back, ${user.fullName}!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go(AppRoutes.staffDashboard);
          ref.read(authControllerProvider.notifier).resetState();
        } else if (role == 'Engineering Student' || role == 'BCA Student' || role == 'MCA Student') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome back, ${user.fullName}!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go(AppRoutes.studentDashboard);
          ref.read(authControllerProvider.notifier).resetState();
        } else {
          await ref.read(authControllerProvider.notifier).logout();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User role not found. Contact the administrator.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // ICEM Logo Container with Crimson subtle border & glow
              Container(
                width: 82,
                height: 82,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryCrimson.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryCrimson.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/bus_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),

              // Welcome Title
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your smart campus mobility starts here.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Login Input Form wrapped in PremiumCard
              Form(
                key: _formKey,
                child: PremiumCard(
                  padding: const EdgeInsets.all(22.0),
                  borderRadius: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email Field
                      AppTextField(
                        controller: _emailController,
                        label: 'College Email',
                        hintText: 'student@indiraicem.ac.in',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (value) {
                          return ref.read(authControllerProvider.notifier).validateEmail(value ?? '');
                        },
                      ),
                      const SizedBox(height: 18),

                      // Password Field
                      AppTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hintText: 'Enter your password',
                        isPassword: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      
                      // Remember Me & Forgot Password Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _rememberMe,
                                  activeColor: AppColors.primaryCrimson,
                                  checkColor: Colors.white,
                                  side: const BorderSide(color: AppColors.borderSubtle, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  onChanged: (val) => setState(() => _rememberMe = val ?? false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Remember Me',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: _showForgotPasswordDialog,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primaryCrimson,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Sign In Button (LOGIN)
                      PrimaryButton(
                        text: 'LOGIN',
                        icon: Icons.login_rounded,
                        isLoading: authState.isLoading,
                        onPressed: _onLoginPressed,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // OR CONTINUE WITH Divider
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.borderSubtle, thickness: 1)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'OR CONTINUE WITH',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.borderSubtle, thickness: 1)),
                ],
              ),
              const SizedBox(height: 24),

              // Google Login Button
              SecondaryButton(
                text: 'Google',
                icon: Icons.g_mobiledata_rounded,
                isLoading: authState.isLoading,
                onPressed: () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
              ),
              const SizedBox(height: 32),

              // Register Redirection Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.register),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        color: AppColors.primaryCrimson,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
