import 'package:equatable/equatable.dart';

/// Centralized Payment Configuration Entity.
/// Admin can configure these values in Firestore (e.g. `system_config/payment_config`),
/// with secure fallback to institutional defaults.
class PaymentConfigEntity extends Equatable {
  final String upiId;
  final String upiDisplayName;
  final String upiQrAsset;
  final String? upiQrNetworkUrl;
  final String razorpayKeyId;
  final String currency;
  final double defaultFee;
  final String environment; // 'TEST' or 'LIVE'
  final bool isManualUpiEnabled;

  const PaymentConfigEntity({
    required this.upiId,
    required this.upiDisplayName,
    required this.upiQrAsset,
    this.upiQrNetworkUrl,
    required this.razorpayKeyId,
    this.currency = 'INR',
    this.defaultFee = 4500.0,
    this.environment = 'TEST',
    this.isManualUpiEnabled = true,
  });

  bool get isRazorpayConfigured =>
      razorpayKeyId.isNotEmpty && !razorpayKeyId.contains('YOUR_KEY');

  bool get isTestMode => environment.toUpperCase() == 'TEST';

  int get feeInPaise => (defaultFee * 100).round();

  @override
  List<Object?> get props => [
        upiId,
        upiDisplayName,
        upiQrAsset,
        upiQrNetworkUrl,
        razorpayKeyId,
        currency,
        defaultFee,
        environment,
        isManualUpiEnabled,
      ];
}
