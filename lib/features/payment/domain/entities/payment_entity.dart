import 'package:equatable/equatable.dart';

class PaymentEntity extends Equatable {
  final String receiptId;
  final String uid;
  final String passId;
  final String studentName;
  final double amount;
  final String transactionId;
  final DateTime paymentDate;
  final String paymentStatus;
  final String paymentMethod;
  final String route;
  final String routeId;
  final String boarding;
  final String destination;
  final String distance;
  final double fare;

  const PaymentEntity({
    required this.receiptId,
    required this.uid,
    required this.passId,
    required this.studentName,
    required this.amount,
    required this.transactionId,
    required this.paymentDate,
    required this.paymentStatus,
    this.paymentMethod = '',
    this.route = '',
    this.routeId = '',
    this.boarding = '',
    this.destination = '',
    this.distance = '',
    this.fare = 0.0,
  });

  @override
  List<Object?> get props => [
        receiptId,
        uid,
        passId,
        studentName,
        amount,
        transactionId,
        paymentDate,
        paymentStatus,
        paymentMethod,
        route,
        routeId,
        boarding,
        destination,
        distance,
        fare,
      ];
}
