import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/features/bus_pass/domain/entities/bus_pass_entity.dart';

class BusPassModel extends BusPassEntity {
  const BusPassModel({
    required super.uid,
    required super.passId,
    super.passNumber,
    super.applicationId,
    super.studentId,
    required super.route,
    super.routeName,
    required super.routeId,
    required super.boardingStop,
    required super.destinationStop,
    required super.fare,
    super.busNumber,
    required super.status,
    required super.paymentStatus,
    super.applicationStatus,
    required super.expiryDate,
    super.validFrom,
    super.validUntil,
    super.department,
    super.course,
    super.year,
    super.distance,
    super.qrCode,
    super.busId,
    super.paymentId,
    super.createdAt,
    super.approvedAt,
  });

  /// Convert a Firestore Map into a BusPassModel
  factory BusPassModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String && val.isNotEmpty) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return fallback ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
      return null;
    }

    final String passId = map['passId'] as String? ?? '';
    final String? passNumber = map['passNumber'] as String? ??
        (passId.startsWith('ICEM-BP-') ? passId : null);

    final expiry = parseDate(
      map['validUntil'] ?? map['expiryDate'],
      DateTime.now().add(const Duration(days: 180)),
    );

    return BusPassModel(
      uid: map['uid'] as String? ?? map['studentId'] as String? ?? '',
      passId: passId,
      passNumber: passNumber,
      applicationId: map['applicationId'] as String? ?? map['passId'] as String?,
      studentId: map['studentId'] as String? ?? map['uid'] as String?,
      route: map['route'] as String? ?? map['routeName'] as String? ?? '',
      routeName: map['routeName'] as String? ?? map['route'] as String?,
      routeId: map['routeId'] as String? ?? '',
      boardingStop: map['boardingStop'] as String? ?? '',
      destinationStop: map['destinationStop'] as String? ?? '',
      fare: (map['fare'] as num?)?.toDouble() ?? 0.0,
      busNumber: map['busNumber'] as String?,
      status: map['passStatus'] as String? ??
          map['status'] as String? ??
          'Payment Pending',
      paymentStatus: map['paymentStatus'] as String? ?? 'Pending',
      applicationStatus: map['applicationStatus'] as String? ??
          (map['status'] == 'Approved' ? 'Approved' : map['status'] as String?),
      expiryDate: expiry,
      validFrom: parseNullableDate(map['validFrom']),
      validUntil: parseNullableDate(map['validUntil']) ?? expiry,
      department: map['department'] as String?,
      course: map['course'] as String?,
      year: map['year'] as String?,
      distance: map['distance'] as String?,
      qrCode: map['qrCode'] as String?,
      busId: map['busId'] as String?,
      paymentId: map['paymentId'] as String?,
      createdAt: parseNullableDate(map['createdAt']),
      approvedAt: parseNullableDate(map['approvedAt']),
    );
  }

  /// Convert a BusPassModel into a Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'studentId': studentId ?? uid,
      'passId': passId,
      if (passNumber != null && passNumber!.isNotEmpty) 'passNumber': passNumber,
      if (applicationId != null && applicationId!.isNotEmpty)
        'applicationId': applicationId,
      'route': route,
      'routeName': routeName ?? route,
      'routeId': routeId,
      'boardingStop': boardingStop,
      'destinationStop': destinationStop,
      'fare': fare,
      'busNumber': busNumber,
      'passStatus': status,
      'status': status,
      'paymentStatus': paymentStatus,
      if (applicationStatus != null) 'applicationStatus': applicationStatus,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'validUntil': Timestamp.fromDate(validUntil ?? expiryDate),
      if (validFrom != null) 'validFrom': Timestamp.fromDate(validFrom!),
      'department': department,
      'course': course,
      'year': year,
      'distance': distance,
      'qrCode': qrCode,
      'busId': busId,
      if (paymentId != null) 'paymentId': paymentId,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
    };
  }

  /// Create a copy of this model with modified fields
  BusPassModel copyWith({
    String? uid,
    String? passId,
    String? passNumber,
    String? applicationId,
    String? studentId,
    String? route,
    String? routeName,
    String? routeId,
    String? boardingStop,
    String? destinationStop,
    double? fare,
    String? busNumber,
    String? status,
    String? paymentStatus,
    String? applicationStatus,
    DateTime? expiryDate,
    DateTime? validFrom,
    DateTime? validUntil,
    String? department,
    String? course,
    String? year,
    String? distance,
    String? qrCode,
    String? busId,
    String? paymentId,
    DateTime? createdAt,
    DateTime? approvedAt,
  }) {
    return BusPassModel(
      uid: uid ?? this.uid,
      passId: passId ?? this.passId,
      passNumber: passNumber ?? this.passNumber,
      applicationId: applicationId ?? this.applicationId,
      studentId: studentId ?? this.studentId,
      route: route ?? this.route,
      routeName: routeName ?? this.routeName,
      routeId: routeId ?? this.routeId,
      boardingStop: boardingStop ?? this.boardingStop,
      destinationStop: destinationStop ?? this.destinationStop,
      fare: fare ?? this.fare,
      busNumber: busNumber ?? this.busNumber,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      applicationStatus: applicationStatus ?? this.applicationStatus,
      expiryDate: expiryDate ?? this.expiryDate,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      department: department ?? this.department,
      course: course ?? this.course,
      year: year ?? this.year,
      distance: distance ?? this.distance,
      qrCode: qrCode ?? this.qrCode,
      busId: busId ?? this.busId,
      paymentId: paymentId ?? this.paymentId,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }
}

