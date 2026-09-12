import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/bus_pass/presentation/controllers/bus_pass_controller.dart';
import 'package:icem_bus/shared/custom_button.dart';
import 'package:icem_bus/shared/glass_card.dart';
import 'package:icem_bus/features/bus_pass/data/repositories/bus_pass_repository_impl.dart';
import 'package:icem_bus/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:qr_flutter/qr_flutter.dart';

// StreamProvider to query ACTIVE routes from Firestore collection 'bus_routes'
// Students can only see and apply for routes with status == 'Active'
final busRoutesStreamProvider = StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_routes')
      .where('status', isEqualTo: 'Active')
      .snapshots();
});


// StreamProvider to query student's pending pass applications
final pendingApplicationStreamProvider = StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) {
    return const Stream.empty();
  }
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .where('uid', isEqualTo: user.uid)
      .where('passStatus', isEqualTo: 'Pending Payment')
      .limit(1)
      .snapshots();
});

// StreamProvider to query student's pending pass in bus_passes collection
final pendingPassStreamProvider = StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) {
    return const Stream.empty();
  }
  return FirebaseFirestore.instance
      .collection('bus_passes')
      .where('uid', isEqualTo: user.uid)
      .where('paymentStatus', whereIn: const ['Pending', 'Failed', 'Pending Verification'])
      .limit(1)
      .snapshots();
});

// ==========================================
// APPLY BUS PASS SCREEN
// ==========================================
class ApplyPassScreen extends ConsumerStatefulWidget {
  const ApplyPassScreen({super.key});

  @override
  ConsumerState<ApplyPassScreen> createState() => _ApplyPassScreenState();
}

class _ApplyPassScreenState extends ConsumerState<ApplyPassScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for personal details
  final _prnController = TextEditingController();
  final _collegeIdController = TextEditingController();
  final _departmentController = TextEditingController();
  final _courseController = TextEditingController();
  final _yearController = TextEditingController();
  final _semesterController = TextEditingController();
  final _mobileController = TextEditingController();

  // Selection states
  DocumentSnapshot<Map<String, dynamic>>? _selectedRouteDoc;
  String? _selectedBoardingStop;
  String? _selectedDestinationStop;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeDefaultRoutesIfNeeded();
  }

  @override
  void dispose() {
    _prnController.dispose();
    _collegeIdController.dispose();
    _departmentController.dispose();
    _courseController.dispose();
    _yearController.dispose();
    _semesterController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  /// Automatically populate route samples if Firestore is empty
  Future<void> _initializeDefaultRoutesIfNeeded() async {
    try {
      final query = await FirebaseFirestore.instance.collection('bus_routes').get();
      if (query.docs.isEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        
        final route1 = FirebaseFirestore.instance.collection('bus_routes').doc('route_A');
        batch.set(route1, {
          'routeId': 'route_A',
          'routeName': 'Route A - Wakad & Hinjewadi',
          'boardingStops': ['Wakad Chowk', 'Dange Chowk', 'Kalewadi Phata'],
          'destinationStops': ['ICEM Campus', 'Indira College Wakad'],
          'distance': '18 km',
          'fare': 4500.0,
        });

        final route2 = FirebaseFirestore.instance.collection('bus_routes').doc('route_B');
        batch.set(route2, {
          'routeId': 'route_B',
          'routeName': 'Route B - Kothrud & Deccan',
          'boardingStops': ['Kothrud Stand', 'Deccan Corner', 'Karve Nagar'],
          'destinationStops': ['ICEM Campus'],
          'distance': '22 km',
          'fare': 5500.0,
        });

        final route3 = FirebaseFirestore.instance.collection('bus_routes').doc('route_C');
        batch.set(route3, {
          'routeId': 'route_C',
          'routeName': 'Route C - Chinchwad & Pimpri',
          'boardingStops': ['Chinchwad Station', 'Pimpri Chowk', 'Akurdi Railway Station'],
          'destinationStops': ['ICEM Campus'],
          'distance': '15 km',
          'fare': 4000.0,
        });

        await batch.commit();
      }
    } catch (_) {}
  }

  void _onApplyPressed() async {
    if (_formKey.currentState!.validate() &&
        _selectedRouteDoc != null &&
        _selectedBoardingStop != null &&
        _selectedDestinationStop != null) {
      
      final user = ref.read(authControllerProvider).user;
      if (user == null) return;

      setState(() => _isSubmitting = true);
      
      try {
        await ref.read(busPassRepositoryProvider).applyForBusPass(
          uid: user.uid,
          route: _selectedRouteDoc!['routeName'],
          routeId: _selectedRouteDoc!['routeId'],
          boardingStop: _selectedBoardingStop!,
          destinationStop: _selectedDestinationStop!,
          fare: (_selectedRouteDoc!['fare'] as num).toDouble(),
          distance: _selectedRouteDoc!.data()!.containsKey('distance') ? _selectedRouteDoc!['distance']?.toString() : null,
          department: _departmentController.text.trim(),
        );

        // Update user profile document with academic details
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'prn': _prnController.text.trim(),
          'collegeId': _collegeIdController.text.trim(),
          'department': _departmentController.text.trim(),
          'course': _courseController.text.trim(),
          'year': _yearController.text.trim(),
          'semester': _semesterController.text.trim(),
          'mobile': _mobileController.text.trim(),
        });

        // Sync local auth user state and bus pass provider
        await ref.read(authControllerProvider.notifier).checkCurrentUser();
        await ref.read(busPassControllerProvider.notifier).loadBusPass(user.uid);

        if (mounted) {
          context.pushReplacement(AppRoutes.studentPayment);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit application: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  // ── Helper: Extract boarding stops (supports old + new schema) ──
  List<String> _getBoardingStops(Map<String, dynamic> data) {
    // New schema: 'stops' list + 'source'
    final source = data['source'] as String?;
    final stops = data['stops'];
    if (stops is List && stops.isNotEmpty) {
      final list = stops.map((s) => s.toString()).toList();
      if (source != null && source.isNotEmpty && !list.contains(source)) {
        return [source, ...list];
      }
      return list;
    }
    // Old schema: 'boardingStops'
    final boardingStops = data['boardingStops'];
    if (boardingStops is List) {
      return boardingStops.map((s) => s.toString()).toList();
    }
    // Fallback: source only
    if (source != null && source.isNotEmpty) return [source];
    return [];
  }

  // ── Helper: Extract destination stops (supports old + new schema) ──
  List<String> _getDestinationStops(Map<String, dynamic> data) {
    // New schema: 'destination'
    final destination = data['destination'] as String?;
    final stops = data['stops'];
    if (stops is List && stops.isNotEmpty) {
      final list = stops.map((s) => s.toString()).toList();
      if (destination != null && destination.isNotEmpty && !list.contains(destination)) {
        return [...list, destination];
      }
      return list;
    }
    // Old schema: 'destinationStops'
    final destStops = data['destinationStops'];
    if (destStops is List) {
      return destStops.map((s) => s.toString()).toList();
    }
    // Fallback: destination only
    if (destination != null && destination.isNotEmpty) return [destination];
    return [];
  }

  // ── Helper: Route info card shown after selection ──
  Widget _buildRouteInfoCard(Map<String, dynamic> data) {
    final routeName = data['routeName'] as String? ?? '';
    final routeNumber = data['routeNumber'] as String? ?? '';
    final source = data['source'] as String? ?? '';
    final destination = data['destination'] as String? ?? '';
    final fareRaw = data['fare'];
    final fare = fareRaw is num
        ? fareRaw.toDouble()
        : double.tryParse(fareRaw?.toString() ?? '') ?? 0.0;
    final distKm = data['distanceKm'];
    final distOld = data['distance'] as String?;
    final distStr = distKm is num
        ? '${distKm.toStringAsFixed(1)} km'
        : (distOld ?? '');
    final estimatedTime = data['estimatedTime'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryCrimson.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryCrimson.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route name + number header
          Row(
            children: [
              Padding(padding: EdgeInsets.all(4.0), child: Image.asset('assets/images/bus_logo.png', width: 24, height: 24, fit: BoxFit.contain)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  routeNumber.isNotEmpty
                      ? '$routeNumber – $routeName'
                      : routeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Source → Destination
          if (source.isNotEmpty || destination.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.trip_origin_rounded,
                    size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    source.isNotEmpty ? source : 'N/A',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF475569)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 12, color: Color(0xFF94A3B8)),
                ),
                const Icon(Icons.flag_rounded,
                    size: 13, color: AppColors.primaryCrimson),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    destination.isNotEmpty ? destination : 'N/A',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 20),
          // Stats row: Distance | Time | Fare
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (distStr.isNotEmpty)
                _RouteInfoStat(
                    icon: Icons.straighten_rounded,
                    label: 'Distance',
                    value: distStr),
              if (estimatedTime.isNotEmpty)
                _RouteInfoStat(
                    icon: Icons.timer_outlined,
                    label: 'Travel Time',
                    value: estimatedTime),
              _RouteInfoStat(
                icon: Icons.currency_rupee_rounded,
                label: 'Fare',
                value: fare > 0 ? '₹${fare.toStringAsFixed(0)}' : 'N/A',
                valueColor: AppColors.primaryCrimson,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;
    final routesAsync = ref.watch(busRoutesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Apply for Bus Pass')),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Personal Details
                Text(
                  'Personal Details',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryCrimson),
                ),
                const SizedBox(height: 12),
                
                GlassCard(
                  blur: 10,
                  borderColor: AppColors.primaryCrimson.withOpacity(0.3),
                  opacity: 0.04,
                  child: Column(
                    children: [
                      // Full Name (Auto-filled & Read-only)
                      TextFormField(
                        initialValue: user?.fullName ?? '',
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Email (Auto-filled & Read-only)
                      TextFormField(
                        initialValue: user?.email ?? '',
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // PRN Number
                      TextFormField(
                        controller: _prnController,
                        decoration: const InputDecoration(
                          labelText: 'PRN Number',
                          prefixIcon: Icon(Icons.badge_outlined),
                          hintText: 'Enter college registration PRN',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'PRN Number is required.' : null,
                      ),
                      const SizedBox(height: 16),
                      // College ID
                      TextFormField(
                        controller: _collegeIdController,
                        decoration: const InputDecoration(
                          labelText: 'College ID Card Number',
                          prefixIcon: Icon(Icons.card_membership_rounded),
                          hintText: 'Enter college ID badge number',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'College ID is required.' : null,
                      ),
                      const SizedBox(height: 16),
                      // Department
                      TextFormField(
                        controller: _departmentController,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          prefixIcon: Icon(Icons.business_rounded),
                          hintText: 'e.g. Computer Engineering, Applied Science',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Department is required.' : null,
                      ),
                      const SizedBox(height: 16),
                      // Course
                      TextFormField(
                        controller: _courseController,
                        decoration: const InputDecoration(
                          labelText: 'Course',
                          prefixIcon: Icon(Icons.school_outlined),
                          hintText: 'e.g. B.Tech, MCA, BCA',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Course is required.' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          // Year
                          Expanded(
                            child: TextFormField(
                              controller: _yearController,
                              decoration: const InputDecoration(
                                labelText: 'Year',
                                hintText: 'e.g. FE, SE, TE, BE',
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Semester
                          Expanded(
                            child: TextFormField(
                              controller: _semesterController,
                              decoration: const InputDecoration(
                                labelText: 'Semester',
                                hintText: 'e.g. Sem 1, Sem V',
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Mobile Number
                      TextFormField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          prefixIcon: Icon(Icons.phone_iphone_rounded),
                          hintText: '10-digit mobile number',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Mobile number is required.';
                          if (val.trim().length < 10) return 'Enter a valid 10-digit number.';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Section 2: Travel Details
                Text(
                  'Travel Details & Route',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryCrimson),
                ),
                const SizedBox(height: 12),

                GlassCard(
                  blur: 10,
                  borderColor: AppColors.primaryCrimson.withOpacity(0.3),
                  opacity: 0.04,
                  child: routesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                    data: (routesSnapshot) {
                      final routes = routesSnapshot.docs;

                      if (routes.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Image.asset('assets/images/bus_logo.png', width: 40, height: 40, fit: BoxFit.contain),
                              const SizedBox(height: 10),
                              const Text(
                                'No active routes available.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Please contact the administrator to add routes.',
                                style: TextStyle(color: AppColors.textLight, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Select Route — shows routeNumber + name in label
                          DropdownButtonFormField<String>(
                            value: _selectedRouteDoc?.id,
                            decoration: InputDecoration(
                              labelText: 'Select Route',
                              prefixIcon: Padding(padding: const EdgeInsets.all(12.0), child: Image.asset('assets/images/bus_logo.png', width: 24, height: 24, fit: BoxFit.contain)),
                            ),
                            items: routes.map((doc) {
                              final data = doc.data();
                              final routeName = data['routeName'] as String? ?? '';
                              final routeNumber = data['routeNumber'] as String? ?? '';
                              final label = routeNumber.isNotEmpty
                                  ? '$routeNumber – $routeName'
                                  : routeName;
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(label, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (routeId) {
                              setState(() {
                                _selectedRouteDoc = routes.firstWhere((doc) => doc.id == routeId)
                                    as DocumentSnapshot<Map<String, dynamic>>?;
                                _selectedBoardingStop = null;
                                _selectedDestinationStop = null;
                              });
                            },
                            validator: (val) => val == null ? 'Please select a route.' : null,
                          ),

                          // Auto-display: Source, Destination, Distance, Fare
                          if (_selectedRouteDoc != null) ...[
                            const SizedBox(height: 16),
                            _buildRouteInfoCard(_selectedRouteDoc!.data()!),
                          ],
                          const SizedBox(height: 16),

                          // Select Boarding Stop — supports both old boardingStops and new stops field
                          DropdownButtonFormField<String>(
                            value: _selectedBoardingStop,
                            disabledHint: const Text('Select a route first'),
                            decoration: const InputDecoration(
                              labelText: 'Select Boarding Stop',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                            items: _selectedRouteDoc == null
                                ? null
                                : _getBoardingStops(_selectedRouteDoc!.data()!).map((stop) {
                                    return DropdownMenuItem<String>(
                                      value: stop,
                                      child: Text(stop),
                                    );
                                  }).toList(),
                            onChanged: _selectedRouteDoc == null
                                ? null
                                : (stop) => setState(() => _selectedBoardingStop = stop),
                            validator: (val) => val == null ? 'Please select a boarding stop.' : null,
                          ),
                          const SizedBox(height: 16),

                          // Select Destination Stop — supports both old destinationStops and new stops/destination field
                          DropdownButtonFormField<String>(
                            value: _selectedDestinationStop,
                            disabledHint: const Text('Select a route first'),
                            decoration: const InputDecoration(
                              labelText: 'Select Destination Stop',
                              prefixIcon: Icon(Icons.flag_outlined),
                            ),
                            items: _selectedRouteDoc == null
                                ? null
                                : _getDestinationStops(_selectedRouteDoc!.data()!).map((stop) {
                                    return DropdownMenuItem<String>(
                                      value: stop,
                                      child: Text(stop),
                                    );
                                  }).toList(),
                            onChanged: _selectedRouteDoc == null
                                ? null
                                : (stop) => setState(() => _selectedDestinationStop = stop),
                            validator: (val) => val == null ? 'Please select a destination stop.' : null,
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 36),
                PrimaryButton(
                  text: 'Submit & Proceed to Payment',
                  isLoading: _isSubmitting,
                  onPressed: _onApplyPressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// RENEW BUS PASS SCREEN
// ==========================================
class RenewPassScreen extends ConsumerWidget {
  const RenewPassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final busPassState = ref.watch(busPassControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Renew Bus Pass')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: busPassState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (pass) {
              if (pass == null) {
                return Center(
                  child: Column(
                    children: [
                      const Icon(Icons.card_membership_rounded, size: 64, color: AppColors.textLight),
                      const SizedBox(height: 16),
                      Text('No active pass record found.', style: theme.textTheme.titleMedium),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassCard(
                    blur: 12,
                    borderColor: AppColors.primaryCrimson,
                    opacity: 0.05,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow('Pass ID', pass.passId, theme),
                        const Divider(height: 24),
                        _infoRow('Selected Route', pass.route, theme),
                        const Divider(height: 24),
                        _infoRow('Pass Expiry', pass.expiryDate.toString().substring(0, 10), theme),
                        const Divider(height: 24),
                        _infoRow('Payment Status', pass.paymentStatus, theme, color: AppColors.primaryCrimson),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  PrimaryButton(
                    text: 'Proceed to Payment',
                    isLoading: busPassState.isLoading,
                    onPressed: () async {
                      final success = await ref.read(busPassControllerProvider.notifier).renewPass();
                      if (success && context.mounted) {
                        context.pushReplacement(AppRoutes.studentPayment);
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String val, ThemeData theme, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary)),
      ],
    );
  }
}

// ==========================================
// DIGITAL BUS PASS SCREEN (STANDALONE SUB-SCREEN PLACEHOLDER)
// ==========================================
class DigitalPassScreen extends ConsumerWidget {
  const DigitalPassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userState = ref.watch(authControllerProvider);
    final busPassState = ref.watch(busPassControllerProvider);
    final user = userState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Digital Pass'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go(AppRoutes.studentDashboard),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: busPassState.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 80.0),
                child: CircularProgressIndicator(color: AppColors.primaryCrimson),
              ),
            ),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 80.0),
                child: Text('Error: $err', style: const TextStyle(color: AppColors.error)),
              ),
            ),
            data: (pass) {
              final isActive = pass != null && (pass.status == 'Active' || pass.status == 'Approved');
              final isPaid = pass != null && (pass.paymentStatus == 'Paid' || pass.paymentStatus == 'Success');

              if (pass == null || !isActive || !isPaid) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      const Icon(Icons.qr_code_scanner_rounded, size: 80, color: AppColors.textLight),
                      const SizedBox(height: 20),
                      const Text(
                        "You do not have an active digital bus pass.",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Please complete application and payment to activate pass.",
                        style: TextStyle(fontSize: 12, color: AppColors.textLight),
                      ),
                      const SizedBox(height: 28),
                      PrimaryButton(
                        text: 'Apply for Bus Pass',
                        onPressed: () => context.push(AppRoutes.studentApply),
                      ),
                    ],
                  ),
                );
              }

              final String name = user?.fullName ?? 'Student';
              final String prn = user?.prn ?? 'N/A';
              final String collegeId = user?.collegeId ?? 'N/A';
              final String photoUrl = user?.photoUrl ?? '';
              final String validityDate = pass.expiryDate.toString().substring(0, 10);

              return Column(
                children: [
                  // Pass Card
                  GlassCard(
                    blur: 16,
                    borderColor: AppColors.accentGold,
                    color: AppColors.primaryCrimson,
                    opacity: 0.1,
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ICEM DIGITAL BUS PASS',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.accentGold,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    fontSize: 14,
                                  ),
                                ),
                                const Text('Indira College Network', style: TextStyle(color: Colors.white70, fontSize: 10)),
                              ],
                            ),
                            const Icon(Icons.nfc_rounded, color: AppColors.accentGold, size: 28),
                          ],
                        ),
                        const Divider(color: Colors.white24, height: 28),

                        // Student Details Row with Photo
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Student Photo
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.accentGold.withOpacity(0.5), width: 1.5),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: photoUrl.isNotEmpty && photoUrl.startsWith('http')
                                    ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.white70, size: 40))
                                    : const Icon(Icons.person, color: Colors.white70, size: 40),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('PRN: $prn', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text('College ID: $collegeId', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text('Dept: ${pass.department ?? user?.department ?? "N/A"}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Route Details
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Padding(padding: EdgeInsets.all(2.0), child: Image.asset('assets/images/bus_logo.png', width: 16, height: 16, fit: BoxFit.contain)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      pass.route,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white10, height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('BOARDING', style: TextStyle(color: Colors.white60, fontSize: 9)),
                                      Text(pass.boardingStop, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11)),
                                    ],
                                  ),
                                  const Icon(Icons.arrow_forward_rounded, color: Colors.white54, size: 14),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('DESTINATION', style: TextStyle(color: Colors.white60, fontSize: 9)),
                                      Text(pass.destinationStop, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white10, height: 16),
                              Row(
                                children: [
                                  Image.asset('assets/images/bus_logo.png', width: 16, height: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'BUS: ${pass.busNumber ?? "Not Assigned"}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // QR Code center area
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                ),
                                child: (pass.qrCode != null && pass.qrCode!.isNotEmpty)
                                    ? QrImageView(
                                        data: pass.qrCode!,
                                        version: QrVersions.auto,
                                        size: 160,
                                        gapless: false,
                                        eyeStyle: const QrEyeStyle(
                                          eyeShape: QrEyeShape.square,
                                          color: AppColors.primaryCrimson,
                                        ),
                                        dataModuleStyle: const QrDataModuleStyle(
                                          dataModuleShape: QrDataModuleShape.square,
                                          color: Colors.black,
                                        ),
                                      )
                                    : const SizedBox(
                                        width: 160,
                                        height: 160,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.primaryCrimson,
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 8),
                              const Text('SCAN AT BOARDING TERMINAL', style: TextStyle(color: AppColors.accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Validity, Pass Status, and Pass ID Footer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('PASS ID / NO', style: TextStyle(color: Colors.white60, fontSize: 9)),
                                Text(pass.passId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('STATUS', style: TextStyle(color: Colors.white60, fontSize: 9)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    pass.status.toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('VALIDITY UNTIL', style: TextStyle(color: Colors.white60, fontSize: 9)),
                                Text(validityDate, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PAYMENT HISTORY SCREEN
// ==========================================
class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view history.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go(AppRoutes.studentDashboard),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('receipts')
              .where('uid', isEqualTo: user.uid)
              .orderBy('paymentDate', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading history: ${snapshot.error}'));
            }
            
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 72, color: AppColors.textLight),
                    const SizedBox(height: 16),
                    Text('No transaction receipts found.', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('Receipts will appear here after a successful pass payment.', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(24.0),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final String receiptId = data['receiptId'] ?? 'RCPT-N/A';
                final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                
                final dynamic dateData = data['paymentDate'];
                String dateString = 'Recent';
                if (dateData is Timestamp) {
                  dateString = dateData.toDate().toString().substring(0, 16);
                } else if (dateData is String) {
                  dateString = dateData.substring(0, 16);
                }

                final String route = data['route'] ?? 'Bus Pass Registration';
                final String status = data['paymentStatus'] ?? 'Paid';
                
                Color statusColor = AppColors.success;
                IconData leadingIcon = Icons.arrow_upward_rounded;
                if (status == 'Failed') {
                  statusColor = AppColors.error;
                  leadingIcon = Icons.error_outline_rounded;
                } else if (status == 'Pending Verification' || status == 'Pending') {
                  statusColor = AppColors.warning;
                  leadingIcon = Icons.hourglass_empty_rounded;
                }

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(leadingIcon, color: statusColor, size: 20),
                    ),
                    title: Text(
                      route,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Receipt: $receiptId', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        Text('Date: $dateString', style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${amount.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: status == 'Failed' ? AppColors.error : AppColors.primaryCrimson, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showReceiptDetailsDialog(context, data, dateString),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showReceiptDetailsDialog(BuildContext context, Map<String, dynamic> data, String dateString) {
    final theme = Theme.of(context);
    final String receiptId = data['receiptId'] ?? 'RCPT-N/A';
    final String transactionId = data['transactionId'] ?? 'TXN-N/A';
    final String paymentMethod = data['paymentMethod'] ?? 'Online Payment';
    final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final String route = data['route'] ?? 'Bus Pass';
    final String boarding = data['boarding'] ?? 'N/A';
    final String destination = data['destination'] ?? 'N/A';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('E-Receipt Details', style: TextStyle(fontWeight: FontWeight.bold)),
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
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
                      const Text('TOTAL PAID AMOUNT', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(
                        '₹${amount.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _receiptDetailRow('Receipt ID', receiptId),
                const Divider(height: 16),
                _receiptDetailRow('Transaction ID', transactionId),
                const Divider(height: 16),
                _receiptDetailRow('Route Name', route),
                const Divider(height: 16),
                _receiptDetailRow('Boarding Stop', boarding),
                const Divider(height: 16),
                _receiptDetailRow('Destination Stop', destination),
                const Divider(height: 16),
                _receiptDetailRow('Payment Date', dateString),
                const Divider(height: 16),
                _receiptDetailRow('Payment Method', paymentMethod),
              ],
            ),
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
                  final file = File('${directory.path}/icem_receipt_$receiptId.txt');
                  
                  final content = '''
=============================================
             ICEM TRANSPORT PORTAL
                E-RECEIPT
=============================================
Receipt ID     : $receiptId
Transaction ID : $transactionId
Route Name     : $route
Boarding Stop  : $boarding
Destination    : $destination
Payment Date   : $dateString
Method         : $paymentMethod
---------------------------------------------
Total Amount   : ₹${amount.toStringAsFixed(2)}
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

  Widget _receiptDetailRow(String label, String val) {
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
}

// ==========================================
// NEW: SIMULATED PAYMENT SCREEN
// ==========================================
class StudentPaymentScreen extends ConsumerStatefulWidget {
  const StudentPaymentScreen({super.key});

  @override
  ConsumerState<StudentPaymentScreen> createState() => _StudentPaymentScreenState();
}

class _StudentPaymentScreenState extends ConsumerState<StudentPaymentScreen> {
  int _selectedPaymentMethod = 0; // 0: UPI ID, 1: QR Code, 2: Razorpay, 3: Cash (Admin), 4: Manual Transfer
  final _formKey = GlobalKey<FormState>();

  // Input Controllers
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _qrUtrController = TextEditingController();
  final _manualUtrController = TextEditingController();

  bool _simulateFailure = false;
  bool _isProcessing = false;
  String _processingStep = '';

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _upiIdController.dispose();
    _qrUtrController.dispose();
    _manualUtrController.dispose();
    super.dispose();
  }

  Future<void> _startPaymentSequence(
    Map<String, dynamic> passData,
    String passDocId,
    double totalAmount,
  ) async {
    setState(() {
      _isProcessing = true;
      _processingStep = 'Contacting Payment Gateway...';
    });

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _processingStep = 'Connecting to Secure Banking Server...');

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _processingStep = 'Verifying Transaction Credentials...');

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _processingStep = 'Authorizing Transaction...');

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    final double fare = (passData['fare'] as num?)?.toDouble() ?? 0.0;
    final String routeName = passData['route'] ?? passData['routeName'] ?? 'Unknown Route';
    final String routeId = passData['routeId'] ?? '';
    final String boardingStop = passData['boardingStop'] ?? 'N/A';
    final String destinationStop = passData['destinationStop'] ?? 'N/A';
    final String dept = passData['department'] ?? 'N/A';
    final String? dist = passData['distance'];

    final transactionId = 'TXN-${DateTime.now().millisecondsSinceEpoch}';

    String paymentMethodStr = '';
    String finalStatus = '';
    String finalPassStatus = '';

    if (_selectedPaymentMethod == 0) {
      paymentMethodStr = 'UPI ID (${_upiIdController.text.trim()})';
      finalStatus = _simulateFailure ? 'Failed' : 'Paid';
      finalPassStatus = _simulateFailure ? 'Pending Payment' : 'Active';
    } else if (_selectedPaymentMethod == 1) {
      paymentMethodStr = 'QR Code Scan (UTR: ${_qrUtrController.text.trim()})';
      finalStatus = _simulateFailure ? 'Failed' : 'Paid';
      finalPassStatus = _simulateFailure ? 'Pending Payment' : 'Active';
    } else if (_selectedPaymentMethod == 2) {
      paymentMethodStr = 'Razorpay Card (${_cardNumberController.text.substring(0, 4)}...)';
      finalStatus = _simulateFailure ? 'Failed' : 'Paid';
      finalPassStatus = _simulateFailure ? 'Pending Payment' : 'Active';
    } else if (_selectedPaymentMethod == 3) {
      paymentMethodStr = 'Cash Payment (Admin Verification)';
      finalStatus = 'Pending Verification';
      finalPassStatus = 'Pending Payment';
    } else if (_selectedPaymentMethod == 4) {
      paymentMethodStr = 'Manual Verification (UTR: ${_manualUtrController.text.trim()})';
      finalStatus = 'Pending Verification';
      finalPassStatus = 'Pending Payment';
    }

    if (finalStatus == 'Failed') {
      try {
        await ref.read(busPassRepositoryProvider).updatePassPayment(uid: user.uid, isSuccess: false);
        await ref.read(paymentRepositoryProvider).submitPayment(
          uid: user.uid,
          passId: 'N/A',
          studentName: user.fullName ?? 'N/A',
          amount: totalAmount,
          transactionId: transactionId,
          paymentDate: DateTime.now(),
          paymentStatus: 'Failed',
          paymentMethod: paymentMethodStr,
          route: routeName,
          routeId: routeId,
          boarding: boardingStop,
          destination: destinationStop,
          distance: dist ?? 'N/A',
          fare: fare,
        );

        await ref.read(busPassControllerProvider.notifier).loadBusPass(user.uid);
      } catch (_) {}

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment Transaction Declined by Issuing Bank.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } else {
      try {
        await ref.read(paymentRepositoryProvider).submitPayment(
          uid: user.uid,
          passId: 'N/A',
          studentName: user.fullName ?? 'N/A',
          amount: totalAmount,
          transactionId: transactionId,
          paymentDate: DateTime.now(),
          paymentStatus: finalStatus,
          paymentMethod: paymentMethodStr,
          route: routeName,
          routeId: routeId,
          boarding: boardingStop,
          destination: destinationStop,
          distance: dist ?? 'N/A',
          fare: fare,
        );

        // Update application
        final appQuery = await FirebaseFirestore.instance
            .collection('bus_pass_applications')
            .where('uid', isEqualTo: user.uid)
            .where('passStatus', isEqualTo: 'Pending Payment')
            .limit(1)
            .get();

        if (appQuery.docs.isNotEmpty) {
          await appQuery.docs.first.reference.update({
            'paymentStatus': finalStatus,
            'passStatus': finalPassStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Update/create digital bus pass in bus_passes
        await FirebaseFirestore.instance
            .collection('bus_passes')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'passId': 'PASS-${passDocId.length > 5 ? passDocId.substring(4) : passDocId}',
          'route': routeName,
          'routeId': routeId,
          'boardingStop': boardingStop,
          'destinationStop': destinationStop,
          'fare': fare,
          'department': dept,
          'distance': dist,
          'paymentStatus': finalStatus,
          'passStatus': finalPassStatus,
          'expiryDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 180))),
          'busNumber': 'Not Assigned',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await ref.read(busPassRepositoryProvider).updatePassPayment(uid: user.uid, isSuccess: true);
        await ref.read(busPassControllerProvider.notifier).loadBusPass(user.uid);

        if (mounted) {
          setState(() => _isProcessing = false);
          String snackMsg = finalStatus == 'Paid'
              ? 'Payment Successful! Digital Pass generated and receipt saved.'
              : 'Manual Payment Request Submitted. Awaiting administrative approval.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(snackMsg),
              backgroundColor: AppColors.success,
            ),
          );
          context.go(AppRoutes.studentDashboard);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Transaction Failed: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;
    final pendingPassAsync = ref.watch(pendingPassStreamProvider);

    if (_isProcessing) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.secondaryDark, Colors.black],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: GlassCard(
                blur: 16,
                borderColor: AppColors.accentGold,
                opacity: 0.1,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      color: AppColors.accentGold,
                      size: 64,
                    ),
                    const SizedBox(height: 32),
                    const CircularProgressIndicator(
                      color: AppColors.primaryCrimson,
                      strokeWidth: 4,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Securing Transaction...',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _processingStep,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Please do not close the app or tap back.',
                      style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Pass Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go(AppRoutes.studentDashboard),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: pendingPassAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (snapshot) {
              if (snapshot.docs.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      const Icon(Icons.check_circle_outline_rounded, size: 72, color: AppColors.success),
                      const SizedBox(height: 16),
                      Text('No pending pass applications found.', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        text: 'Go to Dashboard',
                        onPressed: () => context.go(AppRoutes.studentDashboard),
                      ),
                    ],
                  ),
                );
              }

              final passDoc = snapshot.docs.first;
              final passData = passDoc.data();
              final String routeName = passData['route'] as String? ?? 'No Route Selected';
              final double fare = (passData['fare'] as num?)?.toDouble() ?? 0.0;
              final String boarding = passData['boardingStop'] as String? ?? 'N/A';
              final String destination = passData['destinationStop'] as String? ?? 'N/A';
              final String dept = passData['department'] as String? ?? user?.department ?? 'N/A';
              final String courseStr = user?.course ?? user?.department ?? 'N/A';
              final String? dist = passData['distance'] as String?;

              // Calculations: GST (18%) and Convenience fee (50 for online, 0 for cash/manual)
              final double gst = fare * 0.18;
              final double convenienceFee = (_selectedPaymentMethod == 3 || _selectedPaymentMethod == 4) ? 0.0 : 50.0;
              final double totalAmount = fare + gst + convenienceFee;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Review Student & Route Details
                  Text(
                    'Verification Summary',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryCrimson),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    blur: 10,
                    borderColor: AppColors.primaryCrimson.withOpacity(0.3),
                    opacity: 0.04,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        _infoRow('Student Name', user?.fullName ?? 'N/A', theme),
                        const Divider(height: 20),
                        _infoRow('PRN Number', user?.prn ?? 'N/A', theme),
                        const Divider(height: 20),
                        _infoRow('Course', courseStr, theme),
                        const Divider(height: 20),
                        _infoRow('Department', dept, theme),
                        const Divider(height: 20),
                        _infoRow('Selected Route', routeName, theme),
                        const Divider(height: 20),
                        _infoRow('Boarding Stop', boarding, theme),
                        const Divider(height: 20),
                        _infoRow('Destination Stop', destination, theme),
                        if (dist != null) ...[
                          const Divider(height: 20),
                          _infoRow('Distance', dist, theme),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 2. Fare Breakdown
                  Text(
                    'Fee Summary',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryCrimson),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    blur: 10,
                    borderColor: AppColors.primaryCrimson.withOpacity(0.3),
                    opacity: 0.04,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        _infoRow('Pass Base Fee', '₹${fare.toStringAsFixed(2)}', theme),
                        const Divider(height: 20),
                        _infoRow('GST (18%)', '₹${gst.toStringAsFixed(2)}', theme),
                        const Divider(height: 20),
                        _infoRow('Convenience Charge', convenienceFee > 0 ? '₹${convenienceFee.toStringAsFixed(2)}' : 'Not Applicable', theme),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount Payable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                              '₹${totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryCrimson),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 3. Payment Methods
                  Text(
                    'Select Payment Mode',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryCrimson),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 84,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _paymentTabButton(0, Icons.mobile_friendly_rounded, 'UPI ID'),
                        const SizedBox(width: 8),
                        _paymentTabButton(1, Icons.qr_code_2_rounded, 'QR Code'),
                        const SizedBox(width: 8),
                        _paymentTabButton(2, Icons.payment_rounded, 'Razorpay'),
                        const SizedBox(width: 8),
                        _paymentTabButton(3, Icons.payments_rounded, 'Cash (Admin)'),
                        const SizedBox(width: 8),
                        _paymentTabButton(4, Icons.account_balance_rounded, 'Bank Manual'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Form Inputs
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedPaymentMethod == 0) ...[
                          // UPI Form
                          TextFormField(
                            controller: _upiIdController,
                            decoration: const InputDecoration(
                              labelText: 'UPI Virtual Payment Address (VPA) *',
                              hintText: 'student@okaxis',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'UPI ID is required.';
                              if (!val.contains('@')) return 'Enter a valid UPI ID (e.g. student@ybl).';
                              return null;
                            },
                          ),
                        ] else if (_selectedPaymentMethod == 1) ...[
                          // QR Code Form
                          Center(
                            child: GlassCard(
                              blur: 5,
                              borderColor: AppColors.primaryCrimson.withOpacity(0.2),
                              opacity: 0.02,
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  QrImageView(
                                    data: 'upi://pay?pa=icem@upi&pn=ICEM%20Bus%20Fund&am=${totalAmount.toStringAsFixed(2)}&cu=INR',
                                    version: QrVersions.auto,
                                    size: 150.0,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: AppColors.primaryCrimson,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: AppColors.secondaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Scan QR via GPay, PhonePe, or Paytm\nPayable: ₹${totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryDark),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _qrUtrController,
                            keyboardType: TextInputType.number,
                            maxLength: 12,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Transaction Reference / UTR Number * (12 digits)',
                              hintText: 'e.g. 301234567890',
                              prefixIcon: Icon(Icons.numbers_rounded),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Reference / UTR number is required.';
                              if (val.trim().length != 12) return 'UTR must be exactly 12 digits.';
                              return null;
                            },
                          ),
                        ] else if (_selectedPaymentMethod == 2) ...[
                          // Razorpay Card Form
                          TextFormField(
                            controller: _cardNumberController,
                            keyboardType: TextInputType.number,
                            maxLength: 16,
                            decoration: const InputDecoration(
                              labelText: 'Card Number *',
                              hintText: '1234 5678 1234 5678',
                              prefixIcon: Icon(Icons.credit_card_outlined),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Card number is required.';
                              if (val.trim().length < 16) return 'Enter a valid 16-digit card number.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _cardHolderController,
                            decoration: const InputDecoration(
                              labelText: 'Cardholder Name *',
                              hintText: 'Enter name printed on card',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Cardholder name is required.' : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _expiryController,
                                  keyboardType: TextInputType.datetime,
                                  maxLength: 5,
                                  decoration: const InputDecoration(
                                    labelText: 'Expiry Date (MM/YY) *',
                                    hintText: '12/29',
                                    prefixIcon: Icon(Icons.calendar_today_outlined),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Required';
                                    if (!val.contains('/')) return 'Format MM/YY';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _cvvController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 3,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'CVV *',
                                    hintText: '***',
                                    prefixIcon: Icon(Icons.lock_outline_rounded),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Required';
                                    if (val.trim().length < 3) return '3 digits';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ] else if (_selectedPaymentMethod == 3) ...[
                          // Cash Form Instructions
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.primaryCrimson.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primaryCrimson.withOpacity(0.15)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, color: AppColors.primaryCrimson, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Cash Payment Instructions',
                                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryCrimson),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '1. Please submit cash of ₹${totalAmount.toStringAsFixed(2)} at the College Admin desk.\n'
                                  '2. Share your PRN (${user?.prn ?? "N/A"}) or Pass Application ID.\n'
                                  '3. Tap the request button below to notify the administrator.',
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Manual Verification Transfer details
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('COLLEGE BANK ACCOUNT DETAILS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textLight, letterSpacing: 0.5)),
                                const SizedBox(height: 8),
                                _infoRow('Account Name', 'ICEM Student Welfare & Bus Fund', theme),
                                const Divider(height: 12),
                                _infoRow('Bank Name', 'State Bank of India', theme),
                                const Divider(height: 12),
                                _infoRow('Account Number', '98765432101', theme),
                                const Divider(height: 12),
                                _infoRow('IFSC Code', 'SBIN0004567', theme),
                              ],
                            ),
                          ),
                          TextFormField(
                            controller: _manualUtrController,
                            keyboardType: TextInputType.number,
                            maxLength: 12,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Bank Transfer Reference / UTR Number * (12 digits)',
                              hintText: 'e.g. 301234567890',
                              prefixIcon: Icon(Icons.numbers_rounded),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Reference / UTR number is required.';
                              if (val.trim().length != 12) return 'UTR must be exactly 12 digits.';
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Simulation Switch for Online Modes
                  if (_selectedPaymentMethod <= 2) ...[
                    SwitchListTile(
                      title: const Text('Simulate Bank Network Failure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('Toggle to simulate transaction decline/timeout', style: TextStyle(fontSize: 11)),
                      activeColor: AppColors.primaryCrimson,
                      value: _simulateFailure,
                      onChanged: (val) => setState(() => _simulateFailure = val),
                    ),
                    const SizedBox(height: 20),
                  ],

                  PrimaryButton(
                    text: _selectedPaymentMethod >= 3 
                        ? 'Request Manual Verification' 
                        : 'Pay Securely ₹${totalAmount.toStringAsFixed(2)}',
                    icon: Icons.security_rounded,
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _startPaymentSequence(passData, passDoc.id, totalAmount);
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _paymentTabButton(int index, IconData icon, String label) {
    final active = _selectedPaymentMethod == index;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryCrimson : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppColors.primaryCrimson : Colors.grey.withOpacity(0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? Colors.white : AppColors.textSecondary, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String val, ThemeData theme, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            val,
            textAlign: TextAlign.end,
            style: TextStyle(fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

// ── Route Info Stat widget for Apply screen ──
class _RouteInfoStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _RouteInfoStat({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: valueColor ?? const Color(0xFF64748B)),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
