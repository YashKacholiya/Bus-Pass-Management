import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  /// Sign up a new user with email and password
  Future<UserEntity> signUpWithEmailAndPassword({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? mobile,
    String? collegeId,
  });

  /// Log in an existing user with email and password
  Future<UserEntity> loginWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Sign in/up with Google
  Future<UserEntity> signInWithGoogle();

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email);

  /// Sign out the current user
  Future<void> signOut();

  /// Retrieve the current authenticated user's Firestore profile
  Future<UserEntity?> getCurrentUser();

  /// Update the authenticated user's profile in Firestore and Auth
  Future<UserEntity> updateUserProfile({
    required String uid,
    required String fullName,
    String? mobile,
    String? department,
  });

  /// Change password using current password re-authentication
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Delete the current authenticated user account and Firestore document
  Future<void> deleteAccount({
    required String password,
  });
}
