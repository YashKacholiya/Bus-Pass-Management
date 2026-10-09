import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_state.dart';
import 'package:icem_bus/shared/app_card.dart';
import 'package:icem_bus/shared/app_text_field.dart';
import 'package:icem_bus/shared/custom_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedRole;

  final List<String> _roles = [
    'Engineering Student',
    'BCA Student',
    'MCA Student',
    'Staff',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _studentIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRegisterPressed() {
    if (_formKey.currentState!.validate()) {
      if (_selectedRole == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your college role / course.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      
      ref.read(authControllerProvider.notifier).signUp(
            fullName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            confirmPassword: _confirmPasswordController.text,
            role: _selectedRole!,
            mobile: _mobileController.text.trim().isNotEmpty ? _mobileController.text.trim() : null,
            collegeId: _studentIdController.text.trim().isNotEmpty ? _studentIdController.text.trim() : null,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // Listen for AuthState mutations (Errors or successful registration redirects)
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(authControllerProvider.notifier).resetState();
      } else if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please check your inbox for verification link.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
        context.go(AppRoutes.login);
        ref.read(authControllerProvider.notifier).resetState();
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
              const SizedBox(height: 16),

              // App logo / branding
              Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(14),
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
              const SizedBox(height: 18),

              const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Join the ICEM Smart Bus Pass portal',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 26),

              // Inputs wrapped in PremiumCard
              Form(
                key: _formKey,
                child: PremiumCard(
                  padding: const EdgeInsets.all(22.0),
                  borderRadius: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section: Personal Details
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.primaryCrimson,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Full Name
                      AppTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        hintText: 'e.g. Yash Kacholiya',
                        keyboardType: TextInputType.name,
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Full name is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
                      AppTextField(
                        controller: _emailController,
                        label: 'College Email Address',
                        hintText: 'student@indiraicem.ac.in',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (value) {
                          return ref.read(authControllerProvider.notifier).validateEmail(value ?? '');
                        },
                      ),
                      const SizedBox(height: 16),

                      // Mobile Number
                      AppTextField(
                        controller: _mobileController,
                        label: 'Mobile Number',
                        hintText: '+91 98765 43210',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                      ),
                      const SizedBox(height: 24),

                      // Section: Academic Details
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.primaryCrimson,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Academic Details',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Course / Role Dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Course / Role',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            dropdownColor: AppColors.cardSurface,
                            borderRadius: BorderRadius.circular(16),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surfaceElevated,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textMuted, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.borderSubtle),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.borderSubtle),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.primaryCrimson, width: 1.5),
                              ),
                            ),
                            hint: const Text('Select course / role', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                            items: _roles.map((String role) {
                              return DropdownMenuItem<String>(
                                value: role,
                                child: Text(role),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedRole = value),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select your role / course.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Student ID / PRN
                      AppTextField(
                        controller: _studentIdController,
                        label: 'Student ID / PRN (Optional)',
                        hintText: 'e.g. ICEM2026CS001',
                        prefixIcon: Icons.pin_outlined,
                      ),
                      const SizedBox(height: 24),

                      // Section: Security
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.primaryCrimson,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Account Security',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Password
                      AppTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hintText: 'At least 6 characters',
                        isPassword: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: (value) {
                          return ref.read(authControllerProvider.notifier).validatePassword(value ?? '');
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      AppTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        hintText: 'Re-enter your password',
                        isPassword: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 26),

                      // Register Button
                      PrimaryButton(
                        text: 'CREATE ACCOUNT',
                        icon: Icons.person_add_rounded,
                        isLoading: authState.isLoading,
                        onPressed: _onRegisterPressed,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // OR Divider
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.borderSubtle, thickness: 1)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'OR',
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

              // Google Sign-Up Button
              SecondaryButton(
                text: 'Sign Up with Google',
                icon: Icons.g_mobiledata_rounded,
                isLoading: authState.isLoading,
                onPressed: () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
              ),
              const SizedBox(height: 32),

              // Login Redirection Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.login),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: AppColors.primaryCrimson,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
