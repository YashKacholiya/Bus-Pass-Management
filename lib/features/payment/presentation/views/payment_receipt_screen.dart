import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:icem_bus/features/payment/domain/entities/payment_entity.dart';
import 'package:icem_bus/shared/glass_card.dart';

class PaymentReceiptScreen extends ConsumerWidget {
  final String paymentId;
  final PaymentEntity? initialPayment;

  const PaymentReceiptScreen({
    super.key,
    required this.paymentId,
    this.initialPayment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Receipt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go(AppRoutes.studentDashboard),
        ),
      ),
      body: SafeArea(
        child: initialPayment != null
            ? _buildReceiptContent(context, initialPayment!)
            : FutureBuilder<PaymentEntity?>(
                future: ref.read(paymentRepositoryProvider).getPaymentById(paymentId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primaryCrimson));
                  }

                  final payment = snapshot.data;
                  if (payment == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textLight),
                          const SizedBox(height: 16),
                          const Text('Receipt record not found.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context.go(AppRoutes.studentDashboard),
                            child: const Text('Back to Dashboard'),
                          ),
                        ],
                      ),
                    );
                  }

                  return _buildReceiptContent(context, payment);
                },
              ),
      ),
    );
  }

  Widget _buildReceiptContent(BuildContext context, PaymentEntity payment) {
    final dateStr = payment.paidAt != null
        ? payment.paidAt.toString().substring(0, 16)
        : payment.createdAt.toString().substring(0, 16);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Column(
        children: [
          // Receipt Container
          GlassCard(
            blur: 16,
            borderColor: AppColors.primaryCrimson.withValues(alpha: 0.25),
            opacity: 0.05,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                        // Institution Header
                        Image.asset(
                          'assets/images/bus_logo.png',
                          height: 54,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.directions_bus_filled_rounded,
                            size: 48,
                            color: AppColors.primaryCrimson,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'ICEM',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: AppColors.primaryCrimson,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Bus Pass Payment Receipt',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: payment.isPaid
                                ? AppColors.success.withValues(alpha: 0.12)
                                : AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: payment.isPaid ? AppColors.success : AppColors.warning,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                payment.isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                                size: 16,
                                color: payment.isPaid ? AppColors.success : AppColors.warning,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                payment.isPaid ? 'PAID / VERIFIED' : 'PENDING VERIFICATION',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: payment.isPaid ? AppColors.success : AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Amount Block
                        Text(
                          payment.amount == 4500 ? '₹4,500' : '₹${payment.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryCrimson,
                          ),
                        ),
                        const Text(
                          'Total Fee Paid',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // Detailed receipt rows per Section 13
                        _receiptRow('Student', payment.studentName),
                        _receiptRow('Application ID', payment.applicationId),
                        _receiptRow('Route', payment.routeName),
                        _receiptRow('Amount', payment.amount == 4500 ? '₹4,500' : '₹${payment.amount.toStringAsFixed(0)}'),
                        _receiptRow('Payment Method', payment.paymentMethod),
                        if (payment.razorpayPaymentId != null && payment.razorpayPaymentId!.isNotEmpty)
                          _receiptRow('Razorpay Payment ID', payment.razorpayPaymentId!),
                        if (payment.utrNumber != null && payment.utrNumber!.isNotEmpty)
                          _receiptRow('UTR Reference', payment.utrNumber!),
                        _receiptRow('Payment Date', dateStr),
                        _receiptRow('Payment Status', payment.isPaid ? 'PAID / VERIFIED' : payment.paymentStatus.toUpperCase()),
                        _receiptRow('Receipt ID', payment.receiptId ?? payment.paymentId),

                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        const Row(
                          children: [
                            Icon(Icons.verified_user_rounded, color: AppColors.success, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Official system generated electronic receipt. Valid for college transport services.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Return Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.studentDashboard),
                      icon: const Icon(Icons.dashboard_rounded, color: AppColors.primaryCrimson),
                      label: const Text('Return to Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryCrimson)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryCrimson),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
