// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/config/theme/app_colors.dart';

// ============================================================
// STAT CARD — Dark Mobility Metric Card
// ============================================================

class AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  final dynamic icon;
  final Color color;
  final bool isLoading;
  final String? subtitle;

  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isLoading = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.25), width: 1),
                ),
                child: Center(
                  child: icon is Widget
                      ? (icon as Widget)
                      : Icon(icon as IconData, color: color, size: 18),
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const _ShimmerBox(width: 48, height: 24, borderRadius: 6)
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
            ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.7,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ACTION CARD — Premium layered action card with description & arrow
// ============================================================

class AdminActionCard extends StatefulWidget {
  final String title;
  final String description;
  final dynamic icon;
  final Color color;
  final VoidCallback onTap;

  const AdminActionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<AdminActionCard> createState() => _AdminActionCardState();
}

class _AdminActionCardState extends State<AdminActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _pressed ? widget.color.withOpacity(0.5) : AppColors.borderSubtle,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.color.withOpacity(0.25), width: 1),
                    ),
                    child: Center(
                      child: widget.icon is Widget
                          ? (widget.icon as Widget)
                          : Icon(widget.icon as IconData, color: widget.color, size: 20),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: AppColors.textMuted.withOpacity(0.5),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.description,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Quick action alias for compatibility
class AdminQuickAction extends StatelessWidget {
  final String label;
  final dynamic icon;
  final Color color;
  final VoidCallback onTap;

  const AdminQuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AdminActionCard(
      title: label.replaceAll('\n', ' '),
      description: 'Manage & update',
      icon: icon,
      color: color,
      onTap: onTap,
    );
  }
}

// ============================================================
// STATUS BADGE — Unified dark status badge
// ============================================================

class AdminStatusBadge extends StatelessWidget {
  final String status;

  const AdminStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label = status.toUpperCase();

    final s = status.trim().toUpperCase();

    if (s == 'ACTIVE' || s == 'APPROVED' || s == 'PAID' || s == 'PAYMENT VERIFIED' || s == 'SUCCESS') {
      color = AppColors.success;
      icon = Icons.check_circle_rounded;
      if (s == 'PAID' || s == 'PAYMENT VERIFIED' || s == 'SUCCESS') {
        label = 'PAID';
      } else if (s == 'APPROVED') {
        label = 'APPROVED';
      } else {
        label = 'ACTIVE';
      }
    } else if (s == 'REJECTED' || s == 'FAILED' || s == 'REVOKED' || s == 'INACTIVE' || s == 'SUSPENDED') {
      color = AppColors.error;
      icon = Icons.cancel_rounded;
      if (s == 'REJECTED') {
        label = 'REJECTED';
      } else if (s == 'REVOKED') {
        label = 'REVOKED';
      } else if (s == 'FAILED') {
        label = 'FAILED';
      } else {
        label = 'INACTIVE';
      }
    } else if (s == 'MAINTENANCE') {
      color = const Color(0xFFA855F7); // Purple
      icon = Icons.build_circle_rounded;
      label = 'MAINTENANCE';
    } else if (s == 'EXPIRED') {
      color = const Color(0xFF94A3B8); // Slate
      icon = Icons.history_toggle_off_rounded;
      label = 'EXPIRED';
    } else if (s == 'REFUNDED') {
      color = const Color(0xFF06B6D4); // Cyan
      icon = Icons.replay_rounded;
      label = 'REFUNDED';
    } else {
      // Pending variants
      color = AppColors.warning;
      icon = Icons.schedule_rounded;
      if (s == 'PAYMENT PENDING' || s == 'PENDING PAYMENT') {
        label = 'PAYMENT PENDING';
      } else if (s == 'PENDING APPROVAL') {
        label = 'PENDING APPROVAL';
      } else {
        label = 'PENDING';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// APPLICATION CARD — Used in Recent Applications & Applications Tab
// ============================================================

class AdminApplicationCard extends StatelessWidget {
  final Map<String, dynamic> application;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRequestCorrection;
  final VoidCallback? onViewDetails;

  const AdminApplicationCard({
    super.key,
    required this.application,
    this.onApprove,
    this.onReject,
    this.onRequestCorrection,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final name = application['studentName'] ?? application['fullName'] ?? 'Unknown';
    final prn = application['prn'] ?? '-';
    final collegeId = application['collegeId'] ?? '-';
    final course = application['course'] ?? '-';
    final route = application['routeName'] ?? application['route'] ?? '-';
    final boardingStop = application['boardingStop'] ?? '-';
    final destinationStop = application['destinationStop'] ?? '-';
    final fare = application['fare'];
    final photoUrl = application['photoUrl'] as String?;
    final createdAt = application['createdAt'];

    final String paymentStatusStr = (application['paymentStatus'] as String? ?? 'Pending').trim();
    final bool isPaid = paymentStatusStr.toLowerCase() == 'paid' || paymentStatusStr.toLowerCase() == 'success';
    final String rawStatus = (application['passStatus'] ?? application['status'] ?? 'Pending').toString();

    // Normalized display statuses
    String displayStatus;
    if (rawStatus == 'Approved' || rawStatus == 'Active') {
      displayStatus = 'Approved';
    } else if (rawStatus == 'Rejected') {
      displayStatus = 'Rejected';
    } else if (isPaid) {
      displayStatus = 'Pending Approval';
    } else {
      displayStatus = 'Pending Payment';
    }

    String dateStr = '-';
    if (createdAt != null) {
      DateTime? dt;
      if (createdAt is Timestamp) {
        dt = createdAt.toDate();
      } else if (createdAt is DateTime) {
        dt = createdAt;
      }
      if (dt != null) {
        dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
    }

    String fareStr = '-';
    if (fare != null) {
      fareStr = '₹${(fare is num) ? fare.toStringAsFixed(0) : fare.toString()}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Student avatar + name + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(photoUrl, name.toString()),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'PRN: $prn • ID: $collegeId',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AdminStatusBadge(status: displayStatus),
            ],
          ),
          const SizedBox(height: 14),

          // Payment Status Banner Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isPaid
                  ? AppColors.success.withOpacity(0.12)
                  : AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isPaid
                    ? AppColors.success.withOpacity(0.28)
                    : AppColors.warning.withOpacity(0.28),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPaid ? Icons.verified_rounded : Icons.pending_actions_rounded,
                  size: 14,
                  color: isPaid ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  isPaid ? 'PAYMENT VERIFIED' : 'PAYMENT PENDING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isPaid ? AppColors.success : AppColors.warning,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Info Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(icon: Icons.school_rounded, label: course.toString()),
              _InfoChip(icon: Icons.route_rounded, label: route.toString()),
              _InfoChip(
                icon: Icons.location_on_rounded,
                label: '$boardingStop → $destinationStop',
              ),
              _InfoChip(
                icon: Icons.currency_rupee_rounded,
                label: fareStr,
              ),
              _InfoChip(
                icon: Icons.calendar_today_rounded,
                label: dateStr,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'View Details',
                  color: AppColors.info,
                  icon: Icons.visibility_rounded,
                  onTap: onViewDetails,
                ),
              ),
              if (displayStatus != 'Approved' && displayStatus != 'Rejected') ...[
                if (isPaid) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      label: 'Approve',
                      color: AppColors.success,
                      icon: Icons.check_circle_rounded,
                      onTap: onApprove,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Reject',
                    color: AppColors.error,
                    icon: Icons.cancel_rounded,
                    onTap: onReject,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String name) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          photoUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialAvatar(name),
        ),
      );
    }
    return _buildInitialAvatar(name);
  }

  Widget _buildInitialAvatar(String name) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primaryCrimson.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryCrimson.withOpacity(0.3)),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.primaryCrimson,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SEARCH BAR — Dark input with subtle border
// ============================================================

class AdminSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final String value;

  const AdminSearchBar({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.value = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
      ),
      child: TextField(
        onChanged: onChanged,
        controller: TextEditingController(text: value)
          ..selection = TextSelection.collapsed(offset: value.length),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ============================================================
// FILTER CHIPS ROW — Horizontally scrollable dark pills
// ============================================================

class AdminFilterChips extends StatelessWidget {
  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelected;

  const AdminFilterChips({
    super.key,
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((filter) {
          final isActive = filter == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primaryCrimson.withOpacity(0.18)
                      : AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? AppColors.primaryCrimson
                        : AppColors.borderSubtle,
                    width: isActive ? 1.4 : 1.0,
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class AdminEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? customIcon;

  const AdminEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_rounded,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Center(
                child: customIcon ?? Icon(icon, size: 36, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ERROR STATE
// ============================================================

class AdminErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AdminErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.error),
            ),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCrimson,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  minimumSize: const Size(120, 44),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LOADING STATE
// ============================================================

class AdminLoadingState extends StatelessWidget {
  const AdminLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                color: AppColors.primaryCrimson,
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 18),
            Text(
              'Loading mobility data...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SECTION HEADER
// ============================================================

class AdminSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AdminSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryCrimson,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// APPLICATION DETAIL BOTTOM SHEET
// ============================================================

class ApplicationDetailSheet extends StatelessWidget {
  final Map<String, dynamic> application;

  const ApplicationDetailSheet({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1.5)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Application Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _DetailRow('Student Name', application['studentName'] ?? application['fullName'] ?? '-'),
                    _DetailRow('PRN', application['prn'] ?? '-'),
                    _DetailRow('Course', application['course'] ?? '-'),
                    _DetailRow('Department', application['department'] ?? '-'),
                    _DetailRow('Year', application['year'] ?? '-'),
                    _DetailRow('Route', application['routeName'] ?? application['route'] ?? '-'),
                    _DetailRow('Payment Status', application['paymentStatus'] ?? '-'),
                    _DetailRow('Pass Status', application['status'] ?? '-'),
                    _DetailRow('Email', application['email'] ?? '-'),
                    _DetailRow('Mobile', application['mobile'] ?? '-'),
                    _DetailRow('Address', application['address'] ?? '-'),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// PRIVATE HELPER WIDGETS
// ============================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.28)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final dynamic value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
