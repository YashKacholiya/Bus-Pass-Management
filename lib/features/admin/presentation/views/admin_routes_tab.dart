// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/data/repositories/admin_repository.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';

// ============================================================
// ADMIN ROUTES TAB
// ============================================================

class AdminRoutesTab extends ConsumerStatefulWidget {
  const AdminRoutesTab({super.key});

  @override
  ConsumerState<AdminRoutesTab> createState() => _AdminRoutesTabState();
}

class _AdminRoutesTabState extends ConsumerState<AdminRoutesTab>
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
    final routesAsync = ref.watch(routesListStreamProvider);
    final searchQuery = ref.watch(routeSearchQueryProvider);
    final statusFilter = ref.watch(routeStatusFilterProvider);

    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: isMobile
          ? AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: const Text(
                'Route Management',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
              ),
              leading: IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A)),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
              elevation: 0,
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add_route_fab'),
        onPressed: () => _showRouteSheet(context, route: null),
        label: const Text('Add Route'),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: AppColors.primaryCrimson,
        foregroundColor: Colors.white,
      ),
      body: routesAsync.when(
        loading: () => const AdminLoadingState(),
        error: (e, _) => AdminErrorState(message: e.toString()),
        data: (routes) {
          if (routes.isEmpty && searchQuery.isEmpty && statusFilter == 'All') {
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
                      child: const Icon(
                        Icons.route_rounded,
                        size: 48,
                        color: AppColors.primaryCrimson,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No routes available',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create your first bus route to begin transit operations.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: () => _showRouteSheet(context, route: null),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add First Route'),
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
          var filtered = routes;
          if (statusFilter != 'All') {
            filtered = filtered
                .where((r) => (r['status'] ?? 'Active').toString() == statusFilter)
                .toList();
          }

          // Apply search
          if (searchQuery.isNotEmpty) {
            final q = searchQuery.toLowerCase();
            filtered = filtered.where((r) {
              final name = (r['routeName'] ?? '').toString().toLowerCase();
              final number = (r['routeNumber'] ?? '').toString().toLowerCase();
              final source = (r['source'] ?? '').toString().toLowerCase();
              final destination = (r['destination'] ?? '').toString().toLowerCase();
              return name.contains(q) ||
                  number.contains(q) ||
                  source.contains(q) ||
                  destination.contains(q);
            }).toList();
          }

          if (filtered.isEmpty) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: _RouteSearchBar(
                    value: searchQuery,
                    onChanged: (q) =>
                        ref.read(routeSearchQueryProvider.notifier).state = q,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: ['All', 'Active', 'Inactive'].map((filter) {
                      final selected = statusFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter),
                          selected: selected,
                          onSelected: (_) => ref
                              .read(routeStatusFilterProvider.notifier)
                              .state = filter,
                          selectedColor: AppColors.primaryCrimson.withOpacity(0.12),
                          checkmarkColor: AppColors.primaryCrimson,
                          labelStyle: TextStyle(
                            color: selected ? AppColors.primaryCrimson : const Color(0xFF64748B),
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                          side: BorderSide(
                            color: selected ? AppColors.primaryCrimson : const Color(0xFFE2E8F0),
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
                    title: 'No routes match',
                    subtitle: 'Try changing your search or filter.',
                    icon: Icons.route_rounded,
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: _RouteSearchBar(
                  value: searchQuery,
                  onChanged: (q) =>
                      ref.read(routeSearchQueryProvider.notifier).state = q,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: ['All', 'Active', 'Inactive'].map((filter) {
                    final selected = statusFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: selected,
                        onSelected: (_) => ref
                            .read(routeStatusFilterProvider.notifier)
                            .state = filter,
                        selectedColor: AppColors.primaryCrimson.withOpacity(0.12),
                        checkmarkColor: AppColors.primaryCrimson,
                        labelStyle: TextStyle(
                          color: selected ? AppColors.primaryCrimson : const Color(0xFF64748B),
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: selected ? AppColors.primaryCrimson : const Color(0xFFE2E8F0),
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
                    final route = filtered[i];
                    return FadeTransition(
                      opacity: _animController,
                      child: _RouteCard(
                        route: route,
                        index: i,
                        onEdit: () => _showRouteSheet(context, route: route),
                        onDelete: () => _confirmDelete(context, route),
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
  void _showRouteSheet(BuildContext context,
      {Map<String, dynamic>? route}) {
    final busesAsync = ref.read(busesListStreamProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RouteFormSheet(
        route: route,
        busesAsync: busesAsync,
        onSave: (data) async {
          try {
            if (route == null) {
              await AdminRepository().addRoute(data);
              if (mounted) {
                _showSnackBar('Route added successfully', success: true);
              }
            } else {
              await AdminRepository().updateRoute(route['id'], data);
              if (mounted) {
                _showSnackBar('Route updated successfully', success: true);
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
  void _confirmDelete(BuildContext context, Map<String, dynamic> route) {
    showDialog(
      context: context,
      builder: (ctx) => _DeleteConfirmDialog(
        routeName:
            route['routeName']?.toString() ?? 'this route',
        onConfirm: () async {
          Navigator.pop(ctx);
          // Check if route is in use
          bool inUse = false;
          try {
            inUse =
                await AdminRepository().checkRouteInUse(route['id']);
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
                    const Text('Cannot Delete'),
                  ],
                ),
                content: Text(
                  '"${route['routeName'] ?? 'This route'}" is currently assigned to active students or bus passes. '
                  'Please reassign students before deleting this route.',
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

          try {
            await AdminRepository().deleteRoute(route['id']);
            if (mounted) {
              _showSnackBar('Route deleted', success: true);
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

  void _showSnackBar(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ============================================================
// ROUTE FORM BOTTOM SHEET
// ============================================================

class _RouteFormSheet extends StatefulWidget {
  final Map<String, dynamic>? route;
  final AsyncValue<List<Map<String, dynamic>>> busesAsync;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _RouteFormSheet({
    required this.route,
    required this.busesAsync,
    required this.onSave,
  });

  @override
  State<_RouteFormSheet> createState() => _RouteFormSheetState();
}

class _RouteFormSheetState extends State<_RouteFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _numberCtrl;
  late TextEditingController _sourceCtrl;
  late TextEditingController _destCtrl;
  late TextEditingController _distanceCtrl;
  late TextEditingController _timeCtrl;
  late TextEditingController _fareCtrl;

  // Intermediate stops (dynamic list)
  final List<TextEditingController> _stopControllers = [];

  String _status = 'Active';
  String? _assignedBusId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.route;

    _nameCtrl =
        TextEditingController(text: r?['routeName']?.toString() ?? '');
    _numberCtrl =
        TextEditingController(text: r?['routeNumber']?.toString() ?? '');
    _sourceCtrl =
        TextEditingController(text: r?['source']?.toString() ?? '');
    _destCtrl =
        TextEditingController(text: r?['destination']?.toString() ?? '');
    _distanceCtrl =
        TextEditingController(text: r?['distanceKm']?.toString() ?? '');
    _timeCtrl = TextEditingController(
        text: r?['estimatedTime']?.toString() ?? '');
    _fareCtrl =
        TextEditingController(text: r?['fare']?.toString() ?? '');
    _status = r?['status']?.toString() ?? 'Active';
    _assignedBusId = r?['assignedBusId']?.toString();

    // Populate existing stops
    final stops = r?['stops'];
    if (stops is List && stops.isNotEmpty) {
      for (final s in stops) {
        _stopControllers
            .add(TextEditingController(text: s.toString()));
      }
    } else {
      _stopControllers.add(TextEditingController()); // start with one
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _sourceCtrl.dispose();
    _destCtrl.dispose();
    _distanceCtrl.dispose();
    _timeCtrl.dispose();
    _fareCtrl.dispose();
    for (final c in _stopControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final stops = _stopControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final fareText = _fareCtrl.text.trim().replaceAll(',', '');
    final fareValue = double.tryParse(fareText) ?? 0.0;

    final distText = _distanceCtrl.text.trim().replaceAll(',', '');
    final distValue = double.tryParse(distText) ?? 0.0;

    final data = <String, dynamic>{
      'routeName': _nameCtrl.text.trim(),
      'routeNumber': _numberCtrl.text.trim(),
      'source': _sourceCtrl.text.trim(),
      'destination': _destCtrl.text.trim(),
      'stops': stops,
      'distanceKm': distValue,
      'estimatedTime': _timeCtrl.text.trim(),
      'fare': fareValue,
      'assignedBusId':
          (_assignedBusId?.isNotEmpty ?? false) ? _assignedBusId : null,
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
    final isEdit = widget.route != null;
    final buses = widget.busesAsync.valueOrNull ?? [];

    // Filter out duplicates and ensure bus IDs are unique and non-empty
    final uniqueBuses = <String, Map<String, dynamic>>{};
    for (final bus in buses) {
      final busId = bus['id']?.toString() ?? '';
      if (busId.isNotEmpty) {
        uniqueBuses[busId] = bus;
      }
    }

    // Automatically set the value to null if it no longer exists in the unique list
    if (_assignedBusId != null && !uniqueBuses.containsKey(_assignedBusId)) {
      _assignedBusId = null;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.97,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(28)),
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
                            color: AppColors.primaryCrimson
                                .withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEdit
                                ? Icons.edit_road_rounded
                                : Icons.add_road_rounded,
                            color: AppColors.primaryCrimson,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Edit Route' : 'Add New Route',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              isEdit
                                  ? 'Update route information'
                                  : 'Fill in the route details below',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B)),
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
                      // ── Section: Basic Info ──
                      _SectionHeader(
                          title: 'Basic Information',
                          icon: Icons.info_outline_rounded),
                      const SizedBox(height: 12),

                      // Route Name
                      _FormField(
                        controller: _nameCtrl,
                        label: 'Route Name *',
                        hint: 'e.g. Route A – Wakad & Hinjewadi',
                        icon: Icons.route_rounded,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Route name is required'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Route Number
                      _FormField(
                        controller: _numberCtrl,
                        label: 'Route Number *',
                        hint: 'e.g. RT-01',
                        icon: Icons.tag_rounded,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Route number is required'
                            : null,
                      ),
                      const SizedBox(height: 24),

                      // ── Section: Stops ──
                      _SectionHeader(
                          title: 'Route Stops',
                          icon: Icons.location_on_rounded),
                      const SizedBox(height: 12),

                      // Source
                      _FormField(
                        controller: _sourceCtrl,
                        label: 'Source / Origin *',
                        hint: 'e.g. Wakad Chowk',
                        icon: Icons.trip_origin_rounded,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Source is required'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Destination
                      _FormField(
                        controller: _destCtrl,
                        label: 'Destination *',
                        hint: 'e.g. ICEM Campus',
                        icon: Icons.flag_rounded,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Destination is required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Intermediate Stops
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Intermediate Stops',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => setState(() =>
                                _stopControllers
                                    .add(TextEditingController())),
                            icon: const Icon(Icons.add_circle_outline,
                                size: 16,
                                color: AppColors.primaryCrimson),
                            label: const Text(
                              'Add Stop',
                              style: TextStyle(
                                  color: AppColors.primaryCrimson,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Dynamic stop fields
                      ...List.generate(_stopControllers.length,
                          (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              // Stop number indicator
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF94A3B8)
                                      .withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _stopControllers[i],
                                  decoration: InputDecoration(
                                    hintText:
                                        'Stop ${i + 1} name',
                                    hintStyle: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF94A3B8)),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: AppColors
                                              .primaryCrimson),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12),
                                  ),
                                  style:
                                      const TextStyle(fontSize: 13),
                                ),
                              ),
                              if (_stopControllers.length > 1)
                                IconButton(
                                  icon: const Icon(
                                      Icons
                                          .remove_circle_outline_rounded,
                                      color: AppColors.error,
                                      size: 20),
                                  onPressed: () => setState(() {
                                    _stopControllers[i].dispose();
                                    _stopControllers.removeAt(i);
                                  }),
                                ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 24),

                      // ── Section: Distance & Time ──
                      _SectionHeader(
                          title: 'Distance & Time',
                          icon: Icons.straighten_rounded),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _FormField(
                              controller: _distanceCtrl,
                              label: 'Distance (KM) *',
                              hint: 'e.g. 18.5',
                              icon: Icons.straighten_rounded,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*')),
                              ],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                if (double.tryParse(
                                        v.trim()) ==
                                    null) {
                                  return 'Invalid number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FormField(
                              controller: _timeCtrl,
                              label: 'Est. Travel Time *',
                              hint: 'e.g. 45 mins',
                              icon: Icons.timer_outlined,
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Required'
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Section: Fare & Bus ──
                      _SectionHeader(
                          title: 'Fare & Assignment',
                          icon: Icons.currency_rupee_rounded),
                      const SizedBox(height: 12),

                      // Fare
                      _FormField(
                        controller: _fareCtrl,
                        label: 'Fare (₹) *',
                        hint: 'e.g. 4500',
                        icon: Icons.currency_rupee_rounded,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Fare is required';
                          }
                          if (double.tryParse(v.trim()) == null) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Assigned Bus (optional dropdown)
                      DropdownButtonFormField<String>(
                        value: (_assignedBusId == null || !uniqueBuses.containsKey(_assignedBusId)) ? null : _assignedBusId,
                        decoration: InputDecoration(
                          labelText: 'Assigned Bus (optional)',
                          labelStyle: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B)),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Image.asset('assets/images/bus_logo.png', width: 20, height: 20),
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.primaryCrimson),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                        ),
                        style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF0F172A)),
                        hint: const Text('No bus assigned'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No bus assigned'),
                          ),
                          ...uniqueBuses.values.map((bus) {
                            final busId = bus['id'] ?? '';
                            final busLabel =
                                bus['busNumber'] ??
                                    bus['busName'] ??
                                    bus['name'] ??
                                    busId;
                            return DropdownMenuItem<String>(
                              value: busId.toString(),
                              child: Text(busLabel.toString()),
                            );
                          }),
                        ],
                        onChanged: (v) =>
                            setState(() => _assignedBusId = v),
                      ),
                      const SizedBox(height: 24),

                      // ── Status Toggle ──
                      _SectionHeader(
                          title: 'Route Status',
                          icon: Icons.toggle_on_rounded),
                      const SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: ['Active', 'Inactive']
                              .map((s) {
                            final selected = _status == s;
                            final isActive = s == 'Active';
                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _status = s),
                                child: AnimatedContainer(
                                  duration: const Duration(
                                      milliseconds: 200),
                                  margin:
                                      const EdgeInsets.all(4),
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 12),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? (isActive
                                            ? AppColors.success
                                                .withOpacity(0.12)
                                            : AppColors.error
                                                .withOpacity(0.08))
                                        : Colors.transparent,
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    border: selected
                                        ? Border.all(
                                            color: isActive
                                                ? AppColors.success
                                                : AppColors.error,
                                            width: 1.5)
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isActive
                                            ? Icons
                                                .check_circle_rounded
                                            : Icons
                                                .cancel_rounded,
                                        size: 16,
                                        color: selected
                                            ? (isActive
                                                ? AppColors.success
                                                : AppColors.error)
                                            : const Color(
                                                0xFF94A3B8),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        s,
                                        style: TextStyle(
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontSize: 13,
                                          color: selected
                                              ? (isActive
                                                  ? AppColors.success
                                                  : AppColors.error)
                                              : const Color(
                                                  0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.primaryCrimson,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.primaryCrimson
                                    .withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isEdit
                                      ? 'Save Changes'
                                      : 'Add Route',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
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
}

// ============================================================
// ROUTE CARD
// ============================================================

class _RouteCard extends StatelessWidget {
  final Map<String, dynamic> route;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RouteCard({
    required this.route,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = route['routeName']?.toString() ?? 'Unnamed Route';
    final number = route['routeNumber']?.toString() ?? '';
    final source = route['source']?.toString() ?? '';
    final dest = route['destination']?.toString() ?? '';
    final fareRaw = route['fare'];
    final fare = fareRaw is num
        ? fareRaw.toDouble()
        : double.tryParse(fareRaw?.toString() ?? '') ?? 0.0;
    final distance = route['distanceKm'];
    final distStr = distance is num
        ? '${distance.toStringAsFixed(1)} km'
        : distance?.toString() ?? '';
    final status = route['status']?.toString() ?? 'Active';
    final isActive = status == 'Active';
    final stops = route['stops'];
    final stopsCount = stops is List ? stops.length : 0;
    final assignedBus = route['assignedBusId']?.toString() ?? '';

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 50)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? AppColors.success.withOpacity(0.15)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header Row ──
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 16, 8, 12),
              child: Row(
                children: [
                  // Route icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primaryCrimson.withOpacity(0.1)
                          : const Color(0xFF94A3B8).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.route_rounded,
                      color: isActive
                          ? AppColors.primaryCrimson
                          : const Color(0xFF94A3B8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Route name + number
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (number.isNotEmpty)
                          Text(
                            number,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Route Path ──
            if (source.isNotEmpty || dest.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    const Icon(Icons.trip_origin_rounded,
                        size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        source,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 14, color: Color(0xFF94A3B8)),
                    ),
                    const Icon(Icons.flag_rounded,
                        size: 14, color: AppColors.primaryCrimson),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dest,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Stats Row ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  _StatChip(
                    icon: Icons.currency_rupee_rounded,
                    label: fare > 0
                        ? '₹${fare.toStringAsFixed(0)}'
                        : 'N/A',
                    color: AppColors.accentGold,
                  ),
                  const SizedBox(width: 8),
                  if (distStr.isNotEmpty)
                    _StatChip(
                      icon: Icons.straighten_rounded,
                      label: distStr,
                      color: AppColors.info,
                    ),
                  if (distStr.isNotEmpty) const SizedBox(width: 8),
                  if (stopsCount > 0)
                    _StatChip(
                      icon: Icons.location_on_rounded,
                      label: '$stopsCount stops',
                      color: AppColors.success,
                    ),
                  const Spacer(),

                  // Action buttons
                  _ActionIconBtn(
                    icon: Icons.edit_rounded,
                    color: AppColors.info,
                    onTap: onEdit,
                    tooltip: 'Edit route',
                  ),
                  const SizedBox(width: 4),
                  _ActionIconBtn(
                    icon: Icons.delete_rounded,
                    color: AppColors.error,
                    onTap: onDelete,
                    tooltip: 'Delete route',
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
// DELETE CONFIRM DIALOG
// ============================================================

class _DeleteConfirmDialog extends StatelessWidget {
  final String routeName;
  final VoidCallback onConfirm;

  const _DeleteConfirmDialog({
    required this.routeName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delete_rounded,
                color: AppColors.error, size: 22),
          ),
          const SizedBox(width: 12),
          const Text(
            'Delete Route',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.5),
          children: [
            const TextSpan(text: 'Are you sure you want to delete '),
            TextSpan(
              text: '"$routeName"',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A)),
            ),
            const TextSpan(
                text:
                    '?\n\nThis action cannot be undone. If the route is assigned to active students, deletion will be blocked.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: onConfirm,
          icon: const Icon(Icons.delete_rounded, size: 16),
          label: const Text('Delete'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SHARED SMALL WIDGETS
// ============================================================

class _RouteSearchBar extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _RouteSearchBar(
      {required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: 'Search by name, number, source, destination…',
        hintStyle:
            const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        prefixIcon: const Icon(Icons.search_rounded,
            color: Color(0xFF94A3B8), size: 20),
        suffixIcon: value.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: Color(0xFF94A3B8)),
                onPressed: () => onChanged(''),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: AppColors.primaryCrimson, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _AddRouteButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddRouteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Add Route'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryCrimson,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        elevation: 0,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryCrimson),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _FormField({
    required this.controller,
    required this.label,
    this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        hintStyle:
            const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
          borderSide: const BorderSide(
              color: AppColors.primaryCrimson, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
