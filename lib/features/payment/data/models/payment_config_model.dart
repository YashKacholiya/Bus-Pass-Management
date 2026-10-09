import 'package:icem_bus/features/payment/domain/entities/payment_config_entity.dart';

class PaymentConfigModel extends PaymentConfigEntity {
  const PaymentConfigModel({
    required super.upiId,
    required super.upiDisplayName,
    required super.upiQrAsset,
    super.upiQrNetworkUrl,
    required super.razorpayKeyId,
    super.currency = 'INR',
    super.defaultFee = 4500.0,
    super.environment = 'TEST',
    super.isManualUpiEnabled = true,
  });

  /// Institutional Default Configuration
  factory PaymentConfigModel.initial() {
    return const PaymentConfigModel(
      upiId: '8766629441@axl',
      upiDisplayName: 'Yash Mahendra Kacholiya',
      upiQrAsset: 'assets/images/college_upi_qr.png',
      upiQrNetworkUrl: null,
      razorpayKeyId: '', // To be configured by Admin via Razorpay Dashboard
      currency: 'INR',
      defaultFee: 4500.0,
      environment: 'TEST',
      isManualUpiEnabled: true,
    );
  }

  factory PaymentConfigModel.defaultConfig() => PaymentConfigModel.initial();

  factory PaymentConfigModel.fromMap(Map<String, dynamic> map) {
    return PaymentConfigModel(
      upiId: (map['upiId'] as String?)?.trim().isNotEmpty == true
          ? (map['upiId'] as String).trim()
          : '8766629441@axl',
      upiDisplayName: (map['upiDisplayName'] as String?)?.trim().isNotEmpty == true
          ? (map['upiDisplayName'] as String).trim()
          : 'Yash Mahendra Kacholiya',
      upiQrAsset: (map['upiQrAsset'] as String?)?.trim().isNotEmpty == true
          ? (map['upiQrAsset'] as String).trim()
          : 'assets/images/college_upi_qr.png',
      upiQrNetworkUrl: map['upiQrNetworkUrl'] as String?,
      razorpayKeyId: (map['razorpayKeyId'] as String? ?? '').trim(),
      currency: (map['currency'] as String? ?? 'INR').trim(),
      defaultFee: (map['defaultFee'] as num?)?.toDouble() ?? 4500.0,
      environment: (map['environment'] as String? ?? 'TEST').trim().toUpperCase(),
      isManualUpiEnabled: map['isManualUpiEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'upiId': upiId,
      'upiDisplayName': upiDisplayName,
      'upiQrAsset': upiQrAsset,
      'upiQrNetworkUrl': upiQrNetworkUrl,
      'razorpayKeyId': razorpayKeyId,
      'currency': currency,
      'defaultFee': defaultFee,
      'environment': environment,
      'isManualUpiEnabled': isManualUpiEnabled,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}
