// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/data/repositories/admin_repository.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';

/// Bus management tab — list, search, filter, add, edit, delete buses
class AdminBusesTab extends ConsumerStatefulWidget {
  const AdminBusesTab({super.key});

  @override
  ConsumerState<AdminBusesTab> createState() => _AdminBusesTabState();
}

class _AdminBusesTabState extends ConsumerState<AdminBusesTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busesAsync = ref.watch(busesListStreamProvider);
    final routesAsync = ref.watch(routesListStreamProvider);
    final searchQuery = ref.watch(busSearchQueryProvider);
    final statusFilter = ref.watch(busStatusFilterProvider);


    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add_bus_fab'),
        onPressed: () => _showBusFormSheet(context, bus: null),
        label: const Text('Add Bus'),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: AppColors.primaryCrimson,
        foregroundColor: Colors.white,
      ),
      body: busesAsync.when(
        loading: () => const AdminLoadingState(),
        error: (e, _) => AdminErrorState(message: e.toString()),
        data: (buses) {
          if (buses.isEmpty && searchQuery.isEmpty && statusFilter == 'All') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppColors.primaryCrimson.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Image.asset(
                        'assets/images/bus_logo.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No buses available',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Get started by registering the first bus in your fleet.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: () => _showBusFormSheet(context, bus: null),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add First Bus'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryCrimson,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Apply status filter
          var filtered = buses;
          if (statusFilter != 'All') {
            filtered = filtered
                .where((b) => (b['status'] ?? 'Active').toString() == statusFilter)
                .toList();
          }

          // Apply search query
          if (searchQuery.isNotEmpty) {
            final q = searchQuery.toLowerCase();
            filtered = filtered.where((b) {
              final busNumber = (b['busNumber'] ?? '').toString().toLowerCase();
              final regNum = (b['registrationNumber'] ?? '').toString().toLowerCase();
              final driverName = (b['driverName'] ?? '').toString().toLowerCase();
              final busName = (b['busName'] ?? '').toString().toLowerCase();
              return busNumber.contains(q) ||
                  regNum.contains(q) ||
                  driverName.contains(q) ||
                  busName.contains(q);
            }).toList();
          }

          if (filtered.isEmpty) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: AdminSearchBar(
                    hintText: 'Search by Number, Reg No, Driver...',
                    value: searchQuery,
                    onChanged: (q) =>
                        ref.read(busSearchQueryProvider.notifier).state = q,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: ['All', 'Active', 'Maintenance', 'Inactive'].map((filter) {
                      final selected = statusFilter == filter;
                      Color chipColor = AppColors.primaryCrimson;
                      if (filter == 'Active') chipColor = AppColors.success;
                      if (filter == 'Maintenance') chipColor = AppColors.warning;
                      if (filter == 'Inactive') chipColor = AppColors.error;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter),
                          selected: selected,
                          onSelected: (_) => ref
                              .read(busStatusFilterProvider.notifier)
                              .state = filter,
                          selectedColor: chipColor.withOpacity(0.12),
                          checkmarkColor: chipColor,
                          labelStyle: TextStyle(
                            color: selected ? chipColor : const Color(0xFF64748B),
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                          side: BorderSide(
                            color: selected ? chipColor : const Color(0xFFE2E8F0),
                          ),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: AdminEmptyState(
                    title: 'No buses match',
                    subtitle: 'Try changing your search or filter.',
                    customIcon: Padding(
                      padding: const EdgeInsets.all(22.0),
                      child: Image.asset('assets/images/bus_logo.png', width: 40, height: 40, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ],
            );
          }

          final routesList = routesAsync.valueOrNull ?? [];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: AdminSearchBar(
                  hintText: 'Search by Number, Reg No, Driver...',
                  value: searchQuery,
                  onChanged: (q) =>
                      ref.read(busSearchQueryProvider.notifier).state = q,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: ['All', 'Active', 'Maintenance', 'Inactive'].map((filter) {
                    final selected = statusFilter == filter;
                    Color chipColor = AppColors.primaryCrimson;
                    if (filter == 'Active') chipColor = AppColors.success;
                    if (filter == 'Maintenance') chipColor = AppColors.warning;
                    if (filter == 'Inactive') chipColor = AppColors.error;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: selected,
                        onSelected: (_) => ref
                            .read(busStatusFilterProvider.notifier)
                            .state = filter,
                        selectedColor: chipColor.withOpacity(0.12),
                        checkmarkColor: chipColor,
                        labelStyle: TextStyle(
                          color: selected ? chipColor : const Color(0xFF64748B),
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: selected ? chipColor : const Color(0xFFE2E8F0),
                        ),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final bus = filtered[i];
                    final assignedRouteId = bus['assignedRouteId'] as String?;
                    Map<String, dynamic>? routeInfo;
                    if (assignedRouteId != null) {
                      routeInfo = routesList.firstWhere(
                        (r) => r['id'] == assignedRouteId,
                        orElse: () => <String, dynamic>{},
                      );
                    }

                    return FadeTransition(
                      opacity: _animController,
                      child: _BusCard(
                        bus: bus,
                        routeInfo: routeInfo,
                        onEdit: () => _showBusFormSheet(context, bus: bus),
                        onDelete: () => _confirmDelete(context, bus),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Open Add / Edit Bottom Sheet ──
  void _showBusFormSheet(BuildContext context, {Map<String, dynamic>? bus}) {
    final busesAsync = ref.read(busesListStreamProvider);
    final routesAsync = ref.read(routesListStreamProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BusFormSheet(
        bus: bus,
        busesAsync: busesAsync,
        routesAsync: routesAsync,
        onSave: (data) async {
          try {
            if (bus == null) {
              await AdminRepository().addBus(data);
              if (mounted) {
                _showSnackBar('Bus added successfully', success: true);
              }
            } else {
              await AdminRepository().updateBus(
                bus['id'],
                data,
                oldRouteId: bus['assignedRouteId'] as String?,
              );
              if (mounted) {
                _showSnackBar('Bus updated successfully', success: true);
              }
            }
          } catch (e) {
            if (mounted) {
              _showSnackBar('Error: $e', success: false);
            }
          }
        },
      ),
    );
  }

  // ── Confirm Delete ──
  void _confirmDelete(BuildContext context, Map<String, dynamic> bus) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Delete Bus'),
          ],
        ),
        content: Text(
            'Are you sure you want to delete "${bus['busNumber'] ?? bus['busName'] ?? 'this bus'}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
              // 1. Deletion Check: Prevent deletion if bus is assigned to an active route
              final assignedRouteId = bus['assignedRouteId'] as String?;
              bool inUse = false;
              try {
                inUse = await AdminRepository().checkBusInUse(assignedRouteId);
              } catch (_) {}

              if (!mounted) return;

              if (inUse) {
                showDialog(
                  context: context,
                  builder: (ctx2) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.warning_amber_rounded,
                              color: AppColors.warning, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text('Cannot Delete Bus'),
                      ],
                    ),
                    content: Text(
                      'The bus "${bus['busNumber'] ?? 'this bus'}" is currently assigned to an Active Route. '
                      'Please unassign or deactivate the route before deleting this bus.',
                    ),
                    actions: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx2),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryCrimson,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Understood'),
                      ),
                    ],
                  ),
                );
                return;
              }

              // 2. Perform deletion and sync
              try {
                await AdminRepository().deleteBus(
                  bus['id'],
                  assignedRouteId: assignedRouteId,
                );
                if (mounted) {
                  _showSnackBar('Bus deleted successfully', success: true);
                }
              } catch (e) {
                if (mounted) {
                  _showSnackBar('Error: $e', success: false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ============================================================
// BUS FORM BOTTOM SHEET (Draggable Scrollable)
// ============================================================

class _BusFormSheet extends StatefulWidget {
  final Map<String, dynamic>? bus;
  final AsyncValue<List<Map<String, dynamic>>> busesAsync;
  final AsyncValue<List<Map<String, dynamic>>> routesAsync;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _BusFormSheet({
    required this.bus,
    required this.busesAsync,
    required this.routesAsync,
    required this.onSave,
  });

  @override
  State<_BusFormSheet> createState() => _BusFormSheetState();
}

class _BusFormSheetState extends State<_BusFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _numberCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _regCtrl;
  late TextEditingController _driverNameCtrl;
  late TextEditingController _driverPhoneCtrl;
  late TextEditingController _capacityCtrl;

  String _status = 'Active';
  String? _assignedRouteId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.bus;

    _numberCtrl = TextEditingController(text: b?['busNumber']?.toString() ?? '');
    _nameCtrl = TextEditingController(text: b?['busName']?.toString() ?? '');
    _regCtrl = TextEditingController(text: b?['registrationNumber']?.toString() ?? '');
    _driverNameCtrl = TextEditingController(text: b?['driverName']?.toString() ?? '');
    _driverPhoneCtrl = TextEditingController(text: b?['driverPhone']?.toString() ?? '');
    _capacityCtrl = TextEditingController(text: b?['capacity']?.toString() ?? '');
    _status = b?['status']?.toString() ?? 'Active';
    _assignedRouteId = b?['assignedRouteId']?.toString();
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    _regCtrl.dispose();
    _driverNameCtrl.dispose();
    _driverPhoneCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final capacityValue = int.tryParse(_capacityCtrl.text.trim()) ?? 0;

    final data = <String, dynamic>{
      'busNumber': _numberCtrl.text.trim(),
      'busName': _nameCtrl.text.trim(),
      'registrationNumber': _regCtrl.text.trim(),
      'driverName': _driverNameCtrl.text.trim(),
      'driverPhone': _driverPhoneCtrl.text.trim(),
      'capacity': capacityValue,
      'assignedRouteId': (_assignedRouteId?.isNotEmpty ?? false) ? _assignedRouteId : null,
      'status': _status,
    };

    setState(() => _isSaving = true);
    await widget.onSave(data);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.bus != null;
    final routes = widget.routesAsync.valueOrNull ?? [];
    final buses = widget.busesAsync.valueOrNull ?? [];

    // Filter Active Routes & enforce 1-to-1: Filter out routes assigned to other buses
    final activeRoutes = routes.where((r) => (r['status'] ?? 'Active') == 'Active').toList();

    final assignedRouteIdsByOthers = buses
        .where((b) => b['id'] != widget.bus?['id'])
        .map((b) => b['assignedRouteId'])
        .whereType<String>()
        .toSet();

    final selectableRoutes = activeRoutes.where((route) {
      final routeId = route['id'] ?? '';
      return !assignedRouteIdsByOthers.contains(routeId) || routeId == _assignedRouteId;
    }).toList();

    // Filter out duplicate routes and ensure unique IDs
    final uniqueRoutes = <String, Map<String, dynamic>>{};
    for (final route in selectableRoutes) {
      final routeId = route['id']?.toString() ?? '';
      if (routeId.isNotEmpty) {
        uniqueRoutes[routeId] = route;
      }
    }

    // Automatically set value to null if it no longer exists
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
              // Handle + Title
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
                              isEdit ? 'Edit Bus details' : 'Add New Bus',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              isEdit
                                  ? 'Update driver and operational details'
                                  : 'Register a new bus in the fleet',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B)),
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

              // Form Body
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    children: [
                      // ── Section: Fleet Specs ──
                      _SectionHeader(
                          title: 'Fleet Specifications',
                          customIcon: Image.asset('assets/images/bus_logo.png', width: 16, height: 16),
                      ),
                      const SizedBox(height: 12),

                      // Bus Number
                      _FormField(
                        controller: _numberCtrl,
                        label: 'Bus Number *',
                        hint: 'e.g. BUS-01',
                        icon: Icons.tag_rounded,
                        enabled: !isEdit, // Read-only on edit
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Bus number is required'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Bus Name
                      _FormField(
                        controller: _nameCtrl,
                        label: 'Bus Name *',
                        hint: 'e.g. Crimson Cruiser',
                        icon: Icons.badge_rounded,
                        enabled: !isEdit, // Read-only on edit
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Bus name is required'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Registration Number
                      _FormField(
                        controller: _regCtrl,
                        label: 'Registration Number *',
                        hint: 'e.g. MH 12 PQ 1234',
                        icon: Icons.featured_play_list_rounded,
                        enabled: !isEdit, // Read-only on edit
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Registration number is required'
                            : null,
                      ),
                      const SizedBox(height: 24),

                      // ── Section: Driver Specs ──
                      _SectionHeader(
                          title: 'Driver Information',
                          icon: Icons.person_rounded),
                      const SizedBox(height: 12),

                      // Driver Name
                      _FormField(
                        controller: _driverNameCtrl,
                        label: 'Driver Name *',
                        hint: 'e.g. Suresh Kumar',
                        icon: Icons.portrait_rounded,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Driver name is required'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Driver Mobile
                      _FormField(
                        controller: _driverPhoneCtrl,
                        label: 'Driver Mobile Number *',
                        hint: 'e.g. 9876543210',
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Mobile number is required';
                          }
                          if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) {
                            return 'Enter a valid 10-digit mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // ── Section: Operational details ──
                      _SectionHeader(
                          title: 'Operational Configuration',
                          icon: Icons.settings_suggest_rounded),
                      const SizedBox(height: 12),

                      // Capacity
                      _FormField(
                        controller: _capacityCtrl,
                        label: 'Bus Capacity (seats) *',
                        hint: 'e.g. 50',
                        icon: Icons.airline_seat_recline_normal_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Capacity is required';
                          }
                          final cap = int.tryParse(v.trim()) ?? 0;
                          if (cap <= 0) {
                            return 'Capacity must be greater than 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Assigned Route (Dropdown)
                      DropdownButtonFormField<String>(
                        value: (_assignedRouteId == null || !uniqueRoutes.containsKey(_assignedRouteId)) ? null : _assignedRouteId,
                        decoration: InputDecoration(
                          labelText: 'Assigned Route',
                          labelStyle: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                          prefixIcon: const Icon(Icons.route_rounded,
                              color: Color(0xFF94A3B8), size: 20),
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
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                        hint: const Text('No route assigned'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No route assigned (Unassigned)'),
                          ),
                          ...uniqueRoutes.values.map((route) {
                            final routeId = route['id'] ?? '';
                            final name = route['routeName'] ?? 'Route';
                            final num = route['routeNumber'] ?? '';
                            return DropdownMenuItem<String>(
                              value: routeId.toString(),
                              child: Text('$num – $name'),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() => _assignedRouteId = v),
                      ),
                      const SizedBox(height: 24),

                      // ── Status Selection ──
                      _SectionHeader(
                          title: 'Fleet Status',
                          icon: Icons.toggle_on_rounded),
                      const SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _buildStatusTile('Active', 'Fleet is operational', AppColors.success),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _buildStatusTile('Maintenance', 'Fleet is in repair workshop', AppColors.warning),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _buildStatusTile('Inactive', 'Fleet is out of service', AppColors.error),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryCrimson,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE2E8F0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : Text(
                                isEdit ? 'Save Changes' : 'Create Bus Entry',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
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

  Widget _buildStatusTile(String val, String desc, Color color) {
    final selected = _status == val;
    return InkWell(
      onTap: () => setState(() => _status = val),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.12) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? color : const Color(0xFF94A3B8),
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    val,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: selected ? color : const Color(0xFF334155),
                    ),
                  ),
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SECTION HEADER HELPER
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

// ============================================================
// FORM FIELD HELPER
// ============================================================

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool enabled;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        filled: !enabled,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryCrimson),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      style: TextStyle(
        fontSize: 14,
        color: enabled ? const Color(0xFF0F172A) : const Color(0xFF64748B),
      ),
    );
  }
}


// ============================================================
// BUS CARD WIDGET
// ============================================================

class _BusCard extends StatelessWidget {
  final Map<String, dynamic> bus;
  final Map<String, dynamic>? routeInfo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BusCard({
    required this.bus,
    required this.routeInfo,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = bus['busName'] ?? 'Unnamed Bus';
    final number = bus['busNumber'] ?? 'N/A';
    final regNo = bus['registrationNumber'] ?? 'N/A';
    final driverName = bus['driverName'] ?? 'No Driver';
    final driverPhone = bus['driverPhone'] ?? 'N/A';
    final capacity = bus['capacity'] ?? 0;
    final status = bus['status'] ?? 'Active';

    Color statusColor = AppColors.success;
    if (status == 'Maintenance') statusColor = AppColors.warning;
    if (status == 'Inactive') statusColor = AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryCrimson.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Image.asset('assets/images/bus_logo.png', width: 24, height: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'No: $number',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          regNo.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Text(
                  status.toString(),
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
          const SizedBox(height: 14),

          // Details Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Driver Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DRIVER',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            driverName.toString(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone_android_rounded,
                            size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          driverPhone.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Capacity Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CAPACITY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.airline_seat_recline_normal_rounded,
                          size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        '$capacity Seats',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16), // balancing height spacer
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Assigned Route Row + Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Route
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.route_rounded,
                        size: 16, color: AppColors.primaryCrimson),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        routeInfo != null && routeInfo!.isNotEmpty
                            ? '${routeInfo!['routeNumber'] ?? ''} • ${routeInfo!['routeName'] ?? ''}'
                            : 'No route assigned',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: routeInfo != null && routeInfo!.isNotEmpty
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF94A3B8),
                          fontStyle: routeInfo != null && routeInfo!.isNotEmpty
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Action Buttons
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded,
                        size: 18, color: AppColors.info),
                    onPressed: onEdit,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.info.withOpacity(0.08),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded,
                        size: 18, color: AppColors.error),
                    onPressed: onDelete,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.error.withOpacity(0.08),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
