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
  }) async {
    try {
      final paymentRef = firestore.collection('payments').doc();
      final now = DateTime.now();

      final model = PaymentModel(
        paymentId: paymentRef.id,
        applicationId: applicationId,
        studentId: studentId,
        studentName: studentName,
        routeId: routeId,
        routeName: routeName,
        amount: amount,
        currency: 'INR',
        razorpayOrderId: razorpayOrderId,
        paymentStatus: paymentStatus,
        paymentMethod: paymentMethod,
        utrNumber: utrNumber,
        createdAt: now,
      );

      await paymentRef.set(model.toMap());
      return model;
    } catch (e) {
      throw ServerFailure('Failed to create payment record: ${e.toString()}');
    }
  }

  @override
  Future<PaymentEntity> submitManualUpiPayment({
    required String applicationId,
    required String studentId,
    required String studentName,
    required String routeId,
    required String routeName,
    required double amount,
    required String utrNumber,
  }) async {
    try {
      final paymentRef = firestore.collection('payments').doc();
      final now = DateTime.now();

      final model = PaymentModel(
        paymentId: paymentRef.id,
        applicationId: applicationId,
        studentId: studentId,
        studentName: studentName,
        routeId: routeId,
        routeName: routeName,
        amount: amount,
        currency: 'INR',
        paymentStatus: 'submitted_for_verification',
        paymentMethod: 'UPI Manual QR',
        utrNumber: utrNumber,
        createdAt: now,
      );

      // Write to payments collection
      await paymentRef.set(model.toMap());

      // Also write to receipts collection so legacy streams and reports immediately pick it up
      await firestore.collection('receipts').doc(paymentRef.id).set(model.toMap());

      // Update application to Pending Verification
      final appRef = firestore.collection('bus_pass_applications').doc(applicationId);
      final appSnap = await appRef.get();
      if (appSnap.exists) {
        await appRef.update({
          'paymentStatus': 'Pending Verification',
          'status': 'Payment Pending',
          'passStatus': 'Payment Pending',
          'paymentId': paymentRef.id,
          'utrNumber': utrNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update bus_passes doc as well so student dashboard knows it's submitted for verification
      final passRef = firestore.collection('bus_passes').doc(studentId);
      final passSnap = await passRef.get();
      if (passSnap.exists) {
        await passRef.update({
          'paymentStatus': 'Pending Verification',
          'status': 'Payment Pending',
          'passStatus': 'Payment Pending',
          'utrNumber': utrNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return model;
    } catch (e) {
      throw ServerFailure('Failed to submit manual UPI payment: ${e.toString()}');
    }
  }

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
      final docRef = firestore.collection('payments').doc();
      final model = PaymentModel(
        paymentId: docRef.id,
        applicationId: passId,
        studentId: uid,
        studentName: studentName,
        routeId: routeId,
        routeName: route,
        amount: amount,
        currency: 'INR',
        razorpayPaymentId: transactionId,
        paymentStatus: paymentStatus,
        paymentMethod: paymentMethod,
        receiptId: docRef.id,
        createdAt: paymentDate,
        paidAt: paymentStatus.toLowerCase() == 'paid' ? paymentDate : null,
      );

      final map = model.toMap();
      map['boarding'] = boarding;
      map['destination'] = destination;
      map['distance'] = distance;
      map['fare'] = fare;

      await docRef.set(map);
      await firestore.collection('receipts').doc(docRef.id).set(map);

      return model;
    } catch (e) {
      throw ServerFailure('Failed to submit payment: ${e.toString()}');
    }
  }

  @override
  Stream<List<PaymentEntity>> watchStudentPayments(String uid) {
    return firestore
        .collection('payments')
        .where('studentId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            // Check fallback for any legacy docs queried by 'uid'
            return <PaymentEntity>[];
          }
          return snapshot.docs
              .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  @override
  Future<PaymentEntity?> getPaymentById(String paymentId) async {
    try {
      final doc = await firestore.collection('payments').doc(paymentId).get();
      if (doc.exists && doc.data() != null) {
        return PaymentModel.fromMap(doc.data()!, doc.id);
      }
      final rDoc = await firestore.collection('receipts').doc(paymentId).get();
      if (rDoc.exists && rDoc.data() != null) {
        return PaymentModel.fromMap(rDoc.data()!, rDoc.id);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
