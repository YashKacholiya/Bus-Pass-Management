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

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final currentTab = ref.watch(adminTabProvider);
    final user = authState.user;
    final theme = Theme.of(context);

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go(AppRoutes.login));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user.role != 'Admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access Denied'), backgroundColor: AppColors.error));
        context.go(AppRoutes.studentDashboard);
      });
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.gpp_bad_rounded, size: 80, color: AppColors.primaryCrimson),
          const SizedBox(height: 24),
          Text('Access Denied', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Only Administrators are authorized to view this management console.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
        ]))),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: isMobile ? _buildMobileAppBar(context, currentTab, theme) : null,
      drawer: isMobile ? Drawer(backgroundColor: theme.colorScheme.surface, child: _AdminDrawer(currentTab: currentTab, onNavigate: (i) => _navigate(ref, context, i, true), onLogout: () => _handleLogout(context))) : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile) ...[
              SizedBox(width: 260, child: Container(color: theme.colorScheme.surface, child: _AdminDrawer(currentTab: currentTab, onNavigate: (i) => _navigate(ref, context, i, false), onLogout: () => _handleLogout(context)))),
              Container(width: 1, color: theme.dividerColor),
            ],
            Expanded(
              child: Container(
                color: theme.scaffoldBackgroundColor,
                child: Column(children: [
                  if (!isMobile) _buildDesktopHeader(context, user.fullName),
                  Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child), child: _buildTabContent(currentTab))),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context, int currentTab, ThemeData theme) {
    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(icon: Icon(Icons.menu_rounded, color: theme.colorScheme.onSurface, size: 24), onPressed: () => _scaffoldKey.currentState?.openDrawer(), tooltip: 'Open Menu'),
      titleSpacing: 0,
      title: Row(children: [
        Container(width: 30, height: 30, padding: const EdgeInsets.all(4), decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primaryCrimson, AppColors.darkCrimson], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(8)), child: Image.asset('assets/images/bus_logo.png', fit: BoxFit.contain)),
        const SizedBox(width: 10),
        Expanded(child: Text(_getTabTitle(currentTab), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: theme.colorScheme.onSurface, letterSpacing: -0.2), overflow: TextOverflow.ellipsis, maxLines: 1)),
      ]),
      actions: [
        IconButton(icon: Icon(Icons.notifications_none_rounded, color: theme.colorScheme.onSurfaceVariant, size: 22), onPressed: () => ref.read(adminTabProvider.notifier).state = 6, tooltip: 'Notifications'),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: theme.dividerColor)),
    );
  }

  Widget _buildDesktopHeader(BuildContext context, String adminName) {
    final currentTab = ref.watch(adminTabProvider);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(color: theme.colorScheme.surface, border: Border(bottom: BorderSide(color: theme.dividerColor))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ICEM TRANSPORT OFFICE', style: TextStyle(color: AppColors.primaryCrimson, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1.4)),
            const SizedBox(height: 3),
            Text(_getTabTitle(currentTab), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface, letterSpacing: -0.3)),
          ]),
          Row(children: [
            IconButton(icon: Icon(Icons.qr_code_scanner_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20), onPressed: () => context.push(AppRoutes.qrVerification), tooltip: 'Verify QR'),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.dividerColor)),
              child: Row(children: [const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primaryCrimson, size: 16), const SizedBox(width: 7), Text(adminName, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13))]),
            ),
            const SizedBox(width: 10),
            Material(color: AppColors.primaryCrimson.withOpacity(0.08), borderRadius: BorderRadius.circular(10), child: InkWell(borderRadius: BorderRadius.circular(10), onTap: () => _handleLogout(context), child: const Padding(padding: EdgeInsets.all(9), child: Icon(Icons.logout_rounded, color: AppColors.primaryCrimson, size: 18)))),
          ]),
        ],
      ),
    );
  }

  Widget _buildTabContent(int tabIndex) {
    switch (tabIndex) {
      case 0: return const AdminOverviewTab(key: ValueKey('overview'));
      case 1: return const AdminApplicationsTab(key: ValueKey('applications'));
      case 2: return const AdminRoutesTab(key: ValueKey('routes'));
      case 3: return const AdminBusesTab(key: ValueKey('buses'));
      case 4: return const AdminStudentsTab(key: ValueKey('students'));
      case 5: return const AdminPaymentsTab(key: ValueKey('payments'));
      case 6: return const AdminNotificationsTab(key: ValueKey('notifications'));
      case 7: return const AdminReportsTab(key: ValueKey('reports'));
      case 8: return const AdminSettingsTab(key: ValueKey('settings'));
      default: return const AdminOverviewTab(key: ValueKey('overview'));
    }
  }

  String _getTabTitle(int tabIndex) {
    switch (tabIndex) {
      case 0: return 'Overview Dashboard';
      case 1: return 'Pass Management';
      case 2: return 'Route Management';
      case 3: return 'Bus Management';
      case 4: return 'Student Management';
      case 5: return 'Payment Management';
      case 6: return 'Notifications';
      case 7: return 'Reports & Analytics';
      case 8: return 'Settings';
      default: return 'Admin Portal';
    }
  }

  void _navigate(WidgetRef ref, BuildContext context, int tabIndex, bool isMobile) {
    ref.read(adminTabProvider.notifier).state = tabIndex;
    if (isMobile) Navigator.pop(context);
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Sign Out'),
        content: const Text('Are you sure you want to sign out from the Administrative Console?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out', style: TextStyle(color: AppColors.primaryCrimson, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
      context.go(AppRoutes.login);
    }
  }
}

// ============================================================
// PREMIUM GROUPED NAVIGATION DRAWER (Stateless, Reusable)
// ============================================================
class _AdminDrawer extends StatelessWidget {
  final int currentTab;
  final void Function(int tabIndex) onNavigate;
  final VoidCallback onLogout;
  const _AdminDrawer({required this.currentTab, required this.onNavigate, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // ── Branding Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                  child: Row(children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primaryCrimson, AppColors.darkCrimson], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [BoxShadow(color: AppColors.primaryCrimson.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 5))],
                      ),
                      child: Center(child: Padding(padding: const EdgeInsets.all(8), child: Image.asset('assets/images/bus_logo.png', fit: BoxFit.contain))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('ADMIN PORTAL', style: TextStyle(color: AppColors.primaryCrimson, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
                      const SizedBox(height: 2),
                      Text('Smart Campus Mobility', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500)),
                    ])),
                  ]),
                ),
                Container(height: 1, color: theme.dividerColor),
                const SizedBox(height: 10),

                // ── OVERVIEW ──
                _SectionLabel(label: 'OVERVIEW', theme: theme),
                _NavItem(index: 0, title: 'Dashboard', icon: Icons.dashboard_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(0)),
                const SizedBox(height: 6),

                // ── MANAGEMENT ──
                _SectionLabel(label: 'MANAGEMENT', theme: theme),
                _NavItem(index: 4, title: 'Students', icon: Icons.people_alt_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(4)),
                _NavItem(index: 2, title: 'Routes', icon: Icons.route_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(2)),
                _NavItem(index: 3, title: 'Buses', icon: Icons.directions_bus_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(3)),
                _NavItem(index: -1, title: 'Drivers', icon: Icons.badge_rounded, currentTab: currentTab, theme: theme, onTap: () {
                  Navigator.of(context).maybePop();
                  context.push(AppRoutes.driverManagement);
                }),
                const SizedBox(height: 6),

                // ── OPERATIONS ──
                _SectionLabel(label: 'OPERATIONS', theme: theme),
                _NavItem(index: 5, title: 'Payments', icon: Icons.receipt_long_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(5)),
                _NavItem(index: 1, title: 'Pass Management', icon: Icons.card_membership_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(1)),
                _NavItem(index: 6, title: 'Notifications', icon: Icons.notifications_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(6)),
                const SizedBox(height: 6),

                // ── ANALYTICS ──
                _SectionLabel(label: 'ANALYTICS', theme: theme),
                _NavItem(index: 7, title: 'Reports & Analytics', icon: Icons.analytics_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(7)),
                const SizedBox(height: 6),

                // ── SYSTEM ──
                _SectionLabel(label: 'SYSTEM', theme: theme),
                _NavItem(index: 8, title: 'Settings', icon: Icons.settings_rounded, currentTab: currentTab, theme: theme, onTap: () => onNavigate(8)),

                const Spacer(),

                // ── Logout ──
                Container(height: 1, color: theme.dividerColor),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Material(
                    color: AppColors.primaryCrimson.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onLogout,
                      child: const Padding(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13), child: Row(children: [
                        Icon(Icons.logout_rounded, size: 20, color: AppColors.primaryCrimson),
                        SizedBox(width: 14),
                        Text('Logout', style: TextStyle(color: AppColors.primaryCrimson, fontWeight: FontWeight.w700, fontSize: 13.5)),
                      ])),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

/// Muted section label in the drawer.
class _SectionLabel extends StatelessWidget {
  final String label;
  final ThemeData theme;
  const _SectionLabel({required this.label, required this.theme});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), letterSpacing: 1.2)),
    );
  }
}

/// Single navigation item in the drawer.
class _NavItem extends StatelessWidget {
  final int index;
  final String title;
  final IconData icon;
  final int currentTab;
  final ThemeData theme;
  final VoidCallback onTap;
  const _NavItem({required this.index, required this.title, required this.icon, required this.currentTab, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = index != -1 && currentTab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
      child: Material(
        color: isSelected ? AppColors.primaryCrimson.withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(children: [
              Icon(icon, size: 19, color: isSelected ? AppColors.primaryCrimson : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 13),
              Expanded(child: Text(title, style: TextStyle(color: isSelected ? AppColors.primaryCrimson : theme.colorScheme.onSurface, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, fontSize: 13.5))),
              if (isSelected) Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.primaryCrimson, shape: BoxShape.circle)),
            ]),
          ),
        ),
      ),
    );
  }
}