import 'package:icem_bus/features/payment/domain/entities/payment_entity.dart';

abstract class PaymentRepository {
  Future<PaymentEntity> submitPayment({
    required String uid,
    required String passId,
    required String studentName,
    required double amount,
    required String transactionId,
    required DateTime paymentDate,
    required String paymentStatus,
    required String paymentMethod,
    required String route,
    required String routeId,
    required String boarding,
    required String destination,
    required String distance,
    required double fare,
  });

  Stream<List<PaymentEntity>> watchStudentPayments(String uid);
}
