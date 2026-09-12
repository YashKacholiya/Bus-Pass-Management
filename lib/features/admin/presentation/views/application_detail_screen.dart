// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/data/repositories/admin_repository.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';

/// Full-page detail screen for a single bus pass application.
///
/// Receives the application document ID via GoRouter path parameter,
/// streams the document in real-time, and provides admin actions
/// (Approve / Reject / Request Correction) with appropriate dialogs.
class ApplicationDetailScreen extends ConsumerWidget {
  final String applicationId;

  const ApplicationDetailScreen({super.key, required this.applicationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appAsync = ref.watch(singleApplicationStreamProvider(applicationId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Application Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      body: appAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryCrimson),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Failed to load application',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
        data: (application) {
          if (application == null) {
            return const Center(
              child: Text(
                'Application not found',
                style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
            );
          }

          return _ApplicationDetailBody(
            application: application,
            applicationId: applicationId,
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Detail body — extracted as StatelessWidget for clarity
// ────────────────────────────────────────────────────────────

class _ApplicationDetailBody extends ConsumerWidget {
  final Map<String, dynamic> application;
  final String applicationId;

  const _ApplicationDetailBody({
    required this.application,
    required this.applicationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passStatus =
        application['passStatus'] ?? application['status'] ?? 'Pending';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        // ── Student Header Card ──
        _buildStudentHeader(context),
        const SizedBox(height: 16),

        // ── Application Info Card ──
        _buildInfoCard(context, 'Application Information', [
          _row('PRN', application['prn']),
          _row('College ID', application['collegeId']),
          _row('Course', application['course']),
          _row('Department', application['department']),
          _row('Year', application['year']),
          _row('Semester', application['semester']),
        ]),
        const SizedBox(height: 16),

        // ── Route & Travel Card ──
        _buildInfoCard(context, 'Route & Travel Details', [
          _row('Route', application['routeName'] ?? application['route']),
          _row('Boarding Stop', application['boardingStop']),
          _row('Destination Stop', application['destinationStop']),
          _row('Distance', application['distance']),
          _row('Bus Number', application['busNumber']),
        ]),
        const SizedBox(height: 16),

        // ── Payment & Status Card ──
        _buildInfoCard(context, 'Payment & Status', [
          _row('Fare', _formatFare(application['fare'])),
          _row('Payment Status', application['paymentStatus']),
          _row('Pass Status', passStatus),
          _row('Pass ID', application['passId']),
          _row('Applied Date', _formatTimestamp(application['createdAt'])),
        ]),
        const SizedBox(height: 16),

        // ── Contact Card ──
        _buildInfoCard(context, 'Contact Information', [
          _row('Email', application['email']),
          _row('Mobile', application['mobile']),
          _row('Address', application['address']),
        ]),
        const SizedBox(height: 16),

        // ── Action History Card (if already actioned) ──
        if (passStatus == 'Approved' ||
            passStatus == 'Rejected' ||
            passStatus == 'Correction Required')
          ...[
            _buildHistoryCard(context, passStatus.toString()),
            const SizedBox(height: 16),
          ],

        // ── Admin Actions (only for Pending applications) ──
        if (passStatus == 'Pending') ...[
          _buildAdminActions(context, ref),
          const SizedBox(height: 32),
        ],
      ],
    );
  }

  // ── Student Header ──
  Widget _buildStudentHeader(BuildContext context) {
    final name =
        application['studentName'] ?? application['fullName'] ?? 'Unknown';
    final photoUrl = application['photoUrl'] as String?;
    final passStatus =
        application['passStatus'] ?? application['status'] ?? 'Pending';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Photo
          _buildPhoto(photoUrl, name.toString()),
          const SizedBox(width: 16),
          // Name + Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'PRN: ${application['prn'] ?? '-'}  •  ID: ${application['collegeId'] ?? '-'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),
                _buildStatusChip(passStatus.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto(String? photoUrl, String name) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          photoUrl,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialAvatar(name, 64),
        ),
      );
    }
    return _buildInitialAvatar(name, 64);
  }

  Widget _buildInitialAvatar(String name, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryCrimson.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: AppColors.primaryCrimson,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'Approved':
      case 'Active':
        bgColor = AppColors.success.withOpacity(0.1);
        textColor = AppColors.success;
        break;
      case 'Rejected':
        bgColor = AppColors.error.withOpacity(0.1);
        textColor = AppColors.error;
        break;
      case 'Expired':
        bgColor = AppColors.warning.withOpacity(0.1);
        textColor = AppColors.warning;
        break;
      case 'Correction Required':
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
        break;
      default:
        bgColor = AppColors.info.withOpacity(0.1);
        textColor = AppColors.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  // ── Info Card Builder ──
  Widget _buildInfoCard(
      BuildContext context, String title, List<Widget> rows) {
    // Filter out rows that are just dashes
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryCrimson,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    final displayValue = value?.toString();
    if (displayValue == null || displayValue.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── History Card (for already actioned applications) ──
  Widget _buildHistoryCard(BuildContext context, String status) {
    IconData icon;
    Color color;
    String title;
    List<Widget> details = [];

    switch (status) {
      case 'Approved':
        icon = Icons.check_circle_rounded;
        color = AppColors.success;
        title = 'Approved';
        details = [
          _row('Approved By', application['approvedBy']),
          _row('Approved At', _formatTimestamp(application['approvedAt'])),
          _row('Pass ID', application['passId']),
        ];
        break;
      case 'Rejected':
        icon = Icons.cancel_rounded;
        color = AppColors.error;
        title = 'Rejected';
        details = [
          _row('Rejection Reason', application['rejectionReason']),
          _row('Rejected At', _formatTimestamp(application['rejectedAt'])),
        ];
        break;
      case 'Correction Required':
        icon = Icons.edit_note_rounded;
        color = const Color(0xFFE65100);
        title = 'Correction Required';
        details = [
          _row('Correction Message', application['correctionMessage']),
          _row('Requested At',
              _formatTimestamp(application['correctionRequestedAt'])),
        ];
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...details,
        ],
      ),
    );
  }

  // ── Admin Actions (Approve / Reject / Request Correction) ──
  Widget _buildAdminActions(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
          const Text(
            'Admin Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryCrimson,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _AdminActionButton(
                  label: 'Approve',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                  onTap: () => _handleApprove(context, ref),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AdminActionButton(
                  label: 'Reject',
                  icon: Icons.cancel_rounded,
                  color: AppColors.error,
                  onTap: () => _handleReject(context, ref),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AdminActionButton(
                  label: 'Correction',
                  icon: Icons.edit_note_rounded,
                  color: AppColors.warning,
                  onTap: () => _handleCorrection(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Action Handlers ──

  void _handleApprove(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve Application'),
        content: const Text(
            'This will approve the application and generate a unique Pass ID. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final adminUid =
                    ref.read(authControllerProvider).user?.uid ?? '';
                final repo = AdminRepository();
                await repo.approveApplication(applicationId, adminUid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Application approved successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Approve',
              style: TextStyle(
                  color: AppColors.success, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _handleReject(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Rejection reason...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a rejection reason'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                final adminUid =
                    ref.read(authControllerProvider).user?.uid ?? '';
                final repo = AdminRepository();
                await repo.rejectApplication(applicationId, reason, adminUid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Application rejected'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Reject',
              style: TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _handleCorrection(BuildContext context) {
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Request Correction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Describe what corrections the student needs to make.'),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Correction message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final message = messageController.text.trim();
              if (message.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a correction message'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                final repo = AdminRepository();
                await repo.requestCorrection(applicationId, message);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Correction requested'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Send',
              style: TextStyle(
                  color: AppColors.warning, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  String _formatFare(dynamic fare) {
    if (fare == null) return '-';
    return '₹${(fare is num) ? fare.toStringAsFixed(0) : fare.toString()}';
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '-';
    DateTime? dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    }
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ────────────────────────────────────────────────────────────
// Admin Action Button — styled consistently
// ────────────────────────────────────────────────────────────

class _AdminActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdminActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
