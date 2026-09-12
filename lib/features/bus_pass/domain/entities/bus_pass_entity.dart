class BusPassEntity {
  final String uid;
  final String passId;
  final String route;
  final String routeId;
  final String boardingStop;
  final String destinationStop;
  final double fare;
  final String? busNumber;
  final String status; // 'Approved', 'Pending', 'Expired', 'None'
  final String paymentStatus; // 'Paid', 'Unpaid', 'Pending'
  final DateTime expiryDate;
  final String? department;
  final String? distance;
  final String? qrCode;
  final DateTime? validFrom;
  final String? busId;

  const BusPassEntity({
    required this.uid,
    required this.passId,
    required this.route,
    required this.routeId,
    required this.boardingStop,
    required this.destinationStop,
    required this.fare,
    this.busNumber,
    required this.status,
    required this.paymentStatus,
    required this.expiryDate,
    this.department,
    this.distance,
    this.qrCode,
    this.validFrom,
    this.busId,
  });
}
