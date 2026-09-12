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
    final paymentsAsync = ref.watch(paymentsListStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Verify student transactions, record failures, execute refunds, and download receipts.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Column(
                  children: [
                    AdminSearchBar(
                      hintText: 'Search by name, PRN, or transaction ID...',
                      value: _searchQuery,
                      onChanged: (q) => setState(() => _searchQuery = q),
                    ),
                    const SizedBox(height: 10),
                    AdminFilterChips(
                      filters: const ['All', 'Pending', 'Success', 'Failed', 'Refunded'],
                      selected: _statusFilter,
                      onSelected: (val) => setState(() => _statusFilter = val),
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

                  // Status filter matching
                  if (_statusFilter != 'All') {
                    filtered = filtered.where((p) {
                      final status = p['paymentStatus'] ?? 'Pending';
                      if (_statusFilter == 'Pending') {
                        return status == 'Pending' || status == 'Pending Verification' || status == 'Pending Payment';
                      }
                      if (_statusFilter == 'Success') {
                        return status == 'Paid' || status == 'Success' || status == 'Successful';
                      }
                      return status.toString().toLowerCase() == _statusFilter.toLowerCase();
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
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
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
              Text(
                label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
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
        title: const Text('Approve Transaction?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Confirm cash/bank transaction of ₹$amount from $name?\n\n'
          'This activates the student\'s digital bus pass instantly.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
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
    final amount = payment['amount'] ?? 0;
    final status = payment['paymentStatus'] ?? 'Pending';
    final createdAt = payment['createdAt'] ?? payment['paymentDate'];
    final prn = payment['prn'] ?? 'N/A';
    final route = payment['route'] ?? 'N/A';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Paid':
      case 'Success':
      case 'Successful':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'Failed':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        break;
      case 'Refunded':
        statusColor = Colors.grey;
        statusIcon = Icons.history_rounded;
        break;
      case 'Pending Verification':
      case 'Pending':
      default:
        statusColor = AppColors.warning;
        statusIcon = Icons.pending_actions_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon container
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 14),
                    // Core Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '₹${amount is num ? amount.toStringAsFixed(2) : amount}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _formatDate(createdAt),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('PRN: $prn', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    Text(route, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  ],
                ),
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
    final receiptId = payment['receiptId'] ?? payment['id'] ?? 'N/A';
    final studentUid = payment['uid'] ?? '';
    final name = payment['studentName'] ?? 'Unknown';
    final prn = payment['prn'] ?? 'N/A';
    final course = payment['course'] ?? 'N/A';
    final amount = payment['amount'] ?? 0;
    final status = payment['paymentStatus'] ?? 'Pending';
    final method = payment['paymentMethod'] ?? 'Online Payment';
    final transactionId = payment['transactionId'] ?? 'N/A';
    final dateField = payment['createdAt'] ?? payment['paymentDate'];
    final routeName = payment['route'] ?? 'N/A';
    final boarding = payment['boardingStop'] ?? 'N/A';
    final destination = payment['destinationStop'] ?? 'N/A';
    final passId = payment['passId'] ?? 'N/A';

    final isPending = status == 'Pending' || status == 'Pending Verification' || status == 'Pending Payment';
    final isSuccess = status == 'Paid' || status == 'Success' || status == 'Successful';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              const Text(
                'Transaction Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                '₹${amount is num ? amount.toStringAsFixed(2) : amount}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
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
          _buildInfoRow('PRN', prn),
          _buildInfoRow('Course', course),
          const SizedBox(height: 16),

          // Payment Details Block
          const Text('Payment Information', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          _buildInfoRow('Status', status, isBold: true, valueColor: isSuccess ? AppColors.success : (isPending ? AppColors.warning : AppColors.error)),
          _buildInfoRow('Method', method),
          _buildInfoRow('Receipt ID', receiptId),
          _buildInfoRow('Transaction ID', transactionId),
          _buildInfoRow('Date & Time', _formatDate(dateField)),
          const SizedBox(height: 16),

          // Route Details Block
          const Text('Pass & Route Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          _buildInfoRow('Bus Pass ID', passId),
          _buildInfoRow('Route', routeName),
          _buildInfoRow('Boarding Stop', boarding),
          _buildInfoRow('Destination', destination),
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
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Flexible(
            child: Text(
              value,
              textAlign: Alignment.centerRight.x > 0 ? TextAlign.end : TextAlign.start,
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
