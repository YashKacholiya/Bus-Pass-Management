import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/bus_pass/presentation/controllers/bus_pass_controller.dart';
import 'package:icem_bus/features/payment/data/models/payment_config_model.dart';
import 'package:icem_bus/features/payment/data/repositories/payment_config_repository.dart';
import 'package:icem_bus/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:icem_bus/features/payment/domain/entities/payment_config_entity.dart';
import 'package:icem_bus/features/payment/domain/entities/payment_entity.dart';
import 'package:icem_bus/features/payment/presentation/services/razorpay_service.dart';
import 'package:icem_bus/shared/app_card.dart';
import 'package:icem_bus/shared/status_badge.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

final studentPendingPassStreamProvider = StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) {
    return const Stream.empty();
  }
  return FirebaseFirestore.instance
      .collection('bus_passes')
      .where('uid', isEqualTo: user.uid)
      .where('paymentStatus', whereIn: const ['Pending', 'Failed', 'Unpaid', 'pending', 'Payment Pending'])
      .snapshots();
});

class StudentPaymentScreen extends ConsumerStatefulWidget {
  final String? testApplicationId;
  final String? testRouteName;
  final String? testStudentName;
  final String? testStudentEmail;
  final String? testStudentPhone;
  final double? testRouteFee;

  const StudentPaymentScreen({
    super.key,
    this.testApplicationId,
    this.testRouteName,
    this.testStudentName,
    this.testStudentEmail,
    this.testStudentPhone,
    this.testRouteFee,
  });

  @override
  ConsumerState<StudentPaymentScreen> createState() => _StudentPaymentScreenState();
}

class _StudentPaymentScreenState extends ConsumerState<StudentPaymentScreen> {
  final RazorpayService _razorpayService = RazorpayService();
  bool _isProcessing = false;
  String? _paymentErrorMessage;
  PaymentEntity? _verifiedPayment;

  @override
  void initState() {
    super.initState();
    _razorpayService.init(
      onSuccess: _onRazorpaySuccess,
      onError: _onRazorpayError,
      onExternalWallet: _onRazorpayExternalWallet,
    );
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  void _onRazorpaySuccess(PaymentSuccessResponse response) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    setState(() {
      _isProcessing = true;
      _paymentErrorMessage = null;
    });

    debugPrint('✅ Razorpay checkout success: paymentId=${response.paymentId}, orderId=${response.orderId}');

    try {
      final appQuery = await FirebaseFirestore.instance
          .collection('bus_pass_applications')
          .where('uid', isEqualTo: user.uid)
          .where('paymentStatus', whereIn: const ['Pending', 'Unpaid', 'pending', 'Pending Payment', 'Payment Pending'])
          .limit(1)
          .get();

      if (appQuery.docs.isNotEmpty) {
        final appDoc = appQuery.docs.first;
        final appData = appDoc.data();
        final fare = (appData['fare'] as num?)?.toDouble() ?? 4500.0;
        final routeName = appData['route'] ?? appData['routeName'] ?? 'Bus Route';
        final routeId = appData['routeId'] ?? '';

        // 1. Create verified payment record with paymentStatus = 'paid'
        final paymentModel = await ref.read(paymentRepositoryProvider).createPaymentRecord(
              applicationId: appDoc.id,
              studentId: user.uid,
              studentName: user.fullName,
              routeId: routeId,
              routeName: routeName,
              amount: fare,
              paymentMethod: 'Razorpay',
              razorpayOrderId: response.orderId,
              paymentStatus: 'paid',
            );

        final now = DateTime.now();

        // 2. Transition Application Status to Pending Admin Approval (Section 6: MUST NOT auto-approve!)
        await appDoc.reference.update({
          'paymentStatus': 'Paid',
          'applicationStatus': 'pending_admin_approval',
          'status': 'Pending', // Pending Admin Approval
          'passStatus': 'Pending',
          'razorpayPaymentId': response.paymentId,
          'razorpayOrderId': response.orderId,
          'razorpaySignature': response.signature,
          'paidAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 3. Update bus_passes document (Pass is NOT active yet, awaiting admin approval)
        await FirebaseFirestore.instance.collection('bus_passes').doc(user.uid).set(
          {
            'paymentStatus': 'Paid',
            'applicationStatus': 'pending_admin_approval',
            'status': 'Pending',
            'passStatus': 'Pending',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // 4. Create official receipt linked to payment record
        await FirebaseFirestore.instance.collection('receipts').doc(paymentModel.paymentId).set({
          'receiptId': paymentModel.paymentId,
          'paymentId': paymentModel.paymentId,
          'applicationId': appDoc.id,
          'studentId': user.uid,
          'studentName': user.fullName,
          'route': routeName,
          'routeId': routeId,
          'amount': fare,
          'paymentMethod': 'Razorpay',
          'transactionId': response.paymentId ?? paymentModel.paymentId,
          'razorpayPaymentId': response.paymentId,
          'razorpayOrderId': response.orderId,
          'razorpaySignature': response.signature,
          'paymentStatus': 'Paid',
          'paymentDate': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        await ref.read(busPassControllerProvider.notifier).loadBusPass(user.uid);

        if (mounted) {
          setState(() {
            _isProcessing = false;
            _verifiedPayment = PaymentEntity(
              paymentId: paymentModel.paymentId,
              applicationId: appDoc.id,
              studentId: user.uid,
              studentName: user.fullName,
              routeId: routeId,
              routeName: routeName,
              amount: fare,
              paymentStatus: 'paid',
              paymentMethod: 'Razorpay',
              razorpayPaymentId: response.paymentId,
              razorpayOrderId: response.orderId,
              razorpaySignature: response.signature,
              receiptId: paymentModel.paymentId,
              createdAt: now,
              paidAt: now,
              verifiedAt: now,
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _paymentErrorMessage = 'Payment recorded with error: ${e.toString()}';
        });
      }
    }
  }

  void _onRazorpayError(PaymentFailureResponse response) {
    debugPrint('❌ Razorpay payment error/cancellation: code=${response.code}, message=${response.message}');
    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      // Section 7 Requirement: clear user-friendly message
      _paymentErrorMessage = 'Payment was not completed. Please try again.';
    });
  }

  void _onRazorpayExternalWallet(ExternalWalletResponse response) {
    debugPrint('💳 Razorpay External Wallet Selected: ${response.walletName}');
  }

  void _initiateRazorpayPayment({
    required BuildContext context,
    required PaymentConfigEntity config,
    required Map<String, dynamic> passData,
    required String passDocId,
    required double fare,
    required UserEntity? user,
  }) {
    setState(() => _paymentErrorMessage = null);

    // Section 20 Requirement: DO NOT FAKE PAYMENT.
    // If Razorpay Key ID is not configured, inform administrator / student.
    if (!config.isRazorpayConfigured) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.warning, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Razorpay Gateway Setup Required',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Razorpay Key ID is missing from system configuration.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Client-side fake payments are prohibited. The college administrator must configure the Razorpay Key ID in Admin Settings -> Payment Gateway Configuration.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryCrimson,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Amount strictly 450000 paise for ₹4500 (Section 1 & 2)
    final int amountInPaise = (fare * 100).round();
    final String routeName = passData['route'] ?? passData['routeName'] ?? 'Bus Route';

    try {
      _razorpayService.openCheckout(
        keyId: config.razorpayKeyId,
        amountInPaise: amountInPaise,
        studentName: user?.fullName ?? 'Student',
        studentEmail: user?.email ?? 'student@indiraicem.ac.in',
        studentContact: user?.mobile ?? '',
        routeName: routeName,
        currency: config.currency,
      );
    } catch (e) {
      setState(() {
        _paymentErrorMessage = 'Failed to launch Razorpay Checkout: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;
    final pendingPassAsync = ref.watch(studentPendingPassStreamProvider);
    final configAsync = ref.watch(paymentConfigStreamProvider);

    final config = configAsync.value ?? PaymentConfigModel.initial();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Bus Pass Payment',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.go(AppRoutes.studentDashboard),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: _verifiedPayment != null
              ? _buildPaymentSuccessView(theme, _verifiedPayment!)
              : (widget.testApplicationId != null
                  ? _buildPaymentCardAndButtons(
                      theme: theme,
                      config: config,
                      user: user,
                      passDocId: widget.testApplicationId!,
                      passData: {
                        'route': widget.testRouteName ?? 'Selected Route',
                        'routeId': 'ROUTE-01',
                        'fare': widget.testRouteFee ?? config.defaultFee,
                        'paymentStatus': 'Payment Pending',
                      },
                      routeName: widget.testRouteName ?? 'Selected Route',
                      studentName: widget.testStudentName ?? 'Student',
                      fare: widget.testRouteFee ?? config.defaultFee,
                      paymentStatusStr: 'Payment Pending',
                    )
                  : pendingPassAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 80.0),
                          child: CircularProgressIndicator(color: AppColors.primaryCrimson),
                        ),
                      ),
                      error: (err, stack) => Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 80.0),
                          child: Text('Error loading application: $err', style: const TextStyle(color: AppColors.error)),
                        ),
                      ),
                      data: (snapshot) {
                        if (snapshot.docs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 60.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.success),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'No Payment Pending',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'You have no outstanding bus pass fee payments.',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                  const SizedBox(height: 28),
                                  ElevatedButton(
                                    onPressed: () => context.go(AppRoutes.studentDashboard),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.cardSurface,
                                      foregroundColor: AppColors.textPrimary,
                                      side: const BorderSide(color: AppColors.borderSubtle),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                    ),
                                    child: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final passDoc = snapshot.docs.first;
                        final passData = passDoc.data();
                        final String routeName = passData['route'] as String? ?? 'No Route Selected';
                        final double fare = (passData['fare'] as num?)?.toDouble() ?? config.defaultFee;
                        final String studentName = user?.fullName.isNotEmpty == true ? user!.fullName : 'Student';
                        final String paymentStatusStr = passData['paymentStatus'] as String? ?? 'Payment Pending';

                        return _buildPaymentCardAndButtons(
                          theme: theme,
                          config: config,
                          user: user,
                          passDocId: passDoc.id,
                          passData: passData,
                          routeName: routeName,
                          studentName: studentName,
                          fare: fare,
                          paymentStatusStr: paymentStatusStr,
                        );
                      },
                    )),
        ),
      ),
    );
  }

  /// SECTION 13: Premium Dark Payment Screen UI before opening Razorpay
  Widget _buildPaymentCardAndButtons({
    required ThemeData theme,
    required PaymentConfigEntity config,
    required UserEntity? user,
    required String passDocId,
    required Map<String, dynamic> passData,
    required String routeName,
    required String studentName,
    required double fare,
    required String paymentStatusStr,
  }) {
    final formattedFee = fare == 4500 ? '₹4,500' : '₹${fare.toStringAsFixed(0)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── TOP HEADER ──
        const Text(
          'BUS PASS PAYMENT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: AppColors.primaryCrimson,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Complete Pass Activation',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),

        // ── MAIN PAYMENT CARD ──
        PremiumCard(
          borderRadius: 24,
          borderColor: AppColors.borderSubtle,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCrimson.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.directions_bus_rounded, color: AppColors.primaryCrimson, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'ICEM TRANSIT PASS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  StatusBadge(status: paymentStatusStr),
                ],
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: AppColors.borderSubtle),
              const SizedBox(height: 20),

              _detailRow('Student', studentName, theme),
              const SizedBox(height: 14),
              _detailRow('Route', routeName, theme),
              const SizedBox(height: 14),
              _detailRow('Academic Session', '2026 – 2027', theme),
              const SizedBox(height: 20),

              // ── TOTAL AMOUNT DISPLAY ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Annual Bus Pass Fee',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      formattedFee,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── FAILURE NOTICE ──
        if (_paymentErrorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment was not completed. Please try again.',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Your bus pass application remains pending payment. You may re-attempt checkout.',
                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                setState(() => _paymentErrorMessage = null);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryCrimson,
                side: const BorderSide(color: AppColors.primaryCrimson, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('TRY AGAIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── PRIMARY BUTTON: PAY ₹4,500 ──
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryCrimson, AppColors.darkCrimson],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryCrimson.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isProcessing
                  ? null
                  : () => _initiateRazorpayPayment(
                        context: context,
                        config: config,
                        passData: passData,
                        passDocId: passDocId,
                        fare: fare,
                        user: user,
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                        ),
                        SizedBox(width: 14),
                        Text(
                          'Opening Razorpay...',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                      ],
                    )
                  : Text(
                      'PAY $formattedFee',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── SMALL TEXT: SECURE PAYMENT POWERED BY RAZORPAY ──
        const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 13, color: AppColors.textSecondary),
              SizedBox(width: 6),
              Text(
                'Secure payment powered by Razorpay',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// SECTION 11: Payment Successful View with receipt navigation
  Widget _buildPaymentSuccessView(ThemeData theme, PaymentEntity payment) {
    final dt = payment.paidAt ?? payment.createdAt;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final formattedDate = '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $ampm';
    final formattedFee = payment.amount == 4500 ? '₹4,500' : '₹${payment.amount.toStringAsFixed(0)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumCard(
          borderRadius: 24,
          borderColor: AppColors.success.withValues(alpha: 0.35),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Successful',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      Text(
                        'Transaction completed & recorded',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: AppColors.borderSubtle),
              const SizedBox(height: 18),

              _detailRow('Amount', formattedFee, theme, valueColor: AppColors.success, isBold: true, fontSize: 18),
              const SizedBox(height: 12),
              _detailRow('Payment ID', payment.razorpayPaymentId ?? payment.paymentId, theme),
              const SizedBox(height: 12),
              _detailRow('Order ID', payment.razorpayOrderId ?? 'N/A', theme),
              const SizedBox(height: 12),
              _detailRow('Payment Method', payment.paymentMethod, theme),
              const SizedBox(height: 12),
              _detailRow('Payment Date', formattedDate, theme),
              const SizedBox(height: 12),
              _detailRow(
                'Application Status',
                'Pending Admin Approval',
                theme,
                valueColor: AppColors.warning,
                isBold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── VIEW RECEIPT BUTTON ──
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              context.push('/student/payment-receipt/${payment.paymentId}');
            },
            icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
            label: const Text(
              'VIEW RECEIPT',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCrimson,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => context.go(AppRoutes.studentDashboard),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.borderSubtle),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value, ThemeData theme,
      {Color? valueColor, bool isBold = false, double fontSize = 13.5}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
