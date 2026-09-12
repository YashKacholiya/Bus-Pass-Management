import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/bus_pass/data/repositories/bus_pass_repository_impl.dart';
import 'package:icem_bus/features/bus_pass/domain/entities/bus_pass_entity.dart';

final busPassControllerProvider = NotifierProvider<BusPassController, AsyncValue<BusPassEntity?>>(BusPassController.new);

class BusPassController extends Notifier<AsyncValue<BusPassEntity?>> {
  StreamSubscription<BusPassEntity?>? _subscription;

  @override
  AsyncValue<BusPassEntity?> build() {
    // Reactively watch user session changes
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    ref.onDispose(() {
      _subscription?.cancel();
    });

    if (user != null) {
      _subscription?.cancel();
      _subscription = ref.read(busPassRepositoryProvider).watchBusPass(user.uid).listen(
        (pass) {
          state = AsyncValue.data(pass);
        },
        onError: (err, stack) {
          state = AsyncValue.error(err, stack);
        },
      );
    } else {
      return const AsyncValue.data(null);
    }
    return const AsyncValue.loading();
  }

  /// Load bus pass details from database (falls back to single load if needed)
  Future<void> loadBusPass(String uid) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(busPassRepositoryProvider);
      final pass = await repository.getBusPass(uid);
      state = AsyncValue.data(pass);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Submit a new bus pass application
  Future<bool> applyForPass({
    required String route,
    required String routeId,
    required String boardingStop,
    required String destinationStop,
    required double fare,
    String? distance,
    String? department,
  }) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final repository = ref.read(busPassRepositoryProvider);
      final pass = await repository.applyForBusPass(
        uid: user.uid,
        route: route,
        routeId: routeId,
        boardingStop: boardingStop,
        destinationStop: destinationStop,
        fare: fare,
        distance: distance,
        department: department,
      );
      state = AsyncValue.data(pass);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Request pass renewal
  Future<bool> renewPass() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final repository = ref.read(busPassRepositoryProvider);
      final pass = await repository.renewBusPass(user.uid);
      state = AsyncValue.data(pass);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Process simulated payment outcomes
  Future<bool> completePassPayment({required bool isSuccess}) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final repository = ref.read(busPassRepositoryProvider);
      final pass = await repository.updatePassPayment(uid: user.uid, isSuccess: isSuccess);
      state = AsyncValue.data(pass);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}
