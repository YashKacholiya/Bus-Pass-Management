import 'package:equatable/equatable.dart';

class PaymentEntity extends Equatable {
  final String paymentId;
  final String applicationId;
  final String studentId;
  final String studentName;
  final String routeId;
  final String routeName;
  final double amount;
  final String currency;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final String paymentStatus; // created, pending, processing, paid, failed, submitted_for_verification, cancelled, refunded
  final String paymentMethod; // Razorpay, UPI Manual QR, Cash (Admin)
  final String? utrNumber;
  final String? receiptId;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? verifiedAt;

  // Backwards compatibility getters
  String get uid => studentId;
  String get passId => applicationId;
  DateTime get paymentDate => paidAt ?? createdAt;
  String get route => routeName;
  String get transactionId => razorpayPaymentId ?? utrNumber ?? paymentId;
  String get boarding => '';
  String get destination => '';
  String get distance => '';
  double get fare => amount;

  const PaymentEntity({
    required this.paymentId,
    required this.applicationId,
    required this.studentId,
    required this.studentName,
    required this.routeId,
    required this.routeName,
    required this.amount,
    this.currency = 'INR',
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    required this.paymentStatus,
    required this.paymentMethod,
    this.utrNumber,
    this.receiptId,
    required this.createdAt,
    this.paidAt,
    this.verifiedAt,
  });

  bool get isPaid =>
      paymentStatus.toLowerCase() == 'paid' ||
      paymentStatus.toLowerCase() == 'success';

  bool get isPendingVerification =>
      paymentStatus == 'submitted_for_verification' ||
      paymentStatus == 'Pending Verification';

  @override
  List<Object?> get props => [
        paymentId,
        applicationId,
        studentId,
        studentName,
        routeId,
        routeName,
        amount,
        currency,
        razorpayOrderId,
        razorpayPaymentId,
        razorpaySignature,
        paymentStatus,
        paymentMethod,
        utrNumber,
        receiptId,
        createdAt,
        paidAt,
        verifiedAt,
      ];
}
