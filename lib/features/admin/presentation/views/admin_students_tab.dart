// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import 'package:icem_bus/features/admin/data/repositories/admin_repository.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ============================================================
// STUDENT PASS PROVIDER
// ============================================================

final studentPassStreamProvider = StreamProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('bus_passes')
      .doc(uid)
      .snapshots()
      .map((snap) {
    if (!snap.exists) return null;
    final data = snap.data();
    if (data != null) data['id'] = snap.id;
    return data;
  });
});

// ============================================================
// ADMIN STUDENTS TAB
// ============================================================

class AdminStudentsTab extends ConsumerStatefulWidget {
  const AdminStudentsTab({super.key});

  @override
  ConsumerState<AdminStudentsTab> createState() => _AdminStudentsTabState();
}

class _AdminStudentsTabState extends ConsumerState<AdminStudentsTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsListStreamProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: AdminSearchBar(
              hintText: 'Search by Name, PRN, or Email...',
              value: _searchQuery,
              onChanged: (q) => setState(() => _searchQuery = q),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: studentsAsync.when(
              loading: () => const AdminLoadingState(),
              error: (e, _) => AdminErrorState(message: e.toString()),
              data: (students) {
                var filtered = students;

                // Client-side search filtering
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filtered = filtered.where((s) {
                    final name = (s['fullName'] ?? '').toString().toLowerCase();
                    final prn = (s['prn'] ?? '').toString().toLowerCase();
                    final email = (s['email'] ?? '').toString().toLowerCase();
                    return name.contains(q) || prn.contains(q) || email.contains(q);
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return const AdminEmptyState(
                    title: 'No students found',
                    subtitle: 'Try adjusting your search criteria.',
                    icon: Icons.people_alt_rounded,
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final student = filtered[i];
                    return _StudentCard(
                      student: student,
                      onTap: () => _showStudentDetails(context, student),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showStudentDetails(BuildContext context, Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudentDetailsSheet(student: student),
    );
  }
}

// ============================================================
// STUDENT CARD WIDGET
// ============================================================

class _StudentCard extends ConsumerWidget {
  final Map<String, dynamic> student;
  final VoidCallback onTap;

  const _StudentCard({
    required this.student,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = student['fullName'] ?? 'Unknown';
    final email = student['email'] ?? 'N/A';
    final prn = student['prn'] ?? 'N/A';
    final course = student['course'] ?? 'N/A';
    final phone = student['mobile'] ?? student['phone'] ?? 'N/A';
    final isActive = student['isActive'] ?? true;
    final photoUrl = student['photoUrl'] as String?;

    final passAsync = ref.watch(studentPassStreamProvider(student['id']));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Photo / Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryCrimson.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    image: photoUrl != null && photoUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(photoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Center(
                          child: Text(
                            name.toString().isNotEmpty
                                ? name.toString()[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.primaryCrimson,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),

                // Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and Status Icon
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isActive ? AppColors.success : AppColors.error).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Suspended',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isActive ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Academic Details
                      Row(
                        children: [
                          Text(
                            course.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                          const SizedBox(width: 6),
                          Text(
                            'PRN: $prn',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Email and Phone
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              email.toString(),
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_android_rounded, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 5),
                          Text(
                            phone.toString(),
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: theme.dividerColor),
                      const SizedBox(height: 10),

                      // Pass and Route details (Watched asynchronously)
                      passAsync.when(
                        loading: () => const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryCrimson),
                        ),
                        error: (e, _) => const Text('Error loading pass details', style: TextStyle(fontSize: 11, color: AppColors.error)),
                        data: (pass) {
                          final passStatus = pass?['passStatus'] ?? 'No Pass';
                          final routeName = pass?['route'] ?? 'N/A';

                          Color statusColor = const Color(0xFF94A3B8); // grey for No Pass
                          if (passStatus == 'Active' || passStatus == 'Approved') statusColor = AppColors.success;
                          if (passStatus == 'Rejected') statusColor = AppColors.error;
                          if (passStatus == 'Pending' || passStatus == 'Pending Payment' || passStatus == 'Pending Verification') statusColor = AppColors.warning;

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Route Info
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.route_rounded, size: 14, color: AppColors.primaryCrimson),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        routeName.toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Pass Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusColor.withOpacity(0.12)),
                                ),
                                child: Text(
                                  passStatus.toString(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
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
// STUDENT DETAILS SHEET
// ============================================================

class _StudentDetailsSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> student;

  const _StudentDetailsSheet({required this.student});

  @override
  ConsumerState<_StudentDetailsSheet> createState() => _StudentDetailsSheetState();
}

class _StudentDetailsSheetState extends ConsumerState<_StudentDetailsSheet> {
  bool _isPerformingAction = false;

  @override
  Widget build(BuildContext context) {
    final studentId = widget.student['id'];
    final passAsync = ref.watch(studentPassStreamProvider(studentId));
    final adminUid = ref.watch(authControllerProvider).user?.uid ?? '';

    // Watch real-time changes to the user document itself to display active/inactive live
    final userSnap = FirebaseFirestore.instance.collection('users').doc(studentId).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userSnap,
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() ?? widget.student;
        final name = userData['fullName'] ?? 'Unknown';
        final email = userData['email'] ?? 'N/A';
        final prn = userData['prn'] ?? 'N/A';
        final collegeId = userData['collegeId'] ?? 'N/A';
        final course = userData['course'] ?? 'N/A';
        final phone = userData['mobile'] ?? userData['phone'] ?? 'N/A';
        final role = userData['role'] ?? 'N/A';
        final isActive = userData['isActive'] ?? true;
        final photoUrl = userData['photoUrl'] as String?;
        final registrationDate = userData['createdAt'];

        return DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.6,
          maxChildSize: 0.97,
          builder: (context, scrollController) {
            final theme = Theme.of(context);
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primaryCrimson.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                image: photoUrl != null && photoUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(photoUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: photoUrl == null || photoUrl.isEmpty
                                  ? const Icon(Icons.person_rounded, color: AppColors.primaryCrimson, size: 24)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.toString(),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    role.toString(),
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            if (_isPerformingAction)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryCrimson),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                      ],
                    ),
                  ),

                  // Detail Fields
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      children: [
                        // Section: Personal Details
                        _SectionHeader(title: 'Personal Details', icon: Icons.person_outline_rounded),
                        const SizedBox(height: 12),
                        _buildDetailRow('PRN / Roll Number', prn.toString()),
                        _buildDetailRow('College / Faculty ID', collegeId.toString()),
                        _buildDetailRow('Course / Program', course.toString()),
                        _buildDetailRow('Email Address', email.toString()),
                        _buildDetailRow('Mobile Number', phone.toString()),
                        _buildDetailRow('Account Status', isActive ? 'Active / Authorized' : 'Suspended / Unauthorized',
                            color: isActive ? AppColors.success : AppColors.error),
                        _buildDetailRow('Registration Date', _formatDate(registrationDate)),
                        const SizedBox(height: 24),

                        // Section: Route & Pass Details (Watched asynchronously)
                        passAsync.when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(color: AppColors.primaryCrimson),
                            ),
                          ),
                          error: (err, _) => Text('Error: $err', style: const TextStyle(color: AppColors.error)),
                          data: (pass) {
                            final routeName = pass?['route'] ?? 'N/A';
                            final boarding = pass?['boardingStop'] ?? 'N/A';
                            final destination = pass?['destinationStop'] ?? 'N/A';
                            final fareValue = pass?['fare'] ?? 'N/A';
                            final paymentStatus = pass?['paymentStatus'] ?? 'No Pass';
                            final passStatus = pass?['passStatus'] ?? 'No Pass';
                            final bool isPassPaid = paymentStatus.toString().toLowerCase() == 'paid';

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionHeader(title: 'Route Details', icon: Icons.route_rounded),
                                const SizedBox(height: 12),
                                _buildDetailRow('Assigned Route', routeName.toString()),
                                _buildDetailRow('Boarding Point', boarding.toString()),
                                _buildDetailRow('Destination Point', destination.toString()),
                                _buildDetailRow('Pass Fare Cost', fareValue != 'N/A' ? '₹$fareValue' : 'N/A'),
                                const SizedBox(height: 24),

                                _SectionHeader(title: 'Status Indicators', icon: Icons.playlist_add_check_rounded),
                                const SizedBox(height: 12),
                                _buildDetailRow('Payment State', paymentStatus.toString(),
                                    color: paymentStatus == 'Paid'
                                        ? AppColors.success
                                        : (paymentStatus == 'No Pass' ? const Color(0xFF94A3B8) : AppColors.warning)),
                                _buildDetailRow('Bus Pass State', passStatus.toString(),
                                    color: (passStatus == 'Active' || passStatus == 'Approved')
                                        ? AppColors.success
                                        : (passStatus == 'No Pass' ? const Color(0xFF94A3B8) : AppColors.warning)),
                                if (pass?['qrCode'] != null && pass!['qrCode'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Center(
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.grey.shade200),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.05),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              )
                                            ]
                                          ),
                                          child: QrImageView(
                                            data: pass['qrCode'].toString(),
                                            version: QrVersions.auto,
                                            size: 140,
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
                                        const SizedBox(height: 8),
                                        const Text(
                                          'STUDENT DIGITAL QR CODE',
                                          style: TextStyle(
                                            color: AppColors.primaryCrimson,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),

                                // Actions Section based on Pass Status
                                if (pass != null) ...[
                                  _SectionHeader(title: 'Administrative Controls', icon: Icons.security_rounded),
                                  const SizedBox(height: 14),
                                  if (!isPassPaid && passStatus != 'Active' && passStatus != 'Approved') ...[
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.error.withOpacity(0.2)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.lock_rounded, size: 16, color: AppColors.error),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Payment required before approval. Student has not completed verified payment.',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  Row(
                                    children: [
                                      if (passStatus != 'Active' && passStatus != 'Approved')
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _isPerformingAction
                                                ? null
                                                : (isPassPaid
                                                    ? () => _approvePass(studentId, adminUid)
                                                    : () {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(
                                                            content: Text('Payment required before approval. Student must complete verified payment first.'),
                                                            backgroundColor: AppColors.error,
                                                          ),
                                                        );
                                                      }),
                                            icon: Icon(isPassPaid ? Icons.check_circle_rounded : Icons.lock_outline_rounded, size: 16),
                                            label: Text(isPassPaid ? 'Approve Pass' : 'Payment Required'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isPassPaid ? AppColors.success : Colors.grey.shade400,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          ),
                                        ),
                                      if (passStatus != 'Active' && passStatus != 'Approved' && passStatus != 'Rejected')
                                        const SizedBox(width: 12),
                                      if (passStatus != 'Rejected' && passStatus != 'Active' && passStatus != 'Approved')
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _isPerformingAction
                                                ? null
                                                : () => _rejectPass(studentId),
                                            icon: const Icon(Icons.cancel_rounded, size: 16),
                                            label: const Text('Reject Pass'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.error,
                                              side: const BorderSide(color: AppColors.error),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          ),
                                        ),
                                      if (passStatus == 'Active' || passStatus == 'Approved')
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _isPerformingAction
                                                ? null
                                                : () => _revokePass(studentId),
                                            icon: const Icon(Icons.block_rounded, size: 16),
                                            label: const Text('Revoke Pass'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.error,
                                              side: const BorderSide(color: AppColors.error),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                ],
                              ],
                            );
                          },
                        ),

                        // General account actions (Suspend/Activate, Delete)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isPerformingAction
                                    ? null
                                    : () => _toggleStudentStatus(studentId, isActive),
                                icon: Icon(isActive ? Icons.lock_rounded : Icons.lock_open_rounded, size: 16),
                                label: Text(isActive ? 'Suspend User' : 'Activate User'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isActive ? AppColors.warning : AppColors.success,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isPerformingAction
                                    ? null
                                    : () => _confirmDeleteStudent(context, studentId, name.toString()),
                                icon: const Icon(Icons.delete_rounded, size: 16),
                                label: const Text('Delete Student'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: color ?? const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Action Handlers ──

  Future<void> _approvePass(String uid, String adminUid) async {
    setState(() => _isPerformingAction = true);
    try {
      await AdminRepository().approveStudentPass(uid, adminUid);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bus pass approved successfully'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isPerformingAction = false);
    }
  }

  Future<void> _rejectPass(String uid) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Bus Pass'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this student\'s bus pass application:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Rejection reason is required')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm Reject', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isPerformingAction = true);
      try {
        await AdminRepository().rejectStudentPass(uid, reasonController.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bus pass application rejected'), backgroundColor: AppColors.success),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      } finally {
        if (mounted) setState(() => _isPerformingAction = false);
      }
    }
  }

  Future<void> _revokePass(String uid) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Revoke Active Pass'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to revoke this student\'s bus pass? They will no longer be authorized to board buses:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Enter revocation reason...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Revocation reason is required')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm Revoke', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isPerformingAction = true);
      try {
        final adminUid = ref.read(authControllerProvider).user?.uid ?? '';
        await AdminRepository().revokePass(uid, reasonController.text.trim(), adminUid);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bus pass revoked successfully'), backgroundColor: AppColors.error),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      } finally {
        if (mounted) setState(() => _isPerformingAction = false);
      }
    }
  }

  Future<void> _toggleStudentStatus(String uid, bool currentActive) async {
    setState(() => _isPerformingAction = true);
    try {
      if (currentActive) {
        await AdminRepository().suspendStudent(uid);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student account suspended'), backgroundColor: AppColors.success),
        );
      } else {
        await AdminRepository().activateStudent(uid);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student account activated'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isPerformingAction = false);
    }
  }

  Future<void> _confirmDeleteStudent(BuildContext context, String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Delete Student'),
          ],
        ),
        content: Text('Are you sure you want to permanently delete "$name" and all associated bus passes/applications? This action is irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Student', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isPerformingAction = true);
      try {
        await AdminRepository().deleteStudent(uid);
        Navigator.pop(context); // close sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student account permanently deleted'), backgroundColor: AppColors.success),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      } finally {
        if (mounted) setState(() => _isPerformingAction = false);
      }
    }
  }
}

// ============================================================
// FORMAT DATE HELPER
// ============================================================

String _formatDate(dynamic value) {
  if (value == null) return 'N/A';
  DateTime? date;
  if (value is Timestamp) {
    date = value.toDate();
  } else if (value is DateTime) {
    date = value;
  }
  if (date == null) return 'N/A';
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final day = date.day.toString().padLeft(2, '0');
  final month = months[date.month - 1];
  final year = date.year;
  
  int hour = date.hour;
  final period = hour >= 12 ? 'PM' : 'AM';
  if (hour > 12) hour -= 12;
  if (hour == 0) hour = 12;
  final minute = date.minute.toString().padLeft(2, '0');
  
  return "$day $month $year, $hour:$minute $period";
}

// ============================================================
// SECTION HEADER HELPER
// ============================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
