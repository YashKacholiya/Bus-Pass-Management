import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

typedef PaymentSuccessCallback = void Function(PaymentSuccessResponse response);
typedef PaymentErrorCallback = void Function(PaymentFailureResponse response);
typedef ExternalWalletCallback = void Function(ExternalWalletResponse response);

/// Service wrapper for official Razorpay Flutter SDK.
class RazorpayService {
  Razorpay? _razorpay;
  PaymentSuccessCallback? _onSuccess;
  PaymentErrorCallback? _onError;
  ExternalWalletCallback? _onExternalWallet;

  void init({
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
    ExternalWalletCallback? onExternalWallet,
  }) {
    dispose(); // Clean any previous instance
    _razorpay = Razorpay();
    _onSuccess = onSuccess;
    _onError = onError;
    _onExternalWallet = onExternalWallet;

    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void openCheckout({
    required String keyId,
    String? orderId,
    required int amountInPaise, // e.g. 450000 for ₹4500
    required String studentName,
    required String studentEmail,
    required String studentContact,
    required String routeName,
    String currency = 'INR',
  }) {
    if (_razorpay == null) {
      throw StateError('RazorpayService has not been initialized. Call init() first.');
    }

    final Map<String, dynamic> options = {
      'key': keyId,
      'amount': amountInPaise,
      'name': 'ICEM Bus Pass',
      'description': 'Pass Fee for $routeName',
      'currency': currency,
      'timeout': 300, // 5 minutes timeout
      'prefill': {
        'contact': studentContact.isNotEmpty ? studentContact : '9876543210',
        'email': studentEmail.isNotEmpty ? studentEmail : 'student@indiraicem.ac.in',
        'name': studentName.isNotEmpty ? studentName : 'Student',
      },
      'theme': {
        'color': '#8B0000', // ICEM Crimson Theme
      },
    };

    if (orderId != null && orderId.isNotEmpty) {
      options['order_id'] = orderId;
    }

    debugPrint('🚀 Opening Razorpay Checkout with Key: $keyId, Amount: $amountInPaise paise');
    _razorpay!.open(options);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('✅ Razorpay Payment Success: paymentId=${response.paymentId}, orderId=${response.orderId}');
    _onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('❌ Razorpay Payment Error: code=${response.code}, message=${response.message}');
    _onError?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('💳 Razorpay External Wallet: walletName=${response.walletName}');
    _onExternalWallet?.call(response);
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
    _onSuccess = null;
    _onError = null;
    _onExternalWallet = null;
  }
}
