class BusPassEntity {
  final String uid;
  final String passId;
  final String? passNumber;
  final String? applicationId;
  final String? studentId;
  final String route;
  final String? routeName;
  final String routeId;
  final String boardingStop;
  final String destinationStop;
  final double fare;
  final String? busNumber;
  final String status; // 'Active', 'Pending', 'Expired', 'Revoked', 'Rejected', 'Payment Pending'
  final String paymentStatus; // 'Paid', 'Pending', 'Unpaid', 'Failed'
  final String? applicationStatus; // 'Approved', 'Pending', 'Rejected'
  final DateTime expiryDate;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? department;
  final String? course;
  final String? year;
  final String? distance;
  final String? qrCode;
  final String? busId;
  final String? paymentId;
  final DateTime? createdAt;
  final DateTime? approvedAt;

  const BusPassEntity({
    required this.uid,
    required this.passId,
    this.passNumber,
    this.applicationId,
    this.studentId,
    required this.route,
    this.routeName,
    required this.routeId,
    required this.boardingStop,
    required this.destinationStop,
    required this.fare,
    this.busNumber,
    required this.status,
    required this.paymentStatus,
    this.applicationStatus,
    required this.expiryDate,
    this.validFrom,
    this.validUntil,
    this.department,
    this.course,
    this.year,
    this.distance,
    this.qrCode,
    this.busId,
    this.paymentId,
    this.createdAt,
    this.approvedAt,
  });

  String get effectivePassNumber =>
      (passNumber != null && passNumber!.isNotEmpty) ? passNumber! : passId;

  DateTime get effectiveValidUntil => validUntil ?? expiryDate;

  String get effectiveRouteName =>
      (routeName != null && routeName!.isNotEmpty) ? routeName! : route;

  String get effectiveStudentId =>
      (studentId != null && studentId!.isNotEmpty) ? studentId! : uid;

  bool get isExpired => DateTime.now().isAfter(effectiveValidUntil);

  bool get isRevoked => status.trim().toLowerCase() == 'revoked';

  bool get isPaid =>
      paymentStatus.trim().toLowerCase() == 'paid' ||
      paymentStatus.trim().toLowerCase() == 'success';

  bool get isApproved =>
      (applicationStatus != null &&
          applicationStatus!.trim().toLowerCase() == 'approved') ||
      status.trim().toLowerCase() == 'approved' ||
      status.trim().toLowerCase() == 'active';

  /// True ONLY when paymentStatus == 'Paid' AND applicationStatus == 'Approved'
  /// AND not expired AND not revoked
  bool get isActive =>
      isPaid &&
      isApproved &&
      !isExpired &&
      !isRevoked &&
      (status.trim().toLowerCase() == 'active' ||
          status.trim().toLowerCase() == 'approved');
}

