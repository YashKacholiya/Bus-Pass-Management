import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/features/payment/domain/entities/payment_entity.dart';

class PaymentModel extends PaymentEntity {
  const PaymentModel({
    required super.receiptId,
    required super.uid,
    required super.passId,
    required super.studentName,
    required super.amount,
    required super.transactionId,
    required super.paymentDate,
    required super.paymentStatus,
    super.paymentMethod = '',
    super.route = '',
    super.routeId = '',
    super.boarding = '',
    super.destination = '',
    super.distance = '',
    super.fare = 0.0,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return PaymentModel(
      receiptId: id,
      uid: map['uid'] as String? ?? '',
      passId: map['passId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      transactionId: map['transactionId'] as String? ?? '',
      paymentDate: (map['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymentStatus: map['paymentStatus'] as String? ?? 'Pending',
      paymentMethod: map['paymentMethod'] as String? ?? '',
      route: map['route'] as String? ?? '',
      routeId: map['routeId'] as String? ?? '',
      boarding: map['boarding'] as String? ?? '',
      destination: map['destination'] as String? ?? '',
      distance: map['distance'] as String? ?? '',
      fare: (map['fare'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'receiptId': receiptId,
      'uid': uid,
      'passId': passId,
      'studentName': studentName,
      'amount': amount,
      'transactionId': transactionId,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'route': route,
      'routeId': routeId,
      'boarding': boarding,
      'destination': destination,
      'distance': distance,
      'fare': fare,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
