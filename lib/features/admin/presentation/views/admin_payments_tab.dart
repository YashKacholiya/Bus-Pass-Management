// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/admin/data/repositories/admin_repository.dart';
import 'package:icem_bus/features/admin/presentation/views/report_exporter.dart';

/// Payment/receipt management tab
class AdminPaymentsTab extends ConsumerStatefulWidget {
  const AdminPaymentsTab({super.key});

  @override
  ConsumerState<AdminPaymentsTab> createState() => _AdminPaymentsTabState();
}

class _AdminPaymentsTabState extends ConsumerState<AdminPaymentsTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paymentsAsync = ref.watch(paymentsListStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Verify student transactions, record failures, execute refunds, and download receipts.',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── DASHBOARD SUMMARY PANEL ──
            paymentsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (err, _) => const SizedBox.shrink(),
              data: (payments) {
                // Calculate dynamic metrics
                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                final monthStart = DateTime(now.year, now.month, 1);

                double totalRevenue = 0.0;
                double todayRevenue = 0.0;
                double monthlyRevenue = 0.0;
                int pendingCount = 0;
                int successCount = 0;

                for (final p in payments) {
                  final status = p['paymentStatus'] ?? 'Pending';
                  final isSuccess = status == 'Paid' || status == 'Success' || status == 'Successful';
                  final isPending = status == 'Pending' || status == 'Pending Verification' || status == 'Pending Payment';

                  final amountVal = p['amount'];
                  double amount = 0.0;
                  if (amountVal is num) {
                    amount = amountVal.toDouble();
                  } else if (amountVal is String) {
                    amount = double.tryParse(amountVal) ?? 0.0;
                  }

                  final dateField = p['createdAt'] ?? p['paymentDate'];
                  DateTime? dt;
                  if (dateField is Timestamp) {
                    dt = dateField.toDate();
                  } else if (dateField is String) {
                    dt = DateTime.tryParse(dateField);
                  }

                  if (isSuccess) {
                    successCount++;
                    totalRevenue += amount;
                    if (dt != null) {
                      if (dt.isAfter(todayStart) || dt.isAtSameMomentAs(todayStart)) {
                        todayRevenue += amount;
                      }
                      if (dt.isAfter(monthStart) || dt.isAtSameMomentAs(monthStart)) {
                        monthlyRevenue += amount;
                      }
                    }
                  } else if (isPending) {
                    pendingCount++;
                  }
                }

                return SizedBox(
                  height: 104,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _buildSummaryCard(
                        'Total Revenue',
                        '₹${totalRevenue.toStringAsFixed(0)}',
                        Colors.indigo,
                        Icons.account_balance_wallet_rounded,
                      ),
                      _buildSummaryCard(
                        "Today's Revenue",
                        '₹${todayRevenue.toStringAsFixed(0)}',
                        Colors.teal,
                        Icons.today_rounded,
                      ),
                      _buildSummaryCard(
                        'Monthly Revenue',
                        '₹${monthlyRevenue.toStringAsFixed(0)}',
                        Colors.purple,
                        Icons.calendar_month_rounded,
                      ),
                      _buildSummaryCard(
                        'Pending Verification',
                        pendingCount.toString(),
                        AppColors.warning,
                        Icons.pending_actions_rounded,
                      ),
                      _buildSummaryCard(
                        'Paid Pass Holders',
                        successCount.toString(),
                        AppColors.success,
                        Icons.verified_user_rounded,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // ── SEARCH AND FILTERS BAR ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    AdminSearchBar(
                      hintText: 'Search by name, PRN, or transaction ID...',
                      value: _searchQuery,
                      onChanged: (q) => setState(() => _searchQuery = q),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            'All',
                            'Pending',
                            'Processing',
                            'Paid',
                            'Failed',
                            'Manual Verification',
                            'Refunded',
                          ].map((filter) {
                            final isActive = filter == _statusFilter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(filter),
                                selected: isActive,
                                onSelected: (_) => setState(() => _statusFilter = filter),
                                selectedColor: AppColors.primaryCrimson.withValues(alpha: 0.15),
                                checkmarkColor: AppColors.primaryCrimson,
                                labelStyle: TextStyle(
                                  color: isActive
                                      ? AppColors.primaryCrimson
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                  fontSize: 12.5,
                                ),
                                backgroundColor: theme.colorScheme.surface,
                                side: BorderSide(
                                  color: isActive
                                      ? AppColors.primaryCrimson.withValues(alpha: 0.35)
                                      : theme.colorScheme.outlineVariant,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── PAYMENTS LIST ──
            Expanded(
              child: paymentsAsync.when(
                loading: () => const AdminLoadingState(),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        const Text(
                          'Failed to load payment history',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          e.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(paymentsListStreamProvider),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryCrimson),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (payments) {
                  var filtered = payments;

                  // Status filter matching per Section 10
                  if (_statusFilter != 'All') {
                    filtered = filtered.where((p) {
                      final status = (p['paymentStatus'] ?? 'Pending').toString().toLowerCase();
                      if (_statusFilter == 'Pending') {
                        return status == 'pending' || status == 'created' || status == 'pending payment';
                      }
                      if (_statusFilter == 'Processing') {
                        return status == 'processing';
                      }
                      if (_statusFilter == 'Paid') {
                        return status == 'paid' || status == 'success' || status == 'successful';
                      }
                      if (_statusFilter == 'Failed') {
                        return status == 'failed' || status == 'cancelled';
                      }
                      if (_statusFilter == 'Manual Verification') {
                        return status == 'submitted_for_verification' || status == 'pending verification';
                      }
                      if (_statusFilter == 'Refunded') {
                        return status == 'refunded';
                      }
                      return status == _statusFilter.toLowerCase();
                    }).toList();
                  }

                  // Search query matching
                  if (_searchQuery.trim().isNotEmpty) {
                    final q = _searchQuery.trim().toLowerCase();
                    filtered = filtered.where((p) {
                      final name = (p['studentName'] ?? '').toString().toLowerCase();
                      final prn = (p['prn'] ?? '').toString().toLowerCase();
                      final txId = (p['transactionId'] ?? p['receiptId'] ?? p['id'] ?? '').toString().toLowerCase();
                      return name.contains(q) || prn.contains(q) || txId.contains(q);
                    }).toList();
                  }

                  if (filtered.isEmpty) {
                    return const AdminEmptyState(
                      title: 'No transactions found',
                      subtitle: 'Either there are no payments recorded or adjust your filters.',
                      icon: Icons.receipt_long_rounded,
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final payment = filtered[index];
                      return _PaymentListCard(
                        payment: payment,
                        onTap: () => _showPaymentDetails(context, payment),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      width: 155,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 16),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDetails(BuildContext context, Map<String, dynamic> payment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentDetailsModal(
        payment: payment,
        onVerify: (receiptId, studentUid) async {
          Navigator.pop(context);
          await _verifyManualPayment(receiptId, studentUid, payment['studentName'] ?? '', payment['amount']);
        },
        onFail: (receiptId, studentUid) async {
          Navigator.pop(context);
          await _failPayment(receiptId, studentUid);
        },
        onRefund: (receiptId, studentUid) async {
          Navigator.pop(context);
          await _refundPayment(receiptId, studentUid);
        },
        onDownloadReceipt: (p) async {
          await ReportExporter.exportReceipt(payment: p);
        },
      ),
    );
  }

  Future<void> _verifyManualPayment(String receiptId, String studentUid, String name, dynamic amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Manual UPI Payment?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Confirm manual UPI payment of ₹$amount from $name?\n\n'
          'This will mark paymentStatus = PAID and move the application to Pending Admin Approval.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verify Payment', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final adminUid = ref.read(authControllerProvider).user?.uid ?? 'Admin';
      try {
        await AdminRepository().verifyManualPayment(receiptId, studentUid, adminUid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment $receiptId approved successfully!'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _failPayment(String receiptId, String studentUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Payment as Failed?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'Mark this transaction as Failed? This will reject the associated bus pass application.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark Failed', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AdminRepository().markPaymentFailed(receiptId, studentUid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction status set to Failed.'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _refundPayment(String receiptId, String studentUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refund Transaction?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'Mark this transaction as Refunded? This will deactivate the student\'s digital bus pass.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Refund Status', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AdminRepository().refundPayment(receiptId, studentUid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction status updated to Refunded.'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to refund: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}

// ============================================================
// PAYMENT LIST CARD
// ============================================================

class _PaymentListCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onTap;

  const _PaymentListCard({
    required this.payment,
    required this.onTap,
  });

  String _formatDate(dynamic dateField) {
    if (dateField == null) return 'N/A';
    DateTime? dt;
    if (dateField is Timestamp) {
      dt = dateField.toDate();
    } else if (dateField is String) {
      dt = DateTime.tryParse(dateField);
    }
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name = payment['studentName'] ?? 'Unknown';
    final appId = payment['applicationId'] ?? payment['passId'] ?? payment['id'] ?? 'N/A';
    final amount = payment['amount'] ?? 0;
    final status = (payment['paymentStatus'] ?? 'Pending').toString();
    final statusLower = status.toLowerCase();
    final createdAt = payment['createdAt'] ?? payment['paymentDate'];
    final paidAt = payment['paidAt'] ?? payment['verifiedAt'];
    final prn = payment['prn'] ?? '';
    final route = payment['routeName'] ?? payment['route'] ?? 'N/A';
    final method = (payment['paymentMethod'] ?? 'Online').toString();
    final orderId = (payment['razorpayOrderId'] ?? payment['utrNumber'] ?? '').toString();
    final paymentId = (payment['razorpayPaymentId'] ?? payment['transactionId'] ?? '').toString();

    final isPaid = statusLower == 'paid' || statusLower == 'success' || statusLower == 'successful';
    final isManualUpi = method.toLowerCase().contains('upi') ||
        statusLower == 'submitted_for_verification' ||
        statusLower == 'pending verification';

    String displayStatus;
    Color statusColor;
    IconData statusIcon;

    if (isPaid) {
      displayStatus = '✓ Payment Verified';
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle_rounded;
    } else if (isManualUpi) {
      displayStatus = 'Pending Verification';
      statusColor = AppColors.warning;
      statusIcon = Icons.pending_actions_rounded;
    } else if (statusLower == 'processing') {
      displayStatus = 'Processing';
      statusColor = Colors.blue;
      statusIcon = Icons.hourglass_top_rounded;
    } else if (statusLower == 'failed' || statusLower == 'cancelled') {
      displayStatus = 'Failed';
      statusColor = AppColors.error;
      statusIcon = Icons.cancel_rounded;
    } else if (statusLower == 'refunded') {
      displayStatus = 'Refunded';
      statusColor = Colors.grey;
      statusIcon = Icons.history_rounded;
    } else {
      displayStatus = 'Pending Payment';
      statusColor = AppColors.warning;
      statusIcon = Icons.pending_actions_rounded;
    }

    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── HEADER ROW: Student / Payment Information + Status Badge ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon container
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 12),
                    // Student details (Takes remaining width)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            prn.isNotEmpty ? 'PRN: $prn • App: $appId' : 'App: $appId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Badge (constrained)
                    Flexible(
                      flex: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              displayStatus,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: theme.dividerColor),
                const SizedBox(height: 10),

                // ── SEPARATE RESPONSIVE SECTION (WRAP) ──
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Amount Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryCrimson.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '₹${amount is num ? amount.toStringAsFixed(0) : amount}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.primaryCrimson,
                        ),
                      ),
                    ),

                    // Payment Method Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payment_rounded, size: 11, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            method,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Date Tag
                    if (createdAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 10.5, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(createdAt),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Route Tag
                    if (route != 'N/A' && route.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_bus_rounded, size: 11, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Text(
                                route,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // ── IDENTIFIERS SECTION (ORDER/UTR, PAYMENT ID, PAID TIME) ──
                if (orderId.isNotEmpty || paymentId.isNotEmpty || paidAt != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (orderId.isNotEmpty)
                        Text(
                          'Order/UTR: $orderId',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      if (paymentId.isNotEmpty)
                        Text(
                          'Payment ID: $paymentId',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      if (paidAt != null)
                        Text(
                          'Verified: ${_formatDate(paidAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DETAILS MODAL SHEET
// ============================================================

class _PaymentDetailsModal extends StatelessWidget {
  final Map<String, dynamic> payment;
  final Function(String receiptId, String studentUid) onVerify;
  final Function(String receiptId, String studentUid) onFail;
  final Function(String receiptId, String studentUid) onRefund;
  final ValueChanged<Map<String, dynamic>> onDownloadReceipt;

  const _PaymentDetailsModal({
    required this.payment,
    required this.onVerify,
    required this.onFail,
    required this.onRefund,
    required this.onDownloadReceipt,
  });

  String _formatDate(dynamic dateField) {
    if (dateField == null) return 'N/A';
    DateTime? dt;
    if (dateField is Timestamp) {
      dt = dateField.toDate();
    } else if (dateField is String) {
      dt = DateTime.tryParse(dateField);
    }
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final receiptId = payment['receiptId'] ?? payment['paymentId'] ?? payment['id'] ?? 'N/A';
    final studentUid = payment['studentId'] ?? payment['uid'] ?? '';
    final applicationId = payment['applicationId'] ?? payment['passId'] ?? payment['id'] ?? 'N/A';
    final name = payment['studentName'] ?? 'Unknown';
    final prn = payment['prn'] ?? 'N/A';
    final course = payment['course'] ?? 'N/A';
    final amount = payment['amount'] ?? 0;
    final status = (payment['paymentStatus'] ?? 'Pending').toString();
    final statusLower = status.toLowerCase();
    final method = (payment['paymentMethod'] ?? 'Online Payment').toString();
    final razorpayOrderId = payment['razorpayOrderId'] ?? 'N/A';
    final razorpayPaymentId = payment['razorpayPaymentId'] ?? payment['transactionId'] ?? 'N/A';
    final utrNumber = payment['utrNumber'] ?? 'N/A';
    final dateField = payment['createdAt'] ?? payment['paymentDate'];
    final paidAt = payment['paidAt'] ?? payment['verifiedAt'];
    final routeName = payment['routeName'] ?? payment['route'] ?? 'N/A';
    final boarding = payment['boardingStop'] ?? payment['boarding'] ?? 'N/A';
    final destination = payment['destinationStop'] ?? payment['destination'] ?? 'N/A';

    final isSuccess = statusLower == 'paid' || statusLower == 'success' || statusLower == 'successful';
    final isManualUpi = method.toLowerCase().contains('upi') ||
        statusLower == 'submitted_for_verification' ||
        statusLower == 'pending verification';
    final isPending = statusLower == 'pending' ||
        statusLower == 'pending verification' ||
        statusLower == 'submitted_for_verification' ||
        statusLower == 'pending payment' ||
        statusLower == 'created' ||
        statusLower == 'processing';

    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag indicator
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Transaction Details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${amount is num ? amount.toStringAsFixed(0) : amount}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),

          // Student Details Block
          const Text('Student Information', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          _buildInfoRow('Name', name),
          _buildInfoRow('Application ID', applicationId),
          if (prn != 'N/A') _buildInfoRow('PRN', prn),
          if (course != 'N/A') _buildInfoRow('Course', course),
          const SizedBox(height: 16),

          // Payment Details Block
          const Text('Payment Information', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          _buildInfoRow(
            'Status',
            isSuccess ? '✓ Payment Verified' : (isManualUpi && isPending ? 'Pending Verification' : status),
            isBold: true,
            valueColor: isSuccess ? AppColors.success : (isPending ? AppColors.warning : AppColors.error),
          ),
          _buildInfoRow('Method', method),
          _buildInfoRow('Receipt / Record ID', receiptId),
          if (razorpayOrderId != 'N/A') _buildInfoRow('Razorpay Order ID', razorpayOrderId),
          if (razorpayPaymentId != 'N/A') _buildInfoRow('Razorpay Payment ID', razorpayPaymentId),
          if (utrNumber != 'N/A') _buildInfoRow('UPI UTR Number', utrNumber),
          _buildInfoRow('Created Time', _formatDate(dateField)),
          if (paidAt != null) _buildInfoRow('Paid Time', _formatDate(paidAt)),
          const SizedBox(height: 16),

          // Route Details Block
          const Text('Pass & Route Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          _buildInfoRow('Route', routeName),
          if (boarding != 'N/A') _buildInfoRow('Boarding Stop', boarding),
          if (destination != 'N/A') _buildInfoRow('Destination', destination),
          const SizedBox(height: 28),

          // Action Controls
          Column(
            children: [
              if (isPending) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onFail(receiptId, studentUid),
                        icon: const Icon(Icons.cancel_rounded, size: 18),
                        label: const Text('Mark Failed'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (isManualUpi) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => onVerify(receiptId, studentUid),
                          icon: const Icon(Icons.verified_rounded, size: 18, color: Colors.white),
                          label: const Text('Verify Payment', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!isManualUpi)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                    child: Text(
                      'Online payments are verified automatically by the Razorpay backend service.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 12),
              ] else if (isSuccess) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onRefund(receiptId, studentUid),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('Refund Payment'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade800,
                          side: BorderSide(color: Colors.orange.shade800),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Always visible Receipt PDF download
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onDownloadReceipt(payment),
                  icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                  label: const Text('Download PDF Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
