import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/features/payment/domain/entities/payment_entity.dart';

class PaymentModel extends PaymentEntity {
  const PaymentModel({
    required super.paymentId,
    required super.applicationId,
    required super.studentId,
    required super.studentName,
    required super.routeId,
    required super.routeName,
    required super.amount,
    super.currency = 'INR',
    super.razorpayOrderId,
    super.razorpayPaymentId,
    super.razorpaySignature,
    required super.paymentStatus,
    required super.paymentMethod,
    super.utrNumber,
    super.receiptId,
    required super.createdAt,
    super.paidAt,
    super.verifiedAt,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    final createdAt = parseDate(map['createdAt'] ?? map['paymentDate'], DateTime.now());
    final paidAt = map['paidAt'] != null ? parseDate(map['paidAt'], createdAt) : null;
    final verifiedAt = map['verifiedAt'] != null ? parseDate(map['verifiedAt'], createdAt) : null;

    final studentId = map['studentId'] as String? ?? map['uid'] as String? ?? '';
    final applicationId = map['applicationId'] as String? ?? map['passId'] as String? ?? '';
    final routeName = map['routeName'] as String? ?? map['route'] as String? ?? '';
    final routeId = map['routeId'] as String? ?? '';

    return PaymentModel(
      paymentId: id,
      applicationId: applicationId,
      studentId: studentId,
      studentName: map['studentName'] as String? ?? '',
      routeId: routeId,
      routeName: routeName,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'INR',
      razorpayOrderId: map['razorpayOrderId'] as String?,
      razorpayPaymentId: map['razorpayPaymentId'] as String? ?? map['transactionId'] as String?,
      razorpaySignature: map['razorpaySignature'] as String?,
      paymentStatus: map['paymentStatus'] as String? ?? 'pending',
      paymentMethod: map['paymentMethod'] as String? ?? 'Razorpay',
      utrNumber: map['utrNumber'] as String?,
      receiptId: map['receiptId'] as String? ?? id,
      createdAt: createdAt,
      paidAt: paidAt,
      verifiedAt: verifiedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'applicationId': applicationId,
      'studentId': studentId,
      'uid': studentId,
      'passId': applicationId,
      'studentName': studentName,
      'routeId': routeId,
      'routeName': routeName,
      'route': routeName,
      'amount': amount,
      'currency': currency,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'transactionId': razorpayPaymentId ?? utrNumber ?? paymentId,
      'razorpaySignature': razorpaySignature,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'utrNumber': utrNumber,
      'receiptId': receiptId ?? paymentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'paymentDate': Timestamp.fromDate(paidAt ?? createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
