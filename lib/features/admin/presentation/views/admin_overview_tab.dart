// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/data/repositories/admin_repository.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/config/routes/app_routes.dart';

/// Dashboard Overview Tab — Summary cards, quick actions, recent applications
class AdminOverviewTab extends ConsumerWidget {
  const AdminOverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(dashboardSearchQueryProvider);
    final statusFilter = ref.watch(dashboardStatusFilterProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary Stat Cards ──
          const AdminSectionHeader(title: 'Overview'),
          const SizedBox(height: 14),
          _buildStatCardsGrid(context, ref),
          const SizedBox(height: 28),

          // ── Quick Actions ──
          AdminSectionHeader(
            title: 'Quick Actions',
            actionLabel: null,
          ),
          const SizedBox(height: 14),
          _buildQuickActions(context, ref),
          const SizedBox(height: 28),

          // ── Recent Applications ──
          AdminSectionHeader(
            title: 'Recent Applications',
            actionLabel: 'View All',
            onAction: () {
              ref.read(adminTabProvider.notifier).state = 1;
            },
          ),
          const SizedBox(height: 14),

          // Search + Filter
          AdminSearchBar(
            hintText: 'Search by Name, PRN, or College ID...',
            value: searchQuery,
            onChanged: (q) =>
                ref.read(dashboardSearchQueryProvider.notifier).state = q,
          ),
          const SizedBox(height: 12),
          AdminFilterChips(
            filters: const ['All', 'Pending', 'Approved', 'Rejected', 'Expired'],
            selected: statusFilter,
            onSelected: (f) =>
                ref.read(dashboardStatusFilterProvider.notifier).state = f,
          ),
          const SizedBox(height: 14),

          // Recent application cards
          _buildRecentApplications(context, ref, searchQuery, statusFilter),
        ],
      ),
    );
  }

  Widget _buildIcemLogoIcon({double size = 22}) {
    return Image.asset(
      'assets/images/bus_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  // ── Stat Cards Grid ──
  Widget _buildStatCardsGrid(BuildContext context, WidgetRef ref) {
    final totalStudents = ref.watch(totalStudentsStreamProvider);
    final activePasses = ref.watch(activePassesStreamProvider);
    final pending = ref.watch(pendingAppsStreamProvider);
    final approved = ref.watch(approvedPassesStreamProvider);
    final rejected = ref.watch(rejectedPassesStreamProvider);
    final expired = ref.watch(expiredPassesStreamProvider);
    final totalRoutes = ref.watch(totalRoutesStreamProvider);
    final totalBuses = ref.watch(totalBusesStreamProvider);

    final stats = <_StatData>[
      _StatData(
        'Total Students',
        totalStudents.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        _buildIcemLogoIcon(size: 22),
        AppColors.info,
        totalStudents.isLoading,
      ),
      _StatData(
        'Active Passes',
        activePasses.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        _buildIcemLogoIcon(size: 22),
        AppColors.success,
        activePasses.isLoading,
      ),
      _StatData(
        'Pending',
        pending.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        _buildIcemLogoIcon(size: 22),
        AppColors.warning,
        pending.isLoading,
      ),
      _StatData(
        'Approved',
        approved.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        _buildIcemLogoIcon(size: 22),
        AppColors.success,
        approved.isLoading,
      ),
      _StatData(
        'Rejected',
        rejected.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        _buildIcemLogoIcon(size: 22),
        AppColors.error,
        rejected.isLoading,
      ),
      _StatData(
        'Expired',
        expired.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        _buildIcemLogoIcon(size: 22),
        const Color(0xFF78909C),
        expired.isLoading,
      ),
      _StatData(
        'Total Routes',
        totalRoutes.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        _buildIcemLogoIcon(size: 22),
        AppColors.accentGold,
        totalRoutes.isLoading,
      ),
      _StatData(
        'Total Buses',
        totalBuses.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        _buildIcemLogoIcon(size: 22),
        AppColors.primaryCrimson,
        totalBuses.isLoading,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: constraints.maxWidth < 600 ? 1.08 : 1.3,
          ),
          itemCount: stats.length,
          itemBuilder: (context, i) => AdminStatCard(
            label: stats[i].label,
            value: stats[i].value,
            icon: stats[i].icon,
            color: stats[i].color,
            isLoading: stats[i].isLoading,
          ),
        );
      },
    );
  }

  // ── Quick Actions Grid ──
  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    final actions = [
      _QuickActionData('Review\nApplications', _buildIcemLogoIcon(size: 20), AppColors.primaryCrimson, 1),
      _QuickActionData('Manage\nRoutes', _buildIcemLogoIcon(size: 20), AppColors.accentGold, 2),
      _QuickActionData('Manage\nBuses', _buildIcemLogoIcon(size: 20), AppColors.info, 3),
      _QuickActionData('Manage\nDrivers', _buildIcemLogoIcon(size: 20), AppColors.primaryCrimson, 9),
      _QuickActionData('Manage\nStudents', Icons.people_alt_rounded, AppColors.success, 4),
      _QuickActionData('Payments', Icons.receipt_long_rounded, const Color(0xFF7C3AED), 5),
      _QuickActionData('Reports', Icons.analytics_rounded, const Color(0xFF0891B2), 7),
      _QuickActionData('Settings', Icons.settings_rounded, const Color(0xFF64748B), 8),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
                ? 4
                : 4;
        final cardWidth = (constraints.maxWidth - (crossAxisCount - 1) * 12) / crossAxisCount;
        final desiredHeight = constraints.maxWidth < 600 ? 95.0 : 100.0;
        final childAspectRatio = cardWidth / desiredHeight;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: actions.length,
          itemBuilder: (context, i) => AdminQuickAction(
            label: actions[i].label,
            icon: actions[i].icon,
            color: actions[i].color,
            onTap: () {
              if (actions[i].tabIndex == 9) {
                context.push(AppRoutes.driverManagement);
              } else if (actions[i].tabIndex == 8) {
                context.push(AppRoutes.adminSettings);
              } else {
                ref.read(adminTabProvider.notifier).state = actions[i].tabIndex;
              }
            },
          ),
        );
      },
    );
  }

  // ── Recent Applications List ──
  Widget _buildRecentApplications(
    BuildContext context,
    WidgetRef ref,
    String searchQuery,
    String statusFilter,
  ) {
    final recentApps = ref.watch(recentApplicationsStreamProvider);

    return recentApps.when(
      loading: () => const AdminLoadingState(),
      error: (e, _) => AdminErrorState(message: e.toString()),
      data: (applications) {
        // Apply local search filter
        var filtered = applications;

        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          filtered = filtered.where((app) {
            final name =
                (app['studentName'] ?? app['fullName'] ?? '').toString().toLowerCase();
            final prn = (app['prn'] ?? '').toString().toLowerCase();
            final collegeId = (app['collegeId'] ?? '').toString().toLowerCase();
            return name.contains(q) || prn.contains(q) || collegeId.contains(q);
          }).toList();
        }

        if (statusFilter != 'All') {
          filtered =
              filtered.where((app) => app['status'] == statusFilter).toList();
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
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final app = filtered[i];
            return AdminApplicationCard(
              application: app,
              onApprove: () => _confirmAction(
                context,
                'Approve Application',
                'Are you sure you want to approve this application?',
                () {
                  final adminUid = ref.read(authControllerProvider).user?.uid ?? '';
                  return repo.approveApplication(app['id'], adminUid);
                },
              ),
              onReject: () => _showRejectDialog(context, ref, repo, app['id']),
              onRequestCorrection: () => _showCorrectionDialog(context, repo, app['id']),
              onViewDetails: () => context.push('/admin/application/${app['id']}'),
            );
          },
        );
      },
    );
  }

  void _confirmAction(
    BuildContext context,
    String title,
    String message,
    Future<void> Function() action,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await action();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$title successful'),
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
            child: Text(
              'Confirm',
              style: TextStyle(
                color: title.contains('Reject')
                    ? AppColors.error
                    : AppColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, Map<String, dynamic> application) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ApplicationDetailSheet(application: application),
    );
  }

  void _showRejectDialog(
      BuildContext context, WidgetRef ref, AdminRepository repo, String applicationId) {
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
                final adminUid = ref.read(authControllerProvider).user?.uid ?? '';
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

  void _showCorrectionDialog(
      BuildContext context, AdminRepository repo, String applicationId) {
    final messageController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Request Correction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Describe what corrections the student needs to make.'),
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
}

// ── Private data classes ──

class _StatData {
  final String label;
  final String value;
  final dynamic icon;
  final Color color;
  final bool isLoading;

  _StatData(this.label, this.value, this.icon, this.color, this.isLoading);
}

class _QuickActionData {
  final String label;
  final dynamic icon;
  final Color color;
  final int tabIndex;

  _QuickActionData(this.label, this.icon, this.color, this.tabIndex);
}
