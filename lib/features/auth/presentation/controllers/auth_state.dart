import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';

class AuthState {
  final UserEntity? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  AuthState copyWith({
    UserEntity? user,
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // Allow setting to null to clear errors
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  bool get isAuthenticated => user != null;
}
