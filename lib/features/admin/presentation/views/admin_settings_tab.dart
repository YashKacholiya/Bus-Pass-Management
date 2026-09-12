// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/config/constants/app_constants.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/driver/domain/driver_providers.dart';
import 'package:icem_bus/services/storage/storage_service.dart';

/// Settings tab for admin preferences — pure scrollable content widget (no inner Scaffold)
class AdminSettingsTab extends ConsumerStatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  ConsumerState<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends ConsumerState<AdminSettingsTab> {
  bool _isRefreshingData = false;
  bool _isCheckingStatus = false;
  String _firestoreStatus = 'Operational';

  String _formatDateTime(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $ampm';
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsNotifierProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final fbUser = FirebaseAuth.instance.currentUser;

    final adminName = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : (fbUser?.displayName ?? 'Administrator');
    final adminEmail = user?.email.isNotEmpty == true
        ? user!.email
        : (fbUser?.email ?? 'admin@icem.edu');
    final adminRole = user?.role.isNotEmpty == true ? user!.role : 'Administrator';
    final adminMobile = user?.mobile ?? 'Not provided';
    final adminDept = user?.department ?? 'Central Transport Cell';
    final isEmailVerified = fbUser?.emailVerified ?? user?.isEmailVerified ?? true;

    // Formatting timestamps from real Firebase Auth metadata
    final lastSignIn = fbUser?.metadata.lastSignInTime;
    final formattedLastSignIn = lastSignIn != null
        ? _formatDateTime(lastSignIn)
        : 'Current Session Active';

    final createdDate = fbUser?.metadata.creationTime;
    final formattedCreated = createdDate != null
        ? _formatDate(createdDate)
        : 'Registered';

    return Container(
      color: const Color(0xFFF8FAFC),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          // ── Header Title & Subtitle ──
          const Text(
            'Console Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage administrator profile, application preferences, notifications, security, and system status.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 20),

          // ── 1. ADMIN PROFILE ──
          _SettingsSection(
            title: 'Admin Profile',
            icon: Icons.person_rounded,
            accentColor: AppColors.primaryCrimson,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar with Crimson gradient
                        Container(
                          width: 58,
                          height: 58,
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
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Name, Email, Role & Verified Badge
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                adminName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                adminEmail,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  // Role Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryCrimson.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      adminRole,
                                      style: const TextStyle(
                                        color: AppColors.primaryCrimson,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  // Account Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isEmailVerified
                                          ? const Color(0xFF10B981).withOpacity(0.12)
                                          : const Color(0xFFF59E0B).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isEmailVerified
                                              ? Icons.check_circle_rounded
                                              : Icons.pending_rounded,
                                          size: 11,
                                          color: isEmailVerified
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFF59E0B),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isEmailVerified ? 'Active & Verified' : 'Pending Verification',
                                          style: TextStyle(
                                            color: isEmailVerified
                                                ? const Color(0xFF047857)
                                                : const Color(0xFFB45309),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),
                    // Detail fields
                    _ProfileInfoTile(label: 'Contact Number', value: adminMobile, icon: Icons.phone_rounded),
                    const SizedBox(height: 6),
                    _ProfileInfoTile(label: 'Department', value: adminDept, icon: Icons.domain_rounded),
                    const SizedBox(height: 14),
                    // Edit Profile Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text(
                          'Edit Profile Details',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryCrimson,
                          side: const BorderSide(color: AppColors.primaryCrimson, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _openEditProfileDialog(
                          currentName: adminName,
                          currentMobile: adminMobile == 'Not provided' ? '' : adminMobile,
                          currentDept: adminDept == 'Central Transport Cell' ? '' : adminDept,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 2. APPEARANCE ──
          _SettingsSection(
            title: 'Appearance',
            icon: Icons.palette_rounded,
            accentColor: const Color(0xFF6366F1),
            children: [
              _SettingsRow(
                label: 'Theme Mode',
                subLabel: 'Select light, dark, or follow device system theme',
                trailing: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ThemePill(
                        title: 'System',
                        icon: Icons.brightness_auto_rounded,
                        isSelected: settings.themeMode == ThemeMode.system,
                        onTap: () => ref
                            .read(settingsNotifierProvider.notifier)
                            .updateThemeMode(ThemeMode.system),
                      ),
                      _ThemePill(
                        title: 'Light',
                        icon: Icons.light_mode_rounded,
                        isSelected: settings.themeMode == ThemeMode.light,
                        onTap: () => ref
                            .read(settingsNotifierProvider.notifier)
                            .updateThemeMode(ThemeMode.light),
                      ),
                      _ThemePill(
                        title: 'Dark',
                        icon: Icons.dark_mode_rounded,
                        isSelected: settings.themeMode == ThemeMode.dark,
                        onTap: () => ref
                            .read(settingsNotifierProvider.notifier)
                            .updateThemeMode(ThemeMode.dark),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),
              _SettingsRow(
                label: 'Compact UI Density',
                subLabel: 'Tighten spacing and card margins for high-density information',
                trailing: Switch(
                  value: settings.isCompactDensity,
                  activeColor: AppColors.primaryCrimson,
                  onChanged: (val) => ref
                      .read(settingsNotifierProvider.notifier)
                      .updateCompactDensity(val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 3. NOTIFICATION SETTINGS ──
          _SettingsSection(
            title: 'Notification Settings',
            icon: Icons.notifications_active_rounded,
            accentColor: const Color(0xFF0EA5E9),
            children: [
              _SettingsRow(
                label: 'Enable Notifications',
                subLabel: 'Master toggle for console alerts and activity events',
                trailing: Switch(
                  value: settings.notificationsEnabled,
                  activeColor: AppColors.primaryCrimson,
                  onChanged: (val) => ref
                      .read(settingsNotifierProvider.notifier)
                      .updateNotificationsEnabled(val),
                ),
              ),
              if (settings.notificationsEnabled) ...[
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                _SettingsRow(
                  label: 'Application Updates',
                  subLabel: 'Alerts when system versions or features update',
                  trailing: Switch(
                    value: settings.appUpdatesEnabled,
                    activeColor: AppColors.primaryCrimson,
                    onChanged: (val) => ref
                        .read(settingsNotifierProvider.notifier)
                        .updateAppUpdatesEnabled(val),
                  ),
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                _SettingsRow(
                  label: 'New Bus Pass Applications',
                  subLabel: 'Instant alerts when a student submits a new pass request',
                  trailing: Switch(
                    value: settings.newApplicationsEnabled,
                    activeColor: AppColors.primaryCrimson,
                    onChanged: (val) => ref
                        .read(settingsNotifierProvider.notifier)
                        .updateNewApplicationsEnabled(val),
                  ),
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                _SettingsRow(
                  label: 'Payment Notifications',
                  subLabel: 'Alerts on student online transactions and receipt uploads',
                  trailing: Switch(
                    value: settings.paymentNotificationsEnabled,
                    activeColor: AppColors.primaryCrimson,
                    onChanged: (val) => ref
                        .read(settingsNotifierProvider.notifier)
                        .updatePaymentNotificationsEnabled(val),
                  ),
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                _SettingsRow(
                  label: 'Approval / Rejection Notifications',
                  subLabel: 'Track status dispatch to students and drivers',
                  trailing: Switch(
                    value: settings.passDecisionNotificationsEnabled,
                    activeColor: AppColors.primaryCrimson,
                    onChanged: (val) => ref
                        .read(settingsNotifierProvider.notifier)
                        .updatePassDecisionNotificationsEnabled(val),
                  ),
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                _SettingsRow(
                  label: 'System Notifications',
                  subLabel: 'Critical alerts, server health, and maintenance notices',
                  trailing: Switch(
                    value: settings.systemNotificationsEnabled,
                    activeColor: AppColors.primaryCrimson,
                    onChanged: (val) => ref
                        .read(settingsNotifierProvider.notifier)
                        .updateSystemNotificationsEnabled(val),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'In-app alert indicators are active. Background push delivery requires Firebase Cloud Messaging (FCM) background service configuration.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 4. SECURITY ──
          _SettingsSection(
            title: 'Security',
            icon: Icons.security_rounded,
            accentColor: const Color(0xFF10B981),
            children: [
              _SettingsRow(
                label: 'Change Password',
                subLabel: 'Update your administrator credentials with current password verification',
                trailing: OutlinedButton(
                  onPressed: () => _openChangePasswordDialog(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Update', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),
              _SettingsRow(
                label: 'Password Reset Email',
                subLabel: 'Send a secure recovery link directly to $adminEmail',
                trailing: TextButton(
                  onPressed: () => _sendPasswordResetLink(adminEmail),
                  child: const Text('Send Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 5. SESSION / LOGIN SECURITY ──
          _SettingsSection(
            title: 'Session & Login Security',
            icon: Icons.history_toggle_off_rounded,
            accentColor: const Color(0xFFF59E0B),
            children: [
              _SettingsRow(
                label: 'Last Sign-In Timestamp',
                subLabel: 'Verified time of current authenticated session',
                trailing: Text(
                  formattedLastSignIn,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _SettingsRow(
                label: 'Account Registration Date',
                subLabel: 'Creation timestamp of admin credential',
                trailing: Text(
                  formattedCreated,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _SettingsRow(
                label: 'Session Persistence',
                subLabel: 'Automated token refresh on application restart',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 6. APPLICATION SETTINGS ──
          _SettingsSection(
            title: 'Application Settings',
            icon: Icons.settings_applications_rounded,
            accentColor: const Color(0xFF8B5CF6),
            children: [
              _SettingsRow(
                label: 'Application Name',
                subLabel: 'Institutional mobility management system',
                trailing: const Text(
                  'ICEM Smart Bus Pass',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _SettingsRow(
                label: 'App Version & Build',
                subLabel: 'Production mobile client release',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'v${AppConstants.appVersion}+${AppConstants.buildNumber}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _SettingsRow(
                label: 'Deployment Environment',
                subLabel: 'Indira College of Engineering & Management Production',
                trailing: const Text(
                  'Production Console',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _SettingsRow(
                label: 'Clear Local Cache',
                subLabel: 'Safely clear local app preferences without affecting database records',
                trailing: OutlinedButton(
                  onPressed: () => _confirmClearCache(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    side: const BorderSide(color: Color(0xFFFCD34D)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Clear Cache', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 7. DATA / FIREBASE STATUS ──
          _SettingsSection(
            title: 'System Status',
            icon: Icons.cloud_done_rounded,
            accentColor: const Color(0xFF14B8A6),
            children: [
              _SettingsRow(
                label: 'Firebase Authentication',
                subLabel: fbUser != null ? 'Authenticated (UID: ${fbUser.uid.substring(0, 8)}...)' : 'Offline',
                trailing: _StatusBadge(
                  status: fbUser != null ? 'Operational' : 'Disconnected',
                  isOk: fbUser != null,
                ),
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _SettingsRow(
                label: 'Cloud Firestore',
                subLabel: 'Real-time database sync and rules enforcement',
                trailing: _StatusBadge(
                  status: _firestoreStatus,
                  isOk: _firestoreStatus == 'Operational',
                ),
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _SettingsRow(
                label: 'Cloud Connection Test',
                subLabel: 'Perform real-time round-trip latency check',
                trailing: TextButton.icon(
                  icon: _isCheckingStatus
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Test Connection', style: TextStyle(fontSize: 12)),
                  onPressed: _isCheckingStatus ? null : _testCloudConnection,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 8. ADMIN DATA MANAGEMENT ──
          _SettingsSection(
            title: 'Admin Data Management',
            icon: Icons.sync_rounded,
            accentColor: const Color(0xFF3B82F6),
            children: [
              _SettingsRow(
                label: 'Refresh Dashboard Statistics',
                subLabel: 'Force reload overview statistics, routes, buses, and applications',
                trailing: ElevatedButton.icon(
                  icon: _isRefreshingData
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded, size: 14),
                  label: const Text('Refresh Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryCrimson,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isRefreshingData ? null : _refreshDashboardData,
                ),
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _SettingsRow(
                label: 'Synchronize Preferences',
                subLabel: 'Merge local cache settings with Firestore user document',
                trailing: TextButton(
                  onPressed: () async {
                    await ref.read(settingsNotifierProvider.notifier).syncPreferences();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Preferences synchronized with Firestore.'),
                        backgroundColor: Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Sync Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 9. ABOUT ICEM ──
          _SettingsSection(
            title: 'About ICEM',
            icon: Icons.info_rounded,
            accentColor: AppColors.primaryCrimson,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/bus_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Indira College of Engineering & Management',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Parandwadi, Pune 410507 • AICTE Approved',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'ICEM Smart Bus Pass is an institutional transport management system designed for secure bus pass generation, route optimization, real-time tracking, and automated student verification.',
                style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openPrivacyPolicyModal(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Privacy Policy', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openTermsModal(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Terms of Use', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 10. HELP & SUPPORT ──
          _SettingsSection(
            title: 'Help & Support',
            icon: Icons.help_outline_rounded,
            accentColor: const Color(0xFF059669),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Central Transport Office',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 4),
                    Text('Email: transport@indiraicem.ac.in', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    Text('Helpline: +91 2114 661500 / +91 95525 21000', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    Text('Office Hours: Monday - Saturday, 8:30 AM - 5:00 PM', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.report_problem_outlined, size: 15),
                      label: const Text('Report an Issue', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _openReportIssueDialog(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.question_answer_outlined, size: 15),
                      label: const Text('Admin FAQ', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _openFaqModal(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 11. DANGER ZONE ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Danger Zone',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SettingsRow(
                  label: 'Sign Out Console',
                  subLabel: 'Safely terminate current session on this device',
                  trailing: OutlinedButton(
                    onPressed: () => _confirmSignOut(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Sign Out', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
                const Divider(height: 24, color: Color(0xFFFEE2E2)),
                _SettingsRow(
                  label: 'Delete Admin Account',
                  subLabel: 'Permanently revoke your administrator account credentials',
                  trailing: ElevatedButton(
                    onPressed: () => _openDeleteAccountDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Delete Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ==========================================
  // ACTION HANDLERS & MODALS
  // ==========================================

  /// 1. Edit Profile Dialog
  void _openEditProfileDialog({
    required String currentName,
    required String currentMobile,
    required String currentDept,
  }) {
    final nameController = TextEditingController(text: currentName);
    final mobileController = TextEditingController(text: currentMobile);
    final deptController = TextEditingController(text: currentDept);
    bool isLoading = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Administrator Profile',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Changes are saved directly to your Firestore administrator profile.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    if (errorText != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(errorText!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: deptController,
                      decoration: const InputDecoration(
                        labelText: 'Department / Section',
                        prefixIcon: Icon(Icons.domain_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryCrimson,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                final newName = nameController.text.trim();
                                if (newName.isEmpty) {
                                  setModalState(() => errorText = 'Full Name cannot be empty.');
                                  return;
                                }

                                setModalState(() {
                                  isLoading = true;
                                  errorText = null;
                                });

                                final success = await ref
                                    .read(authControllerProvider.notifier)
                                    .updateProfile(
                                      fullName: newName,
                                      mobile: mobileController.text.trim(),
                                      department: deptController.text.trim(),
                                    );

                                if (success) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Profile updated successfully!'),
                                      backgroundColor: Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } else {
                                  final err = ref.read(authControllerProvider).errorMessage ??
                                      'Failed to update profile.';
                                  setModalState(() {
                                    isLoading = false;
                                    errorText = err;
                                  });
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Save Changes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 4. Change Password Dialog
  void _openChangePasswordDialog() {
    final currentPwdController = TextEditingController();
    final newPwdController = TextEditingController();
    final confirmPwdController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: const [
                  Icon(Icons.lock_reset_rounded, color: AppColors.primaryCrimson),
                  SizedBox(width: 8),
                  Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'For security, verify your current password before creating a new password.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),
                    if (errorText != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(errorText!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11)),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: currentPwdController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newPwdController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password (min 8 chars)',
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmPwdController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryCrimson,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final cur = currentPwdController.text;
                          final nw = newPwdController.text;
                          final cnf = confirmPwdController.text;

                          if (cur.isEmpty) {
                            setDialogState(() => errorText = 'Please enter your current password.');
                            return;
                          }
                          if (nw.length < 8) {
                            setDialogState(() => errorText = 'New password must be at least 8 characters.');
                            return;
                          }
                          if (nw != cnf) {
                            setDialogState(() => errorText = 'New passwords do not match.');
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            errorText = null;
                          });

                          final success = await ref
                              .read(authControllerProvider.notifier)
                              .changePassword(
                                currentPassword: cur,
                                newPassword: nw,
                                confirmPassword: cnf,
                              );

                          if (success) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Password changed successfully!'),
                                backgroundColor: Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            final err = ref.read(authControllerProvider).errorMessage ??
                                'Failed to change password.';
                            setDialogState(() {
                              isLoading = false;
                              errorText = err;
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Update Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 4b. Send Password Reset Link
  Future<void> _sendPasswordResetLink(String email) async {
    final success = await ref.read(authControllerProvider.notifier).forgotPassword(email);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset instructions sent to $email.'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final err = ref.read(authControllerProvider).errorMessage ?? 'Could not send reset email.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 6. Clear Cache Confirmation
  void _confirmClearCache() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Local Cache?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'This action clears only temporary local client preferences. It will NOT delete any Firebase data, users, bus routes, buses, drivers, payments, or applications.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(settingsNotifierProvider.notifier).clearLocalCache();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Local client preferences cache cleared successfully.'),
                  backgroundColor: Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );
  }

  /// 7. Test Cloud Connection
  Future<void> _testCloudConnection() async {
    setState(() => _isCheckingStatus = true);
    try {
      final stopwatch = Stopwatch()..start();
      // Real lightweight ping to Firestore
      await FirebaseFirestore.instance.collection('users').limit(1).get();
      stopwatch.stop();

      setState(() {
        _firestoreStatus = 'Operational (${stopwatch.elapsedMilliseconds}ms)';
        _isCheckingStatus = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firebase connection healthy (${stopwatch.elapsedMilliseconds}ms round-trip).'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _firestoreStatus = 'Indeterminate';
        _isCheckingStatus = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection check: ${e.toString()}'),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 8. Refresh Dashboard Statistics
  Future<void> _refreshDashboardData() async {
    setState(() => _isRefreshingData = true);
    try {
      // Invalidate stream providers to trigger real Firestore queries
      ref.invalidate(totalStudentsStreamProvider);
      ref.invalidate(activePassesStreamProvider);
      ref.invalidate(pendingAppsStreamProvider);
      ref.invalidate(approvedPassesStreamProvider);
      ref.invalidate(routesListStreamProvider);
      ref.invalidate(busesListStreamProvider);
      ref.invalidate(driversListStreamProvider);
      ref.invalidate(studentsListStreamProvider);
      ref.invalidate(paymentsListStreamProvider);

      await Future.delayed(const Duration(milliseconds: 600));

      setState(() => _isRefreshingData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin dashboard datasets and statistics reloaded!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      setState(() => _isRefreshingData = false);
    }
  }

  /// 9. Sign Out Confirmation
  Future<void> _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to end your current administrator session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  /// 9b. Delete Account Dialog with Re-authentication
  void _openDeleteAccountDialog() {
    final pwdController = TextEditingController();
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'CAUTION: This permanently revokes your administrator credential and removes your user document from Firestore. You will NOT be able to log in again without a new account.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Enter your current administrator password to confirm deletion:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 10),
                    if (errorText != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(errorText!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11)),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: pwdController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Administrator Password',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final pwd = pwdController.text;
                          if (pwd.isEmpty) {
                            setDialogState(() => errorText = 'Password is required.');
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            errorText = null;
                          });

                          final success = await ref
                              .read(authControllerProvider.notifier)
                              .deleteAccount(password: pwd);

                          if (success) {
                            Navigator.pop(ctx);
                          } else {
                            final err = ref.read(authControllerProvider).errorMessage ??
                                'Account deletion failed.';
                            setDialogState(() {
                              isLoading = false;
                              errorText = err;
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Permanently Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 10. Privacy Policy Modal
  void _openPrivacyPolicyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            controller: scrollController,
            children: const [
              Text(
                'Privacy Policy',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              SizedBox(height: 8),
              Text('Effective Date: Academic Year 2026-2027', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              SizedBox(height: 16),
              Text(
                '1. Data Collection & Purpose\n'
                'The ICEM Smart Bus Pass system collects student information (PRN, Full Name, Contact Number, Academic Year, Route Stop) and payment details solely for the verification and issuance of institutional transportation passes.\n\n'
                '2. Role-Based Access\n'
                'Only authorized administrative personnel and assigned drivers have access to student pass validity records. Pass validity is securely verifiable via cryptographic QR codes.\n\n'
                '3. Location & GPS Data\n'
                'Real-time vehicle GPS coordinates are collected from driver devices during active scheduled trips to enable safe fleet tracking and student arrival alerts.\n\n'
                '4. Data Retention & Security\n'
                'All records are stored securely in Google Cloud Firestore with strict security rules. Pass records are maintained for institutional audit and academic term reconciliation only.',
                style: TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 10b. Terms & Conditions Modal
  void _openTermsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            controller: scrollController,
            children: const [
              Text(
                'Terms & Conditions of Transport',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              SizedBox(height: 8),
              Text('Indira College of Engineering & Management', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              SizedBox(height: 16),
              Text(
                '1. Pass Validity\n'
                'The digital bus pass is non-transferable and valid exclusively for the student whose PRN and photograph appear on the credential.\n\n'
                '2. Boarding & Inspection\n'
                'Students must present their valid QR pass to the driver or conductor upon boarding. Failure to present a verified pass may result in boarding refusal.\n\n'
                '3. Route Compliance\n'
                'Bus passes are allocated to specific routes and boarding points. Changing pickup points requires prior administrative approval via the console.\n\n'
                '4. Code of Conduct\n'
                'Students must maintain discipline while traveling. Misbehavior or damage to college buses will lead to immediate cancellation of transport privileges.',
                style: TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 11. Report an Issue Dialog
  void _openReportIssueDialog() {
    final issueController = TextEditingController();
    String category = 'Bus Route Discrepancy';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Report System Issue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Describe the operational issue for the ICEM technical support team:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Issue Category', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Bus Route Discrepancy', child: Text('Bus Route Discrepancy')),
                    DropdownMenuItem(value: 'Pass Generation Bug', child: Text('Pass Generation Bug')),
                    DropdownMenuItem(value: 'Payment Status Mismatch', child: Text('Payment Status Mismatch')),
                    DropdownMenuItem(value: 'Driver App Sync Error', child: Text('Driver App Sync Error')),
                    DropdownMenuItem(value: 'Other Technical Bug', child: Text('Other Technical Bug')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: issueController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Details / Description',
                    hintText: 'Enter specific bus number, route, PRN, or error encountered...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryCrimson,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      if (issueController.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('Issue submitted to ICEM Transport Desk. Reference logged.'),
                          backgroundColor: Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Text('Submit Report'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 11b. Admin FAQ Modal
  void _openFaqModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            controller: scrollController,
            children: const [
              Text(
                'Administrator FAQs',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              SizedBox(height: 12),
              _FaqAccordionTile(
                question: 'How are student bus pass applications approved?',
                answer: 'In the Applications tab, review the student\'s submitted route, pickup stop, and payment receipt. Click "Approve Pass" to automatically generate the QR pass and activate the student credential.',
              ),
              _FaqAccordionTile(
                question: 'How do route updates reach drivers?',
                answer: 'Any stop timing or route modification saved in the Routes tab synchronizes in real-time to driver dashboards via live Firestore stream providers.',
              ),
              _FaqAccordionTile(
                question: 'What if a student changes their boarding stop?',
                answer: 'Admins can edit the student\'s registered stop directly from the Students tab or reassign the student to an alternate bus route if capacity allows.',
              ),
              _FaqAccordionTile(
                question: 'How is offline/cash payment verified?',
                answer: 'Admins can verify offline fee receipts in the Payments tab by marking the transaction as "Verified" with the college cash receipt number.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SUB-COMPONENTS & HELPER WIDGETS
// ==========================================

class _ProfileInfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileInfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ThemePill extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePill({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? AppColors.primaryCrimson : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryCrimson : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isOk;

  const _StatusBadge({required this.status, required this.isOk});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOk ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFFEF4444).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isOk ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              color: isOk ? const Color(0xFF047857) : const Color(0xFFB91C1C),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqAccordionTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqAccordionTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        question,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            answer,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ── Shared Settings Section Card ──
class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

// ── Shared Settings Item Row ──
class _SettingsRow extends StatelessWidget {
  final String label;
  final String? subLabel;
  final Widget trailing;

  const _SettingsRow({
    required this.label,
    this.subLabel,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subLabel!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}
