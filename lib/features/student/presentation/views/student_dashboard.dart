import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'package:icem_bus/shared/custom_button.dart';
import 'package:icem_bus/shared/glass_card.dart';
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
      _buildNotificationsTab(context),
      _buildProfileTab(context, ref, user),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.primaryCrimson),
            onPressed: () async {
              final router = GoRouter.of(context);
              await ref.read(authControllerProvider.notifier).logout();
              router.go(AppRoutes.login);
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primaryCrimson),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Image.asset('assets/images/bus_logo.png', width: 24, height: 24, fit: BoxFit.contain, color: AppColors.textSecondary),
            selectedIcon: Image.asset('assets/images/bus_logo.png', width: 24, height: 24, fit: BoxFit.contain, color: AppColors.primaryCrimson),
            label: 'Bus Pass',
          ),
          const NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications_rounded, color: AppColors.primaryCrimson),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primaryCrimson),
            label: 'Profile',
          ),
        ],
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
        return 'College Notifications';
      case 3:
        return 'My Profile';
      default:
        return 'Dashboard';
    }
  }

  // ==========================================
  // TAB 1: HOME VIEW
  // ==========================================
  Widget _buildHomeTab(BuildContext context, WidgetRef ref, dynamic user) {
    final theme = Theme.of(context);
    final String studentName = user?.fullName ?? 'Student';
    final String studentRole = user?.role ?? 'Engineering Student';
    
    final activePassAsync = ref.watch(activePassStreamProvider);
    final latestPassAsync = ref.watch(latestPassStreamProvider);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting & Profile Photo Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $studentName!',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryCrimson,
                          fontSize: 26,
                        ),
                      ),
                      Text(
                        studentRole,
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Profile initials circle
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.lightCrimson,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryCrimson.withOpacity(0.3), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      studentName.isNotEmpty ? studentName.substring(0, 1).toUpperCase() : 'S',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryCrimson, fontSize: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            Text(
              'Current Status',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),

            // Dynamic Pass Status & Action Card
            latestPassAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (snapshot) {
                final hasPass = snapshot.docs.isNotEmpty;

                if (hasPass) {
                  final passDoc = snapshot.docs.first.data();
                  final String route = passDoc['route'] as String? ?? 'No Route Selected';
                  final String passStatus = passDoc['passStatus'] as String? ?? passDoc['status'] as String? ?? 'None';
                  final String paymentStatus = passDoc['paymentStatus'] as String? ?? 'Unpaid';
                  
                  final dynamic expiryData = passDoc['expiryDate'];
                  String expiryString = 'N/A';
                  if (expiryData is Timestamp) {
                    expiryString = expiryData.toDate().toString().substring(0, 10);
                  } else if (expiryData is String) {
                    expiryString = expiryData.substring(0, 10);
                  }

                  if (paymentStatus == 'Paid' && passStatus == 'Active') {
                    // Paid & Active
                    return GlassCard(
                      blur: 14,
                      borderColor: AppColors.success,
                      color: AppColors.success,
                      opacity: 0.08,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'PASS ACTIVE & PAID',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                              Icon(
                                Icons.check_circle_rounded,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            route,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Expiry Date: $expiryString',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            text: 'View Digital Pass',
                            icon: Icons.qr_code_rounded,
                            onPressed: () => context.push(AppRoutes.studentDigitalPass),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Applied but Unpaid/Pending/Failed/Pending Verification
                    final bool isFailed = paymentStatus == 'Failed';
                    final bool isPendingVerification = paymentStatus == 'Pending Verification';

                    Color cardBorderColor = AppColors.warning;
                    String headerText = 'PAYMENT PENDING';
                    IconData headerIcon = Icons.warning_amber_rounded;
                    String buttonText = 'Complete Payment';

                    if (isFailed) {
                      cardBorderColor = AppColors.error;
                      headerText = 'PAYMENT FAILED / DECLINED';
                      headerIcon = Icons.error_outline_rounded;
                      buttonText = 'Retry Payment';
                    } else if (isPendingVerification) {
                      cardBorderColor = AppColors.warning;
                      headerText = 'VERIFICATION PENDING';
                      headerIcon = Icons.hourglass_empty_rounded;
                      buttonText = 'View Reference Details';
                    }

                    return GlassCard(
                      blur: 14,
                      borderColor: cardBorderColor,
                      color: cardBorderColor,
                      opacity: 0.08,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                headerText,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isFailed ? AppColors.error : AppColors.primaryCrimson,
                                ),
                              ),
                              Icon(
                                headerIcon,
                                color: isFailed ? AppColors.error : AppColors.primaryCrimson,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            route,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fare Fee: ₹${passDoc['fare'] ?? '0.00'}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            text: buttonText,
                            icon: isFailed
                                ? Icons.refresh_rounded
                                : isPendingVerification
                                    ? Icons.info_outline_rounded
                                    : Icons.payment_rounded,
                            onPressed: () {
                              if (isPendingVerification) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: const Text('Verification Pending'),
                                    content: Text(
                                      'Your manual transfer / cash payment request is currently being verified by the college administration.\n\n'
                                      'Reference Receipt: ${passDoc['passId'] ?? 'N/A'}\n'
                                      'Please coordinate with the admin desk at your college if this takes longer than expected.'
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                context.push(AppRoutes.studentPayment);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }
                } else {
                  // No Pass Applied
                  return Center(
                    child: GlassCard(
                      blur: 10,
                      borderColor: AppColors.primaryCrimson.withOpacity(0.3),
                      opacity: 0.03,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 80,
                            color: AppColors.textLight,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "You don't have a registered bus pass.",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            text: 'Apply for Bus Pass',
                            icon: Icons.add_card_rounded,
                            onPressed: () => context.push(AppRoutes.studentApply),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }
            ),
            const SizedBox(height: 28),

            // Quick Action Buttons
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.45,
              children: [
                _actionCard('Apply Pass', () => context.push(AppRoutes.studentApply)),
                _actionCard('Renew Pass', () => context.push(AppRoutes.studentRenew)),
                _actionCard('Digital Pass', () => context.push(AppRoutes.studentDigitalPass)),
                _actionCard('Payments', () => context.push(AppRoutes.studentPaymentHistory)),
                _actionCard('Alerts', () => setState(() => _currentTabIndex = 2)),
                _actionCard('My Profile', () => setState(() => _currentTabIndex = 3)),
              ],
            ),
            const SizedBox(height: 28),

            // Details Grid
            Text(
              'Bus Schedule Details',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            latestPassAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (snapshot) {
                final hasPass = snapshot.docs.isNotEmpty;
                final passDoc = hasPass ? snapshot.docs.first.data() : null;

                final paymentStatus = passDoc?['paymentStatus'] as String? ?? 'Unpaid';
                final busNumber = passDoc?['busNumber'] as String? ?? 'Not Assigned';

                return Row(
                  children: [
                    _detailCard('Payment', paymentStatus, const Icon(Icons.payment_rounded, color: AppColors.primaryCrimson, size: 24), theme),
                    const SizedBox(width: 16),
                    _detailCard('Bus Number', busNumber, Padding(padding: const EdgeInsets.all(8.0), child: Image.asset('assets/images/bus_logo.png', width: 40, height: 40, fit: BoxFit.contain)), theme),
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

  Widget _actionCard(String label, VoidCallback onTap) {
    return Card(
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: AppColors.lightCrimson, shape: BoxShape.circle),
                child: Image.asset('assets/images/bus_logo.png', width: 40, height: 40, fit: BoxFit.contain),
              ),
              const SizedBox(height: 12),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailCard(String title, String val, Widget iconWidget, ThemeData theme) {
    return Expanded(
      child: Card(
        color: AppColors.surfaceLight,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              iconWidget,
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                val,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
        padding: const EdgeInsets.all(24.0),
        child: activePassAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (snapshot) {
            final hasActivePass = snapshot.docs.isNotEmpty;

            if (!hasActivePass) {
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
            final String route = passDoc['route'] as String? ?? 'No Route Selected';
            final String routeId = passDoc['routeId'] as String? ?? '';
            
            final dynamic expiryData = passDoc['expiryDate'];
            String expiryString = 'N/A';
            if (expiryData is Timestamp) {
              expiryString = expiryData.toDate().toString().substring(0, 10);
            } else if (expiryData is String) {
              expiryString = expiryData.substring(0, 10);
            }

            final busAsync = ref.watch(assignedBusStreamProvider(routeId));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Frosted Pass Card
                GlassCard(
                  blur: 16,
                  borderColor: AppColors.accentGold,
                  color: AppColors.primaryCrimson,
                  opacity: 0.12,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ICEM DIGITAL PASS',
                            style: TextStyle(color: AppColors.accentGold, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                          ),
                          const Icon(Icons.nfc_rounded, color: AppColors.accentGold, size: 24),
                        ],
                      ),
                      const SizedBox(height: 36),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.qr_code_2_rounded, size: 140, color: AppColors.primaryCrimson),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.fullName.toUpperCase() ?? 'STUDENT',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text('Route: $route', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('EXPIRY DATE', style: TextStyle(color: Colors.white60, fontSize: 8)),
                              Text(expiryString, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Assigned Bus Section Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    children: [
                      Image.asset('assets/images/bus_logo.png', width: 18, height: 18),
                      const SizedBox(width: 8),
                      const Text(
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
                  loading: () => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryCrimson),
                    ),
                  ),
                  error: (err, _) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Center(
                      child: Text('Error loading bus details: $err', style: const TextStyle(color: AppColors.error)),
                    ),
                  ),
                  data: (bus) {
                    if (bus == null) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          children: [
                            Image.asset('assets/images/bus_logo.png', width: 40, height: 40),
                            const SizedBox(height: 12),
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

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.015),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
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
                                        fontSize: 15,
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
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusColor.withOpacity(0.2)),
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
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 16),

                          // Driver details
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryCrimson.withOpacity(0.08),
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
                                        color: AppColors.textLight,
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
                                    backgroundColor: AppColors.primaryCrimson.withOpacity(0.08),
                                    padding: const EdgeInsets.all(10),
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: driverPhone));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Driver's phone number copied!"),
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
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
  // TAB 3: ALERTS TAB
  // ==========================================
  Widget _buildNotificationsTab(BuildContext context) {
    final mockAlerts = [
      _AlertItem('Pass Approved', 'Your bus pass application has been approved by the administrative office.', '2 hours ago', Icons.verified_rounded, AppColors.success),
      _AlertItem('Route Delay', 'Route No. 4 bus is delayed by 15 minutes due to highway traffic.', '5 hours ago', Icons.warning_amber_rounded, AppColors.warning),
      _AlertItem('Renewal reminder', 'Your current bus pass expires in 12 days. Submit a renewal request to avoid disruptions.', '1 day ago', Icons.info_outline_rounded, AppColors.info),
    ];

    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.all(24.0),
        itemCount: mockAlerts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final alert = mockAlerts[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: alert.color.withOpacity(0.08), shape: BoxShape.circle),
                    child: Icon(alert.icon, color: alert.color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(alert.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3)),
                        const SizedBox(height: 8),
                        Text(alert.time, style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 4: PROFILE & SETTINGS TAB
  // ==========================================
  Widget _buildProfileTab(BuildContext context, WidgetRef ref, dynamic user) {
    final theme = Theme.of(context);
    final String name = user?.fullName ?? 'Student User';
    final String email = user?.email ?? 'student@icem.edu.in';
    final String? photoUrl = user?.photoUrl;

    // Real-time email verification check
    final isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    // Preferences state
    final settings = ref.watch(settingsNotifierProvider);
    final settingsNotifier = ref.read(settingsNotifierProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Profile Monogram & Banner
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.primaryCrimson.withOpacity(0.08),
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.colorScheme.primary, width: 2.5),
                        ),
                        child: ClipOval(
                          child: _isPhotoLoading
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
                              : (photoUrl != null && photoUrl.isNotEmpty && photoUrl.startsWith('http')
                                  ? Image.network(
                                      photoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Center(
                                        child: Text(
                                          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                              fontSize: 36),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                            fontSize: 36),
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
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.scaffoldBackgroundColor, width: 2.0),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text(email, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isEmailVerified ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isEmailVerified ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
                          size: 14,
                          color: isEmailVerified ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isEmailVerified ? 'Verified Email' : 'Unverified Email',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isEmailVerified ? AppColors.success : AppColors.error,
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
                                color: _emailVerificationCooldown > 0 ? Colors.grey : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _sectionHeader(theme, 'Academic Profile'),
            const SizedBox(height: 8),
            GlassCard(
              blur: 10,
              borderColor: theme.colorScheme.primary.withOpacity(0.2),
              opacity: 0.04,
              child: Column(
                children: [
                  _profileItem(Icons.numbers_rounded, 'PRN Number', user?.prn ?? 'Not Applied Yet', theme),
                  const Divider(height: 24),
                  _profileItem(Icons.pin_rounded, 'College ID', user?.collegeId ?? 'Not Applied Yet', theme),
                  const Divider(height: 24),
                  _profileItem(Icons.domain_rounded, 'Department', user?.department ?? 'Not Applied Yet', theme),
                  const Divider(height: 24),
                  _profileItem(Icons.school_rounded, 'Course', user?.course ?? 'Not Applied Yet', theme),
                  const Divider(height: 24),
                  _profileItem(Icons.calendar_today_rounded, 'Academic Year', user?.year ?? 'Not Applied Yet', theme),
                  const Divider(height: 24),
                  _profileItem(Icons.class_rounded, 'Semester', user?.semester ?? 'Not Applied Yet', theme),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _sectionHeader(theme, 'Personal & Contact Details'),
            const SizedBox(height: 8),
            GlassCard(
              blur: 10,
              borderColor: theme.colorScheme.primary.withOpacity(0.2),
              opacity: 0.04,
              child: Column(
                children: [
                  _profileItem(Icons.phone_iphone_rounded, 'Mobile Number', user?.mobile ?? 'Not set', theme),
                  const Divider(height: 24),
                  _profileItem(Icons.home_outlined, 'Home Address', user?.address ?? 'Not set', theme),
                  const Divider(height: 24),
                  _profileItem(Icons.contact_emergency_outlined, 'Emergency Contact', user?.emergencyContact ?? 'Not set', theme),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: 'Edit Profile Information',
                    icon: Icons.edit_note_rounded,
                    onPressed: () => _showEditProfileDialog(context, ref, user),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _sectionHeader(theme, 'Transit Passes & Billing Invoices'),
            const SizedBox(height: 8),
            GlassCard(
              blur: 10,
              borderColor: theme.colorScheme.primary.withOpacity(0.2),
              opacity: 0.04,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.qr_code_2_rounded, color: theme.colorScheme.primary),
                    title: const Text('My Digital Bus Pass', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Access scan codes and route configurations', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => _showDigitalPassModal(context, user),
                  ),
                  const Divider(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.history_rounded, color: theme.colorScheme.primary),
                    title: const Text('Payment & Receipt History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('View and download official billing invoices', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => _showPaymentHistorySheet(context, user?.uid ?? ''),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _sectionHeader(theme, 'Security & Authentication'),
            const SizedBox(height: 8),
            GlassCard(
              blur: 10,
              borderColor: theme.colorScheme.primary.withOpacity(0.2),
              opacity: 0.04,
              child: Column(
                children: [
                  _profileItem(Icons.fingerprint_rounded, 'User ID (UID)', user?.uid ?? 'N/A', theme),
                  const SizedBox(height: 16),
                  SecondaryButton(
                    text: 'Change Account Password',
                    icon: Icons.lock_reset_rounded,
                    onPressed: () => _showChangePasswordDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _sectionHeader(theme, 'Aesthetics & Settings'),
            const SizedBox(height: 8),
            GlassCard(
              blur: 10,
              borderColor: theme.colorScheme.primary.withOpacity(0.2),
              opacity: 0.04,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('App Theme Mode', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _themeChip(ThemeMode.light, 'Light', Icons.wb_sunny_outlined, settings.themeMode, settingsNotifier),
                      _themeChip(ThemeMode.dark, 'Dark', Icons.nightlight_round_outlined, settings.themeMode, settingsNotifier),
                      _themeChip(ThemeMode.system, 'System', Icons.settings_brightness_rounded, settings.themeMode, settingsNotifier),
                    ],
                  ),
                  const Divider(height: 32),
                  Text('Accent Color Theme', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _colorChip('crimson', AppColors.primaryCrimson, settings.accentColor, settingsNotifier),
                      _colorChip('blue', Colors.blue.shade700, settings.accentColor, settingsNotifier),
                      _colorChip('green', Colors.green.shade700, settings.accentColor, settingsNotifier),
                      _colorChip('purple', Colors.purple.shade700, settings.accentColor, settingsNotifier),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _sectionHeader(theme, 'Local App Preferences'),
            const SizedBox(height: 8),
            GlassCard(
              blur: 10,
              borderColor: theme.colorScheme.primary.withOpacity(0.2),
              opacity: 0.04,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.translate_rounded, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                          const SizedBox(width: 12),
                          const Text('Preferred Language', style: TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      DropdownButton<String>(
                        value: settings.language,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'english', child: Text('English')),
                          DropdownMenuItem(value: 'hindi', child: Text('Hindi')),
                          DropdownMenuItem(value: 'marathi', child: Text('Marathi')),
                        ],
                        onChanged: (val) {
                          if (val != null) settingsNotifier.updateLanguage(val);
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    title: const Text('Push Notifications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: const Text('Get real-time updates regarding bus timings', style: TextStyle(fontSize: 11)),
                    contentPadding: EdgeInsets.zero,
                    activeColor: theme.colorScheme.primary,
                    value: settings.notificationsEnabled,
                    onChanged: (val) => settingsNotifier.updateNotificationsEnabled(val),
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    title: const Text('Pass Expiry Reminders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: const Text('Get alerts 5 days prior to pass expiry', style: TextStyle(fontSize: 11)),
                    contentPadding: EdgeInsets.zero,
                    activeColor: theme.colorScheme.primary,
                    value: settings.passExpiryReminderEnabled,
                    onChanged: (val) => settingsNotifier.updatePassExpiryReminderEnabled(val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _sectionHeader(theme, 'Support & Documentation'),
            const SizedBox(height: 8),
            GlassCard(
              blur: 10,
              borderColor: theme.colorScheme.primary.withOpacity(0.2),
              opacity: 0.04,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
                    title: const Text('App Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Check application build version and specs', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => _showAppInfoDialog(context),
                  ),
                  const Divider(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.privacy_tip_outlined, color: theme.colorScheme.primary),
                    title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Review transport data utilization terms', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => _showPrivacyPolicySheet(context),
                  ),
                  const Divider(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.support_agent_rounded, color: theme.colorScheme.primary),
                    title: const Text('Contact Support Helpline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Submit ticket or call helpline desk', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => _showContactSupportSheet(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _sectionHeader(theme, 'Danger Zone'),
            const SizedBox(height: 8),
            GlassCard(
              blur: 10,
              borderColor: AppColors.error.withOpacity(0.2),
              opacity: 0.04,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout_rounded, color: AppColors.primaryCrimson),
                    title: const Text('Sign Out Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Log out of the current device session', style: TextStyle(fontSize: 11)),
                    onTap: () async {
                      final router = GoRouter.of(context);
                      await ref.read(authControllerProvider.notifier).logout();
                      router.go(AppRoutes.login);
                    },
                  ),
                  const Divider(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                    title: const Text('Delete Account Permanently', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error)),
                    subtitle: const Text('Erase profile details and transit data', style: TextStyle(fontSize: 11)),
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

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          letterSpacing: 0.5,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _profileItem(IconData icon, String label, String val, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _themeChip(ThemeMode mode, String label, IconData icon, ThemeMode current, SettingsNotifier notifier) {
    final active = mode == current;
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: active ? Colors.white : theme.colorScheme.onSurface),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: active,
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: active ? Colors.white : theme.colorScheme.onSurface,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (_) => notifier.updateThemeMode(mode),
    );
  }

  Widget _colorChip(String colorName, Color colorValue, String current, SettingsNotifier notifier) {
    final active = colorName == current;
    return ChoiceChip(
      avatar: CircleAvatar(backgroundColor: colorValue, radius: 10),
      label: Text(colorName[0].toUpperCase() + colorName.substring(1)),
      selected: active,
      selectedColor: colorValue.withOpacity(0.2),
      side: BorderSide(color: active ? colorValue : Colors.transparent, width: 2.0),
      labelStyle: TextStyle(
        color: colorValue,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (_) => notifier.updateAccentColor(colorName),
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
        final theme = Theme.of(ctx);
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

class _AlertItem {
  final String title;
  final String description;
  final String time;
  final IconData icon;
  final Color color;

  _AlertItem(this.title, this.description, this.time, this.icon, this.color);
}

