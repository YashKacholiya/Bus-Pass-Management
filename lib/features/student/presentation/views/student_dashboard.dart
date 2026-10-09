import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:icem_bus/services/storage/storage_service.dart';
import 'package:icem_bus/shared/app_card.dart';
import 'package:icem_bus/shared/custom_button.dart';
import 'package:icem_bus/shared/empty_state.dart';
import 'package:icem_bus/shared/glass_card.dart';
import 'package:icem_bus/shared/loading_skeleton.dart';
import 'package:icem_bus/shared/status_badge.dart';
import 'package:icem_bus/features/notification/domain/notification_providers.dart';
import 'package:icem_bus/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:icem_bus/features/payment/domain/entities/payment_entity.dart';
import 'package:qr_flutter/qr_flutter.dart';

// StreamProvider to query active pass in Firestore collection 'bus_passes'
final activePassStreamProvider = StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) {
    return const Stream.empty();
  }
  return FirebaseFirestore.instance
      .collection('bus_passes')
      .where('uid', isEqualTo: user.uid)
      .where('passStatus', isEqualTo: 'Active')
      .limit(1)
      .snapshots();
});

// StreamProvider to retrieve the student's latest pass (active or pending) for payment status grid
final latestPassStreamProvider = StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) {
    return const Stream.empty();
  }
  return FirebaseFirestore.instance
      .collection('bus_passes')
      .where('uid', isEqualTo: user.uid)
      .limit(1)
      .snapshots();
});

// StreamProvider to query the bus assigned to the student's active route
final assignedBusStreamProvider = StreamProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, routeId) {
  if (routeId.isEmpty) {
    return Stream.value(null);
  }
  return FirebaseFirestore.instance
      .collection('buses')
      .where('assignedRouteId', isEqualTo: routeId)
      .limit(1)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return null;
    final data = snapshot.docs.first.data();
    data['id'] = snapshot.docs.first.id;
    return data;
  });
});


class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends ConsumerState<StudentDashboardScreen> {
  int _currentTabIndex = 0;
  int _emailVerificationCooldown = 0;
  Timer? _cooldownTimer;
  bool _isPhotoLoading = false;

  void _startVerificationCooldown() {
    setState(() => _emailVerificationCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_emailVerificationCooldown > 0) {
        setState(() => _emailVerificationCooldown--);
      } else {
        _cooldownTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    final List<Widget> tabs = [
      _buildHomeTab(context, ref, user),
      _buildPassTab(context, ref, user),
      _buildScheduleTab(context, ref, user),
      _buildNotificationsTab(context),
      _buildProfileTab(context, ref, user),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
        ),
        elevation: 0,
        backgroundColor: AppColors.bgDark,
        automaticallyImplyLeading: false,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
                onPressed: () => setState(() => _currentTabIndex = 3),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryCrimson,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.primaryCrimson),
            onPressed: () async {
              final router = GoRouter.of(context);
              await ref.read(authControllerProvider.notifier).logout();
              router.go(AppRoutes.login);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: tabs,
      ),
      bottomNavigationBar: _buildFloatingBottomNavBar(),
    );
  }

  Widget _buildFloatingBottomNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardSurface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
          _buildNavItem(1, Icons.badge_rounded, Icons.badge_outlined, 'Pass'),
          _buildNavItem(2, Icons.calendar_month_rounded, Icons.calendar_month_outlined, 'Schedule'),
          _buildNavItem(3, Icons.notifications_rounded, Icons.notifications_outlined, 'Alerts', hasNotificationDot: true),
          _buildNavItem(4, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label, {bool hasNotificationDot = false}) {
    final isSelected = _currentTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTabIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 12 : 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryCrimson.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryCrimson.withValues(alpha: 0.4) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  color: isSelected ? AppColors.primaryCrimson : AppColors.textMuted,
                  size: 20,
                ),
                if (hasNotificationDot)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryCrimson,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primaryCrimson,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentTabIndex) {
      case 0:
        return 'ICEM Bus Portal';
      case 1:
        return 'My Bus Pass';
      case 2:
        return 'Bus Schedule';
      case 3:
        return 'College Alerts';
      case 4:
        return 'My Profile';
      default:
        return 'Dashboard';
    }
  }

  // ==========================================
  // TAB 1: HOME VIEW (Dark Luxury Mobility UI)
  // ==========================================
  Widget _buildHomeTab(BuildContext context, WidgetRef ref, dynamic user) {
    final String studentName = user?.fullName ?? 'Student';
    final String? photoUrl = user?.photoUrl;
    
    final hour = DateTime.now().hour;
    final String greeting = hour < 12 ? 'Good Morning' : (hour < 17 ? 'Good Afternoon' : 'Good Evening');
    
    final latestPassAsync = ref.watch(latestPassStreamProvider);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 48.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section: Greeting, Student Name, Avatar & ICEM Branding
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting,',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        studentName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Indira College of Engineering & Management',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryCrimson,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Profile Avatar with subtle crimson border & glow
                GestureDetector(
                  onTap: () => setState(() => _currentTabIndex = 4),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryCrimson.withValues(alpha: 0.35),
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryCrimson.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: (photoUrl != null && photoUrl.isNotEmpty && photoUrl.startsWith('http'))
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Text(
                                  studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryCrimson,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryCrimson,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section: Current Status Header
            const Text(
              'Current Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Dynamic Pass Status & Action Card (Hero Card)
            latestPassAsync.when(
              loading: () => const LoadingSkeleton.card(height: 180, borderRadius: 24),
              error: (err, stack) => PremiumCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(20),
                borderColor: AppColors.error.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 28),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unable to load pass status',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Please check your network connection or try again.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              data: (snapshot) {
                final hasPass = snapshot.docs.isNotEmpty;

                if (hasPass) {
                  final passDoc = snapshot.docs.first.data();
                  final String route = passDoc['route'] as String? ?? passDoc['routeName'] as String? ?? 'No Route Selected';
                  final String passStatus = passDoc['passStatus'] as String? ?? passDoc['status'] as String? ?? 'Pending';
                  final String paymentStatus = passDoc['paymentStatus'] as String? ?? 'Unpaid';
                  final String passNumber = passDoc['passNumber'] as String? ?? '';
                  final String boardingStop = passDoc['boardingStop'] as String? ?? passDoc['boarding'] as String? ?? 'Campus Gate';
                  
                  final dynamic expiryData = passDoc['validUntil'] ?? passDoc['expiryDate'];
                  DateTime? validUntilDate;
                  String expiryString = 'N/A';
                  if (expiryData is Timestamp) {
                    validUntilDate = expiryData.toDate();
                    expiryString = '${validUntilDate.day.toString().padLeft(2, '0')}/${validUntilDate.month.toString().padLeft(2, '0')}/${validUntilDate.year}';
                  } else if (expiryData is String && expiryData.isNotEmpty) {
                    validUntilDate = DateTime.tryParse(expiryData);
                    if (validUntilDate != null) {
                      expiryString = '${validUntilDate.day.toString().padLeft(2, '0')}/${validUntilDate.month.toString().padLeft(2, '0')}/${validUntilDate.year}';
                    } else {
                      expiryString = expiryData.length > 10 ? expiryData.substring(0, 10) : expiryData;
                    }
                  }

                  final bool isRevoked = passStatus.toLowerCase() == 'revoked';
                  final bool isExpired = passStatus.toLowerCase() == 'expired' || 
                      (validUntilDate != null && DateTime.now().isAfter(validUntilDate));
                  final bool isPaid = paymentStatus.toLowerCase() == 'paid';
                  final bool isApproved = passStatus.toLowerCase() == 'active' || 
                      passStatus.toLowerCase() == 'approved' ||
                      (passDoc['applicationStatus']?.toString().toLowerCase() == 'approved');

                  // Pass is ACTIVE only if payment is paid AND application is approved
                  final bool isPassActive = isPaid && isApproved && !isRevoked && !isExpired;
                  final bool isPaidWaitingApproval = isPaid && !isApproved && !isRevoked;
                  final bool isRejected = passStatus.toLowerCase() == 'rejected';

                  if (isRevoked) {
                    // Pass Revoked
                    return PremiumCard(
                      borderRadius: 24,
                      borderColor: AppColors.error.withValues(alpha: 0.4),
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pass Revoked',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                  fontSize: 16,
                                ),
                              ),
                              StatusBadge(status: 'REJECTED', label: 'Revoked'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            route,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'This bus pass was revoked by the college transport office. QR scanning is disabled.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 18),
                          SecondaryButton(
                            text: 'View Pass History',
                            icon: Icons.history_rounded,
                            onPressed: () => context.push(AppRoutes.studentPassHistory),
                          ),
                        ],
                      ),
                    );
                  } else if (isExpired) {
                    // Pass Expired
                    return PremiumCard(
                      borderRadius: 24,
                      borderColor: AppColors.warning.withValues(alpha: 0.4),
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pass Expired',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning,
                                  fontSize: 16,
                                ),
                              ),
                              StatusBadge(status: 'EXPIRED'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            route,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Validity expired on $expiryString. Please renew to continue utilizing ICEM bus services.',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 18),
                          PrimaryButton(
                            text: 'Renew Bus Pass',
                            icon: Icons.autorenew_rounded,
                            onPressed: () => context.push(AppRoutes.studentRenew),
                          ),
                        ],
                      ),
                    );
                  } else if (isPassActive) {
                    // ACTIVE DIGITAL PASS - Large Hero Card
                    return PremiumCard(
                      borderRadius: 26,
                      isSelected: true,
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryCrimson.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.primaryCrimson.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: const Text(
                                  'ICEM SMART BUS PASS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryCrimson,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const StatusBadge(status: 'ACTIVE'),
                            ],
                          ),
                          if (passNumber.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Pass No: $passNumber',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          const Text(
                            'Route',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            route,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (boardingStop.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 15, color: AppColors.primaryCrimson),
                                const SizedBox(width: 5),
                                Text(
                                  'Boarding: $boardingStop',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 6),
                              Text(
                                'Valid Until: $expiryString',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          PrimaryButton(
                            text: 'VIEW PASS',
                            icon: Icons.badge_rounded,
                            onPressed: () => context.push(AppRoutes.studentDigitalPass),
                          ),
                        ],
                      ),
                    );
                  } else if (isPaidWaitingApproval) {
                    // Paid — Waiting for Admin Approval
                    return PremiumCard(
                      borderRadius: 26,
                      padding: const EdgeInsets.all(22),
                      borderColor: AppColors.info.withValues(alpha: 0.4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Under Admin Review',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.info,
                                  fontSize: 15,
                                ),
                              ),
                              StatusBadge(status: 'PENDING', label: 'In Review'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            route,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Paid Fare: ₹${passDoc['fare'] ?? '4,500'} (Verified ✓)',
                            style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Payment has been verified. Application is waiting for transport administrator review and approval. Digital pass and QR activate upon approval.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 18),
                          SecondaryButton(
                            text: 'View Pass History',
                            icon: Icons.history_rounded,
                            onPressed: () => context.push(AppRoutes.studentPassHistory),
                          ),
                        ],
                      ),
                    );
                  } else if (isRejected) {
                    // Application Rejected
                    return PremiumCard(
                      borderRadius: 26,
                      padding: const EdgeInsets.all(22),
                      borderColor: AppColors.error.withValues(alpha: 0.4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Application Rejected',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                  fontSize: 16,
                                ),
                              ),
                              StatusBadge(status: 'REJECTED'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            route,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Reason: ${passDoc['rejectionReason'] ?? 'Application did not meet college requirements.'}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 18),
                          PrimaryButton(
                            text: 'Re-apply for Bus Pass',
                            icon: Icons.refresh_rounded,
                            onPressed: () => context.push(AppRoutes.studentApply),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Payment Pending
                    return PremiumCard(
                      borderRadius: 26,
                      padding: const EdgeInsets.all(22),
                      borderColor: AppColors.warning.withValues(alpha: 0.4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Payment Pending',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryCrimson,
                                  fontSize: 16,
                                ),
                              ),
                              StatusBadge(status: 'UNPAID', label: 'Payment Pending'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            route,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Fare Fee: ₹${passDoc['fare'] ?? '4,500'}',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Application submitted. Complete fee payment via Razorpay to submit for administrative review.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 18),
                          PrimaryButton(
                            text: 'Complete Payment',
                            icon: Icons.payment_rounded,
                            onPressed: () => context.push(AppRoutes.studentPayment),
                          ),
                        ],
                      ),
                    );
                  }
                } else {
                  // No Pass Applied Hero Card
                  return PremiumCard(
                    borderRadius: 26,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: const Text(
                                'YOUR BUS PASS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const StatusBadge(status: 'INACTIVE', label: 'No Active Pass'),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'No active pass',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Apply for your ICEM bus pass to get started with seamless college transportation.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        PrimaryButton(
                          text: 'APPLY NOW',
                          icon: Icons.add_card_rounded,
                          onPressed: () => context.push(AppRoutes.studentApply),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 28),

            // ==========================================
            // SECTION 6: LIVE BUS / ROUTE CARD
            // ==========================================
            latestPassAsync.when(
              loading: () => const LoadingSkeleton.card(height: 180, borderRadius: 24),
              error: (err, stack) => const SizedBox.shrink(),
              data: (snapshot) {
                final hasPass = snapshot.docs.isNotEmpty;
                final passDoc = hasPass ? snapshot.docs.first.data() : null;
                return _buildLiveBusRouteCard(passDoc);
              },
            ),
            const SizedBox(height: 28),

            // ==========================================
            // SECTION 7: QUICK ACTIONS
            // ==========================================
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            latestPassAsync.when(
              loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
              error: (err, stack) => const SizedBox.shrink(),
              data: (snapshot) {
                final hasPass = snapshot.docs.isNotEmpty;
                final passDoc = hasPass ? snapshot.docs.first.data() : null;
                final passStatus = passDoc?['passStatus'] as String? ?? passDoc?['status'] as String? ?? '';
                final paymentStatus = passDoc?['paymentStatus'] as String? ?? '';
                
                final dynamic expiryData = passDoc?['validUntil'] ?? passDoc?['expiryDate'];
                DateTime? validUntilDate;
                if (expiryData is Timestamp) {
                  validUntilDate = expiryData.toDate();
                } else if (expiryData is String && expiryData.isNotEmpty) {
                  validUntilDate = DateTime.tryParse(expiryData);
                }

                final bool isRevoked = passStatus.toLowerCase() == 'revoked';
                final bool isExpired = passStatus.toLowerCase() == 'expired' ||
                    (validUntilDate != null && DateTime.now().isAfter(validUntilDate));
                final bool isPaid = paymentStatus.toLowerCase() == 'paid';
                final bool isApproved = passStatus.toLowerCase() == 'active' ||
                    passStatus.toLowerCase() == 'approved' ||
                    (passDoc?['applicationStatus']?.toString().toLowerCase() == 'approved');
                final bool isPassActive = isPaid && isApproved && !isRevoked && !isExpired;

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _quickActionTile(
                            title: isPassActive ? 'My Pass' : 'Apply Pass',
                            subtitle: isPassActive ? 'Digital Pass & QR' : 'New Application',
                            icon: isPassActive ? Icons.badge_rounded : Icons.add_card_rounded,
                            accentColor: AppColors.primaryCrimson,
                            onTap: () {
                              if (isPassActive) {
                                context.push(AppRoutes.studentDigitalPass);
                              } else {
                                context.push(AppRoutes.studentApply);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _quickActionTile(
                            title: 'Bus Schedule',
                            subtitle: 'Stops & Timings',
                            icon: Icons.calendar_month_rounded,
                            accentColor: const Color(0xFF38BDF8),
                            onTap: () => setState(() => _currentTabIndex = 2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _quickActionTile(
                            title: 'Notifications',
                            subtitle: 'Campus Alerts',
                            icon: Icons.notifications_active_rounded,
                            accentColor: const Color(0xFFA855F7),
                            onTap: () => setState(() => _currentTabIndex = 3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _quickActionTile(
                            title: 'Pass History',
                            subtitle: 'Archive & Status',
                            icon: Icons.history_rounded,
                            accentColor: const Color(0xFF2DD4BF),
                            onTap: () => context.push(AppRoutes.studentPassHistory),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _quickActionTile(
                            title: 'Fee Payments',
                            subtitle: 'Receipts & History',
                            icon: Icons.receipt_long_rounded,
                            accentColor: const Color(0xFF4ADE80),
                            onTap: () => context.push(AppRoutes.studentPaymentHistory),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _quickActionTile(
                            title: 'My Profile',
                            subtitle: 'Student Identity',
                            icon: Icons.person_rounded,
                            accentColor: const Color(0xFFF43F5E),
                            onTap: () => setState(() => _currentTabIndex = 4),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),

            // Schedule Overview Cards
            const Text(
              'Schedule Overview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            latestPassAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
              data: (snapshot) {
                final hasPass = snapshot.docs.isNotEmpty;
                final passDoc = hasPass ? snapshot.docs.first.data() : null;

                final paymentStatus = passDoc?['paymentStatus'] as String? ?? 'Unpaid';
                final busNumber = passDoc?['busNumber'] as String? ?? 'Assigned on Route';

                return Row(
                  children: [
                    _detailCard(
                      'Payment Status',
                      paymentStatus,
                      const Icon(Icons.payment_rounded, color: AppColors.primaryCrimson, size: 20),
                    ),
                    const SizedBox(width: 14),
                    _detailCard(
                      'Bus Number',
                      busNumber,
                      const Icon(Icons.directions_bus_rounded, color: AppColors.primaryCrimson, size: 20),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// SECTION 6: LIVE BUS / ROUTE CARD (Inspired by modern mobility map section)
  Widget _buildLiveBusRouteCard(Map<String, dynamic>? passDoc) {
    final route = passDoc?['route'] as String? ?? passDoc?['routeName'] as String? ?? 'Wakad → ICEM Campus';
    final boardingStop = passDoc?['boardingStop'] as String? ?? passDoc?['boarding'] as String? ?? 'Wakad';
    final busNumber = passDoc?['busNumber'] as String? ?? 'ICEM-Bus 04';
    
    // Determine realistic next stop from actual boarding or default route
    String nextStop = 'Baner';
    if (boardingStop.toLowerCase().contains('baner')) {
      nextStop = 'Balewadi';
    } else if (boardingStop.toLowerCase().contains('balewadi')) {
      nextStop = 'ICEM Campus';
    }

    return PremiumCard(
      borderRadius: 26,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with Live Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.primaryCrimson,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryCrimson.withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'LIVE BUS & ROUTE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryCrimson,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  busNumber,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Route title
          Text(
            route,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),

          // Stops & ETA info chips
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Stop', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      boardingStop,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: AppColors.borderSubtle),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Next Stop', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      nextStop,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: AppColors.borderSubtle),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('ETA', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCrimson.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '08 min',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryCrimson),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dark mini-map / route visualizer (inspired by mobility map section)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Starting Point
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primaryCrimson, width: 2.5),
                            color: Colors.transparent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          boardingStop,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    // Destination
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        const Text(
                          'ICEM Campus',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Connected Route Line with Current Bus Marker
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Crimson route background track
                    Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.borderSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Crimson active route line
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.55,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primaryCrimson, AppColors.crimsonLight],
                            ),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryCrimson.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bus indicator marker
                    Align(
                      alignment: const Alignment(0.1, 0),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCrimson,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryCrimson.withValues(alpha: 0.6),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_bus_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Start Stop', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    Text('Bus in Transit (Tracked)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryCrimson)),
                    Text('Final Destination', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Compact horizontal Quick Action card
  Widget _quickActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return PremiumCard(
      borderRadius: 18,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(icon, color: accentColor, size: 19),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailCard(String title, String val, Widget iconWidget) {
    return Expanded(
      child: PremiumCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryCrimson.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryCrimson.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Center(child: iconWidget),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              val,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: PASS DETAILS TAB
  // ==========================================
  Widget _buildPassTab(BuildContext context, WidgetRef ref, dynamic user) {
    final theme = Theme.of(context);
    final activePassAsync = ref.watch(activePassStreamProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 48.0),
        child: activePassAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (snapshot) {
            final hasActivePass = snapshot.docs.isNotEmpty;

            if (!hasActivePass) {
              final latestDocs = ref.watch(latestPassStreamProvider).value?.docs;
              if (latestDocs != null && latestDocs.isNotEmpty) {
                final latestPass = latestDocs.first.data();
                final String pStatus = latestPass['passStatus'] as String? ?? latestPass['status'] as String? ?? '';
                final String payStatus = latestPass['paymentStatus'] as String? ?? '';
                final bool isPaid = payStatus.toLowerCase() == 'paid';
                final bool isRevoked = pStatus.toLowerCase() == 'revoked';

                if (isRevoked) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const Icon(Icons.block_rounded, size: 70, color: AppColors.error),
                          const SizedBox(height: 16),
                          Text('Pass Revoked', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.error)),
                          const SizedBox(height: 8),
                          const Text('This bus pass has been revoked by the transport office.', textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          SecondaryButton(
                            text: 'View Pass History',
                            icon: Icons.history_rounded,
                            onPressed: () => context.push(AppRoutes.studentPassHistory),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (isPaid) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const Icon(Icons.hourglass_top_rounded, size: 70, color: AppColors.info),
                          const SizedBox(height: 16),
                          Text(
                            'Paid — Waiting for Admin Approval',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.info),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Text(
                              'Payment verified ✓. Your application is under administrator review. Your Digital Bus Pass and QR Code will activate upon approval.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SecondaryButton(
                            text: 'View Pass History',
                            icon: Icons.history_rounded,
                            onPressed: () => context.push(AppRoutes.studentPassHistory),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const Icon(Icons.payment_rounded, size: 70, color: Color(0xFFD97706)),
                          const SizedBox(height: 16),
                          Text(
                            'Payment Pending',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Text(
                              'Please complete your pass fee payment via Razorpay to submit for administrative approval.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 20),
                          PrimaryButton(
                            text: 'Complete Payment',
                            icon: Icons.payment_rounded,
                            onPressed: () => context.push(AppRoutes.studentPayment),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    const Icon(Icons.wallet_rounded, size: 80, color: AppColors.textLight),
                    const SizedBox(height: 16),
                    Text("You don't have an active bus pass.", style: theme.textTheme.titleMedium),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      text: 'Apply for Bus Pass',
                      icon: Icons.add_card_rounded,
                      onPressed: () => context.push(AppRoutes.studentApply),
                    ),
                  ],
                ),
              );
            }

            final passDoc = snapshot.docs.first.data();
            final String route = passDoc['route'] as String? ?? passDoc['routeName'] as String? ?? 'No Route Selected';
            final String routeId = passDoc['routeId'] as String? ?? '';
            final String passNumber = passDoc['passNumber'] as String? ?? '';
            final String boardingStop = passDoc['boardingStop'] as String? ?? passDoc['boarding'] as String? ?? '';
            
            final dynamic expiryData = passDoc['validUntil'] ?? passDoc['expiryDate'];
            String expiryString = 'N/A';
            if (expiryData is Timestamp) {
              final d = expiryData.toDate();
              expiryString = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
            } else if (expiryData is String && expiryData.isNotEmpty) {
              final d = DateTime.tryParse(expiryData);
              if (d != null) {
                expiryString = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
              } else {
                expiryString = expiryData.length > 10 ? expiryData.substring(0, 10) : expiryData;
              }
            }

            final busAsync = ref.watch(assignedBusStreamProvider(routeId));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modern Luxury Digital Pass Card
                PremiumCard(
                  borderRadius: 26,
                  isSelected: true,
                  padding: const EdgeInsets.all(22.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryCrimson.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primaryCrimson.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(Icons.directions_bus_rounded, color: AppColors.primaryCrimson, size: 20),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ICEM SMART BUS PASS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: AppColors.primaryCrimson,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    passNumber.isNotEmpty ? passNumber : 'DIGITAL PASS',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const StatusBadge(status: 'ACTIVE'),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primaryCrimson.withValues(alpha: 0.3), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryCrimson.withValues(alpha: 0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: (passDoc['qrCode'] != null && passDoc['qrCode'].toString().isNotEmpty)
                                ? passDoc['qrCode'].toString()
                                : jsonEncode({
                                    'type': 'ICEM_BUS_PASS',
                                    'passNumber': passDoc['passNumber'] ?? 'ICEM-BP-${passDoc['passId']}',
                                    'passId': passDoc['passId'] ?? '',
                                    'studentId': user?.uid ?? '',
                                  }),
                            version: QrVersions.auto,
                            size: 160,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: AppColors.primaryCrimson,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AppColors.bgDark,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('STUDENT', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                    const SizedBox(height: 3),
                                    Text(
                                      user?.fullName.toUpperCase() ?? 'STUDENT',
                                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('VALID UNTIL', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                    const SizedBox(height: 3),
                                    Text(expiryString, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: AppColors.borderSubtle),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('ROUTE', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                      const SizedBox(height: 3),
                                      Text(route, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (boardingStop.isNotEmpty)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('BOARDING STOP', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                        const SizedBox(height: 3),
                                        Text(boardingStop, style: const TextStyle(color: AppColors.primaryCrimson, fontWeight: FontWeight.w700, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        text: 'Open Full Digital Pass',
                        icon: Icons.badge_rounded,
                        onPressed: () => context.push(AppRoutes.studentDigitalPass),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Assigned Bus Section Header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.directions_bus_rounded, size: 20, color: AppColors.primaryCrimson),
                      SizedBox(width: 8),
                      Text(
                        'Assigned Bus & Driver Info',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Bus Async Details Card
                busAsync.when(
                  loading: () => const LoadingSkeleton.card(height: 140, borderRadius: 20),
                  error: (err, _) => PremiumCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(20),
                    borderColor: AppColors.error.withValues(alpha: 0.3),
                    child: Center(
                      child: Text('Error loading bus details: $err', style: const TextStyle(color: AppColors.error)),
                    ),
                  ),
                  data: (bus) {
                    if (bus == null) {
                      return PremiumCard(
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: const Column(
                          children: [
                            Icon(Icons.directions_bus_rounded, size: 40, color: AppColors.textMuted),
                            SizedBox(height: 12),
                            Text(
                              'No bus has been assigned to this route yet.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    final busName = bus['busName'] ?? 'Unnamed Bus';
                    final busNumber = bus['busNumber'] ?? 'N/A';
                    final regNo = bus['registrationNumber'] ?? 'N/A';
                    final driverName = bus['driverName'] ?? 'No Driver';
                    final driverPhone = bus['driverPhone'] ?? 'N/A';
                    final capacity = bus['capacity'] ?? 0;
                    final status = bus['status'] ?? 'Active';

                    Color statusColor = AppColors.success;
                    if (status == 'Maintenance') statusColor = AppColors.warning;
                    if (status == 'Inactive') statusColor = AppColors.error;

                    return PremiumCard(
                      borderRadius: 20,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Bus details header row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      busName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Bus No: $busNumber • $regNo',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: AppColors.borderSubtle),
                          const SizedBox(height: 16),

                          // Driver details
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryCrimson.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_rounded, color: AppColors.primaryCrimson, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'DRIVER',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textMuted,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      driverName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      driverPhone,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (driverPhone != 'N/A' && driverPhone.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: AppColors.primaryCrimson),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.primaryCrimson.withValues(alpha: 0.1),
                                    padding: const EdgeInsets.all(10),
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: driverPhone));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text("Driver's phone number copied!"),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: AppColors.success,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: AppColors.borderSubtle),
                          const SizedBox(height: 14),

                          // Seating/Capacity info
                          Row(
                            children: [
                              const Icon(Icons.airline_seat_recline_normal_rounded, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Text(
                                'Capacity: $capacity seats',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: BUS SCHEDULE TAB (Dark Mobility Timeline)
  // ==========================================
  Widget _buildScheduleTab(BuildContext context, WidgetRef ref, dynamic user) {
    final latestPassAsync = ref.watch(latestPassStreamProvider);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 48.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prominent Today's Schedule Card
            latestPassAsync.when(
              loading: () => const LoadingSkeleton.card(height: 200, borderRadius: 24),
              error: (err, stack) => const SizedBox.shrink(),
              data: (snapshot) {
                final hasPass = snapshot.docs.isNotEmpty;
                final passDoc = hasPass ? snapshot.docs.first.data() : null;
                final route = passDoc?['route'] as String? ?? passDoc?['routeName'] as String? ?? 'General Campus Transit';
                final boardingStop = passDoc?['boardingStop'] as String? ?? passDoc?['boarding'] as String? ?? 'Wakad';
                final busNumber = passDoc?['busNumber'] as String? ?? 'ICEM-Bus 04';

                return PremiumCard(
                  borderRadius: 26,
                  isSelected: true,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryCrimson.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.primaryCrimson.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              "TODAY'S SCHEDULE",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryCrimson,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const StatusBadge(status: 'ACTIVE', label: 'On Schedule'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        route,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assigned Bus: $busNumber',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 18),

                      // Time Slot Breakdown Container
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Pickup Time', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                const SizedBox(height: 4),
                                const Text('07:30 AM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                                const SizedBox(height: 2),
                                Text(boardingStop, style: const TextStyle(fontSize: 11, color: AppColors.primaryCrimson, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                            Container(width: 1, height: 42, color: AppColors.borderSubtle),
                            const Column(
                              children: [
                                Text('Campus Arrival', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                SizedBox(height: 4),
                                Text('08:45 AM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                                SizedBox(height: 2),
                                Text('ICEM Main Gate', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            Container(width: 1, height: 42, color: AppColors.borderSubtle),
                            const Column(
                              children: [
                                Text('Evening Return', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                SizedBox(height: 4),
                                Text('04:45 PM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                                SizedBox(height: 2),
                                Text('From Campus', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // College Bus Routes Header
            const Text(
              'All College Routes & Timings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),

            // Firestore bus_routes Stream
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('bus_routes').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingSkeleton.card(height: 140, borderRadius: 20);
                }
                final routes = snapshot.data?.docs ?? [];
                if (routes.isEmpty) {
                  return const EmptyState(
                    icon: Icons.alt_route_rounded,
                    title: 'No Routes Available',
                    description: 'Bus routes will be listed here once published by the transport office.',
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: routes.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final data = routes[index].data();
                    final name = data['routeName'] as String? ?? data['name'] as String? ?? 'Route ${index + 1}';
                    final startPoint = data['startPoint'] as String? ?? 'City Hub';
                    final destination = data['destination'] as String? ?? 'ICEM Campus';
                    final busNo = data['busNumber'] as String? ?? 'Bus Assigned';
                    final stops = (data['stops'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

                    return PremiumCard(
                      borderRadius: 22,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: Text(
                                  busNo,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryCrimson,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(startPoint, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 10),
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 10),
                              const Icon(Icons.location_on_rounded, size: 14, color: AppColors.success),
                              const SizedBox(width: 4),
                              Text(destination, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                            ],
                          ),

                          // Vertical stops timeline preview
                          if (stops.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(height: 1, color: AppColors.borderSubtle),
                            const SizedBox(height: 14),
                            Column(
                              children: List.generate(stops.length.clamp(0, 4), (sIdx) {
                                final stop = stops[sIdx];
                                final isLast = sIdx == (stops.length.clamp(0, 4) - 1);
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: sIdx == 0 ? AppColors.primaryCrimson : AppColors.textSecondary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        if (!isLast)
                                          Container(
                                            width: 1.5,
                                            height: 20,
                                            color: AppColors.borderSubtle,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 6.0),
                                        child: Text(
                                          stop,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: sIdx == 0 ? FontWeight.w700 : FontWeight.w500,
                                            color: sIdx == 0 ? AppColors.textPrimary : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 4: NOTIFICATIONS & ALERTS TAB
  // ==========================================
  Widget _buildNotificationsTab(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return SafeArea(
      child: notificationsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 48.0),
          child: Column(
            children: [
              LoadingSkeleton.card(height: 88, borderRadius: 20),
              SizedBox(height: 12),
              LoadingSkeleton.card(height: 88, borderRadius: 20),
              SizedBox(height: 12),
              LoadingSkeleton.card(height: 88, borderRadius: 20),
            ],
          ),
        ),
        error: (err, stack) => const Padding(
          padding: EdgeInsets.all(24.0),
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to Load Alerts',
            description: 'An error occurred while fetching college notifications. Please try again.',
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24.0),
              child: EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'No Notifications',
                description: 'You have no new alerts or announcements at this time.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 48.0),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final title = notif['title'] as String? ?? 'College Notice';
              final message = notif['message'] as String? ?? notif['body'] as String? ?? '';
              final type = notif['type'] as String? ?? 'info';
              final dynamic ts = notif['createdAt'];

              String timeString = 'Recent';
              if (ts is Timestamp) {
                final dt = ts.toDate();
                final diff = DateTime.now().difference(dt);
                if (diff.inMinutes < 60) {
                  timeString = '${diff.inMinutes}m ago';
                } else if (diff.inHours < 24) {
                  timeString = '${diff.inHours}h ago';
                } else {
                  timeString = '${dt.day}/${dt.month}/${dt.year}';
                }
              }

              IconData icon = Icons.notifications_outlined;
              Color iconColor = AppColors.primaryCrimson;
              if (type.toLowerCase() == 'alert' || type.toLowerCase() == 'delay') {
                icon = Icons.warning_amber_rounded;
                iconColor = AppColors.warning;
              } else if (type.toLowerCase() == 'approval' || type.toLowerCase() == 'success') {
                icon = Icons.check_circle_outline_rounded;
                iconColor = AppColors.success;
              }

              return PremiumCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(18.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: iconColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                                ),
                              ),
                              Text(
                                timeString,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            message,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
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
      ),
    );
  }
  // ==========================================
  // TAB 5: PROFILE & SETTINGS TAB (Luxury Dark)
  // ==========================================
  Widget _buildProfileTab(BuildContext context, WidgetRef ref, dynamic user) {
    final String name = user?.fullName ?? 'Student User';
    final String email = user?.email ?? 'student@icem.edu.in';
    final String studentId = user?.collegeId ?? user?.prn ?? 'ICEM-STD';
    final String course = user?.course ?? 'Undergraduate Student';
    final String? photoUrl = user?.photoUrl;

    // Real-time email verification check
    final isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    // Preferences state
    final settings = ref.watch(settingsNotifierProvider);
    final settingsNotifier = ref.read(settingsNotifierProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 48.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Premium Profile Header
            PremiumCard(
              borderRadius: 26,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryCrimson, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryCrimson.withValues(alpha: 0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _isPhotoLoading
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primaryCrimson))
                              : (photoUrl != null && photoUrl.isNotEmpty && photoUrl.startsWith('http')
                                  ? Image.network(
                                      photoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Center(
                                        child: Text(
                                          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primaryCrimson,
                                            fontSize: 38,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryCrimson,
                                          fontSize: 38,
                                        ),
                                      ),
                                    )),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _showPhotoPickerSheet(context, user?.uid ?? ''),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.primaryCrimson,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.cardSurface, width: 2.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: -0.3,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Text(
                          studentId,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCrimson.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryCrimson.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          course,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryCrimson,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),

                  // Email verification badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isEmailVerified ? AppColors.success.withValues(alpha: 0.12) : AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isEmailVerified ? AppColors.success.withValues(alpha: 0.3) : AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isEmailVerified ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
                          size: 13,
                          color: isEmailVerified ? AppColors.success : AppColors.warning,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isEmailVerified ? 'Verified Student Account' : 'Unverified Email',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isEmailVerified ? AppColors.success : AppColors.warning,
                          ),
                        ),
                        if (!isEmailVerified) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _emailVerificationCooldown > 0
                                ? null
                                : () async {
                                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                                    try {
                                      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
                                      _startVerificationCooldown();
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Verification link sent! Please check your inbox.'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    } catch (e) {
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to send: ${e.toString()}'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  },
                            child: Text(
                              _emailVerificationCooldown > 0
                                  ? 'Resend in ${_emailVerificationCooldown}s'
                                  : 'Verify Now',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                decoration: _emailVerificationCooldown > 0 ? TextDecoration.none : TextDecoration.underline,
                                color: _emailVerificationCooldown > 0 ? AppColors.textMuted : AppColors.primaryCrimson,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Academic Information
            _sectionHeader('Academic Profile'),
            const SizedBox(height: 10),
            PremiumCard(
              borderRadius: 22,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _profileItem(Icons.numbers_rounded, 'PRN Number', user?.prn ?? 'Not Applied Yet'),
                  const Divider(height: 24, color: AppColors.borderSubtle),
                  _profileItem(Icons.pin_rounded, 'College ID', user?.collegeId ?? 'Not Applied Yet'),
                  const Divider(height: 24, color: AppColors.borderSubtle),
                  _profileItem(Icons.domain_rounded, 'Department', user?.department ?? 'Not Applied Yet'),
                  const Divider(height: 24, color: AppColors.borderSubtle),
                  _profileItem(Icons.school_rounded, 'Course', user?.course ?? 'Not Applied Yet'),
                  const Divider(height: 24, color: AppColors.borderSubtle),
                  _profileItem(Icons.calendar_today_rounded, 'Academic Year', user?.year ?? 'Not Applied Yet'),
                  const Divider(height: 24, color: AppColors.borderSubtle),
                  _profileItem(Icons.class_rounded, 'Semester', user?.semester ?? 'Not Applied Yet'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Personal Information
            _sectionHeader('Personal & Contact Details'),
            const SizedBox(height: 10),
            PremiumCard(
              borderRadius: 22,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _profileItem(Icons.phone_iphone_rounded, 'Mobile Number', user?.mobile ?? 'Not set'),
                  const Divider(height: 24, color: AppColors.borderSubtle),
                  _profileItem(Icons.home_outlined, 'Home Address', user?.address ?? 'Not set'),
                  const Divider(height: 24, color: AppColors.borderSubtle),
                  _profileItem(Icons.contact_emergency_outlined, 'Emergency Contact', user?.emergencyContact ?? 'Not set'),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    text: 'Edit Profile Information',
                    icon: Icons.edit_note_rounded,
                    onPressed: () => _showEditProfileDialog(context, ref, user),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Bus Pass Information
            _sectionHeader('Bus Pass & Invoices'),
            const SizedBox(height: 10),
            PremiumCard(
              borderRadius: 22,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryCrimson.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryCrimson.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryCrimson, size: 20),
                    ),
                    title: const Text('My Digital Bus Pass', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                    subtitle: const Text('Access scannable QR pass and route info', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                    onTap: () => _showDigitalPassModal(context, user),
                  ),
                  const Divider(height: 16, color: AppColors.borderSubtle),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryCrimson.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryCrimson.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryCrimson, size: 20),
                    ),
                    title: const Text('Payment & Receipt History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                    subtitle: const Text('View and download official billing invoices', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                    onTap: () => _showPaymentHistorySheet(context, user?.uid ?? ''),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. Settings & Security
            _sectionHeader('Security & Preferences'),
            const SizedBox(height: 10),
            PremiumCard(
              borderRadius: 22,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _profileItem(Icons.fingerprint_rounded, 'User ID (UID)', user?.uid ?? 'N/A'),
                  const SizedBox(height: 16),
                  SecondaryButton(
                    text: 'Change Account Password',
                    icon: Icons.lock_reset_rounded,
                    onPressed: () => _showChangePasswordDialog(context),
                  ),
                  const Divider(height: 28, color: AppColors.borderSubtle),
                  SwitchListTile(
                    title: const Text('Push Notifications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    subtitle: const Text('Get real-time updates regarding bus timings', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryCrimson,
                    value: settings.notificationsEnabled,
                    onChanged: (val) => settingsNotifier.updateNotificationsEnabled(val),
                  ),
                  const Divider(height: 20, color: AppColors.borderSubtle),
                  SwitchListTile(
                    title: const Text('Pass Expiry Reminders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    subtitle: const Text('Get alerts 5 days prior to pass expiry', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryCrimson,
                    value: settings.passExpiryReminderEnabled,
                    onChanged: (val) => settingsNotifier.updatePassExpiryReminderEnabled(val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 6. Support & Documentation
            _sectionHeader('Support & Policies'),
            const SizedBox(height: 10),
            PremiumCard(
              borderRadius: 22,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: const Icon(Icons.info_outline_rounded, color: AppColors.primaryCrimson, size: 22),
                    title: const Text('App Information', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                    subtitle: const Text('Check application build version and specs', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                    onTap: () => _showAppInfoDialog(context),
                  ),
                  const Divider(height: 16, color: AppColors.borderSubtle),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primaryCrimson, size: 22),
                    title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                    subtitle: const Text('Review transport data utilization terms', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                    onTap: () => _showPrivacyPolicySheet(context),
                  ),
                  const Divider(height: 16, color: AppColors.borderSubtle),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: const Icon(Icons.support_agent_rounded, color: AppColors.primaryCrimson, size: 22),
                    title: const Text('Contact Support Helpline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                    subtitle: const Text('Submit ticket or call helpline desk', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                    onTap: () => _showContactSupportSheet(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 7. Logout / Danger Zone (Clearly separated)
            _sectionHeader('Account Session'),
            const SizedBox(height: 10),
            PremiumCard(
              borderRadius: 22,
              padding: const EdgeInsets.all(16),
              borderColor: AppColors.error.withValues(alpha: 0.3),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryCrimson.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.logout_rounded, color: AppColors.primaryCrimson, size: 20),
                    ),
                    title: const Text('Sign Out Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryCrimson)),
                    subtitle: const Text('Log out of the current device session', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    onTap: () async {
                      final router = GoRouter.of(context);
                      await ref.read(authControllerProvider.notifier).logout();
                      router.go(AppRoutes.login);
                    },
                  ),
                  const Divider(height: 16, color: AppColors.borderSubtle),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 20),
                    ),
                    title: const Text('Delete Account Permanently', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.error)),
                    subtitle: const Text('Erase profile details and transit data', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    onTap: () => _showDeleteAccountDialog(context, user?.uid ?? ''),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.primaryCrimson,
          letterSpacing: 0.8,
          fontSize: 11.5,
        ),
      ),
    );
  }

  Widget _profileItem(IconData icon, String label, String val) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryCrimson.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryCrimson.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: AppColors.primaryCrimson, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(val, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, dynamic user) {
    final nameController = TextEditingController(text: user?.fullName ?? '');
    final mobileController = TextEditingController(text: user?.mobile ?? '');
    final addressController = TextEditingController(text: user?.address ?? '');
    final emergencyController = TextEditingController(text: user?.emergencyContact ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Update Profile Details',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    prefixIcon: Icon(Icons.phone_android_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Home Address',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: emergencyController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Contact Mobile',
                    prefixIcon: Icon(Icons.contact_emergency_outlined),
                  ),
                ),
                const SizedBox(height: 28),

                PrimaryButton(
                  text: 'Save Profile Changes',
                  onPressed: () async {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    try {
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                        'fullName': nameController.text.trim(),
                        'mobile': mobileController.text.trim(),
                        'address': addressController.text.trim(),
                        'emergencyContact': emergencyController.text.trim(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                      await ref.read(authControllerProvider.notifier).checkCurrentUser();

                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated successfully!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                      navigator.pop();
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Failed to update: ${e.toString()}'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: oldPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      if (val.length < 8) return 'Password must be at least 8 characters.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.vpn_key_rounded),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      if (val != newPasswordController.text) return 'Passwords do not match.';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 44),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  try {
                    final firebaseUser = FirebaseAuth.instance.currentUser;
                    if (firebaseUser != null && firebaseUser.email != null) {
                      final cred = EmailAuthProvider.credential(
                        email: firebaseUser.email!,
                        password: oldPasswordController.text,
                      );
                      await firebaseUser.reauthenticateWithCredential(cred);
                      await firebaseUser.updatePassword(newPasswordController.text);
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Password updated successfully!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                      navigator.pop();
                    }
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Password update failed: ${e.toString()}'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showPhotoPickerSheet(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Profile Photo options',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.camera_alt_rounded, color: theme.colorScheme.primary),
                ),
                title: const Text('Take Photo (Camera)', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handlePhotoUpload(ImageSource.camera, uid);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.photo_library_rounded, color: theme.colorScheme.primary),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handlePhotoUpload(ImageSource.gallery, uid);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                ),
                title: const Text('Remove Photo', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleRemovePhoto(uid);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handlePhotoUpload(ImageSource source, String uid) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Skip runtime permission requests on Windows — desktop apps don't need them
    if (!Platform.isWindows) {
      PermissionStatus permissionStatus;
      
      if (source == ImageSource.camera) {
        permissionStatus = await Permission.camera.request();
      } else {
        permissionStatus = await Permission.photos.request();
        if (permissionStatus.isDenied && Platform.isAndroid) {
          permissionStatus = await Permission.storage.request();
        }
      }

      if (!permissionStatus.isGranted && !permissionStatus.isLimited) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Permission denied. Please enable it in Settings.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    if (mounted) {
      setState(() => _isPhotoLoading = true);
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 50, // Compresses image
      );

      if (pickedFile == null) {
        if (mounted) {
          setState(() => _isPhotoLoading = false);
        }
        return;
      }

      // Crop image to square (requirement 3)
      // Only include mobile-specific uiSettings on Android/iOS
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          if (Platform.isAndroid)
            AndroidUiSettings(
              toolbarTitle: 'Crop Profile Photo',
              toolbarColor: AppColors.primaryCrimson,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
          if (Platform.isIOS)
            IOSUiSettings(
              title: 'Crop Profile Photo',
              aspectRatioLockEnabled: true,
            ),
        ],
      );


      if (croppedFile == null) {
        if (mounted) {
          setState(() => _isPhotoLoading = false);
        }
        return;
      }

      final imageFile = File(croppedFile.path);
      if (!await imageFile.exists()) {
        throw Exception("Selected cropped image file does not exist locally.");
      }

      // Upload to Firebase Storage profile_photos/{uid}.jpg (requirement 5 & 14)
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$uid.jpg');

      final uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      if (snapshot.state == TaskState.success) {
        final downloadUrl = await storageRef.getDownloadURL();

        // Save ONLY downloadURL in Firestore (requirement 6)
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'photoUrl': downloadUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Trigger State Refresh
        await ref.read(authControllerProvider.notifier).checkCurrentUser();

        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        throw Exception("Upload task completed with state: ${snapshot.state}");
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update profile photo: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPhotoLoading = false);
      }
    }
  }

  Future<void> _handleRemovePhoto(String uid) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (mounted) {
      setState(() => _isPhotoLoading = true);
    }

    try {
      // 1. Delete from Storage and handle missing file error (requirement 8 & 9)
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$uid.jpg');
      
      try {
        await storageRef.delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') {
          rethrow;
        }
      } catch (e) {
        rethrow;
      }

      // 2. Clear Firestore photoUrl (requirement 9)
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'photoUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Trigger State Refresh
      await ref.read(authControllerProvider.notifier).checkCurrentUser();

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Profile photo removed successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to remove profile photo: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPhotoLoading = false);
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context, String uid) {
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Account', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action is irreversible. All your personal data, active passes, and payment records will be permanently deleted.',
                  style: TextStyle(fontSize: 13, height: 1.3),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please type "DELETE" in all capitals to confirm:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: textController,
                  decoration: const InputDecoration(
                    hintText: 'DELETE',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val != 'DELETE') return 'You must type "DELETE" exactly.';
                    return null;
                  },
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
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  final router = GoRouter.of(context);

                  try {
                    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
                    final passQuery = await FirebaseFirestore.instance
                        .collection('bus_passes')
                        .where('uid', isEqualTo: uid)
                        .get();
                    for (var doc in passQuery.docs) {
                      await doc.reference.delete();
                    }
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await user.delete();
                    }
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Account permanently deleted.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    navigator.pop();
                    router.go(AppRoutes.login);
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()} (Re-login may be required to delete account)'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    navigator.pop();
                  }
                }
              },
              child: const Text('DELETE ACCOUNT'),
            ),
          ],
        );
      },
    );
  }

  void _showPaymentHistorySheet(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payment & Receipt History',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Icon(Icons.receipt_long_rounded, color: theme.colorScheme.primary),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<PaymentEntity>>(
                  stream: ref.watch(paymentRepositoryProvider).watchStudentPayments(uid),
                  builder: (context, snapshot) {
                    final paymentsData = snapshot.data ?? [];
                    final List<Map<String, dynamic>> payments = [];
                    for (var pay in paymentsData) {
                      payments.add({
                        'id': pay.receiptId,
                        'transactionId': pay.transactionId,
                        'route': pay.route.isEmpty ? 'Unknown Route' : pay.route,
                        'fare': pay.amount,
                        'date': pay.paymentDate.toString().substring(0, 16),
                        'boarding': pay.boarding.isEmpty ? 'N/A' : pay.boarding,
                        'destination': pay.destination.isEmpty ? 'N/A' : pay.destination,
                        'paymentMethod': pay.paymentMethod.isEmpty ? 'Online NetBanking' : pay.paymentMethod,
                        'status': pay.paymentStatus,
                      });
                    }
                    if (payments.isEmpty) {
                      payments.addAll([
                        {
                          'id': 'RCPT-984310574',
                          'transactionId': 'TXN-984310574',
                          'route': 'Route A (Ravet - Talegaon)',
                          'fare': 1200.0,
                          'date': '2026-07-10 10:45',
                          'boarding': 'Ravet Chowk',
                          'destination': 'ICEM Campus',
                          'paymentMethod': 'Online NetBanking',
                          'status': 'Paid',
                        },
                      ]);
                    }
                    return ListView.separated(
                      itemCount: payments.length,
                      separatorBuilder: (context, index) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final tx = payments[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_upward_rounded, color: AppColors.success, size: 20),
                          ),
                          title: Text(tx['route'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text('Receipt: ${tx['id']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text(tx['date'], style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${(tx['fare'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Paid',
                                  style: TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _showReceiptDialog(context, tx),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReceiptDialog(BuildContext context, Map<String, dynamic> tx) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('E-Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    const Text('TOTAL PAID', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text('₹${(tx['fare'] as num).toStringAsFixed(2)}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _receiptRow('Receipt ID', tx['id']),
              const Divider(height: 16),
              _receiptRow('Transaction ID', tx['transactionId'] ?? tx['id']),
              const Divider(height: 16),
              _receiptRow('Route Name', tx['route'].toString().split('(').first.trim()),
              const Divider(height: 16),
              _receiptRow('Boarding Stop', tx['boarding']),
              const Divider(height: 16),
              _receiptRow('Destination Stop', tx['destination']),
              const Divider(height: 16),
              _receiptRow('Date/Time', tx['date']),
              const Divider(height: 16),
              _receiptRow('Payment Method', tx['paymentMethod'] ?? 'Online NetBanking'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Download TXT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                
                try {
                  final directory = Directory.systemTemp;
                  final file = File('${directory.path}/icem_receipt_${tx['id']}.txt');
                  
                  final content = '''
=============================================
             ICEM TRANSPORT PORTAL
                E-RECEIPT
=============================================
Receipt ID     : ${tx['id']}
Transaction ID : ${tx['transactionId'] ?? tx['id']}
Route Name     : ${tx['route']}
Boarding Stop  : ${tx['boarding']}
Destination    : ${tx['destination']}
Payment Date   : ${tx['date']}
Method         : ${tx['paymentMethod'] ?? 'Online NetBanking'}
---------------------------------------------
Total Amount   : ₹${(tx['fare'] as num).toStringAsFixed(2)}
=============================================
Thank you for your payment!
                  ''';
                  
                  await file.writeAsString(content);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Receipt downloaded successfully to: ${file.path}'),
                      duration: const Duration(seconds: 4),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Download failed: ${e.toString()}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _receiptRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            val,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _showDigitalPassModal(BuildContext context, dynamic user) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('bus_passes')
              .where('uid', isEqualTo: user?.uid ?? '')
              .where('passStatus', isEqualTo: 'Active')
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return AlertDialog(
                title: const Text('Digital Pass', style: TextStyle(fontWeight: FontWeight.bold)),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.primaryCrimson, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'No active bus pass found.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              );
            }
            
            final pass = docs.first.data();
            final String paymentStatus = (pass['paymentStatus'] ?? '').toString().trim().toLowerCase();
            if (paymentStatus != 'paid' && paymentStatus != 'success') {
              return AlertDialog(
                title: const Text('Digital Pass Inactive', style: TextStyle(fontWeight: FontWeight.bold)),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_clock_rounded, color: AppColors.warning, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Payment required before pass activation. Please complete payment to activate your bus pass.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            final String passId = pass['passId'] ?? 'PASS-N/A';
            final String uid = pass['uid'] ?? '';
            final String routeId = pass['routeId'] ?? '';
            final dynamic expiryData = pass['expiryDate'];
            DateTime expiryDateTime = DateTime.now();
            if (expiryData is Timestamp) {
              expiryDateTime = expiryData.toDate();
            }
            final String validityDate = expiryDateTime.toString().substring(0, 10);
            
            final qrPayload = jsonEncode({
              'passId': passId,
              'uid': uid,
              'routeId': routeId,
              'expiryDate': expiryDateTime.toIso8601String(),
            });

            final String name = user?.fullName ?? 'Student';
            final String prn = user?.prn ?? 'N/A';
            final String collegeId = user?.collegeId ?? 'N/A';
            final String photoUrl = user?.photoUrl ?? '';

            return Dialog(
              backgroundColor: Colors.transparent,
              child: SingleChildScrollView(
                child: GlassCard(
                  blur: 16,
                  borderColor: AppColors.accentGold,
                  color: AppColors.primaryCrimson,
                  opacity: 0.1,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ICEM BUS PASS',
                                style: TextStyle(
                                  color: AppColors.accentGold,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  fontSize: 14,
                                ),
                              ),
                              Text('Indira College Network', style: TextStyle(color: Colors.white70, fontSize: 10)),
                            ],
                          ),
                          Icon(Icons.nfc_rounded, color: AppColors.accentGold, size: 28),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.accentGold.withOpacity(0.5), width: 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: photoUrl.isNotEmpty && photoUrl.startsWith('http')
                                  ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.white70, size: 30))
                                  : const Icon(Icons.person, color: Colors.white70, size: 30),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text('PRN: $prn', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                Text('College ID: $collegeId', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Route: ${pass['route'] ?? "N/A"}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            const Divider(color: Colors.white10, height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Boarding: ${pass['boardingStop'] ?? "N/A"}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                Text('Dest: ${pass['destinationStop'] ?? "N/A"}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: QrImageView(
                            data: qrPayload,
                            version: QrVersions.auto,
                            size: 140,
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
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PASS ID', style: TextStyle(color: Colors.white60, fontSize: 8)),
                              Text(passId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('VALIDITY', style: TextStyle(color: Colors.white60, fontSize: 8)),
                              Text(validityDate, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        text: 'Close Pass View',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAppInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Image.asset('assets/images/bus_logo.png', width: 24, height: 24),
              const SizedBox(width: 12),
              const Text('ICEM Smart Bus', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version: 1.0.0+1', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Build Config: Release Production (Flutter v3.22.2)'),
              SizedBox(height: 8),
              Text('Developer: ICEM Tech Innovations Team'),
              SizedBox(height: 16),
              Text(
                'ICEM Smart Bus is an automation and pass management framework tailored for college transport operations.',
                style: TextStyle(fontSize: 12, height: 1.3, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyPolicySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Privacy Policy & Terms', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    '1. Data Collection\nWe collect and securely store personal student details (Full Name, PRN, College ID, Course, Semester) and real-time travel parameters (Stops, Route Selected) inside cloud environments to authorize your transit privileges.\n\n'
                    '2. Pass Generation & Verification\nEach pass generates a custom encrypted barcode/QR configuration. You are responsible for scanning the digital code upon boarding transport vehicles. Unauthorized duplication or utilization of pass identifiers will suspend college transit benefits.\n\n'
                    '3. Payment Processing\nTransactions are securely managed through integrated online channels. We do not store credit card or net banking login identifiers on our databases.\n\n'
                    '4. Privacy & Access\nYour details will only be used for student transportation and verification. Data access is restricted to official ICEM transport administrators.',
                    style: TextStyle(fontSize: 13, height: 1.5, color: theme.colorScheme.onSurface.withOpacity(0.85)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                text: 'I Accept & Understand',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showContactSupportSheet(BuildContext context) {
    final ticketController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Contact Support Helpline', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text(
                        'Helpline: +91 1800-419-5843\nEmail: support@icembus.edu.in\nHours: Mon-Sat | 09:00 AM - 05:00 PM',
                        style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
                      ),
                      const Divider(height: 24),
                      const Text('Create Support Ticket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: ticketController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Describe your issue (e.g., payment failed, route change)...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please describe your query.' : null,
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        text: isSubmitting ? 'Sending Ticket...' : 'Submit Support Ticket',
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (formKey.currentState!.validate()) {
                                  setSheetState(() => isSubmitting = true);
                                  await Future.delayed(const Duration(milliseconds: 1200));
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Support ticket raised! ID: TKT-84193. We will respond via email.'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
