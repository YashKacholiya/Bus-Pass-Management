import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/features/bus_pass/domain/entities/bus_pass_entity.dart';

class BusPassModel extends BusPassEntity {
  const BusPassModel({
    required super.uid,
    required super.passId,
    required super.route,
    required super.routeId,
    required super.boardingStop,
    required super.destinationStop,
    required super.fare,
    super.busNumber,
    required super.status,
    required super.paymentStatus,
    required super.expiryDate,
    super.department,
    super.distance,
    super.qrCode,
    super.validFrom,
    super.busId,
  });

  /// Convert a Firestore Map into a BusPassModel
  factory BusPassModel.fromMap(Map<String, dynamic> map) {
    return BusPassModel(
      uid: map['uid'] as String? ?? '',
      passId: map['passId'] as String? ?? '',
      route: map['route'] as String? ?? '',
      routeId: map['routeId'] as String? ?? '',
      boardingStop: map['boardingStop'] as String? ?? '',
      destinationStop: map['destinationStop'] as String? ?? '',
      fare: (map['fare'] as num?)?.toDouble() ?? 0.0,
      busNumber: map['busNumber'] as String?,
      status: map['passStatus'] as String? ?? map['status'] as String? ?? 'None',
      paymentStatus: map['paymentStatus'] as String? ?? 'Unpaid',
      expiryDate: (map['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 180)),
      department: map['department'] as String?,
      distance: map['distance'] as String?,
      qrCode: map['qrCode'] as String?,
      validFrom: (map['validFrom'] as Timestamp?)?.toDate(),
      busId: map['busId'] as String?,
    );
  }

  /// Convert a BusPassModel into a Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'passId': passId,
      'route': route,
      'routeId': routeId,
      'boardingStop': boardingStop,
      'destinationStop': destinationStop,
      'fare': fare,
      'busNumber': busNumber,
      'passStatus': status,
      'status': status,
      'paymentStatus': paymentStatus,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'department': department,
      'distance': distance,
      'qrCode': qrCode,
      'validFrom': validFrom != null ? Timestamp.fromDate(validFrom!) : null,
      'busId': busId,
    };
  }

  /// Create a copy of this model with modified fields
  BusPassModel copyWith({
    String? uid,
    String? passId,
    String? route,
    String? routeId,
    String? boardingStop,
    String? destinationStop,
    double? fare,
    String? busNumber,
    String? status,
    String? paymentStatus,
    DateTime? expiryDate,
    String? department,
    String? distance,
    String? qrCode,
    DateTime? validFrom,
    String? busId,
  }) {
    return BusPassModel(
      uid: uid ?? this.uid,
      passId: passId ?? this.passId,
      route: route ?? this.route,
      routeId: routeId ?? this.routeId,
      boardingStop: boardingStop ?? this.boardingStop,
      destinationStop: destinationStop ?? this.destinationStop,
      fare: fare ?? this.fare,
      busNumber: busNumber ?? this.busNumber,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      expiryDate: expiryDate ?? this.expiryDate,
      department: department ?? this.department,
      distance: distance ?? this.distance,
      qrCode: qrCode ?? this.qrCode,
      validFrom: validFrom ?? this.validFrom,
      busId: busId ?? this.busId,
    );
  }
}
