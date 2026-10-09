// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/bus_pass/presentation/controllers/bus_pass_controller.dart';
import 'package:icem_bus/shared/app_card.dart';
import 'package:icem_bus/shared/app_text_field.dart';
import 'package:icem_bus/shared/custom_button.dart';
import 'package:icem_bus/shared/empty_state.dart';
import 'package:icem_bus/shared/loading_skeleton.dart';
import 'package:icem_bus/features/bus_pass/data/repositories/bus_pass_repository_impl.dart';
import 'package:qr_flutter/qr_flutter.dart';

export 'package:icem_bus/features/payment/presentation/views/student_payment_screen.dart';

// StreamProvider to query ACTIVE routes from Firestore collection 'bus_routes'
// Students can only see and apply for routes with status == 'Active'
final busRoutesStreamProvider = StreamProvider.autoDispose<List<DocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_routes')
      .snapshots()
      .map((snapshot) {
        final docs = snapshot.docs.where((doc) {
          final data = doc.data();
          final status = (data['status'] as String?)?.trim();
          if (status == null || status.isEmpty) return true;
          return status.toLowerCase() == 'active';
        }).toList();
        docs.sort((a, b) {
          final numA = a.data()['routeNumber']?.toString() ?? '';
          final numB = b.data()['routeNumber']?.toString() ?? '';
          if (numA.isNotEmpty && numB.isNotEmpty) {
            return numA.compareTo(numB);
          }
          final nameA = a.data()['routeName']?.toString() ?? '';
          final nameB = b.data()['routeName']?.toString() ?? '';
          return nameA.compareTo(nameB);
        });
        return docs;
      });
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
      .where('passStatus', whereIn: const ['Payment Pending', 'Pending Payment', 'Pending'])
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
      .where('paymentStatus', whereIn: const ['Pending', 'Failed', 'Pending Verification', 'Unpaid'])
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

  // Profile controllers
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

  // View state: 4-step wizard & submission
  int _currentStep = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadProfileFromCurrentState();
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

  void _loadProfileFromCurrentState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = ref.read(authControllerProvider).user;
      if (user != null) {
        _populateFieldsFromUser(user);

        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (doc.exists && doc.data() != null && mounted) {
            final data = doc.data()!;
            setState(() {
              if (_mobileController.text.trim().isEmpty && data['mobile'] != null && data['mobile'].toString().trim().isNotEmpty) {
                _mobileController.text = data['mobile'].toString().trim();
              }
              if (_prnController.text.trim().isEmpty && data['prn'] != null && data['prn'].toString().trim().isNotEmpty) {
                _prnController.text = data['prn'].toString().trim();
              }
              if (_collegeIdController.text.trim().isEmpty && data['collegeId'] != null && data['collegeId'].toString().trim().isNotEmpty) {
                _collegeIdController.text = data['collegeId'].toString().trim();
              }
              if (_departmentController.text.trim().isEmpty && data['department'] != null && data['department'].toString().trim().isNotEmpty) {
                _departmentController.text = data['department'].toString().trim();
              }
              if (_courseController.text.trim().isEmpty && data['course'] != null && data['course'].toString().trim().isNotEmpty) {
                _courseController.text = data['course'].toString().trim();
              }
              if (_yearController.text.trim().isEmpty && data['year'] != null && data['year'].toString().trim().isNotEmpty) {
                _yearController.text = data['year'].toString().trim();
              }
              if (_semesterController.text.trim().isEmpty && data['semester'] != null && data['semester'].toString().trim().isNotEmpty) {
                _semesterController.text = data['semester'].toString().trim();
              }
            });
          }
        } catch (_) {}
      }
    });
  }

  void _populateFieldsFromUser(UserEntity user) {
    if (_mobileController.text.trim().isEmpty && user.mobile != null && user.mobile!.trim().isNotEmpty) {
      _mobileController.text = user.mobile!.trim();
    }
    if (_prnController.text.trim().isEmpty && user.prn != null && user.prn!.trim().isNotEmpty) {
      _prnController.text = user.prn!.trim();
    }
    if (_collegeIdController.text.trim().isEmpty && user.collegeId != null && user.collegeId!.trim().isNotEmpty) {
      _collegeIdController.text = user.collegeId!.trim();
    }
    if (_departmentController.text.trim().isEmpty && user.department != null && user.department!.trim().isNotEmpty) {
      _departmentController.text = user.department!.trim();
    }
    if (_courseController.text.trim().isEmpty && user.course != null && user.course!.trim().isNotEmpty) {
      _courseController.text = user.course!.trim();
    }
    if (_yearController.text.trim().isEmpty && user.year != null && user.year!.trim().isNotEmpty) {
      _yearController.text = user.year!.trim();
    }
    if (_semesterController.text.trim().isEmpty && user.semester != null && user.semester!.trim().isNotEmpty) {
      _semesterController.text = user.semester!.trim();
    }
  }

  // ── Helper: Extract boarding stops (supports source + stops array) ──
  List<String> _getBoardingStops(Map<String, dynamic> data) {
    final stopsList = <String>[];

    final source = (data['source'] as String?)?.trim();
    if (source != null && source.isNotEmpty) {
      stopsList.add(source);
    }

    final stops = data['stops'];
    if (stops is List) {
      for (final s in stops) {
        final stopStr = s?.toString().trim();
        if (stopStr != null && stopStr.isNotEmpty && !stopsList.contains(stopStr)) {
          stopsList.add(stopStr);
        }
      }
    }

    final legacyStops = data['boardingStops'];
    if (legacyStops is List) {
      for (final s in legacyStops) {
        final stopStr = s?.toString().trim();
        if (stopStr != null && stopStr.isNotEmpty && !stopsList.contains(stopStr)) {
          stopsList.add(stopStr);
        }
      }
    }

    return stopsList;
  }

  String _getDestinationStop(Map<String, dynamic> data) {
    final dest = (data['destination'] as String?)?.trim();
    if (dest != null && dest.isNotEmpty) return dest;
    final destStops = data['destinationStops'];
    if (destStops is List && destStops.isNotEmpty) {
      final s = destStops.first?.toString().trim();
      if (s != null && s.isNotEmpty) return s;
    }
    return 'ICEM Campus';
  }

  double? _getRouteFare(Map<String, dynamic>? data) {
    if (data == null) return null;
    final fareRaw = data['fare'];
    if (fareRaw is num) return fareRaw.toDouble();
    if (fareRaw != null) {
      return double.tryParse(fareRaw.toString());
    }
    return null;
  }

  void _onProceedToReview() {
    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to apply for a bus pass.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all required student profile fields.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedRouteDoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an active bus route.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedBoardingStop == null || _selectedBoardingStop!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your boarding stop.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final data = _selectedRouteDoc!.data()!;
    final fare = _getRouteFare(data);
    if (fare == null || fare <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected route has no valid fare configured. Cannot proceed.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _selectedDestinationStop = _getDestinationStop(data);
      _currentStep = 3;
    });
  }

  Future<void> _onContinueToPayment() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User session expired. Please re-login.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedRouteDoc == null || _selectedBoardingStop == null) {
      setState(() => _currentStep = 1);
      return;
    }

    final routeData = _selectedRouteDoc!.data()!;
    final routeName = routeData['routeName'] as String? ?? 'Bus Route';
    final routeId = _selectedRouteDoc!.id;
    final boardingStop = _selectedBoardingStop!;
    final destinationStop = _selectedDestinationStop ?? _getDestinationStop(routeData);
    final fare = _getRouteFare(routeData) ?? 0.0;
    final distKm = routeData['distanceKm'];
    final distOld = routeData['distance'] as String?;
    final distanceStr = distKm is num
        ? '${distKm.toStringAsFixed(1)} km'
        : (distOld ?? '');

    setState(() => _isSubmitting = true);

    try {
      // 1. Submit application with initial status: 'Pending'
      await ref.read(busPassRepositoryProvider).applyForBusPass(
        uid: user.uid,
        route: routeName,
        routeId: routeId,
        boardingStop: boardingStop,
        destinationStop: destinationStop,
        fare: fare,
        distance: distanceStr.isNotEmpty ? distanceStr : null,
        department: _departmentController.text.trim(),
      );

      // 2. Persist updated student profile in Firestore 'users' collection
      final Map<String, dynamic> userUpdates = {
        'mobile': _mobileController.text.trim(),
        'department': _departmentController.text.trim(),
        'course': _courseController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (_prnController.text.trim().isNotEmpty) {
        userUpdates['prn'] = _prnController.text.trim();
      }
      if (_collegeIdController.text.trim().isNotEmpty) {
        userUpdates['collegeId'] = _collegeIdController.text.trim();
      }
      if (_yearController.text.trim().isNotEmpty) {
        userUpdates['year'] = _yearController.text.trim();
      }
      if (_semesterController.text.trim().isNotEmpty) {
        userUpdates['semester'] = _semesterController.text.trim();
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(userUpdates);

      // 3. Sync local auth and pass providers
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

  // ── Helper: Review item row ──
  Widget _buildReviewRow(
    String label,
    String value,
    IconData icon, {
    bool isBoldValue = false,
    bool highlightValue = false,
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: statusColor ?? AppColors.primaryCrimson),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: highlightValue ? 15 : 13,
                fontWeight: isBoldValue || highlightValue ? FontWeight.bold : FontWeight.w600,
                color: statusColor ??
                    (highlightValue ? AppColors.primaryCrimson : AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step Progress Indicator (Section 9) ──
  Widget _buildStepIndicator() {
    final stepLabels = ['01 Student', '02 Route', '03 Boarding', '04 Review'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'APPLY FOR BUS PASS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.primaryCrimson,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  'Step ${_currentStep + 1} of 4',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Thin crimson progress indicator (Section 9)
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 4.0,
              minHeight: 4,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryCrimson),
            ),
          ),
          const SizedBox(height: 12),
          // Step names row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(stepLabels.length, (idx) {
              final isActive = _currentStep == idx;
              final isDone = _currentStep > idx;
              return Text(
                stepLabels[idx],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive
                      ? AppColors.primaryCrimson
                      : (isDone ? AppColors.textPrimary : AppColors.textMuted),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Student Information ──
  Widget _buildStep1StudentInfo(ThemeData theme, UserEntity? user) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumCard(
            borderRadius: 22,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_rounded, size: 20, color: AppColors.primaryCrimson),
                    SizedBox(width: 8),
                    Text(
                      'Personal Information',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Full Name',
                  initialValue: user?.fullName ?? '',
                  readOnly: true,
                  prefixIcon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Email Address',
                  initialValue: user?.email ?? '',
                  readOnly: true,
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Mobile Number',
                  hint: '10-digit mobile number',
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_iphone_rounded,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Mobile number is required.';
                    if (val.trim().length < 10) return 'Enter a valid 10-digit mobile number.';
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PremiumCard(
            borderRadius: 22,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.school_rounded, size: 20, color: AppColors.primaryCrimson),
                    SizedBox(width: 8),
                    Text(
                      'Academic Details',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'PRN Number',
                  hint: 'Permanent Registration Number',
                  controller: _prnController,
                  prefixIcon: Icons.badge_outlined,
                  validator: (val) {
                    if ((val == null || val.trim().isEmpty) && _collegeIdController.text.trim().isEmpty) {
                      return 'PRN Number or College ID is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'College ID Card Number (Optional)',
                  hint: 'Badge / ID number',
                  controller: _collegeIdController,
                  prefixIcon: Icons.card_membership_rounded,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Department',
                  hint: 'e.g. Computer Engineering, IT',
                  controller: _departmentController,
                  prefixIcon: Icons.business_rounded,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Department is required.' : null,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Course',
                  hint: 'e.g. B.Tech, MCA, MBA',
                  controller: _courseController,
                  prefixIcon: Icons.menu_book_rounded,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Course is required.' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Year',
                        hint: 'e.g. FE, SE, TE, BE',
                        controller: _yearController,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: 'Semester',
                        hint: 'e.g. Sem 1, Sem 4',
                        controller: _semesterController,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            text: 'Next: Select Route',
            icon: Icons.arrow_forward_rounded,
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                setState(() => _currentStep = 1);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please complete all required fields.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Step 2: Route Selection (Section 10) ──
  Widget _buildStep2SelectRoute(ThemeData theme, AsyncValue<List<DocumentSnapshot<Map<String, dynamic>>>> routesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Your Bus Route',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose the official transit route between your area and ICEM campus.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        routesAsync.when(
          loading: () => const Column(
            children: [
              LoadingSkeleton.card(height: 140, borderRadius: 22),
              SizedBox(height: 14),
              LoadingSkeleton.card(height: 140, borderRadius: 22),
            ],
          ),
          error: (err, _) => Center(
            child: Text('Error loading routes: $err', style: const TextStyle(color: AppColors.error)),
          ),
          data: (routes) {
            if (routes.isEmpty) {
              return const EmptyState(
                icon: Icons.alt_route_rounded,
                title: 'No Routes Available',
                description: 'Active bus routes will appear here once published by the transport department.',
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: routes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final doc = routes[index];
                final data = doc.data() ?? {};
                final isSelected = _selectedRouteDoc?.id == doc.id;
                final routeName = data['routeName'] as String? ?? 'Route ${index + 1}';
                final routeNumber = data['routeNumber'] as String? ?? '';
                final source = data['source'] as String? ?? 'Origin';
                final destination = data['destination'] as String? ?? 'ICEM Campus';
                final fare = _getRouteFare(data) ?? 4500.0;
                final stops = _getBoardingStops(data);

                return PremiumCard(
                  borderRadius: 22,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedRouteDoc = doc;
                      _selectedBoardingStop = null;
                      _selectedDestinationStop = null;
                    });
                  },
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Route Name & Badge / Check Icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primaryCrimson : AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primaryCrimson : AppColors.borderSubtle,
                                    ),
                                  ),
                                  child: Text(
                                    routeNumber.isNotEmpty ? routeNumber : 'R-${index + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? Colors.white : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    routeName.toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryCrimson,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 14),
                            )
                          else
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.borderSubtle, width: 2),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Starting Point & Destination
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
                          Text(source, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          const Icon(Icons.location_on_rounded, size: 14, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(destination, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                        ],
                      ),

                      // Stops Preview (Section 10)
                      if (stops.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: stops.take(4).map((s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                            ),
                          )).toList(),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.borderSubtle),
                      const SizedBox(height: 12),

                      // Fare and Stops count
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${stops.length} boarding stops available',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryCrimson.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primaryCrimson.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '₹${fare.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primaryCrimson),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: SecondaryButton(
                text: 'Back',
                icon: Icons.arrow_back_rounded,
                onPressed: () => setState(() => _currentStep = 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                text: 'Next: Boarding Stop',
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  if (_selectedRouteDoc == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please tap to select a route.'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  setState(() => _currentStep = 2);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Step 3: Boarding Stop Timeline Selection (Section 11) ──
  Widget _buildStep3BoardingStop(ThemeData theme) {
    if (_selectedRouteDoc == null) {
      return Center(
        child: Column(
          children: [
            const Text('Please select a route first.', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            PrimaryButton(text: 'Go to Route Selection', onPressed: () => setState(() => _currentStep = 1)),
          ],
        ),
      );
    }

    final routeData = _selectedRouteDoc!.data()!;
    final routeName = routeData['routeName'] as String? ?? 'Selected Route';
    final stops = _getBoardingStops(routeData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumCard(
          borderRadius: 20,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryCrimson.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_bus_rounded, color: AppColors.primaryCrimson, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SELECTED ROUTE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(routeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _currentStep = 1),
                child: const Text('Change', style: TextStyle(color: AppColors.primaryCrimson, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Select Boarding Stop',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose the specific pickup point where you will board the bus every day.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        if (stops.isEmpty)
          const EmptyState(
            icon: Icons.location_off_rounded,
            title: 'No Stops Found',
            description: 'No boarding stops configured for this route. Please contact administration.',
          )
        else
          // Vertical Route Timeline (Section 11)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stops.length,
            itemBuilder: (context, index) {
              final stop = stops[index];
              final isSelected = _selectedBoardingStop == stop;
              final isLast = index == stops.length - 1;

              return GestureDetector(
                onTap: () => setState(() => _selectedBoardingStop = stop),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline indicator column
                    Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? AppColors.primaryCrimson : AppColors.surfaceElevated,
                            border: Border.all(
                              color: isSelected ? AppColors.primaryCrimson : AppColors.borderSubtle,
                              width: isSelected ? 3 : 2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primaryCrimson.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(Icons.check, size: 9, color: Colors.white),
                                )
                              : null,
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 44,
                            color: isSelected
                                ? AppColors.primaryCrimson.withValues(alpha: 0.6)
                                : AppColors.borderSubtle,
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Stop card
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: PremiumCard(
                          borderRadius: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          isSelected: isSelected,
                          onTap: () => setState(() => _selectedBoardingStop = stop),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  stop,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? AppColors.primaryCrimson : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryCrimson.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'SELECTED',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryCrimson),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: SecondaryButton(
                text: 'Back',
                icon: Icons.arrow_back_rounded,
                onPressed: () => setState(() => _currentStep = 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                text: 'Next: Review',
                icon: Icons.arrow_forward_rounded,
                onPressed: _onProceedToReview,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Step 4: Review Screen (Section 12) ──
  Widget _buildStep4Review(ThemeData theme, UserEntity? user) {
    final routeData = _selectedRouteDoc?.data() ?? {};
    final routeName = routeData['routeName'] as String? ?? 'Route';
    final routeNumber = routeData['routeNumber'] as String? ?? '';
    final source = routeData['source'] as String? ?? '';
    final destStop = _selectedDestinationStop ?? _getDestinationStop(routeData);
    final fare = _getRouteFare(routeData) ?? 4500.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review Application',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Please verify your transportation details before continuing to payment.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),

        // Premium summary card (Section 12)
        PremiumCard(
          borderRadius: 24,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // STUDENT SECTION
              const Text('STUDENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryCrimson, letterSpacing: 0.8)),
              const SizedBox(height: 10),
              _buildReviewRow('Full Name', user?.fullName ?? 'Student', Icons.person_outline_rounded),
              _buildReviewRow('Mobile Number', _mobileController.text.trim(), Icons.phone_iphone_rounded),
              if (_prnController.text.trim().isNotEmpty)
                _buildReviewRow('Student ID / PRN', _prnController.text.trim(), Icons.badge_outlined),
              _buildReviewRow('Department', _departmentController.text.trim(), Icons.business_rounded),
              _buildReviewRow('Course', _courseController.text.trim(), Icons.school_outlined),

              const Divider(height: 28, color: AppColors.borderSubtle),

              // ROUTE SECTION
              const Text('ROUTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryCrimson, letterSpacing: 0.8)),
              const SizedBox(height: 10),
              _buildReviewRow('Route', routeNumber.isNotEmpty ? '$routeNumber – $routeName' : routeName, Icons.directions_bus_rounded, isBoldValue: true),
              if (source.isNotEmpty)
                _buildReviewRow('Starting Point', source, Icons.trip_origin_rounded),
              _buildReviewRow('Boarding Stop', _selectedBoardingStop ?? 'Selected Stop', Icons.location_on_rounded, highlightValue: true),
              _buildReviewRow('Destination', destStop, Icons.flag_rounded),
              _buildReviewRow('Validity', '6 Months (One Semester)', Icons.event_available_rounded),

              const Divider(height: 28, color: AppColors.borderSubtle),

              // PAYMENT SECTION (Section 12)
              const Text('PAYMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryCrimson, letterSpacing: 0.8)),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bus Pass Fee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        SizedBox(height: 3),
                        Text('One Semester Transport', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    Text(
                      '₹${fare.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryCrimson,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Action Buttons: Edit and Continue to Payment
        Row(
          children: [
            Expanded(
              flex: 1,
              child: SecondaryButton(
                text: 'Edit',
                icon: Icons.edit_rounded,
                onPressed: () => setState(() => _currentStep = 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                text: 'CONTINUE TO PAYMENT',
                icon: Icons.payment_rounded,
                isLoading: _isSubmitting,
                onPressed: _onContinueToPayment,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;
    final routesAsync = ref.watch(busRoutesStreamProvider);

    final String appBarTitle;
    switch (_currentStep) {
      case 0:
        appBarTitle = 'Step 1: Student Information';
        break;
      case 1:
        appBarTitle = 'Step 2: Select Route';
        break;
      case 2:
        appBarTitle = 'Step 3: Boarding Stop';
        break;
      case 3:
      default:
        appBarTitle = 'Step 4: Review Application';
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderSubtle, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepIndicator(),
              if (_currentStep == 0)
                _buildStep1StudentInfo(theme, user)
              else if (_currentStep == 1)
                _buildStep2SelectRoute(theme, routesAsync)
              else if (_currentStep == 2)
                _buildStep3BoardingStop(theme)
              else
                _buildStep4Review(theme, user),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// RENEW BUS PASS SCREEN (Luxury Dark)
// ==========================================
class RenewPassScreen extends ConsumerWidget {
  const RenewPassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final busPassState = ref.watch(busPassControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Renew Bus Pass', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary)),
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderSubtle, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(22.0),
          child: busPassState.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryCrimson)),
            error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
            data: (pass) {
              if (pass == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: EmptyState(
                      icon: Icons.card_membership_rounded,
                      title: 'No Active Pass Found',
                      description: 'No existing bus pass record was found to renew.',
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumCard(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.autorenew_rounded, color: AppColors.primaryCrimson, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'Pass Renewal Details',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _infoRow('Pass ID', pass.passId, theme),
                        const Divider(height: 24, color: AppColors.borderSubtle),
                        _infoRow('Selected Route', pass.route, theme),
                        const Divider(height: 24, color: AppColors.borderSubtle),
                        _infoRow('Pass Expiry', pass.expiryDate.toString().substring(0, 10), theme),
                        const Divider(height: 24, color: AppColors.borderSubtle),
                        _infoRow('Payment Status', pass.paymentStatus, theme, color: AppColors.primaryCrimson),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  PrimaryButton(
                    text: 'Proceed to Payment',
                    icon: Icons.payment_rounded,
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textMuted)),
        Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: color ?? AppColors.textPrimary)),
      ],
    );
  }
}

// ==========================================
// DIGITAL BUS PASS SCREEN (Section 14: Luxury Mobility Card)
// ==========================================
class DigitalPassScreen extends ConsumerWidget {
  const DigitalPassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(authControllerProvider);
    final busPassState = ref.watch(busPassControllerProvider);
    final user = userState.user;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text(
          'ICEM Digital Bus Pass',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => context.go(AppRoutes.studentDashboard),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderSubtle, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
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
              final isRevoked = pass != null && pass.isRevoked;
              final isExpired = pass != null && pass.isExpired;
              final isRejected = pass != null && pass.status.trim().toLowerCase() == 'rejected';
              final isPaid = pass != null && pass.isPaid;
              final isApproved = pass != null && pass.isApproved;
              final isActive = pass != null && pass.isActive;

              // If pass is not active, display appropriate luxury status screen
              if (pass == null || !isActive) {
                String heading = "You do not have an active digital bus pass.";
                String subtext = "Please complete application and payment to activate pass.";
                String btnText = "Apply for Bus Pass";
                IconData statusIcon = Icons.badge_outlined;
                Color statusColor = AppColors.textMuted;
                VoidCallback btnAction = () => context.push(AppRoutes.studentApply);

                if (isRevoked) {
                  heading = "Pass Revoked";
                  subtext = "Your college bus pass has been revoked by the administration. Please contact the ICEM transport office for inquiries.";
                  statusIcon = Icons.block_rounded;
                  statusColor = AppColors.error;
                  btnText = "View Pass History";
                  btnAction = () => context.push('/student/pass-history');
                } else if (isExpired) {
                  heading = "Pass Expired";
                  subtext = "Your bus pass validity has expired. Please renew your pass to resume college bus transport services.";
                  statusIcon = Icons.warning_amber_rounded;
                  statusColor = AppColors.warning;
                  btnText = "Renew Bus Pass";
                  btnAction = () => context.push(AppRoutes.studentRenew);
                } else if (isRejected) {
                  heading = "Application Rejected";
                  subtext = "Your bus pass application was rejected by ICEM administration. You may review the details and re-apply.";
                  statusIcon = Icons.cancel_rounded;
                  statusColor = AppColors.error;
                  btnText = "Re-apply for Bus Pass";
                  btnAction = () => context.push(AppRoutes.studentApply);
                } else if (isPaid && !isApproved) {
                  heading = "Paid — Waiting for Admin Approval";
                  subtext = "Your payment has been verified. Your active digital pass and QR code will activate as soon as the college administration approves your application.";
                  statusIcon = Icons.hourglass_top_rounded;
                  statusColor = AppColors.info;
                  btnText = "Return to Dashboard";
                  btnAction = () => context.go(AppRoutes.studentDashboard);
                } else if (!isPaid && pass != null) {
                  heading = "Payment Pending";
                  subtext = "Your application has been received, but payment has not been completed. Please complete payment to submit for approval.";
                  statusIcon = Icons.payment_rounded;
                  statusColor = AppColors.warning;
                  btnText = "Complete Payment";
                  btnAction = () => context.push(AppRoutes.studentPayment);
                }

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
                    child: PremiumCard(
                      borderRadius: 26,
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Icon(statusIcon, size: 54, color: statusColor),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            heading,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: statusColor == AppColors.textMuted
                                  ? AppColors.textPrimary
                                  : statusColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            subtext,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          PrimaryButton(
                            text: btnText,
                            onPressed: btnAction,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // SECTION 14: ACTIVE PASS DISPLAY (Luxury Dark Membership Card)
              final String name = user?.fullName ?? 'Student';
              final String prn = user?.prn ?? user?.collegeId ?? 'N/A';
              final String course = pass.course ?? user?.course ?? pass.department ?? user?.department ?? 'Engineering';
              final String academicYear = pass.year ?? user?.year ?? '2025-2026';
              final String photoUrl = user?.photoUrl ?? '';
              final String passNum = pass.effectivePassNumber;
              final String appId = pass.applicationId ?? pass.passId;

              final String validFromStr = pass.validFrom != null
                  ? '${pass.validFrom!.day.toString().padLeft(2, '0')}/${pass.validFrom!.month.toString().padLeft(2, '0')}/${pass.validFrom!.year}'
                  : 'N/A';
              final String validUntilStr =
                  '${pass.effectiveValidUntil.day.toString().padLeft(2, '0')}/${pass.effectiveValidUntil.month.toString().padLeft(2, '0')}/${pass.effectiveValidUntil.year}';

              return Column(
                children: [
                  // Luxury Digital Pass Card Container
                  PremiumCard(
                    borderRadius: 26,
                    isSelected: true,
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card Header: College Brand & Title (Section 14: ICEM, BUS PASS)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.darkCrimson, AppColors.primaryCrimson],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(25),
                              topRight: Radius.circular(25),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.directions_bus_rounded,
                                      color: AppColors.primaryCrimson,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'ICEM',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        Text(
                                          'Indira College of Engineering and Management',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 10.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: const Center(
                                  child: Text(
                                    'BUS PASS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2.5,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Card Body: Details & Photo
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Photo & Student Details Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Student Photo with Crimson ring
                                  Container(
                                    width: 84,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppColors.primaryCrimson, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryCrimson.withValues(alpha: 0.2),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: photoUrl.isNotEmpty && photoUrl.startsWith('http')
                                          ? Image.network(
                                              photoUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(Icons.person, color: AppColors.textMuted, size: 48),
                                            )
                                          : const Icon(Icons.person, color: AppColors.textMuted, size: 48),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Student Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        _infoChip('Student ID', prn),
                                        const SizedBox(height: 3),
                                        _infoChip('Course', course),
                                        const SizedBox(height: 3),
                                        _infoChip('Academic Year', academicYear),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              const Divider(color: AppColors.borderSubtle, height: 1),
                              const SizedBox(height: 14),

                              // Pass Number & Application ID
                              Row(
                                children: [
                                  Expanded(
                                    child: _metaBlock('PASS NUMBER', passNum, isCrimson: true),
                                  ),
                                  Container(width: 1, height: 32, color: AppColors.borderSubtle),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: _metaBlock('APPLICATION ID', appId),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Divider(color: AppColors.borderSubtle, height: 1),
                              const SizedBox(height: 14),

                              // Route & Boarding Stop
                              Row(
                                children: [
                                  Expanded(
                                    child: _metaBlock('ROUTE', pass.effectiveRouteName),
                                  ),
                                  Container(width: 1, height: 32, color: AppColors.borderSubtle),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: _metaBlock('BOARDING STOP', pass.boardingStop, isCrimson: true),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Divider(color: AppColors.borderSubtle, height: 1),
                              const SizedBox(height: 14),

                              // Valid From & Valid Until
                              Row(
                                children: [
                                  Expanded(
                                    child: _metaBlock('VALID FROM', validFromStr),
                                  ),
                                  Container(width: 1, height: 32, color: AppColors.borderSubtle),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: _metaBlock('VALID UNTIL', validUntilStr, isBold: true),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // 3 Status Badges: Payment, Approval, Pass Status (Section 14: ACTIVE)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _statusPill('Payment', 'PAID ✓', AppColors.success),
                                  _statusPill('Approval', 'APPROVED ✓', AppColors.success),
                                  _statusPill('Status', 'ACTIVE', AppColors.primaryCrimson, isSolid: true),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Large Readable QR Code with Crimson Accents (Section 14)
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppColors.primaryCrimson.withValues(alpha: 0.4), width: 1.8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryCrimson.withValues(alpha: 0.18),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: QrImageView(
                                        data: jsonEncode({
                                          'type': 'ICEM_BUS_PASS',
                                          'passNumber': passNum,
                                          'passId': pass.passId,
                                          'studentId': pass.uid,
                                        }),
                                        version: QrVersions.auto,
                                        size: 180,
                                        gapless: false,
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
                                    const SizedBox(height: 10),
                                    const Text(
                                      'SCAN TO VERIFY AUTHORIZATION',
                                      style: TextStyle(
                                        color: AppColors.primaryCrimson,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Card Footer: Security & Hologram bar
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(25),
                              bottomRight: Radius.circular(25),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.verified_user_rounded, size: 14, color: AppColors.success),
                                  SizedBox(width: 5),
                                  Text(
                                    'OFFICIALLY ISSUED BY ICEM',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'NON-TRANSFERABLE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _metaBlock(String label, String value, {bool isCrimson = false, bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold || isCrimson ? FontWeight.bold : FontWeight.w600,
            color: isCrimson ? AppColors.primaryCrimson : AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _statusPill(String header, String label, Color color, {bool isSolid = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header.toUpperCase(),
          style: const TextStyle(fontSize: 8.5, color: AppColors.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSolid ? color : color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isSolid ? Colors.white : color,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// PAYMENT HISTORY SCREEN (Luxury Dark)
// ==========================================
class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(child: Text('Please log in to view history.', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Payment History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary)),
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => context.go(AppRoutes.studentDashboard),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderSubtle, height: 1),
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
              return const Center(child: CircularProgressIndicator(color: AppColors.primaryCrimson));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading history: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
            }
            
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No Transaction Receipts',
                    description: 'Receipts will appear here after a successful pass payment.',
                  ),
                ),
              );
            }

            return ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
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

                return PremiumCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(16),
                  onTap: () => _showReceiptDetailsDialog(context, data, dateString),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(leadingIcon, color: statusColor, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              route,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text('Receipt: $receiptId', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            Text('Date: $dateString', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: status == 'Failed' ? AppColors.error : AppColors.primaryCrimson,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
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
          backgroundColor: AppColors.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('E-Receipt Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary)),
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
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
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      const Text('TOTAL PAID AMOUNT', style: TextStyle(fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '₹${amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primaryCrimson),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _receiptDetailRow('Receipt ID', receiptId),
                const Divider(height: 16, color: AppColors.borderSubtle),
                _receiptDetailRow('Transaction ID', transactionId),
                const Divider(height: 16, color: AppColors.borderSubtle),
                _receiptDetailRow('Route Name', route),
                const Divider(height: 16, color: AppColors.borderSubtle),
                _receiptDetailRow('Boarding Stop', boarding),
                const Divider(height: 16, color: AppColors.borderSubtle),
                _receiptDetailRow('Destination Stop', destination),
                const Divider(height: 16, color: AppColors.borderSubtle),
                _receiptDetailRow('Payment Date', dateString),
                const Divider(height: 16, color: AppColors.borderSubtle),
                _receiptDetailRow('Payment Method', paymentMethod),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
              label: const Text('Download TXT', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryCrimson,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        Flexible(
          child: Text(
            val,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}


