import 'package:icem_bus/features/bus_pass/domain/entities/bus_pass_entity.dart';

abstract class BusPassRepository {
  /// Fetch a student's active bus pass profile by UID
  Future<BusPassEntity?> getBusPass(String uid);

  /// Watch student's bus pass status in real-time
  Stream<BusPassEntity?> watchBusPass(String uid);

  /// Apply for a new bus pass
  Future<BusPassEntity> applyForBusPass({
    required String uid,
    required String route,
    required String routeId,
    required String boardingStop,
    required String destinationStop,
    required double fare,
    String? distance,
    String? department,
  });

  /// Renew an expired or existing bus pass
  Future<BusPassEntity> renewBusPass(String uid);

  /// Update pass status and payment status in Firestore based on payment result
  Future<BusPassEntity> updatePassPayment({
    required String uid,
    required bool isSuccess,
  });
}
