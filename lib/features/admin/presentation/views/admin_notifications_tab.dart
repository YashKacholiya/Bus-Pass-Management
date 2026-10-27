// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import 'package:icem_bus/features/notification/domain/notification_providers.dart';

/// Rebuild Admin Notification Management panel
class AdminNotificationsTab extends ConsumerStatefulWidget {
  const AdminNotificationsTab({super.key});

  @override
  ConsumerState<AdminNotificationsTab> createState() => _AdminNotificationsTabState();
}

class _AdminNotificationsTabState extends ConsumerState<AdminNotificationsTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notification Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Broadcast alerts, schedule reminders, and track announcement delivery.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── SEARCH AND FILTERS BAR ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Column(
                  children: [
                    AdminSearchBar(
                      hintText: 'Search by title or description...',
                      value: _searchQuery,
                      onChanged: (q) => setState(() => _searchQuery = q),
                    ),
                    const SizedBox(height: 10),
                    AdminFilterChips(
                      filters: const ['All', 'Sent', 'Scheduled', 'Failed'],
                      selected: _statusFilter,
                      onSelected: (val) => setState(() => _statusFilter = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── LIST OF NOTIFICATIONS ──
            Expanded(
              child: notificationsAsync.when(
                loading: () => const AdminLoadingState(),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        const Text(
                          'Failed to load notifications',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          err.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(notificationsStreamProvider),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryCrimson),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (list) {
                  var filtered = list;

                  // Apply filter chips
                  if (_statusFilter != 'All') {
                    filtered = filtered.where((n) => n['status'] == _statusFilter).toList();
                  }

                  // Apply search query
                  if (_searchQuery.trim().isNotEmpty) {
                    final q = _searchQuery.trim().toLowerCase();
                    filtered = filtered.where((n) {
                      final title = (n['title'] ?? '').toString().toLowerCase();
                      final msg = (n['message'] ?? '').toString().toLowerCase();
                      return title.contains(q) || msg.contains(q);
                    }).toList();
                  }

                  if (filtered.isEmpty) {
                    return const AdminEmptyState(
                      title: 'No alerts found',
                      subtitle: 'Try adjusting your filters or compose a new announcement.',
                      icon: Icons.notifications_off_outlined,
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _NotificationCard(
                        notification: item,
                        onTap: () => _showNotificationDetails(context, item),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposeSheet(context, null),
        backgroundColor: AppColors.primaryCrimson,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.add_alert_rounded, size: 20),
        label: const Text('Create Alert', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showNotificationDetails(BuildContext context, Map<String, dynamic> notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationDetailsSheet(
        notification: notification,
        onEdit: (item) {
          Navigator.pop(context);
          _openComposeSheet(context, item);
        },
        onDelete: (id) async {
          Navigator.pop(context);
          await _deleteConfirm(id);
        },
      ),
    );
  }

  void _openComposeSheet(BuildContext context, Map<String, dynamic>? initialNotification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComposeNotificationSheet(initialNotification: initialNotification),
    );
  }

  Future<void> _deleteConfirm(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Announcement?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Are you sure you want to permanently delete this scheduled notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(notificationRepositoryProvider).deleteNotification(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Scheduled notification deleted.'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}

// ============================================================
// NOTIFICATION CARD WIDGET
// ============================================================

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Bus Delay':
        return AppColors.warning;
      case 'Route Change':
        return Colors.purple;
      case 'Pass Approved':
        return AppColors.success;
      case 'Pass Rejected':
        return AppColors.error;
      case 'Payment Reminder':
        return Colors.indigo;
      case 'Pass Expiry Reminder':
        return Colors.amber.shade900;
      case 'General':
      default:
        return AppColors.info;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Bus Delay':
        return Icons.access_time_filled_rounded;
      case 'Route Change':
        return Icons.alt_route_rounded;
      case 'Pass Approved':
        return Icons.verified_rounded;
      case 'Pass Rejected':
        return Icons.gpp_bad_rounded;
      case 'Payment Reminder':
        return Icons.currency_rupee_rounded;
      case 'Pass Expiry Reminder':
        return Icons.running_with_errors_rounded;
      case 'General':
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String _formatDate(dynamic dateField) {
    if (dateField == null) return 'N/A';
    DateTime? dt;
    if (dateField is Timestamp) {
      dt = dateField.toDate();
    } else if (dateField is String) {
      dt = DateTime.tryParse(dateField);
    } else if (dateField is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(dateField);
    }
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final title = notification['title'] ?? 'Untitled';
    final message = notification['message'] ?? '';
    final type = notification['type'] ?? 'General';
    final status = notification['status'] ?? 'Sent';
    final targetName = notification['targetName'] ?? 'All Students';
    final scheduledAt = notification['scheduledAt'];

    final typeColor = _getTypeColor(type);
    final typeIcon = _getTypeIcon(type);

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Scheduled':
        statusColor = AppColors.info;
        statusIcon = Icons.schedule_rounded;
        break;
      case 'Failed':
        statusColor = AppColors.error;
        statusIcon = Icons.error_rounded;
        break;
      case 'Sent':
      default:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 20),
                ),
                const SizedBox(width: 14),
                // Title and Message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status Badge
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 12),
                              const SizedBox(width: 3),
                              Text(
                                status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                      ),
                      const SizedBox(height: 10),
                      // Meta details row
                      Row(
                        children: [
                          Icon(Icons.people_alt_rounded, size: 11, color: Colors.blueGrey.shade400),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'To: $targetName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.calendar_month_rounded, size: 11, color: Colors.blueGrey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            status == 'Scheduled'
                                ? 'Schedule: ${_formatDate(scheduledAt)}'
                                : 'Sent: ${_formatDate(scheduledAt)}',
                            style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// NOTIFICATION DETAILS SHEET
// ============================================================

class _NotificationDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> notification;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<String> onDelete;

  const _NotificationDetailsSheet({
    required this.notification,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatDate(dynamic dateField) {
    if (dateField == null) return 'N/A';
    DateTime? dt;
    if (dateField is Timestamp) {
      dt = dateField.toDate();
    } else if (dateField is String) {
      dt = DateTime.tryParse(dateField);
    } else if (dateField is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(dateField);
    }
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final id = notification['notificationId'] ?? '';
    final title = notification['title'] ?? 'Untitled';
    final message = notification['message'] ?? '';
    final type = notification['type'] ?? 'General';
    final targetType = notification['targetType'] ?? 'All Students';
    final targetName = notification['targetName'] ?? 'All Students';
    final status = notification['status'] ?? 'Sent';
    final scheduledAt = notification['scheduledAt'];
    final createdAt = notification['createdAt'];

    final isScheduled = status == 'Scheduled';

    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Drag indicator
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Alert Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isScheduled ? AppColors.info.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isScheduled ? AppColors.info : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),

          // Title
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),

          // Message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
            ),
          ),
          const SizedBox(height: 20),

          // Details grid
          _buildDetailRow('Alert Type', type),
          _buildDetailRow('Target Group', targetType),
          _buildDetailRow('Recipient Scope', targetName),
          if (isScheduled) _buildDetailRow('Scheduled Delivery', _formatDate(scheduledAt)),
          _buildDetailRow('Creation Timestamp', _formatDate(createdAt)),
          const SizedBox(height: 28),

          // Action Controls
          if (isScheduled) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onDelete(id),
                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                    label: const Text('Delete Alert'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onEdit(notification),
                    icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                    label: const Text('Edit Scheduled', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryCrimson,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                label: const Text('Dismiss', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }
}

// ============================================================
// SEARCHABLE STUDENT PICKER MODAL
// ============================================================

class _StudentPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _StudentPickerSheet({required this.students, required this.onSelect});

  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final search = _query.trim().toLowerCase();
    final filtered = search.isEmpty
        ? widget.students
        : widget.students.where((s) {
            final name = (s['fullName'] ?? '').toString().toLowerCase();
            final prn = (s['prn'] ?? '').toString().toLowerCase();
            final email = (s['email'] ?? '').toString().toLowerCase();
            return name.contains(search) || prn.contains(search) || email.contains(search);
          }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Recipient Student',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),
          AdminSearchBar(
            hintText: 'Search by Name or PRN...',
            value: _query,
            onChanged: (q) => setState(() => _query = q),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No students found matching query.', style: TextStyle(color: Color(0xFF64748B))))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final student = filtered[index];
                      final name = student['fullName'] ?? 'Unknown';
                      final prn = student['prn'] ?? 'N/A';
                      final course = student['course'] ?? 'N/A';
                      return ListTile(
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('PRN: $prn | $course', style: const TextStyle(fontSize: 12)),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryCrimson.withOpacity(0.08),
                          foregroundColor: AppColors.primaryCrimson,
                          child: const Icon(Icons.person_rounded, size: 20),
                        ),
                        onTap: () {
                          widget.onSelect(student);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// COMPOSE & EDIT NOTIFICATION SHEET
// ============================================================

class _ComposeNotificationSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialNotification;

  const _ComposeNotificationSheet({this.initialNotification});

  @override
  ConsumerState<_ComposeNotificationSheet> createState() => _ComposeNotificationSheetState();
}

class _ComposeNotificationSheetState extends ConsumerState<_ComposeNotificationSheet> {
  final _titleController = TextEditingController();
  final _msgController = TextEditingController();

  String _type = 'General';
  String _targetType = 'All Students';

  String? _targetId;
  String? _targetName;

  bool _isScheduled = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialNotification;
    if (init != null) {
      _titleController.text = init['title'] ?? '';
      _msgController.text = init['message'] ?? '';
      _type = init['type'] ?? 'General';
      _targetType = init['targetType'] ?? 'All Students';
      _targetId = init['targetId'];
      _targetName = init['targetName'];

      if (init['status'] == 'Scheduled') {
        _isScheduled = true;
        final timestamp = init['scheduledAt'];
        if (timestamp is Timestamp) {
          final dt = timestamp.toDate();
          _scheduledDate = dt;
          _scheduledTime = TimeOfDay.fromDateTime(dt);
        }
      }
    } else {
      _scheduledDate = DateTime.now().add(const Duration(days: 1));
      _scheduledTime = const TimeOfDay(hour: 9, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryCrimson,
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _scheduledDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryCrimson,
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _scheduledTime = picked;
      });
    }
  }

  void _openStudentPickerModal(List<Map<String, dynamic>> students) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudentPickerSheet(
        students: students,
        onSelect: (student) {
          setState(() {
            _targetId = student['id'];
            _targetName = student['fullName'];
          });
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter title'), backgroundColor: AppColors.warning),
      );
      return;
    }
    if (_msgController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter message'), backgroundColor: AppColors.warning),
      );
      return;
    }

    // Dynamic targets logic
    String tId = '';
    String tName = 'All Students';

    if (_targetType == 'Specific Route') {
      if (_targetId == null || _targetId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a route'), backgroundColor: AppColors.warning),
        );
        return;
      }
      tId = _targetId!;
      tName = _targetName ?? 'Route';
    } else if (_targetType == 'Specific Bus') {
      if (_targetId == null || _targetId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a bus'), backgroundColor: AppColors.warning),
        );
        return;
      }
      tId = _targetId!;
      tName = _targetName ?? 'Bus';
    } else if (_targetType == 'Individual Student') {
      if (_targetId == null || _targetId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a student'), backgroundColor: AppColors.warning),
        );
        return;
      }
      tId = _targetId!;
      tName = _targetName ?? 'Student';
    }

    final adminUser = ref.read(authControllerProvider).user;
    final createdBy = adminUser?.uid ?? 'Admin';

    DateTime scheduledDateTime;
    if (_isScheduled) {
      final date = _scheduledDate ?? DateTime.now().add(const Duration(days: 1));
      final time = _scheduledTime ?? const TimeOfDay(hour: 9, minute: 0);
      scheduledDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);

      if (scheduledDateTime.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled time must be in the future'), backgroundColor: AppColors.warning),
        );
        return;
      }
    } else {
      scheduledDateTime = DateTime.now();
    }

    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'message': _msgController.text.trim(),
      'type': _type,
      'targetType': _targetType,
      'targetId': tId.isEmpty ? null : tId,
      'targetName': tName,
      'createdBy': createdBy,
      'scheduledAt': Timestamp.fromDate(scheduledDateTime),
      'status': _isScheduled ? 'Scheduled' : 'Sent',
      'isRead': false,
    };

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(notificationRepositoryProvider);
      if (widget.initialNotification != null) {
        await repo.updateNotification(widget.initialNotification!['notificationId'], data);
      } else {
        await repo.createNotification(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.initialNotification != null ? 'Alert updated!' : 'Alert generated!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch streams to populate targets
    final routesAsync = ref.watch(routesListStreamProvider);
    final busesAsync = ref.watch(busesListStreamProvider);
    final studentsAsync = ref.watch(studentsListStreamProvider);

    final isEditMode = widget.initialNotification != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEditMode ? 'Edit Scheduled Alert' : 'Compose Alert',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 20),

            // Form inputs
            const Text('Alert Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: _inputDecoration(),
              items: const [
                DropdownMenuItem(value: 'General', child: Text('General Announcement')),
                DropdownMenuItem(value: 'Bus Delay', child: Text('Bus Delay Alert')),
                DropdownMenuItem(value: 'Route Change', child: Text('Route Change Alert')),
                DropdownMenuItem(value: 'Pass Approved', child: Text('Pass Approved Alert')),
                DropdownMenuItem(value: 'Pass Rejected', child: Text('Pass Rejected Alert')),
                DropdownMenuItem(value: 'Payment Reminder', child: Text('Payment Reminder')),
                DropdownMenuItem(value: 'Pass Expiry Reminder', child: Text('Pass Expiry Reminder')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _type = val);
              },
            ),
            const SizedBox(height: 16),

            const Text('Target Audience Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _targetType,
              decoration: _inputDecoration(),
              items: const [
                DropdownMenuItem(value: 'All Students', child: Text('All Students')),
                DropdownMenuItem(value: 'Specific Route', child: Text('Specific Route')),
                DropdownMenuItem(value: 'Specific Bus', child: Text('Specific Bus')),
                DropdownMenuItem(value: 'Individual Student', child: Text('Individual Student')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _targetType = val;
                    _targetId = null;
                    _targetName = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Target Group conditional input
            if (_targetType == 'Specific Route') ...[
              const Text('Select Route', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              routesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Text('Error loading routes', style: TextStyle(color: AppColors.error)),
                data: (routes) {
                  return DropdownButtonFormField<String>(
                    value: routes.any((r) => r['id'] == _targetId) ? _targetId : null,
                    decoration: _inputDecoration(),
                    items: routes.map((r) {
                      return DropdownMenuItem<String>(
                        value: r['id'],
                        child: Text(r['routeName'] ?? 'Route'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final r = routes.firstWhere((element) => element['id'] == val);
                        setState(() {
                          _targetId = val;
                          _targetName = r['routeName'] ?? 'Route';
                        });
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
            ] else if (_targetType == 'Specific Bus') ...[
              const Text('Select Bus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              busesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Text('Error loading buses', style: TextStyle(color: AppColors.error)),
                data: (buses) {
                  return DropdownButtonFormField<String>(
                    value: buses.any((b) => b['id'] == _targetId) ? _targetId : null,
                    decoration: _inputDecoration(),
                    items: buses.map((b) {
                      return DropdownMenuItem<String>(
                        value: b['id'],
                        child: Text(b['busNo'] ?? 'Bus'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final b = buses.firstWhere((element) => element['id'] == val);
                        setState(() {
                          _targetId = val;
                          _targetName = 'Bus ${b['busNo'] ?? ''}';
                        });
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
            ] else if (_targetType == 'Individual Student') ...[
              const Text('Select Student', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              studentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Text('Error loading students', style: TextStyle(color: AppColors.error)),
                data: (students) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () => _openStudentPickerModal(students),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_targetName ?? 'Tap to pick student', style: TextStyle(color: _targetName != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8))),
                          const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // Title
            const Text('Alert Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: _inputDecoration(hint: 'Enter alert title'),
            ),
            const SizedBox(height: 16),

            // Message
            const Text('Message Body', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            TextField(
              controller: _msgController,
              maxLines: 4,
              decoration: _inputDecoration(hint: 'Compose alert message...'),
            ),
            const SizedBox(height: 20),

            // Delivery schedule toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Schedule Delivery', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Determine date/time of alert broadcast', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
                Switch.adaptive(
                  value: _isScheduled,
                  activeColor: AppColors.primaryCrimson,
                  onChanged: (val) {
                    setState(() {
                      _isScheduled = val;
                    });
                  },
                ),
              ],
            ),
            if (_isScheduled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: Text(_scheduledDate == null ? 'Pick Date' : '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time_rounded, size: 16),
                      label: Text(_scheduledTime == null ? 'Pick Time' : _scheduledTime!.format(context)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),

            // Save Broadcast Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : (isEditMode ? 'Update Scheduled Broadcast' : (_isScheduled ? 'Schedule Broadcast' : 'Send Announcement Now')),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCrimson,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryCrimson)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
