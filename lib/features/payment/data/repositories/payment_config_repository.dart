import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/features/payment/data/models/payment_config_model.dart';
import 'package:icem_bus/features/payment/domain/entities/payment_config_entity.dart';

final paymentConfigRepositoryProvider = Provider<PaymentConfigRepository>((ref) {
  try {
    return PaymentConfigRepository(firestore: FirebaseFirestore.instance);
  } catch (_) {
    return PaymentConfigRepository(firestore: null);
  }
});

final paymentConfigStreamProvider = StreamProvider<PaymentConfigEntity>((ref) {
  try {
    return ref.watch(paymentConfigRepositoryProvider).watchPaymentConfig();
  } catch (_) {
    return Stream.value(PaymentConfigModel.initial());
  }
});

class PaymentConfigRepository {
  final FirebaseFirestore? firestore;

  PaymentConfigRepository({this.firestore});

  static const String _collection = 'system_config';
  static const String _doc = 'payment_config';

  /// Stream real-time payment settings from Firestore with default fallback
  Stream<PaymentConfigEntity> watchPaymentConfig() {
    final fs = firestore;
    if (fs == null) {
      return Stream.value(PaymentConfigModel.initial());
    }
    try {
      return fs
          .collection(_collection)
          .doc(_doc)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return PaymentConfigModel.initial();
        }
        return PaymentConfigModel.fromMap(snapshot.data()!);
      }).handleError((_) => PaymentConfigModel.initial());
    } catch (_) {
      return Stream.value(PaymentConfigModel.initial());
    }
  }

  /// Get current config once
  Future<PaymentConfigEntity> getPaymentConfig() async {
    final fs = firestore;
    if (fs == null) return PaymentConfigModel.initial();
    try {
      final doc = await fs.collection(_collection).doc(_doc).get();
      if (!doc.exists || doc.data() == null) {
        return PaymentConfigModel.initial();
      }
      return PaymentConfigModel.fromMap(doc.data()!);
    } catch (_) {
      return PaymentConfigModel.initial();
    }
  }

  /// Update payment configuration (Admin only)
  Future<void> updatePaymentConfig(PaymentConfigEntity config) async {
    final fs = firestore;
    if (fs == null) return;

    final model = PaymentConfigModel(
      upiId: config.upiId,
      upiDisplayName: config.upiDisplayName,
      upiQrAsset: config.upiQrAsset,
      upiQrNetworkUrl: config.upiQrNetworkUrl,
      razorpayKeyId: config.razorpayKeyId,
      currency: config.currency,
      defaultFee: config.defaultFee,
      environment: config.environment,
      isManualUpiEnabled: config.isManualUpiEnabled,
    );

    await fs
        .collection(_collection)
        .doc(_doc)
        .set(model.toMap(), SetOptions(merge: true));
  }
}
