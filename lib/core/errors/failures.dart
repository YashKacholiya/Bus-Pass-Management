/// Base class representing errors/failures in the application.
abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

/// Failure representing server or database connectivity/data errors (e.g. Firestore, Cloud Functions).
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'A server error occurred. Please try again.']);
}

/// Failure representing network connectivity errors.
class ConnectionFailure extends Failure {
  const ConnectionFailure([super.message = 'No internet connection.']);
}

/// Failure representing authentication-related errors.
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed.']);
}

/// Failure representing storage-related errors (e.g. SharedPreferences, Local DB).
class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Failed to load local settings.']);
}
