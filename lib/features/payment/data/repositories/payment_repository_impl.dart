import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/core/errors/failures.dart';
import 'package:icem_bus/features/payment/data/models/payment_model.dart';
import 'package:icem_bus/features/payment/domain/entities/payment_entity.dart';
import 'package:icem_bus/features/payment/domain/repositories/payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepositoryImpl(firestore: FirebaseFirestore.instance);
});

class PaymentRepositoryImpl implements PaymentRepository {
  final FirebaseFirestore firestore;

  PaymentRepositoryImpl({required this.firestore});

  @override
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
  }) async {
    try {
      final receiptRef = firestore.collection('receipts').doc();
      final model = PaymentModel(
        receiptId: receiptRef.id,
        uid: uid,
        passId: passId,
        studentName: studentName,
        amount: amount,
        transactionId: transactionId,
        paymentDate: paymentDate,
        paymentStatus: paymentStatus,
        paymentMethod: paymentMethod,
        route: route,
        routeId: routeId,
        boarding: boarding,
        destination: destination,
        distance: distance,
        fare: fare,
      );

      await receiptRef.set(model.toMap());
      return model;
    } catch (e) {
      throw ServerFailure('Failed to submit payment: ${e.toString()}');
    }
  }

  @override
  Stream<List<PaymentEntity>> watchStudentPayments(String uid) {
    return firestore
        .collection('receipts')
        .where('uid', isEqualTo: uid)
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
