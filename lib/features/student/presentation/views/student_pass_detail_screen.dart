// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:qr_flutter/qr_flutter.dart';

final singleApplicationDetailProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, applicationId) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .doc(applicationId)
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return data;
  });
});

class StudentPassDetailScreen extends ConsumerWidget {
  final String applicationId;

  const StudentPassDetailScreen({super.key, required this.applicationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appAsync = ref.watch(singleApplicationDetailProvider(applicationId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Application & Pass Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SafeArea(
        child: appAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryCrimson),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Error: $err', style: const TextStyle(color: AppColors.error)),
            ),
          ),
          data: (app) {
            if (app == null) {
              return const Center(
                child: Text('Application not found',
                    style: TextStyle(color: Color(0xFF64748B))),
              );
            }

            return _buildDetailContent(context, app);
          },
        ),
      ),
    );
  }

  Widget _buildDetailContent(BuildContext context, Map<String, dynamic> app) {
    final String? passNumber = app['passNumber'];
    final String appId = app['id'] ?? applicationId;

    final String paymentStatusStr =
        (app['paymentStatus'] as String? ?? 'Pending').trim();
    final bool isPaid = paymentStatusStr.toLowerCase() == 'paid' ||
        paymentStatusStr.toLowerCase() == 'success';

    final String rawStatus =
        (app['passStatus'] as String? ?? app['status'] as String? ?? 'Pending')
            .trim();
    final bool isApproved = rawStatus.toLowerCase() == 'approved' ||
        rawStatus.toLowerCase() == 'active';
    final bool isRejected = rawStatus.toLowerCase() == 'rejected';
    final bool isRevoked = rawStatus.toLowerCase() == 'revoked';

    // Validity dates
    DateTime? validFromDate;
    final vf = app['validFrom'];
    if (vf is Timestamp) validFromDate = vf.toDate();

    DateTime? validUntilDate;
    final vu = app['validUntil'] ?? app['expiryDate'];
    if (vu is Timestamp) validUntilDate = vu.toDate();

    final bool isExpired =
        validUntilDate != null && DateTime.now().isAfter(validUntilDate);

    // Active ONLY when paid AND approved AND not expired AND not revoked
    final bool isActivePass =
        isPaid && isApproved && !isExpired && !isRevoked;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Header
          _buildStatusBanner(
            isActive: isActivePass,
            isPaid: isPaid,
            isApproved: isApproved,
            isRejected: isRejected,
            isExpired: isExpired,
            isRevoked: isRevoked,
            rejectionReason: app['rejectionReason'],
          ),
          const SizedBox(height: 20),

          // Pass Number & Application Card
          _buildSectionCard(
            title: 'Credential Identifiers',
            icon: Icons.badge_rounded,
            children: [
              _buildRow('Pass Number', passNumber != null && passNumber.isNotEmpty ? passNumber : 'Generated upon Admin Approval', isBold: passNumber != null),
              _buildDivider(),
              _buildRow('Application ID', appId),
              if (app['approvedAt'] is Timestamp) ...[
                _buildDivider(),
                _buildRow('Approved At', _formatTimestamp(app['approvedAt'])),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Route & Stop Information
          _buildSectionCard(
            title: 'Route & Commute Details',
            icon: Icons.directions_bus_rounded,
            children: [
              _buildRow('Route Name', app['routeName'] ?? app['route'] ?? 'N/A'),
              _buildDivider(),
              _buildRow('Boarding Stop', app['boardingStop'] ?? 'N/A'),
              _buildDivider(),
              _buildRow('Destination', app['destinationStop'] ?? 'ICEM Campus'),
              if (app['busNumber'] != null) ...[
                _buildDivider(),
                _buildRow('Assigned Bus', app['busNumber'].toString()),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Validity Section
          _buildSectionCard(
            title: 'Pass Validity',
            icon: Icons.calendar_month_rounded,
            children: [
              _buildRow(
                'Valid From',
                validFromDate != null ? _formatDate(validFromDate) : 'Upon Approval',
              ),
              _buildDivider(),
              _buildRow(
                'Valid Until',
                validUntilDate != null ? _formatDate(validUntilDate) : 'Not Activated',
                color: isExpired ? AppColors.error : null,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Payment Details
          _buildSectionCard(
            title: 'Payment Information',
            icon: Icons.payments_rounded,
            children: [
              _buildRow('Amount / Fare', '₹${app['fare'] ?? app['amount'] ?? 0.0}'),
              _buildDivider(),
              _buildRow(
                'Payment Status',
                isPaid ? 'PAID ✓' : paymentStatusStr.toUpperCase(),
                color: isPaid ? AppColors.success : AppColors.warning,
                isBold: true,
              ),
              _buildDivider(),
              _buildRow('Payment Method', app['paymentMethod'] ?? 'Online / Razorpay'),
              if (app['razorpayPaymentId'] != null || app['paymentId'] != null) ...[
                _buildDivider(),
                _buildRow('Transaction Ref', app['razorpayPaymentId'] ?? app['paymentId']),
              ],
              if (app['paidAt'] is Timestamp) ...[
                _buildDivider(),
                _buildRow('Paid On', _formatTimestamp(app['paidAt'])),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Student Details
          _buildSectionCard(
            title: 'Student Information',
            icon: Icons.person_rounded,
            children: [
              _buildRow('Student Name', app['fullName'] ?? app['studentName'] ?? 'N/A'),
              _buildDivider(),
              _buildRow('PRN / Enrollment', app['prn'] ?? 'N/A'),
              _buildDivider(),
              _buildRow('Department', app['department'] ?? 'N/A'),
              if (app['course'] != null) ...[
                _buildDivider(),
                _buildRow('Course', app['course'].toString()),
              ],
              if (app['year'] != null) ...[
                _buildDivider(),
                _buildRow('Academic Year', app['year'].toString()),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // QR Code Section - ONLY shown for ACTIVE approved passes
          if (isActivePass) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryCrimson.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryCrimson),
                      const SizedBox(width: 8),
                      const Text(
                        'ACTIVE DIGITAL PASS QR',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryCrimson,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: QrImageView(
                      data: jsonEncode({
                        'type': 'ICEM_BUS_PASS',
                        'passNumber': passNumber ?? appId,
                        'passId': appId,
                        'studentId': app['uid'] ?? app['studentId'],
                      }),
                      version: QrVersions.auto,
                      size: 160,
                      gapless: false,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.primaryCrimson,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Scannable by ICEM transport conductors',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.studentDigitalPass),
                    icon: const Icon(Icons.badge_rounded),
                    label: const Text('View Full Digital Pass'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryCrimson,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, color: Color(0xFF64748B), size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'QR Code Inactive',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          !isPaid
                              ? 'Complete payment to proceed with pass approval.'
                              : (!isApproved
                                  ? 'Your payment is verified. QR code activates upon Admin approval.'
                                  : (isRevoked ? 'This pass has been revoked.' : 'This pass has expired.')),
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isPaid) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.studentPayment),
                icon: const Icon(Icons.payment_rounded),
                label: const Text('Complete Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCrimson,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusBanner({
    required bool isActive,
    required bool isPaid,
    required bool isApproved,
    required bool isRejected,
    required bool isExpired,
    required bool isRevoked,
    String? rejectionReason,
  }) {
    Color bannerColor;
    IconData icon;
    String title;
    String subtext;

    if (isRevoked) {
      bannerColor = AppColors.error;
      icon = Icons.block_rounded;
      title = 'Pass Revoked';
      subtext = 'This pass is no longer valid for ICEM transport.';
    } else if (isExpired) {
      bannerColor = AppColors.warning;
      icon = Icons.warning_amber_rounded;
      title = 'Pass Expired';
      subtext = 'The validity period for this pass has ended.';
    } else if (isRejected) {
      bannerColor = AppColors.error;
      icon = Icons.cancel_rounded;
      title = 'Application Rejected';
      subtext = rejectionReason ?? 'Application was rejected by college administration.';
    } else if (isActive) {
      bannerColor = AppColors.success;
      icon = Icons.check_circle_rounded;
      title = 'Active Digital Pass';
      subtext = 'Authorized for ICEM bus transport.';
    } else if (isPaid && !isApproved) {
      bannerColor = AppColors.info;
      icon = Icons.hourglass_top_rounded;
      title = 'Paid — Waiting for Admin Approval';
      subtext = 'Payment verified. Administration will review and approve credential.';
    } else {
      bannerColor = AppColors.warning;
      icon = Icons.payment_rounded;
      title = 'Payment Pending';
      subtext = 'Payment is required to submit application for approval.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bannerColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: bannerColor, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: bannerColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtext,
                  style: TextStyle(fontSize: 12, color: bannerColor.withOpacity(0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryCrimson),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() => const Divider(height: 16, color: Color(0xFFF1F5F9));

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return _formatDate(dt);
    }
    return 'N/A';
  }
}
