/// Base UseCase class for Clean Architecture.
/// [T] represents the return type of the use case.
/// [Params] represents the parameters required to run the usecase.
abstract class UseCase<T, Params> {
  Future<T> call(Params params);
}

/// Use this class if a UseCase does not require any parameters.
class NoParams {
  const NoParams();
}
