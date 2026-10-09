// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/data/repositories/admin_repository.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/driver/domain/driver_providers.dart';
import 'package:icem_bus/config/routes/app_routes.dart';

/// Dashboard Overview Tab — Summary cards, quick actions, recent applications
class AdminOverviewTab extends ConsumerWidget {
  const AdminOverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(dashboardSearchQueryProvider);
    final statusFilter = ref.watch(dashboardStatusFilterProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    final hour = DateTime.now().hour;
    final String greetingTime = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    final adminDisplayName = user?.fullName.isNotEmpty == true ? user!.fullName.split(' ').first : 'Admin';

    return SingleChildScrollView(
      primary: false,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Greeting Section ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greetingTime, $adminDisplayName',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Campus Mobility Overview',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryCrimson.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryCrimson.withOpacity(0.28)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: AppColors.primaryCrimson),
                    SizedBox(width: 4),
                    Text(
                      'LIVE FLEET',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryCrimson,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── Mobility Statistics Section ──
          const AdminSectionHeader(title: 'Mobility Overview'),
          const SizedBox(height: 14),
          _buildStatCardsGrid(context, ref),
          const SizedBox(height: 28),

          // ── Quick Shortcuts (4 compact action tiles) ──
          const AdminSectionHeader(
            title: 'Quick Shortcuts',
            actionLabel: null,
          ),
          const SizedBox(height: 14),
          _buildQuickShortcuts(context, ref),
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
          const SizedBox(height: 16),

          // Recent application cards
          _buildRecentApplications(context, ref, searchQuery, statusFilter),
        ],
      ),
    );
  }

  // ── Stat Cards Grid (Responsive LayoutBuilder, No Overflows) ──
  Widget _buildStatCardsGrid(BuildContext context, WidgetRef ref) {
    final totalStudents = ref.watch(totalStudentsStreamProvider);
    final activePasses = ref.watch(activePassesStreamProvider);
    final pending = ref.watch(pendingAppsStreamProvider);
    final totalBuses = ref.watch(totalBusesStreamProvider);
    final expiredPasses = ref.watch(expiredPassesStreamProvider);
    final driversAsync = ref.watch(driversListStreamProvider);
    final paymentsAsync = ref.watch(paymentsListStreamProvider);

    // Compute Today's Revenue and Pending Payments from real Firestore streams
    double todayRevenue = 0.0;
    int pendingPaymentsCount = 0;
    final now = DateTime.now();

    final paymentsList = paymentsAsync.valueOrNull ?? [];
    for (final p in paymentsList) {
      final status = (p['status'] ?? p['paymentStatus'] ?? '').toString().toLowerCase();
      final isPaid = status == 'paid' || status == 'success';
      if (isPaid) {
        DateTime? dt;
        final val = p['createdAt'] ?? p['paymentDate'];
        if (val is Timestamp) dt = val.toDate();
        if (val is DateTime) dt = val;
        if (dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          final amt = p['amount'] is num
              ? (p['amount'] as num).toDouble()
              : (double.tryParse(p['amount']?.toString() ?? '') ?? 0.0);
          todayRevenue += amt;
        }
      } else if (status == 'pending' || status == 'created') {
        pendingPaymentsCount++;
      }
    }

    final todayRevFormatted = '₹${todayRevenue.toStringAsFixed(0)}';

    // Compute Active Drivers count
    final driversList = driversAsync.valueOrNull ?? [];
    final activeDriversCount = driversList.where((d) => (d['status'] ?? 'Active') == 'Active').length;

    final stats = <_StatData>[
      _StatData(
        'Total Students',
        totalStudents.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        Icons.people_alt_rounded,
        AppColors.info,
        totalStudents.isLoading,
        '+12 this month',
      ),
      _StatData(
        'Active Passes',
        activePasses.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        Icons.badge_rounded,
        AppColors.success,
        activePasses.isLoading,
        'Verified',
      ),
      _StatData(
        'Pending Apps',
        pending.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        Icons.pending_actions_rounded,
        AppColors.warning,
        pending.isLoading,
        'Action needed',
      ),
      _StatData(
        "Today's Revenue",
        paymentsAsync.isLoading ? '...' : todayRevFormatted,
        Icons.currency_rupee_rounded,
        AppColors.primaryCrimson,
        paymentsAsync.isLoading,
        'Live total',
      ),
      _StatData(
        'Total Buses',
        totalBuses.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        Icons.directions_bus_rounded,
        const Color(0xFF06B6D4),
        totalBuses.isLoading,
        'Campus fleet',
      ),
      _StatData(
        'Active Drivers',
        driversAsync.isLoading ? '...' : activeDriversCount.toString(),
        Icons.airline_seat_recline_normal_rounded,
        const Color(0xFF10B981),
        driversAsync.isLoading,
        'On duty',
      ),
      _StatData(
        'Pending Payments',
        paymentsAsync.isLoading ? '...' : pendingPaymentsCount.toString(),
        Icons.receipt_long_rounded,
        const Color(0xFFF97316),
        paymentsAsync.isLoading,
        'Unverified',
      ),
      _StatData(
        'Expired Passes',
        expiredPasses.when(data: (v) => v.toString(), loading: () => '...', error: (_, _) => '!'),
        Icons.history_toggle_off_rounded,
        const Color(0xFF8B5CF6),
        expiredPasses.isLoading,
        'Needs renewal',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
                ? 3
                : 2;
        // mainAxisExtent avoids overflow from ratio arithmetic on small screens
        const double cardHeight = 120;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: cardHeight,
          ),
          itemCount: stats.length,
          itemBuilder: (context, i) => AdminStatCard(
            label: stats[i].label,
            value: stats[i].value,
            icon: stats[i].icon,
            color: stats[i].color,
            isLoading: stats[i].isLoading,
            subtitle: stats[i].subtitle,
          ),
        );
      },
    );
  }

  // ── Quick Shortcuts — 4 focused action tiles (navigation is in the drawer) ──
  Widget _buildQuickShortcuts(BuildContext context, WidgetRef ref) {
    final shortcuts = [
      _ActionItemData(
        'Students',
        'View & manage profiles',
        Icons.people_alt_rounded,
        AppColors.info,
        4,
      ),
      _ActionItemData(
        'Approve Passes',
        'Review pending apps',
        Icons.assignment_turned_in_rounded,
        AppColors.success,
        1,
      ),
      _ActionItemData(
        'Payments',
        'Revenue & Razorpay',
        Icons.receipt_long_rounded,
        const Color(0xFFF97316),
        5,
      ),
      _ActionItemData(
        'Notify Students',
        'Send campus alerts',
        Icons.send_rounded,
        const Color(0xFF8B5CF6),
        6,
      ),
    ];

    // Always 2 columns on mobile; 4 on desktop — fixed height avoids overflow
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        const double cardHeight = 120;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: cardHeight,
          ),
          itemCount: shortcuts.length,
          itemBuilder: (context, i) {
            final a = shortcuts[i];
            return AdminActionCard(
              title: a.title,
              description: a.description,
              icon: a.icon,
              color: a.color,
              onTap: () {
                ref.read(adminTabProvider.notifier).state = a.tabIndex;
              },
            );
          },
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
              onApprove: () => _confirmApprove(context, ref, repo, app['id'], app['paymentStatus']),
              onReject: () => _showRejectDialog(context, ref, repo, app['id']),
              onViewDetails: () => context.push('/admin/application/${app['id']}'),
            );
          },
        );
      },
    );
  }

  void _confirmApprove(BuildContext context, WidgetRef ref, AdminRepository repo, String id, [dynamic paymentStatus]) {
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
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text('Approve Pass Application', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Are you sure you want to approve this application and issue an active digital pass?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final adminUid = ref.read(authControllerProvider).user?.uid ?? 'admin';
              try {
                await repo.approveApplication(id, adminUid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Application approved successfully!'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Approval failed: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, AdminRepository repo, String id) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text('Reject Application', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Specify reason for rejection:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. Invalid document or fee pending',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppColors.elevatedSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              final adminUid = ref.read(authControllerProvider).user?.uid ?? 'admin';
              Navigator.pop(ctx);
              try {
                await repo.rejectApplication(id, reason.isNotEmpty ? reason : 'Rejected by administrator', adminUid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Application rejected.'), backgroundColor: AppColors.error),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Rejection failed: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

// ── Private Data Helper Classes ──
class _StatData {
  final String label;
  final String value;
  final dynamic icon;
  final Color color;
  final bool isLoading;
  final String? subtitle;

  _StatData(this.label, this.value, this.icon, this.color, this.isLoading, [this.subtitle]);
}

class _ActionItemData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int tabIndex;

  _ActionItemData(this.title, this.description, this.icon, this.color, this.tabIndex);
}
