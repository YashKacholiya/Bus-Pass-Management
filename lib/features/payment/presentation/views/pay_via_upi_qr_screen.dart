import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';

/// DEPRECATED: Manual UPI QR and UTR workflow has been removed per production Razorpay specification.
/// All payments must proceed through the official Razorpay Standard Checkout SDK.
@Deprecated('Use Razorpay checkout instead')
class PayViaUpiQrScreen extends StatelessWidget {
  final String applicationId;
  final String routeName;
  final String routeId;
  final double amount;
  final String? studentName;

  const PayViaUpiQrScreen({
    super.key,
    required this.applicationId,
    required this.routeName,
    required this.routeId,
    required this.amount,
    this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go(AppRoutes.studentDashboard),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.payment_rounded, size: 64, color: AppColors.primaryCrimson),
              const SizedBox(height: 20),
              const Text(
                'Direct Razorpay Checkout Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Manual QR scanning and manual UTR submission have been deprecated. All student payments proceed through secure Razorpay Standard Checkout.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.studentPayment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCrimson,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Proceed to Razorpay Checkout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
