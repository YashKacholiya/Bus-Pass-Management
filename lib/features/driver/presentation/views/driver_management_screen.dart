// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import 'package:icem_bus/features/driver/data/repositories/driver_repository.dart';
import 'package:icem_bus/features/driver/domain/driver_providers.dart';

// ============================================================
// DRIVER MANAGEMENT SCREEN
// ============================================================

class DriverManagementScreen extends ConsumerStatefulWidget {
  const DriverManagementScreen({super.key});

  @override
  ConsumerState<DriverManagementScreen> createState() => _DriverManagementScreenState();
}

class _AdminFilterChipsWrapper extends StatefulWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _AdminFilterChipsWrapper({
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_AdminFilterChipsWrapper> createState() => _AdminFilterChipsWrapperState();
}

class _AdminFilterChipsWrapperState extends State<_AdminFilterChipsWrapper> {
  @override
  Widget build(BuildContext context) {
    return AdminFilterChips(
      filters: const ['All', 'Active', 'On Leave', 'Inactive'],
      selected: widget.selected,
      onSelected: widget.onSelected,
    );
  }
}

class _DriverManagementScreenState extends ConsumerState<DriverManagementScreen> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(driversListStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/bus_logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            const Text(
              'Driver Management',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton.icon(
              onPressed: () => _showDriverForm(context),
              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              label: const Text('Add Driver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primaryCrimson,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              children: [
                AdminSearchBar(
                  hintText: 'Search by Name, Mobile, or License...',
                  value: _searchQuery,
                  onChanged: (q) => setState(() => _searchQuery = q),
                ),
                const SizedBox(height: 12),
                _AdminFilterChipsWrapper(
                  selected: _statusFilter,
                  onSelected: (f) => setState(() => _statusFilter = f),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: driversAsync.when(
              loading: () => const AdminLoadingState(),
              error: (e, _) => AdminErrorState(message: e.toString()),
              data: (drivers) {
                var filtered = drivers;

                // Client-side search filtering
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filtered = filtered.where((d) {
                    final name = (d['fullName'] ?? '').toString().toLowerCase();
                    final mobile = (d['mobile'] ?? '').toString().toLowerCase();
                    final license = (d['licenseNumber'] ?? '').toString().toLowerCase();
                    return name.contains(q) || mobile.contains(q) || license.contains(q);
                  }).toList();
                }

                // Client-side status filtering
                if (_statusFilter != 'All') {
                  filtered = filtered.where((d) => (d['status'] ?? 'Active') == _statusFilter).toList();
                }

                if (filtered.isEmpty) {
                  return AdminEmptyState(
                    title: 'No drivers found',
                    subtitle: 'Try adjusting your search or filter criteria.',
                    customIcon: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Image.asset(
                        'assets/images/bus_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final driver = filtered[i];
                    return _DriverCard(
                      driver: driver,
                      onTap: () => _showDriverDetails(context, driver),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDriverForm(BuildContext context, [Map<String, dynamic>? driver]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DriverFormSheet(driver: driver),
    );
  }

  void _showDriverDetails(BuildContext context, Map<String, dynamic> driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DriverDetailsSheet(
        driver: driver,
        onEdit: () {
          Navigator.pop(context); // Close details sheet
          _showDriverForm(context, driver); // Open form sheet
        },
      ),
    );
  }
}

// ============================================================
// DRIVER CARD WIDGET
// ============================================================

class _DriverCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  final VoidCallback onTap;

  const _DriverCard({
    required this.driver,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = driver['fullName'] ?? 'Unknown';
    final driverIdVal = driver['driverId'] ?? 'N/A';
    final mobile = driver['mobile'] ?? 'N/A';
    final license = driver['licenseNumber'] ?? 'N/A';
    final photoUrl = driver['photoUrl'] as String?;
    final busNum = driver['assignedBusNumber'] ?? 'Not Assigned';
    final routeName = driver['assignedRouteName'] ?? 'Not Assigned';
    final status = driver['status'] ?? 'Active';

    Color statusColor = AppColors.success;
    if (status == 'On Leave') statusColor = AppColors.warning;
    if (status == 'Inactive') statusColor = AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Avatar / Photo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryCrimson.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    image: photoUrl != null && photoUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(photoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Center(
                          child: Text(
                            name.toString().isNotEmpty
                                ? name.toString()[0].toUpperCase()
                                : 'D',
                            style: const TextStyle(
                              color: AppColors.primaryCrimson,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status.toString(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // ID & Mobile
                      Row(
                        children: [
                          Text(
                            'ID: $driverIdVal',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                          const SizedBox(width: 6),
                          Text(
                            mobile.toString(),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // License Information
                      Row(
                        children: [
                          const Icon(Icons.badge_outlined, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Lic: $license',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 10),

                      // Bus & Route details
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Image.asset('assets/images/bus_logo.png', width: 14, height: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    busNum.toString(),
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
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.route_rounded, size: 14, color: AppColors.accentGold),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    routeName.toString(),
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
// DRIVER DETAILS SHEET
// ============================================================

class _DriverDetailsSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> driver;
  final VoidCallback onEdit;

  const _DriverDetailsSheet({
    required this.driver,
    required this.onEdit,
  });

  @override
  ConsumerState<_DriverDetailsSheet> createState() => _DriverDetailsSheetState();
}

class _DriverDetailsSheetState extends ConsumerState<_DriverDetailsSheet> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final driverId = widget.driver['id'];

    // Stream the specific driver document for real-time updates inside sheet
    final driverSnap = FirebaseFirestore.instance.collection('drivers').doc(driverId).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: driverSnap,
      builder: (context, snapshot) {
        final d = snapshot.data?.data() ?? widget.driver;
        final name = d['fullName'] ?? 'Unknown';
        final driverIdVal = d['driverId'] ?? 'N/A';
        final mobile = d['mobile'] ?? 'N/A';
        final license = d['licenseNumber'] ?? 'N/A';
        final licenseExpiry = d['licenseExpiryDate'];
        final address = d['address'] ?? 'N/A';
        final emergency = d['emergencyContact'] ?? 'N/A';
        final busNum = d['assignedBusNumber'] ?? 'Not Assigned';
        final routeName = d['assignedRouteName'] ?? 'Not Assigned';
        final status = d['status'] ?? 'Active';
        final photoUrl = d['photoUrl'] as String?;
        final email = d['email'] as String?;
        final joinDate = d['createdAt'];

        Color statusColor = AppColors.success;
        if (status == 'On Leave') statusColor = AppColors.warning;
        if (status == 'Inactive') statusColor = AppColors.error;

        return DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.6,
          maxChildSize: 0.97,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Handle & Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primaryCrimson.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                image: photoUrl != null && photoUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(photoUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: photoUrl == null || photoUrl.isEmpty
                                  ? const Icon(Icons.person_rounded, color: AppColors.primaryCrimson, size: 24)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.toString(),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Driver ID: $driverIdVal',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            if (_isDeleting)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryCrimson),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                      ],
                    ),
                  ),

                  // Content Details List
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      children: [
                        // Personal Information
                        const _SectionHeader(title: 'Personal Information', icon: Icons.person_outline_rounded),
                        const SizedBox(height: 12),
                        _buildDetailRow('Mobile Number', mobile.toString()),
                        if (email != null && email.isNotEmpty) _buildDetailRow('Email Address', email.toString()),
                        _buildDetailRow('Emergency Contact', emergency.toString()),
                        _buildDetailRow('Home Address', address.toString()),
                        _buildDetailRow('Driver Status', status.toString(), color: statusColor),
                        _buildDetailRow('Join Date', _formatDate(joinDate)),
                        const SizedBox(height: 24),

                        // Assignment
                        _SectionHeader(
                          title: 'Assignment Details',
                          customIcon: Image.asset('assets/images/bus_logo.png', width: 16, height: 16),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow('Assigned Bus', busNum.toString()),
                        _buildDetailRow('Assigned Route', routeName.toString()),
                        const SizedBox(height: 24),

                        // License Details
                        const _SectionHeader(title: 'License Information', icon: Icons.badge_outlined),
                        const SizedBox(height: 12),
                        _buildDetailRow('License Number', license.toString()),
                        _buildDetailRow('License Expiry Date', _formatDate(licenseExpiry)),
                        const SizedBox(height: 32),

                        // Administrative Controls
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isDeleting ? null : widget.onEdit,
                                icon: const Icon(Icons.edit_rounded, size: 16),
                                label: const Text('Edit Profile'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryCrimson,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isDeleting ? null : () => _confirmDelete(context, driverId, name.toString()),
                                icon: const Icon(Icons.delete_rounded, size: 16),
                                label: const Text('Delete Driver'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: color ?? const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Delete Driver'),
          ],
        ),
        content: Text('Are you sure you want to permanently delete "$name" and remove all driver details? This action is irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isDeleting = true);
      try {
        await ref.read(driverRepositoryProvider).deleteDriver(id);
        Navigator.pop(context); // Close details sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver profile permanently deleted'), backgroundColor: AppColors.success),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }
}

// ============================================================
// DRIVER ADD/EDIT FORM SHEET
// ============================================================

class _DriverFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? driver;

  const _DriverFormSheet({this.driver});

  @override
  ConsumerState<_DriverFormSheet> createState() => _DriverFormSheetState();
}

class _DriverFormSheetState extends ConsumerState<_DriverFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _driverIdCtrl;
  late TextEditingController _licenseCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _emergencyCtrl;

  DateTime? _licenseExpiryDate;
  String? _assignedBusId;
  String? _assignedRouteId;
  String _status = 'Active';
  String? _photoUrl;
  bool _isPhotoLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.driver;

    _nameCtrl = TextEditingController(text: d?['fullName']?.toString() ?? '');
    _mobileCtrl = TextEditingController(text: d?['mobile']?.toString() ?? '');
    _emailCtrl = TextEditingController(text: d?['email']?.toString() ?? '');
    
    final driverIdVal = d?['driverId'] ?? 'DRV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    _driverIdCtrl = TextEditingController(text: driverIdVal.toString());

    _licenseCtrl = TextEditingController(text: d?['licenseNumber']?.toString() ?? '');
    _addressCtrl = TextEditingController(text: d?['address']?.toString() ?? '');
    _emergencyCtrl = TextEditingController(text: d?['emergencyContact']?.toString() ?? '');

    _status = d?['status']?.toString() ?? 'Active';
    _assignedBusId = d?['assignedBusId']?.toString();
    _assignedRouteId = d?['assignedRouteId']?.toString();
    _photoUrl = d?['photoUrl']?.toString();

    final expiry = d?['licenseExpiryDate'];
    if (expiry is Timestamp) {
      _licenseExpiryDate = expiry.toDate();
    } else if (expiry is DateTime) {
      _licenseExpiryDate = expiry;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _driverIdCtrl.dispose();
    _licenseCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    // Request permission (may require adjust for Android 13+)
    final status = await Permission.photos.request();
    // Proceed regardless of status to test on emulators, or handle appropriately
    
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null) {
      setState(() => _isPhotoLoading = true);
      try {
        final tempId = _driverIdCtrl.text.trim().isEmpty ? 'TEMP_${DateTime.now().millisecondsSinceEpoch}' : _driverIdCtrl.text.trim();
        final ref = FirebaseStorage.instance.ref().child('driver_photos').child('$tempId.jpg');
        await ref.putFile(File(pickedFile.path));
        final downloadUrl = await ref.getDownloadURL();
        setState(() {
          _photoUrl = downloadUrl;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo uploaded successfully!'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload photo: $e'), backgroundColor: AppColors.error),
          );
        }
      } finally {
        if (mounted) setState(() => _isPhotoLoading = false);
      }
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _licenseExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );
    if (picked != null) {
      setState(() => _licenseExpiryDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_licenseExpiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('License expiry date is required'), backgroundColor: AppColors.error),
      );
      return;
    }

    final isEdit = widget.driver != null;
    final buses = ref.read(busesListStreamProvider).valueOrNull ?? [];
    final routes = ref.read(routesListStreamProvider).valueOrNull ?? [];

    // Look up bus number
    String? busNumber;
    if (_assignedBusId != null && _assignedBusId!.isNotEmpty) {
      final busMatch = buses.firstWhere(
        (b) => b['id']?.toString() == _assignedBusId,
        orElse: () => <String, dynamic>{},
      );
      busNumber = busMatch['busNumber'] ?? busMatch['busName'] ?? busMatch['name'] ?? _assignedBusId;
    }

    // Look up route name
    String? routeName;
    if (_assignedRouteId != null && _assignedRouteId!.isNotEmpty) {
      final routeMatch = routes.firstWhere(
        (r) => r['id']?.toString() == _assignedRouteId,
        orElse: () => <String, dynamic>{},
      );
      routeName = routeMatch['routeName'] ?? routeMatch['routeNumber'] ?? _assignedRouteId;
    }

    final data = <String, dynamic>{
      'fullName': _nameCtrl.text.trim(),
      'mobile': _mobileCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'driverId': _driverIdCtrl.text.trim(),
      'licenseNumber': _licenseCtrl.text.trim(),
      'licenseExpiryDate': Timestamp.fromDate(_licenseExpiryDate!),
      'address': _addressCtrl.text.trim(),
      'emergencyContact': _emergencyCtrl.text.trim(),
      'assignedBusId': _assignedBusId,
      'assignedBusNumber': busNumber,
      'assignedRouteId': _assignedRouteId,
      'assignedRouteName': routeName,
      'status': _status,
      'photoUrl': _photoUrl,
    };

    setState(() => _isSaving = true);
    try {
      if (isEdit) {
        await ref.read(driverRepositoryProvider).updateDriver(widget.driver!['id'], data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver profile updated successfully'), backgroundColor: AppColors.success),
        );
      } else {
        await ref.read(driverRepositoryProvider).addDriver(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver profile added successfully'), backgroundColor: AppColors.success),
        );
      }
      Navigator.pop(context); // Close sheet
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.driver != null;
    final buses = ref.watch(busesListStreamProvider).valueOrNull ?? [];
    final routes = ref.watch(routesListStreamProvider).valueOrNull ?? [];

    // Filter unique buses & routes for dropdown integrity
    final uniqueBuses = <String, Map<String, dynamic>>{};
    for (final b in buses) {
      final bId = b['id']?.toString() ?? '';
      if (bId.isNotEmpty) {
        uniqueBuses[bId] = b;
      }
    }

    final uniqueRoutes = <String, Map<String, dynamic>>{};
    for (final r in routes) {
      final rId = r['id']?.toString() ?? '';
      if (rId.isNotEmpty) {
        uniqueRoutes[rId] = r;
      }
    }

    // Sanitize selections
    if (_assignedBusId != null && !uniqueBuses.containsKey(_assignedBusId)) {
      _assignedBusId = null;
    }
    if (_assignedRouteId != null && !uniqueRoutes.containsKey(_assignedRouteId)) {
      _assignedRouteId = null;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.97,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle & Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryCrimson.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEdit ? Icons.edit_road_rounded : Icons.add_road_rounded,
                            color: AppColors.primaryCrimson,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Edit Driver Profile' : 'Add New Driver',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              isEdit ? 'Update driver fields below' : 'Fill in driver parameters',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Section: Photo
                      Center(
                        child: GestureDetector(
                          onTap: _isPhotoLoading ? null : _pickPhoto,
                          child: Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryCrimson.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  image: _photoUrl != null && _photoUrl!.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(_photoUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _photoUrl == null || _photoUrl!.isEmpty
                                    ? const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryCrimson, size: 32)
                                    : null,
                              ),
                              if (_isPhotoLoading)
                                const Positioned.fill(
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryCrimson),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryCrimson,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section: Personal Details
                      const _SectionHeader(title: 'Personal Info', icon: Icons.person_outline_rounded),
                      const SizedBox(height: 12),
                      _FormField(
                        controller: _nameCtrl,
                        label: 'Full Name *',
                        hint: 'e.g. John Doe',
                        icon: Icons.person_rounded,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
                      ),
                      const SizedBox(height: 14),
                      _FormField(
                        controller: _driverIdCtrl,
                        label: 'Driver ID *',
                        hint: 'e.g. DRV-123456',
                        icon: Icons.badge_rounded,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Driver ID is required' : null,
                      ),
                      const SizedBox(height: 14),
                      _FormField(
                        controller: _emailCtrl,
                        label: 'Email Address (Optional)',
                        hint: 'e.g. driver@icem.edu',
                        icon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty && !v.contains('@')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _FormField(
                        controller: _mobileCtrl,
                        label: 'Mobile Number *',
                        hint: 'e.g. 9876543210',
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Mobile number is required';
                          if (v.trim().length < 10) return 'Enter a valid 10-digit number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _FormField(
                        controller: _emergencyCtrl,
                        label: 'Emergency Contact *',
                        hint: 'e.g. 9876543211',
                        icon: Icons.contact_phone_rounded,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) => v == null || v.trim().isEmpty ? 'Emergency contact is required' : null,
                      ),
                      const SizedBox(height: 14),
                      _FormField(
                        controller: _addressCtrl,
                        label: 'Home Address *',
                        hint: 'Enter driver address details...',
                        icon: Icons.home_rounded,
                        maxLines: 2,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Address is required' : null,
                      ),
                      const SizedBox(height: 24),

                      // Section: License Info
                      const _SectionHeader(title: 'License Info', icon: Icons.badge_outlined),
                      const SizedBox(height: 12),
                      _FormField(
                        controller: _licenseCtrl,
                        label: 'License Number *',
                        hint: 'e.g. MH-12-2023004561',
                        icon: Icons.badge_outlined,
                        validator: (v) => v == null || v.trim().isEmpty ? 'License number is required' : null,
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => _pickDate(context),
                        child: AbsorbPointer(
                          child: _FormField(
                            controller: TextEditingController(text: _licenseExpiryDate == null ? '' : _formatDateOnly(_licenseExpiryDate!)),
                            label: 'License Expiry Date *',
                            hint: 'Select expiry date...',
                            icon: Icons.calendar_month_rounded,
                            validator: (_) => _licenseExpiryDate == null ? 'Expiry date is required' : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section: Operation Details
                      _SectionHeader(
                        title: 'Operation Details',
                        customIcon: Image.asset('assets/images/bus_logo.png', width: 16, height: 16),
                      ),
                      const SizedBox(height: 12),
                      
                      // Bus Selection
                      DropdownButtonFormField<String>(
                        value: _assignedBusId,
                        decoration: _getInputDecoration('Assign Bus (optional)', customPrefix: Padding(padding: const EdgeInsets.all(12.0), child: Image.asset('assets/images/bus_logo.png', width: 20, height: 20, fit: BoxFit.contain))),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                        hint: const Text('No bus assigned'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No bus assigned'),
                          ),
                          ...uniqueBuses.values.map((b) {
                            final bId = b['id'] ?? '';
                            final label = b['busNumber'] ?? b['busName'] ?? b['name'] ?? bId;
                            return DropdownMenuItem<String>(
                              value: bId.toString(),
                              child: Text(label.toString()),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() => _assignedBusId = v),
                      ),
                      const SizedBox(height: 14),

                      // Route Selection
                      DropdownButtonFormField<String>(
                        value: _assignedRouteId,
                        decoration: _getInputDecoration('Assign Route (optional)', icon: Icons.route_rounded),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                        hint: const Text('No route assigned'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No route assigned'),
                          ),
                          ...uniqueRoutes.values.map((r) {
                            final rId = r['id'] ?? '';
                            final name = r['routeName'] ?? r['routeNumber'] ?? rId;
                            return DropdownMenuItem<String>(
                              value: rId.toString(),
                              child: Text(name.toString()),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() => _assignedRouteId = v),
                      ),
                      const SizedBox(height: 14),

                      // Status Selection
                      DropdownButtonFormField<String>(
                        value: _status,
                        decoration: _getInputDecoration('Driver Status', icon: Icons.toggle_on_rounded),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'Active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'On Leave',
                            child: Text('On Leave'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Inactive',
                            child: Text('Inactive'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _status = v);
                        },
                      ),
                      const SizedBox(height: 32),

                      // Submit Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving ? null : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryCrimson,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: _isSaving
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(isEdit ? 'Save Changes' : 'Create Profile', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _getInputDecoration(String label, {IconData? icon, Widget? customPrefix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      prefixIcon: customPrefix ?? (icon != null ? Icon(icon, color: const Color(0xFF94A3B8), size: 20) : null),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryCrimson)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

// ============================================================
// FORM FIELD HELPER WIDGET
// ============================================================

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryCrimson),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
    );
  }
}

// ============================================================
// FORMAT DATE HELPERS
// ============================================================

String _formatDate(dynamic value) {
  if (value == null) return 'N/A';
  DateTime? date;
  if (value is Timestamp) {
    date = value.toDate();
  } else if (value is DateTime) {
    date = value;
  }
  if (date == null) return 'N/A';
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final day = date.day.toString().padLeft(2, '0');
  final month = months[date.month - 1];
  final year = date.year;
  
  int hour = date.hour;
  final period = hour >= 12 ? 'PM' : 'AM';
  if (hour > 12) hour -= 12;
  if (hour == 0) hour = 12;
  final minute = date.minute.toString().padLeft(2, '0');
  
  return "$day $month $year, $hour:$minute $period";
}

String _formatDateOnly(DateTime date) {
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final day = date.day.toString().padLeft(2, '0');
  final month = months[date.month - 1];
  final year = date.year;
  return "$day $month $year";
}

// ============================================================
// SECTION HEADER HELPER WIDGET
// ============================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? customIcon;

  const _SectionHeader({
    required this.title,
    this.icon,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (customIcon != null)
          customIcon!
        else if (icon != null)
          Icon(icon!, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
