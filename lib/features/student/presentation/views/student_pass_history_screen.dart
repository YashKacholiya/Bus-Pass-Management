// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/shared/app_card.dart';
import 'package:icem_bus/shared/empty_state.dart';
import 'package:icem_bus/shared/loading_skeleton.dart';
import 'package:icem_bus/shared/status_badge.dart';

final studentPassHistoryStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .where('uid', isEqualTo: user.uid)
      .snapshots()
      .map((snapshot) {
    final list = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    // Sort descending by createdAt
    list.sort((a, b) {
      final aTime = a['createdAt'];
      final bTime = b['createdAt'];
      if (aTime is Timestamp && bTime is Timestamp) {
        return bTime.compareTo(aTime);
      }
      return 0;
    });

    return list;
  });
});

class StudentPassHistoryScreen extends ConsumerWidget {
  const StudentPassHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(studentPassHistoryStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Pass & Application History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SafeArea(
        child: historyAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              children: [
                LoadingSkeleton.card(height: 120, borderRadius: 16),
                SizedBox(height: 14),
                LoadingSkeleton.card(height: 120, borderRadius: 16),
                SizedBox(height: 14),
                LoadingSkeleton.card(height: 120, borderRadius: 16),
              ],
            ),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Error loading history: $err',
                  style: const TextStyle(color: AppColors.error)),
            ),
          ),
          data: (historyList) {
            if (historyList.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: EmptyState(
                  icon: Icons.history_edu_rounded,
                  title: 'No Applications Found',
                  description: "You haven't submitted any bus pass applications yet.",
                  actionText: 'Apply for Bus Pass',
                  onAction: () => context.push(AppRoutes.studentApply),
                ),
              );
            }

            return ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: historyList.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final app = historyList[index];
                return _buildHistoryCard(context, app);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> app) {
    final String appId = app['id'] ?? app['applicationId'] ?? 'N/A';
    final String? passNumber = app['passNumber'];
    final String route = app['routeName'] ?? app['route'] ?? 'Bus Route';
    final String boardingStop = app['boardingStop'] ?? 'Campus';

    final dynamic createdData = app['createdAt'];
    String dateString = 'Recent';
    if (createdData is Timestamp) {
      final dt = createdData.toDate();
      dateString =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }

    // Determine Statuses
    final paymentStatus = (app['paymentStatus'] as String? ?? 'Pending').trim();
    final isPaid = paymentStatus.toLowerCase() == 'paid' ||
        paymentStatus.toLowerCase() == 'success';

    final rawStatus = (app['passStatus'] as String? ??
            app['status'] as String? ??
            'Pending')
        .trim();
    final isApproved = rawStatus.toLowerCase() == 'approved' ||
        rawStatus.toLowerCase() == 'active';
    final isRejected = rawStatus.toLowerCase() == 'rejected';
    final isRevoked = rawStatus.toLowerCase() == 'revoked';

    // Validity check
    final dynamic vu = app['validUntil'] ?? app['expiryDate'];
    bool isExpired = false;
    if (vu is Timestamp) {
      isExpired = DateTime.now().isAfter(vu.toDate());
    }

    String displayPassStatus;
    if (isRevoked) {
      displayPassStatus = 'REJECTED';
    } else if (isExpired) {
      displayPassStatus = 'EXPIRED';
    } else if (isRejected) {
      displayPassStatus = 'REJECTED';
    } else if (isPaid && isApproved) {
      displayPassStatus = 'ACTIVE';
    } else if (isPaid && !isApproved) {
      displayPassStatus = 'PENDING';
    } else {
      displayPassStatus = 'UNPAID';
    }

    return PremiumCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(18),
      onTap: () {
        context.push('/student/pass-detail/$appId');
      },
      borderColor: displayPassStatus == 'ACTIVE'
          ? AppColors.primaryCrimson.withValues(alpha: 0.3)
          : AppColors.slate200,
      isSelected: displayPassStatus == 'ACTIVE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Pass Number & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_rounded,
                      size: 18, color: AppColors.primaryCrimson),
                  const SizedBox(width: 8),
                  Text(
                    passNumber != null && passNumber.isNotEmpty
                        ? passNumber
                        : appId,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.slate900,
                    ),
                  ),
                ],
              ),
              Text(
                dateString,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.slate400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Route & Stop
          Row(
            children: [
              const Icon(Icons.directions_bus_rounded,
                  size: 16, color: AppColors.slate500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  route,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.slate800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              'Boarding: $boardingStop',
              style: const TextStyle(fontSize: 12, color: AppColors.slate600),
            ),
          ),
          const SizedBox(height: 14),

          // Badges Row: Payment, Approval, Pass Status
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusBadge(
                status: isPaid ? 'PAID' : 'UNPAID',
                label: isPaid ? 'PAID ✓' : 'PAYMENT PENDING',
              ),
              StatusBadge(
                status: isApproved
                    ? 'ACTIVE'
                    : (isRejected ? 'REJECTED' : 'PENDING'),
                label: isApproved
                    ? 'APPROVED ✓'
                    : (isRejected ? 'REJECTED ✕' : 'IN REVIEW'),
              ),
              StatusBadge(
                status: displayPassStatus,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
