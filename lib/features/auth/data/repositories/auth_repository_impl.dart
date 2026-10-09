import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:icem_bus/core/errors/failures.dart';
import 'package:icem_bus/features/auth/data/models/user_model.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
import 'package:icem_bus/features/auth/domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    firebaseAuth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );
});

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  AuthRepositoryImpl({
    required this.firebaseAuth,
    required this.firestore,
  });

  @override
  Future<UserEntity> signUpWithEmailAndPassword({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? mobile,
    String? collegeId,
  }) async {
    try {
      // 1. Create Firebase Auth user
      final UserCredential credential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthFailure('Failed to register user.');
      }

      // 2. Send email verification link
      await firebaseUser.sendEmailVerification();

      // 3. Create Firestore User profile
      final userModel = UserModel(
        uid: firebaseUser.uid,
        fullName: fullName,
        email: email,
        role: role,
        photoUrl: firebaseUser.photoURL,
        isEmailVerified: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
        mobile: mobile,
        collegeId: collegeId,
      );

      await firestore.collection('users').doc(firebaseUser.uid).set(userModel.toMap());

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'An authentication error occurred.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<UserEntity> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Sign in with Firebase Auth
      final UserCredential credential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthFailure('User login failed.');
      }

      // 2. Fetch User Profile from Firestore
      final DocumentSnapshot doc = await firestore.collection('users').doc(firebaseUser.uid).get();

      if (!doc.exists) {
        // Fallback: If user doc wasn't created, populate default profile
        final fallbackUser = UserModel(
          uid: firebaseUser.uid,
          fullName: firebaseUser.displayName ?? 'College Student',
          email: firebaseUser.email ?? email,
          role: 'Engineering Student',
          photoUrl: firebaseUser.photoURL,
          isEmailVerified: firebaseUser.emailVerified,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );
        await firestore.collection('users').doc(firebaseUser.uid).set(fallbackUser.toMap());
        return fallbackUser;
      }

      // Load Firestore model and update verification status if changed
      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      UserModel userModel = UserModel.fromMap(data);

      if (userModel.isEmailVerified != firebaseUser.emailVerified) {
        userModel = userModel.copyWith(isEmailVerified: firebaseUser.emailVerified);
        await firestore.collection('users').doc(firebaseUser.uid).update({
          'isEmailVerified': firebaseUser.emailVerified,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Invalid email or password.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<UserEntity> signInWithGoogle() async {
    try {
      // 1. Ensure Google Sign In is initialized (Required in v7.0.0+)
      await GoogleSignIn.instance.initialize();

      // 2. Trigger Google Sign In flow
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

      // 3. Fetch authentication details
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw const AuthFailure('Google authentication failed: Missing ID Token.');
      }

      // 4. Create Firebase auth credentials (accessToken is no longer returned by default in v7)
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      // 5. Sign in to Firebase Auth
      final UserCredential userCredential = await firebaseAuth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw const AuthFailure('Google authentication failed.');
      }

      // 6. Check if user already has a profile in Firestore
      final DocumentSnapshot doc = await firestore.collection('users').doc(firebaseUser.uid).get();

      if (!doc.exists) {
        // Create new user profile, defaulting role to Engineering Student
        final newUser = UserModel(
          uid: firebaseUser.uid,
          fullName: firebaseUser.displayName ?? googleUser.displayName ?? 'Student',
          email: firebaseUser.email ?? googleUser.email,
          role: 'Engineering Student',
          photoUrl: firebaseUser.photoURL ?? googleUser.photoUrl,
          isEmailVerified: true, // Google accounts are verified
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );

        await firestore.collection('users').doc(firebaseUser.uid).set(newUser.toMap());
        return newUser;
      } else {
        // Load existing user profile
        final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return UserModel.fromMap(data);
      }
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Google Sign-In failed.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Failed to send password reset email.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await firebaseAuth.signOut();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      throw ServerFailure('Sign out failed: ${e.toString()}');
    }
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    try {
      final User? firebaseUser = firebaseAuth.currentUser;
      if (firebaseUser == null) return null;

      try {
        final DocumentSnapshot doc = await firestore.collection('users').doc(firebaseUser.uid).get();
        if (doc.exists) {
          final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return UserModel.fromMap(data);
        }
      } catch (_) {
        // Fallback below if Firestore query fails
      }

      // Return fallback user model when firebaseUser is authenticated but Firestore check is offline/empty
      return UserModel(
        uid: firebaseUser.uid,
        fullName: firebaseUser.displayName ?? 'Student User',
        email: firebaseUser.email ?? '',
        role: 'Engineering Student',
        photoUrl: firebaseUser.photoURL,
        isEmailVerified: firebaseUser.emailVerified,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserEntity> updateUserProfile({
    required String uid,
    required String fullName,
    String? mobile,
    String? department,
  }) async {
    try {
      final updates = <String, dynamic>{
        'fullName': fullName.trim(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };
      if (mobile != null) {
        updates['mobile'] = mobile.trim();
      }
      if (department != null) {
        updates['department'] = department.trim();
      }

      // Update Firestore document
      await firestore.collection('users').doc(uid).update(updates);

      // Update Firebase Auth display name if current user matches
      if (firebaseAuth.currentUser?.uid == uid) {
        await firebaseAuth.currentUser?.updateDisplayName(fullName.trim());
      }

      // Fetch and return updated model
      final doc = await firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }

      // Fallback
      return UserModel(
        uid: uid,
        fullName: fullName.trim(),
        email: firebaseAuth.currentUser?.email ?? '',
        role: 'Administrator',
        isEmailVerified: firebaseAuth.currentUser?.emailVerified ?? true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mobile: mobile,
        department: department,
      );
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to update user profile.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null || user.email == null) {
        throw const AuthFailure('No authenticated user session found.');
      }

      // Re-authenticate with current credentials
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);

      // Update password
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const AuthFailure('The current password entered is incorrect.');
      } else if (e.code == 'weak-password') {
        throw const AuthFailure('The new password is too weak. Please use at least 8 characters.');
      } else if (e.code == 'requires-recent-login') {
        throw const AuthFailure('Security requirement: Please log in again before changing password.');
      }
      throw AuthFailure(e.message ?? 'Failed to change password.');
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteAccount({
    required String password,
  }) async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null || user.email == null) {
        throw const AuthFailure('No authenticated user session found.');
      }

      final uid = user.uid;

      // Re-authenticate prior to sensitive account deletion
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);

      // Safely delete only this specific user's Firestore document
      await firestore.collection('users').doc(uid).delete();

      // Delete Firebase Auth account
      await user.delete();

      // Clear Google session if applicable
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const AuthFailure('Incorrect password. Account deletion aborted.');
      } else if (e.code == 'requires-recent-login') {
        throw const AuthFailure('Recent login required. Please sign in again and retry.');
      }
      throw AuthFailure(e.message ?? 'Failed to delete account.');
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure(e.toString());
    }
  }
}
