import 'package:icem_bus/features/payment/domain/entities/payment_entity.dart';

abstract class PaymentRepository {
  /// Record initial payment attempt / record
  Future<PaymentEntity> createPaymentRecord({
    required String applicationId,
    required String studentId,
    required String studentName,
    required String routeId,
    required String routeName,
    required double amount,
    required String paymentMethod,
    String? razorpayOrderId,
    String? utrNumber,
    String paymentStatus = 'pending',
  });

  /// Submit manual UPI payment for administrative verification
  Future<PaymentEntity> submitManualUpiPayment({
    required String applicationId,
    required String studentId,
    required String studentName,
    required String routeId,
    required String routeName,
    required double amount,
    required String utrNumber,
  });

  /// Legacy submitPayment for backward compatibility
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

  Future<PaymentEntity?> getPaymentById(String paymentId);
}
