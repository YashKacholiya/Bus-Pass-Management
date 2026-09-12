import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/features/driver/data/repositories/driver_repository.dart';

final driversListStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repository = ref.watch(driverRepositoryProvider);
  return repository.getDriversStream();
});
