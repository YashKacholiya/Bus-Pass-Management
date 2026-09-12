// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_overview_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_applications_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_routes_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_buses_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_students_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_payments_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_notifications_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_reports_tab.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_settings_tab.dart';

// ============================================================
// ADMIN DASHBOARD SCREEN
// ============================================================

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final currentTab = ref.watch(adminTabProvider);
    final user = authState.user;
    final theme = Theme.of(context);

    // ── Auth Guard ──
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AppRoutes.login);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (user.role != 'Admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Denied'),
            backgroundColor: AppColors.error,
          ),
        );
        context.go(AppRoutes.studentDashboard);
      });
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad_rounded,
                    size: 80, color: AppColors.primaryCrimson),
                const SizedBox(height: 24),
                Text(
                  'Access Denied',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Only Administrators are authorized to view this management console.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: isMobile && currentTab != 2 && currentTab != 3
          ? AppBar(
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              title: Row(
                children: [
                  Image.asset(
                    'assets/images/bus_logo.png',
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getTabTitle(currentTab),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              leading: IconButton(
                icon: Icon(Icons.menu_rounded, color: theme.colorScheme.onSurface),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded,
                      color: AppColors.primaryCrimson),
                  onPressed: () => _handleLogout(context),
                ),
              ],
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  color: theme.dividerColor,
                ),
              ),
            )
          : null,
      drawer: isMobile
          ? Drawer(
              backgroundColor: theme.colorScheme.surface,
              child: _buildSidebarContent(context, ref, currentTab,
                  isMobile: true),
            )
          : null,
      body: SafeArea(
        child: Row(
          children: [
            // ── Desktop Sidebar ──
            if (!isMobile) ...[
              SizedBox(
                width: 260,
                child: Container(
                  color: theme.colorScheme.surface,
                  child: _buildSidebarContent(context, ref, currentTab,
                      isMobile: false),
                ),
              ),
              Container(
                width: 1,
                color: theme.dividerColor,
              ),
            ],
            // ── Main Content ──
            Expanded(
              child: Container(
                color: theme.scaffoldBackgroundColor,
                child: Column(
                  children: [
                    if (!isMobile) _buildDesktopHeader(context, user.fullName),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _buildTabContent(currentTab),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab Content Switcher ──
  Widget _buildTabContent(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return const AdminOverviewTab(key: ValueKey('overview'));
      case 1:
        return const AdminApplicationsTab(key: ValueKey('applications'));
      case 2:
        return const AdminRoutesTab(key: ValueKey('routes'));
      case 3:
        return const AdminBusesTab(key: ValueKey('buses'));
      case 4:
        return const AdminStudentsTab(key: ValueKey('students'));
      case 5:
        return const AdminPaymentsTab(key: ValueKey('payments'));
      case 6:
        return const AdminNotificationsTab(key: ValueKey('notifications'));
      case 7:
        return const AdminReportsTab(key: ValueKey('reports'));
      case 8:
        return const AdminSettingsTab(key: ValueKey('settings'));
      default:
        return const AdminOverviewTab(key: ValueKey('overview'));
    }
  }

  // ── Tab Titles ──
  String _getTabTitle(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 'Overview Dashboard';
      case 1:
        return 'Pass Management';
      case 2:
        return 'Route Management';
      case 3:
        return 'Bus Management';
      case 4:
        return 'Student Management';
      case 5:
        return 'Payment Management';
      case 6:
        return 'Notifications';
      case 7:
        return 'Reports & Analytics';
      case 8:
        return 'Settings';
      default:
        return 'Admin Portal';
    }
  }

  // ── Desktop Header ──
  Widget _buildDesktopHeader(BuildContext context, String adminName) {
    final currentTab = ref.watch(adminTabProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 18.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/bus_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ICEM Transport Office',
                    style: TextStyle(
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getTabTitle(currentTab),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded,
                        color: AppColors.accentGold, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      adminName,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: AppColors.primaryCrimson.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _handleLogout(context),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.logout_rounded,
                        color: AppColors.primaryCrimson, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sidebar Content (shared between drawer and desktop sidebar) ──
  Widget _buildSidebarContent(
    BuildContext context,
    WidgetRef ref,
    int currentTab, {
    required bool isMobile,
  }) {
    final theme = Theme.of(context);
    final sidebarItems = [
      _SidebarItem(0, 'Dashboard', Icons.dashboard_rounded),
      _SidebarItem(1, 'Applications', Icons.badge_rounded),
      _SidebarItem(2, 'Routes', Icons.route_rounded),
      _SidebarItem(3, 'Buses', Icons.directions_bus_rounded),
      _SidebarItem(4, 'Students', Icons.people_alt_rounded),
      _SidebarItem(5, 'Payments', Icons.receipt_long_rounded),
      _SidebarItem(6, 'Notifications', Icons.send_rounded),
      _SidebarItem(7, 'Reports', Icons.analytics_rounded),
      _SidebarItem(8, 'Settings', Icons.settings_rounded),
    ];

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // ── Branding Header ──
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primaryCrimson, AppColors.darkCrimson],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryCrimson.withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.asset(
                                  'assets/images/bus_logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'ICEM BUS PASS',
                            style: TextStyle(
                              color: AppColors.primaryCrimson,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Admin Console',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: theme.dividerColor),
                    const SizedBox(height: 8),

                    // ── Nav Items ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(sidebarItems.length, (index) {
                          final item = sidebarItems[index];
                          final isSelected = currentTab == item.index;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Material(
                              color: isSelected
                                  ? AppColors.primaryCrimson.withOpacity(0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  ref.read(adminTabProvider.notifier).state = item.index;
                                  if (isMobile) {
                                    Navigator.pop(context);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        item.icon,
                                        size: 20,
                                        color: isSelected
                                            ? AppColors.primaryCrimson
                                            : theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            color: isSelected
                                                ? AppColors.primaryCrimson
                                                : theme.colorScheme.onSurface,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primaryCrimson,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    const Spacer(),

                    // ── Logout Button ──
                    Container(height: 1, color: theme.dividerColor),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Material(
                        color: AppColors.primaryCrimson.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _handleLogout(context),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.logout_rounded,
                                    size: 20, color: AppColors.primaryCrimson),
                                SizedBox(width: 14),
                                Text(
                                  'Logout',
                                  style: TextStyle(
                                    color: AppColors.primaryCrimson,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Logout Handler ──
  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Sign Out'),
        content: const Text(
            'Are you sure you want to sign out from the Administrative Console?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(
                  color: AppColors.primaryCrimson, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
      context.go(AppRoutes.login);
    }
  }
}

// ── Sidebar item data class ──
class _SidebarItem {
  final int index;
  final String title;
  final IconData icon;

  _SidebarItem(this.index, this.title, this.icon);
}