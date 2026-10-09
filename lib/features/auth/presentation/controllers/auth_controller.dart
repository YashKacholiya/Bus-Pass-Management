import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/core/errors/failures.dart';
import 'package:icem_bus/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_state.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Schedule loading user session after widget build completes
    Future.microtask(() => checkCurrentUser());
    return const AuthState();
  }

  /// Check if a user session is active on startup
  Future<void> checkCurrentUser() async {
    state = state.copyWith(isLoading: true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final UserEntity? user = await repository.getCurrentUser();
      state = state.copyWith(user: user, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Sign Up with Email and Password
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
    required String role,
    String? mobile,
    String? collegeId,
  }) async {
    // 1. Validations
    if (fullName.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Full Name is required.');
      return;
    }
    
    final emailError = validateEmail(email);
    if (emailError != null) {
      state = state.copyWith(errorMessage: emailError);
      return;
    }

    final passwordError = validatePassword(password);
    if (passwordError != null) {
      state = state.copyWith(errorMessage: passwordError);
      return;
    }

    if (password != confirmPassword) {
      state = state.copyWith(errorMessage: 'Passwords do not match.');
      return;
    }

    if (role.isEmpty) {
      state = state.copyWith(errorMessage: 'Please select a role.');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.signUpWithEmailAndPassword(
        fullName: fullName.trim(),
        email: email.trim(),
        password: password,
        role: role,
        mobile: mobile,
        collegeId: collegeId,
      );
      state = state.copyWith(user: user, isLoading: false, isSuccess: true);
    } on Failure catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  /// Log In with Email and Password
  Future<void> login({
    required String email,
    required String password,
  }) async {
    // 1. Validations
    final emailError = validateEmail(email);
    if (emailError != null) {
      state = state.copyWith(errorMessage: emailError);
      return;
    }

    if (password.isEmpty) {
      state = state.copyWith(errorMessage: 'Password is required.');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.loginWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      state = state.copyWith(user: user, isLoading: false, isSuccess: true);
    } on Failure catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  /// Sign In with Google
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.signInWithGoogle();
      state = state.copyWith(user: user, isLoading: false, isSuccess: true);
    } on Failure catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  /// Forgot Password - Reset Password Link
  Future<bool> forgotPassword(String email) async {
    final emailError = validateEmail(email);
    if (emailError != null) {
      state = state.copyWith(errorMessage: emailError);
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.sendPasswordResetEmail(email.trim());
      state = state.copyWith(isLoading: false);
      return true;
    } on Failure catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  /// Sign Out current user session
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.signOut();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Update user profile (Name, Mobile, Department)
  Future<bool> updateProfile({
    required String fullName,
    String? mobile,
    String? department,
  }) async {
    if (fullName.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Full Name is required.');
      return false;
    }

    final currentUser = state.user;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: 'User session not found.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = ref.read(authRepositoryProvider);
      final updatedUser = await repository.updateUserProfile(
        uid: currentUser.uid,
        fullName: fullName.trim(),
        mobile: mobile?.trim().isNotEmpty == true ? mobile!.trim() : null,
        department: department?.trim().isNotEmpty == true ? department!.trim() : null,
      );
      state = state.copyWith(user: updatedUser, isLoading: false, isSuccess: true);
      return true;
    } on Failure catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  /// Change Password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (currentPassword.isEmpty) {
      state = state.copyWith(errorMessage: 'Current password is required.');
      return false;
    }
    final pwdErr = validatePassword(newPassword);
    if (pwdErr != null) {
      state = state.copyWith(errorMessage: pwdErr);
      return false;
    }
    if (newPassword != confirmPassword) {
      state = state.copyWith(errorMessage: 'New passwords do not match.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } on Failure catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  /// Delete Account
  Future<bool> deleteAccount({required String password}) async {
    if (password.isEmpty) {
      state = state.copyWith(errorMessage: 'Password is required to confirm deletion.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.deleteAccount(password: password);
      state = const AuthState();
      return true;
    } on Failure catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
      return false;
    }
  }

  /// Reset Auth success/error states
  void resetState() {
    state = state.copyWith(errorMessage: null, isSuccess: false);
  }

  // ==========================================
  // VALIDATION HELPERS
  // ==========================================

  /// Check email structure
  String? validateEmail(String email) {
    if (email.trim().isEmpty) {
      return 'Email address is required.';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email.trim())) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  /// Check password criteria (length >= 8)
  String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required.';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    return null;
  }
}
