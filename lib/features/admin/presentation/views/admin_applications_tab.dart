// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/data/repositories/admin_repository.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';

/// Full applications management tab with search, filter, approve/reject/correction
class AdminApplicationsTab extends ConsumerStatefulWidget {
  const AdminApplicationsTab({super.key});

  @override
  ConsumerState<AdminApplicationsTab> createState() =>
      _AdminApplicationsTabState();
}

class _AdminApplicationsTabState extends ConsumerState<AdminApplicationsTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final applicationsAsync =
        ref.watch(filteredApplicationsStreamProvider(_statusFilter));

    return Column(
      children: [
        // Search and filter row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: [
              AdminSearchBar(
                hintText: 'Search by Name, PRN, or College ID...',
                value: _searchQuery,
                onChanged: (q) => setState(() => _searchQuery = q),
              ),
              const SizedBox(height: 12),
              AdminFilterChips(
                filters: const [
                  'All',
                  'Pending',
                  'Approved',
                  'Rejected',
                  'Expired',
                ],
                selected: _statusFilter,
                onSelected: (f) => setState(() => _statusFilter = f),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Applications list
        Expanded(
          child: applicationsAsync.when(
            loading: () => const AdminLoadingState(),
            error: (e, _) => AdminErrorState(message: e.toString()),
            data: (applications) {
              var filtered = applications;
              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                filtered = filtered.where((app) {
                  final name = (app['studentName'] ?? app['fullName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final prn = (app['prn'] ?? '').toString().toLowerCase();
                  final collegeId = (app['collegeId'] ?? '').toString().toLowerCase();
                  return name.contains(q) || prn.contains(q) || collegeId.contains(q);
                }).toList();
              }

              if (filtered.isEmpty) {
                return const AdminEmptyState(
                  title: 'No applications found',
                  subtitle: 'Try adjusting your search or filter criteria.',
                  icon: Icons.search_off_rounded,
                );
              }

              final repo = AdminRepository();

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final app = filtered[i];
                  return AdminApplicationCard(
                    application: app,
                    onApprove: () => _confirmApprove(repo, app['id'], app['paymentStatus']),
                    onReject: () => _showRejectDialog(repo, app['id']),
                    onViewDetails: () => _navigateToDetail(app['id']),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Navigate to the full application detail screen
  void _navigateToDetail(String applicationId) {
    context.push('/admin/application/$applicationId');
  }

  /// Approve with confirmation — includes admin UID
  void _confirmApprove(AdminRepository repo, String applicationId, [dynamic paymentStatus]) {
    final pStatus = (paymentStatus ?? '').toString().trim().toLowerCase();
    if (pStatus.isNotEmpty && pStatus != 'paid' && pStatus != 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment required before approval. Student must complete verified payment first.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve Application'),
        content: const Text(
            'Are you sure you want to approve this bus pass application? A unique Pass ID will be generated and digital pass activated.'),
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
                await repo.approveApplication(applicationId, adminUid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Application approved successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Approve',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Reject with reason dialog
  void _showRejectDialog(AdminRepository repo, String applicationId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this application.'),
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
                await repo.rejectApplication(applicationId, reason, adminUid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Application rejected'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
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
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
