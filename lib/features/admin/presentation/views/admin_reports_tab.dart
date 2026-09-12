// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/driver/domain/driver_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_charts.dart';
import 'package:icem_bus/features/admin/presentation/views/report_exporter.dart';

class AdminReportsTab extends ConsumerStatefulWidget {
  const AdminReportsTab({super.key});

  @override
  ConsumerState<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends ConsumerState<AdminReportsTab> {
  String _searchQuery = '';
  String _filterType = 'This Month';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  int _selectedReportTab = 0; // 0: Students, 1: Buses, 2: Routes, 3: Payments, 4: Passes

  @override
  void initState() {
    super.initState();
    // Default custom date range to current month
    final now = DateTime.now();
    _customStartDate = DateTime(now.year, now.month, 1);
    _customEndDate = DateTime(now.year, now.month + 1, 0);
  }

  /// Calculates the active DateTimeRange based on the selected filter type.
  DateTimeRange _getCurrentDateRange() {
    final now = DateTime.now();
    switch (_filterType) {
      case 'Today':
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day, 0, 0, 0),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case 'This Week':
        final dayOffset = now.weekday - 1;
        final start = DateTime(now.year, now.month, now.day - dayOffset, 0, 0, 0);
        final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        return DateTimeRange(start: start, end: end);
      case 'This Month':
        final start = DateTime(now.year, now.month, 1, 0, 0, 0);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case 'This Year':
        final start = DateTime(now.year, 1, 1, 0, 0, 0);
        final end = DateTime(now.year, 12, 31, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case 'Custom Date Range':
        if (_customStartDate != null && _customEndDate != null) {
          return DateTimeRange(
            start: DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day, 0, 0, 0),
            end: DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59),
          );
        }
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1, 0, 0, 0),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      default:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1, 0, 0, 0),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
    }
  }

  /// Date parser helper
  DateTime? _getDocDate(Map<String, dynamic> doc, String fieldKey) {
    final val = doc[fieldKey];
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    return null;
  }

  /// Date formatter helper
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
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  /// Display name of selected date filter range
  String _getDateRangeString(DateTimeRange range) {
    return '${_formatDate(range.start)} - ${_formatDate(range.end)}';
  }

  /// Launch the custom Date Range Picker dialog
  Future<void> _selectCustomDateRange() async {
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryCrimson,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _customStartDate = pickedRange.start;
        _customEndDate = pickedRange.end;
        _filterType = 'Custom Date Range';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch raw streams
    final studentsAsync = ref.watch(studentsListStreamProvider);
    final driversAsync = ref.watch(driversListStreamProvider);
    final busesAsync = ref.watch(busesListStreamProvider);
    final routesAsync = ref.watch(routesListStreamProvider);
    final paymentsAsync = ref.watch(paymentsListStreamProvider);
    final passesAsync = ref.watch(busPassesListStreamProvider);
    final appsAsync = ref.watch(applicationsListStreamProvider);

    // Resolve data lists safely
    final students = studentsAsync.value ?? [];
    final drivers = driversAsync.value ?? [];
    final buses = busesAsync.value ?? [];
    final routes = routesAsync.value ?? [];
    final payments = paymentsAsync.value ?? [];
    final passes = passesAsync.value ?? [];
    final apps = appsAsync.value ?? [];

    String getStatValue(AsyncValue asyncData, List<Map<String, dynamic>> filteredList, {int Function(List<Map<String, dynamic>>)? customCounter}) {
      if (asyncData.hasError) return 'Error';
      if (asyncData.isLoading && !asyncData.hasValue) return '...';
      if (customCounter != null) return customCounter(filteredList).toString();
      return filteredList.length.toString();
    }

    String getRevenueStat(AsyncValue asyncData, List<Map<String, dynamic>> filteredPayments) {
      if (asyncData.hasError) return 'Error';
      if (asyncData.isLoading && !asyncData.hasValue) return '...';
      double total = 0.0;
      for (final p in filteredPayments) {
        if (p['paymentStatus'] == 'Paid') {
          final amt = p['amount'];
          if (amt is num) total += amt.toDouble();
          else if (amt is String) total += double.tryParse(amt) ?? 0.0;
        }
      }
      return '₹${total.toStringAsFixed(0)}';
    }


    // Filter range boundaries
    final range = _getCurrentDateRange();
    final start = range.start;
    final end = range.end;

    bool isWithinRange(DateTime? date) {
      if (date == null) return false;
      return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          date.isBefore(end.add(const Duration(seconds: 1)));
    }

    // Apply date range filters
    final filteredStudents = students.where((s) => isWithinRange(_getDocDate(s, 'createdAt'))).toList();
    final filteredDrivers = drivers.where((d) => isWithinRange(_getDocDate(d, 'createdAt'))).toList();
    final filteredBuses = buses.where((b) => isWithinRange(_getDocDate(b, 'createdAt'))).toList();
    final filteredRoutes = routes.where((r) => isWithinRange(_getDocDate(r, 'createdAt'))).toList();
    final filteredPayments = payments.where((p) => isWithinRange(_getDocDate(p, 'paymentDate') ?? _getDocDate(p, 'createdAt'))).toList();
    final filteredPasses = passes.where((ps) => isWithinRange(_getDocDate(ps, 'createdAt') ?? _getDocDate(ps, 'updatedAt'))).toList();
    final filteredApps = apps.where((a) => isWithinRange(_getDocDate(a, 'createdAt'))).toList();

    // 1. Stats logic is now handled in the getter methods.

    // 2. Charts Data computations
    // Helper to group by month
    String formatMonthYear(DateTime date) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.year}';
    }

    // Group pass applications by Month
    final Map<String, double> appCountsByMonth = {};
    for (final a in filteredApps) {
      final date = _getDocDate(a, 'createdAt');
      if (date != null) {
        final key = formatMonthYear(date);
        appCountsByMonth[key] = (appCountsByMonth[key] ?? 0.0) + 1;
      }
    }

    // Group paid revenue by Month
    final Map<String, double> revenueByMonth = {};
    for (final p in filteredPayments) {
      if (p['paymentStatus'] == 'Paid') {
        final date = _getDocDate(p, 'paymentDate') ?? _getDocDate(p, 'createdAt');
        if (date != null) {
          final key = formatMonthYear(date);
          final amt = p['amount'];
          double value = 0.0;
          if (amt is num) {
            value = amt.toDouble();
          } else if (amt is String) {
            value = double.tryParse(amt) ?? 0.0;
          }
          revenueByMonth[key] = (revenueByMonth[key] ?? 0.0) + value;
        }
      }
    }

    // Convert grouped values to ChartDataPoints. If empty, generate standard 6 months fallback.
    List<ChartDataPoint> generateChartData(Map<String, double> dataMap) {
      if (dataMap.isEmpty) {
        final fallbackList = <ChartDataPoint>[];
        final now = DateTime.now();
        for (int i = 5; i >= 0; i--) {
          final d = DateTime(now.year, now.month - i, 1);
          final key = formatMonthYear(d);
          fallbackList.add(ChartDataPoint(key, 0.0));
        }
        return fallbackList;
      }
      return dataMap.entries
          .map((e) => ChartDataPoint(e.key, e.value))
          .toList()
        ..sort((a, b) {
          // Simple month sorting: parse keys to dates
          DateTime parseKey(String key) {
            final parts = key.split(' ');
            if (parts.length < 2) return DateTime.now();
            const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            final mIndex = months.indexOf(parts[0]) + 1;
            final y = int.tryParse(parts[1]) ?? 2026;
            return DateTime(y, mIndex);
          }
          return parseKey(a.label).compareTo(parseKey(b.label));
        });
    }

    final passAppsPoints = generateChartData(appCountsByMonth);
    final revenuePoints = generateChartData(revenueByMonth);

    // Pass status distribution donut data
    final activePassesCount = filteredPasses.where((p) => p['passStatus'] == 'Active').length.toDouble();
    final expiredPassesCount = filteredPasses.where((p) => p['passStatus'] == 'Expired').length.toDouble();
    final Map<String, double> passDistribution = {
      'Active': activePassesCount,
      'Expired': expiredPassesCount,
      'Suspended': filteredPasses.where((p) => p['passStatus'] == 'Suspended').length.toDouble(),
    };
    final otherPassStatusCount = filteredPasses
        .where((p) => p['passStatus'] != 'Active' && p['passStatus'] != 'Expired' && p['passStatus'] != 'Suspended')
        .length
        .toDouble();
    if (otherPassStatusCount > 0) {
      passDistribution['Other'] = otherPassStatusCount;
    }

    // Route-wise student count
    final Map<String, double> routeWiseCounts = {};
    for (final pass in filteredPasses) {
      final routeName = pass['route'] ?? pass['routeName'] ?? 'Unknown Route';
      routeWiseCounts[routeName] = (routeWiseCounts[routeName] ?? 0.0) + 1;
    }
    final routePoints = routeWiseCounts.entries
        .map((e) => ChartDataPoint(e.key, e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topRoutes = routePoints.take(5).toList();

    // Bus-wise student count (Map passes -> route -> assignedBus)
    final routeToBusMap = <String, String>{};
    for (final bus in filteredBuses) {
      final routeId = bus['assignedRouteId'] as String?;
      final busNo = bus['busNo'] as String? ?? 'Bus-${bus['busId']}';
      if (routeId != null && routeId.isNotEmpty) {
        routeToBusMap[routeId] = busNo;
      }
    }
    final Map<String, double> busWiseCounts = {};
    for (final pass in filteredPasses) {
      final rId = pass['routeId'] as String?;
      if (rId != null && rId.isNotEmpty) {
        final busNo = routeToBusMap[rId] ?? 'No Bus Assigned';
        busWiseCounts[busNo] = (busWiseCounts[busNo] ?? 0.0) + 1;
      } else {
        busWiseCounts['No Route Assigned'] = (busWiseCounts['No Route Assigned'] ?? 0.0) + 1;
      }
    }
    final busPoints = busWiseCounts.entries
        .map((e) => ChartDataPoint(e.key, e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topBuses = busPoints.take(5).toList();

    // Driver-wise Bus Assignment (Assigned vs Unassigned)
    final driversAssigned = filteredDrivers.where((d) => d['assignedBusId'] != null && d['assignedBusId'].toString().isNotEmpty).length.toDouble();
    final driversUnassigned = filteredDrivers.length.toDouble() - driversAssigned;
    final Map<String, double> driverBusAssignment = {};
    if (driversAssigned > 0) driverBusAssignment['Assigned'] = driversAssigned;
    if (driversUnassigned > 0) driverBusAssignment['Unassigned'] = driversUnassigned;

    // 3. Apply Search query to active reports lists
    final search = _searchQuery.trim().toLowerCase();

    List<Map<String, dynamic>> getSearchedStudents() {
      if (search.isEmpty) return filteredStudents;
      return filteredStudents.where((s) {
        final name = (s['fullName'] ?? '').toString().toLowerCase();
        final prn = (s['prn'] ?? '').toString().toLowerCase();
        final email = (s['email'] ?? '').toString().toLowerCase();
        return name.contains(search) || prn.contains(search) || email.contains(search);
      }).toList();
    }

    List<Map<String, dynamic>> getSearchedDrivers() {
      if (search.isEmpty) return filteredDrivers;
      return filteredDrivers.where((d) {
        final name = (d['fullName'] ?? '').toString().toLowerCase();
        final driverId = (d['driverId'] ?? '').toString().toLowerCase();
        final mobile = (d['mobile'] ?? '').toString().toLowerCase();
        return name.contains(search) || driverId.contains(search) || mobile.contains(search);
      }).toList();
    }

    List<Map<String, dynamic>> getSearchedBuses() {
      if (search.isEmpty) return filteredBuses;
      return filteredBuses.where((b) {
        final busNo = (b['busNo'] ?? '').toString().toLowerCase();
        final driverName = (b['driverName'] ?? '').toString().toLowerCase();
        return busNo.contains(search) || driverName.contains(search);
      }).toList();
    }

    List<Map<String, dynamic>> getSearchedRoutes() {
      if (search.isEmpty) return filteredRoutes;
      return filteredRoutes.where((r) {
        final routeName = (r['routeName'] ?? '').toString().toLowerCase();
        final start = (r['startLocation'] ?? '').toString().toLowerCase();
        final end = (r['endLocation'] ?? '').toString().toLowerCase();
        return routeName.contains(search) || start.contains(search) || end.contains(search);
      }).toList();
    }

    List<Map<String, dynamic>> getSearchedPayments() {
      if (search.isEmpty) return filteredPayments;
      return filteredPayments.where((p) {
        final receiptId = (p['receiptId'] ?? '').toString().toLowerCase();
        final name = (p['studentName'] ?? '').toString().toLowerCase();
        final prn = (p['prn'] ?? '').toString().toLowerCase();
        return receiptId.contains(search) || name.contains(search) || prn.contains(search);
      }).toList();
    }

    List<Map<String, dynamic>> getSearchedPasses() {
      if (search.isEmpty) return filteredPasses;
      return filteredPasses.where((ps) {
        final passId = (ps['passId'] ?? '').toString().toLowerCase();
        final name = (ps['studentName'] ?? ps['fullName'] ?? '').toString().toLowerCase();
        final prn = (ps['prn'] ?? '').toString().toLowerCase();
        final routeName = (ps['route'] ?? ps['routeName'] ?? '').toString().toLowerCase();
        return passId.contains(search) || name.contains(search) || prn.contains(search) || routeName.contains(search);
      }).toList();
    }

    final currentStudentsReport = getSearchedStudents();
    final currentDriversReport = getSearchedDrivers();
    final currentBusesReport = getSearchedBuses();
    final currentRoutesReport = getSearchedRoutes();
    final currentPaymentsReport = getSearchedPayments();
    final currentPassesReport = getSearchedPasses();

    // Responsive screen width adjustments
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 950;
    final isTablet = width >= 650 && width < 950;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER SECTION ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reports & Analytics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Real-time metrics, interactive charts, and system export features.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (_filterType == 'Custom Date Range')
                TextButton.icon(
                  onPressed: _selectCustomDateRange,
                  icon: const Icon(Icons.edit_calendar_rounded, size: 16, color: AppColors.primaryCrimson),
                  label: const Text('Change Date Range', style: TextStyle(color: AppColors.primaryCrimson, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // ── FILTERS AND SEARCH BAR ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.date_range_rounded, color: Color(0xFF64748B), size: 18),
                    const SizedBox(width: 8),
                    const Text('Filter Date Range:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                    const SizedBox(width: 8),
                    Text(
                      _getDateRangeString(range),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primaryCrimson),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AdminFilterChips(
                  filters: const ['Today', 'This Week', 'This Month', 'This Year', 'Custom Date Range'],
                  selected: _filterType,
                  onSelected: (val) async {
                    if (val == 'Custom Date Range') {
                      await _selectCustomDateRange();
                    } else {
                      setState(() {
                        _filterType = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),
                AdminSearchBar(
                  hintText: 'Search report data by Student, PRN, Route or Bus...',
                  value: _searchQuery,
                  onChanged: (q) => setState(() => _searchQuery = q),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── DASHBOARD STATISTICS GRID ──
          const AdminSectionHeader(title: 'Dashboard Statistics'),
          const SizedBox(height: 12),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 3 : (isTablet ? 3 : 2),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isDesktop ? 1.4 : (isTablet ? 1.3 : 0.85), // Adjusted for mobile to prevent vertical overflow
            ),
            children: [
              AdminStatCard(
                label: 'Total Students',
                value: getStatValue(studentsAsync, filteredStudents),
                icon: Icons.people_alt_rounded,
                color: AppColors.info,
              ),
              AdminStatCard(
                label: 'Active Students',
                value: getStatValue(studentsAsync, filteredStudents, customCounter: (list) => list.where((s) => s['isActive'] == true).length),
                icon: Icons.person_add_alt_1_rounded,
                color: AppColors.success,
              ),
              AdminStatCard(
                label: 'Total Drivers',
                value: getStatValue(driversAsync, filteredDrivers),
                icon: Icons.person_pin_circle_rounded,
                color: Colors.blue,
              ),
              AdminStatCard(
                label: 'Total Buses',
                value: getStatValue(busesAsync, filteredBuses),
                icon: Icons.directions_bus_rounded,
                color: Colors.purple,
              ),
              AdminStatCard(
                label: 'Total Routes',
                value: getStatValue(routesAsync, filteredRoutes),
                icon: Icons.route_rounded,
                color: Colors.deepOrange,
              ),
              AdminStatCard(
                label: 'Active Passes',
                value: getStatValue(passesAsync, filteredPasses, customCounter: (list) => list.where((p) => p['passStatus'] == 'Active').length),
                icon: Icons.badge_rounded,
                color: AppColors.success,
              ),
              AdminStatCard(
                label: 'Pending Applications',
                value: getStatValue(appsAsync, filteredApps, customCounter: (list) => list.where((a) => a['status'] == 'Pending').length),
                icon: Icons.hourglass_empty_rounded,
                color: Colors.amber.shade800,
              ),
              AdminStatCard(
                label: 'Approved Applications',
                value: getStatValue(appsAsync, filteredApps, customCounter: (list) => list.where((a) => a['status'] == 'Approved').length),
                icon: Icons.verified_rounded,
                color: Colors.teal,
              ),
              AdminStatCard(
                label: 'Rejected Applications',
                value: getStatValue(appsAsync, filteredApps, customCounter: (list) => list.where((a) => a['status'] == 'Rejected').length),
                icon: Icons.gpp_bad_rounded,
                color: AppColors.error,
              ),
              AdminStatCard(
                label: 'Expired Passes',
                value: getStatValue(passesAsync, filteredPasses, customCounter: (list) => list.where((p) => p['passStatus'] == 'Expired').length),
                icon: Icons.running_with_errors_rounded,
                color: Colors.blueGrey,
              ),
              AdminStatCard(
                label: 'Total Revenue',
                value: getRevenueStat(paymentsAsync, filteredPayments),
                icon: Icons.currency_rupee_rounded,
                color: Colors.indigo,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── CHARTS SECTION ──
          const AdminSectionHeader(title: 'Visual Analytics'),
          const SizedBox(height: 12),
          if (isDesktop) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LineAreaChart(
                    data: passAppsPoints,
                    title: 'Monthly Pass Applications',
                    primaryColor: AppColors.primaryCrimson,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LineAreaChart(
                    data: revenuePoints,
                    title: 'Monthly Revenue Stream',
                    primaryColor: Colors.indigo,
                    valuePrefix: '₹',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DonutChartWidget(
                    data: passDistribution,
                    title: 'Pass Status Distribution',
                    colors: const [AppColors.success, AppColors.warning, AppColors.error, Colors.blueGrey],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: HorizontalBarChart(
                    data: topRoutes,
                    title: 'Top Routes by Passenger Load',
                    barColor: Colors.deepOrange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: HorizontalBarChart(
                    data: topBuses,
                    title: 'Top Buses by Passenger Load',
                    barColor: Colors.purple,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DonutChartWidget(
                    data: driverBusAssignment,
                    title: 'Driver Bus Assignment',
                    colors: const [AppColors.info, AppColors.warning],
                  ),
                ),
              ],
            ),
          ] else ...[
            LineAreaChart(
              data: passAppsPoints,
              title: 'Monthly Pass Applications',
              primaryColor: AppColors.primaryCrimson,
            ),
            const SizedBox(height: 16),
            LineAreaChart(
              data: revenuePoints,
              title: 'Monthly Revenue Stream',
              primaryColor: Colors.indigo,
              valuePrefix: '₹',
            ),
            const SizedBox(height: 16),
            DonutChartWidget(
              data: passDistribution,
              title: 'Pass Status Distribution',
              colors: const [AppColors.success, AppColors.warning, AppColors.error, Colors.blueGrey],
            ),
            const SizedBox(height: 16),
            HorizontalBarChart(
              data: topRoutes,
              title: 'Top Routes by Passenger Load',
              barColor: Colors.deepOrange,
            ),
            const SizedBox(height: 16),
            HorizontalBarChart(
              data: topBuses,
              title: 'Top Buses by Passenger Load',
              barColor: Colors.purple,
            ),
            const SizedBox(height: 16),
            DonutChartWidget(
              data: driverBusAssignment,
              title: 'Driver Bus Assignment',
              colors: const [AppColors.info, AppColors.warning],
            ),
          ],
          const SizedBox(height: 32),

          // ── REPORTS EXPLORER TABS ──
          const AdminSectionHeader(title: 'Reports Explorer'),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildReportTabButton(0, 'Students Report', Icons.people_outline_rounded),
                _buildReportTabButton(5, 'Driver Report', Icons.person_pin_circle_rounded),
                _buildReportTabButton(1, 'Buses Report', null, Image.asset('assets/images/bus_logo.png', width: 16, height: 16, color: _selectedReportTab == 1 ? Colors.white : const Color(0xFF475569), fit: BoxFit.contain)),
                _buildReportTabButton(2, 'Routes Report', Icons.route_outlined),
                _buildReportTabButton(3, 'Payments Report', Icons.payment_rounded),
                _buildReportTabButton(4, 'Passes Report', Icons.badge_outlined),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Active report details card
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFF1F5F9)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab header actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getReportTabTitle(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _handleExport(isPdf: false, dateRangeStr: _getDateRangeString(range)),
                            icon: const Icon(Icons.grid_on_rounded, size: 14, color: AppColors.success),
                            label: const Text('Export Excel (CSV)', style: TextStyle(color: AppColors.success, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.success),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _handleExport(isPdf: true, dateRangeStr: _getDateRangeString(range)),
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 14, color: Colors.white),
                            label: const Text('Export PDF', style: TextStyle(color: Colors.white, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryCrimson,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),

                  // Table content rendering
                  _buildSelectedReportContent(
                    studentsAsync: studentsAsync,
                    driversAsync: driversAsync,
                    busesAsync: busesAsync,
                    routesAsync: routesAsync,
                    paymentsAsync: paymentsAsync,
                    passesAsync: passesAsync,
                    studentsReport: currentStudentsReport,
                    driversReport: currentDriversReport,
                    busesReport: currentBusesReport,
                    routesReport: currentRoutesReport,
                    paymentsReport: currentPaymentsReport,
                    passesReport: currentPassesReport,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildReportTabButton(int index, String title, IconData? icon, [Widget? customIcon]) {
    final isSelected = _selectedReportTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            customIcon ?? Icon(
                    icon,
                    size: 16,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
            const SizedBox(width: 6),
            Text(title),
          ],
        ),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedReportTab = index;
          });
        },
        selectedColor: AppColors.primaryCrimson,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF475569),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? AppColors.primaryCrimson : const Color(0xFFE2E8F0),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  String _getReportTabTitle() {
    switch (_selectedReportTab) {
      case 0:
        return 'Registered Students List';
      case 1:
        return 'System Buses Directory';
      case 2:
        return 'System Routes Directory';
      case 3:
        return 'Student Payments History';
      case 4:
        return 'Issued Bus Passes';
      case 5:
        return 'System Drivers Directory';
      default:
        return 'Report Details';
    }
  }

  Widget _buildSelectedReportContent({
    required AsyncValue studentsAsync,
    required AsyncValue driversAsync,
    required AsyncValue busesAsync,
    required AsyncValue routesAsync,
    required AsyncValue paymentsAsync,
    required AsyncValue passesAsync,
    required List<Map<String, dynamic>> studentsReport,
    required List<Map<String, dynamic>> driversReport,
    required List<Map<String, dynamic>> busesReport,
    required List<Map<String, dynamic>> routesReport,
    required List<Map<String, dynamic>> paymentsReport,
    required List<Map<String, dynamic>> passesReport,
  }) {
    switch (_selectedReportTab) {
      case 0:
        if (studentsAsync.hasError) {
          return const AdminEmptyState(title: 'Error', subtitle: 'Unable to load this report', icon: Icons.error_outline_rounded);
        }
        if (studentsAsync.isLoading && studentsReport.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }
        if (studentsReport.isEmpty) {
          return const AdminEmptyState(
            title: 'No student records found',
            subtitle: 'No student registered or matches your search query in this range.',
            icon: Icons.people_alt_rounded,
          );
        }
        return _buildScrollableTable(
          headers: const ['Full Name', 'Email', 'Course', 'Status', 'Date Joined'],
          rows: studentsReport.map((s) => [
            s['fullName'] ?? '-',
            s['email'] ?? '-',
            s['course'] ?? '-',
            (s['isActive'] == false) ? 'Suspended' : 'Active',
            _formatDate(s['createdAt']),
          ]).toList(),
        );

      case 5:
        if (driversAsync.hasError) {
          return const AdminEmptyState(title: 'Error', subtitle: 'Unable to load this report', icon: Icons.error_outline_rounded);
        }
        if (driversAsync.isLoading && driversReport.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }
        if (driversReport.isEmpty) {
          return const AdminEmptyState(
            title: 'No driver records found',
            subtitle: 'No drivers added or matches your search query in this range.',
            icon: Icons.person_pin_circle_rounded,
          );
        }
        return _buildScrollableTable(
          headers: const ['Driver Name', 'Driver ID', 'Mobile', 'License No', 'Assigned Bus', 'Status'],
          rows: driversReport.map((d) => [
            d['fullName'] ?? '-',
            d['driverId'] ?? '-',
            d['mobile'] ?? '-',
            d['licenseNumber'] ?? '-',
            d['assignedBusNumber'] ?? 'Unassigned',
            d['status'] ?? '-',
          ]).toList(),
        );

      case 1:
        if (busesAsync.hasError) {
          return const AdminEmptyState(title: 'Error', subtitle: 'Unable to load this report', icon: Icons.error_outline_rounded);
        }
        if (busesAsync.isLoading && busesReport.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }
        if (busesReport.isEmpty) {
          return AdminEmptyState(
            title: 'No bus records found',
            subtitle: 'No buses added or matches your search query in this range.',
            customIcon: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Image.asset('assets/images/bus_logo.png', width: 36, height: 36),
            ),
          );
        }
        return _buildScrollableTable(
          headers: const ['Bus Number', 'Driver Name', 'Driver Phone', 'Status', 'Capacity'],
          rows: busesReport.map((b) => [
            b['busNo'] ?? '-',
            b['driverName'] ?? '-',
            b['driverPhone'] ?? '-',
            b['status'] ?? '-',
            b['capacity']?.toString() ?? '-',
          ]).toList(),
        );

      case 2:
        if (routesAsync.hasError) {
          return const AdminEmptyState(title: 'Error', subtitle: 'Unable to load this report', icon: Icons.error_outline_rounded);
        }
        if (routesAsync.isLoading && routesReport.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }
        if (routesReport.isEmpty) {
          return const AdminEmptyState(
            title: 'No route records found',
            subtitle: 'No routes defined or matches your search query in this range.',
            icon: Icons.route_rounded,
          );
        }
        return _buildScrollableTable(
          headers: const ['Route Name', 'Start Location', 'End Location', 'Stops Count', 'Status'],
          rows: routesReport.map((r) => [
            r['routeName'] ?? '-',
            r['startLocation'] ?? '-',
            r['endLocation'] ?? '-',
            (r['stops'] as List?)?.length.toString() ?? '0',
            r['status'] ?? '-',
          ]).toList(),
        );

      case 3:
        if (paymentsAsync.hasError) {
          return const AdminEmptyState(title: 'Error', subtitle: 'Unable to load this report', icon: Icons.error_outline_rounded);
        }
        if (paymentsAsync.isLoading && paymentsReport.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }
        if (paymentsReport.isEmpty) {
          return const AdminEmptyState(
            title: 'No payment records found',
            subtitle: 'No receipts paid or matches your search query in this range.',
            icon: Icons.receipt_long_rounded,
          );
        }
        return _buildScrollableTable(
          headers: const ['Receipt ID', 'Student Name', 'PRN', 'Amount', 'Payment Method', 'Date', 'Status'],
          rows: paymentsReport.map((p) => [
            p['receiptId'] ?? '-',
            p['studentName'] ?? '-',
            p['prn'] ?? '-',
            '₹${p['amount'] ?? 0}',
            p['paymentMethod'] ?? '-',
            _formatDate(p['paymentDate'] ?? p['createdAt']),
            p['paymentStatus'] ?? '-',
          ]).toList(),
        );

      case 4:
        if (passesAsync.hasError) {
          return const AdminEmptyState(title: 'Error', subtitle: 'Unable to load this report', icon: Icons.error_outline_rounded);
        }
        if (passesAsync.isLoading && passesReport.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }
        if (passesReport.isEmpty) {
          return const AdminEmptyState(
            title: 'No pass records found',
            subtitle: 'No passes issued or matches your search query in this range.',
            icon: Icons.badge_rounded,
          );
        }
        return _buildScrollableTable(
          headers: const ['Pass ID', 'Student Name', 'PRN', 'Route Assigned', 'Expiry Date', 'Status'],
          rows: passesReport.map((ps) => [
            ps['passId'] ?? 'N/A',
            ps['studentName'] ?? ps['fullName'] ?? 'Unknown',
            ps['prn'] ?? 'N/A',
            ps['route'] ?? ps['routeName'] ?? 'N/A',
            _formatDate(ps['expiryDate']),
            ps['passStatus'] ?? 'N/A',
          ]).toList(),
        );

      default:
        return const SizedBox();
    }
  }

  Widget _buildScrollableTable({
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
        dataRowColor: MaterialStateProperty.all(Colors.white),
        columnSpacing: 24.0,
        horizontalMargin: 8,
        headingRowHeight: 44,
        dataRowHeight: 48,
        border: TableBorder.symmetric(inside: const BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        columns: headers.map((header) {
          return DataColumn(
            label: Text(
              header,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
            ),
          );
        }).toList(),
        rows: rows.map((row) {
          return DataRow(
            cells: row.map((cell) {
              return DataCell(
                Text(
                  cell?.toString() ?? '',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  /// Initiates document exporting (PDF or CSV) based on user selections
  Future<void> _handleExport({required bool isPdf, required String dateRangeStr}) async {
    // Determine target lists and metadata
    String reportTitle = '';
    String filenamePrefix = '';
    List<String> headers = [];
    List<List<dynamic>> rows = [];

    // Watch raw streams manually in context
    final students = ref.read(studentsListStreamProvider).value ?? [];
    final drivers = ref.read(driversListStreamProvider).value ?? [];
    final buses = ref.read(busesListStreamProvider).value ?? [];
    final routes = ref.read(routesListStreamProvider).value ?? [];
    final payments = ref.read(paymentsListStreamProvider).value ?? [];
    final passes = ref.read(busPassesListStreamProvider).value ?? [];

    final range = _getCurrentDateRange();
    final start = range.start;
    final end = range.end;

    bool isWithinRange(DateTime? date) {
      if (date == null) return false;
      return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          date.isBefore(end.add(const Duration(seconds: 1)));
    }

    final search = _searchQuery.trim().toLowerCase();

    switch (_selectedReportTab) {
      case 0:
        reportTitle = 'Registered Students Report';
        filenamePrefix = 'students_report';
        headers = const ['Full Name', 'PRN', 'Email', 'Course', 'Status', 'Date Joined'];
        
        var list = students.where((s) => isWithinRange(_getDocDate(s, 'createdAt'))).toList();
        if (search.isNotEmpty) {
          list = list.where((s) {
            final name = (s['fullName'] ?? '').toString().toLowerCase();
            final prn = (s['prn'] ?? '').toString().toLowerCase();
            return name.contains(search) || prn.contains(search);
          }).toList();
        }
        
        rows = list.map((s) => [
          s['fullName'] ?? '-',
          s['prn'] ?? '-',
          s['email'] ?? '-',
          s['course'] ?? '-',
          (s['isActive'] == false) ? 'Suspended' : 'Active',
          _formatDate(s['createdAt']),
        ]).toList();
        break;

      case 5:
        reportTitle = 'System Drivers Directory Report';
        filenamePrefix = 'drivers_report';
        headers = const ['Driver Name', 'Driver ID', 'Mobile', 'License No', 'Assigned Bus', 'Status'];
        
        var list = drivers.where((d) => isWithinRange(_getDocDate(d, 'createdAt'))).toList();
        if (search.isNotEmpty) {
          list = list.where((d) {
            final name = (d['fullName'] ?? '').toString().toLowerCase();
            final driverId = (d['driverId'] ?? '').toString().toLowerCase();
            return name.contains(search) || driverId.contains(search);
          }).toList();
        }

        rows = list.map((d) => [
          d['fullName'] ?? '-',
          d['driverId'] ?? '-',
          d['mobile'] ?? '-',
          d['licenseNumber'] ?? '-',
          d['assignedBusNumber'] ?? 'Unassigned',
          d['status'] ?? '-',
        ]).toList();
        break;

      case 1:
        reportTitle = 'System Buses Directory Report';
        filenamePrefix = 'buses_report';
        headers = const ['Bus Number', 'Driver Name', 'Driver Phone', 'Status', 'Capacity'];
        
        var list = buses.where((b) => isWithinRange(_getDocDate(b, 'createdAt'))).toList();
        if (search.isNotEmpty) {
          list = list.where((b) {
            final busNo = (b['busNo'] ?? '').toString().toLowerCase();
            final driverName = (b['driverName'] ?? '').toString().toLowerCase();
            return busNo.contains(search) || driverName.contains(search);
          }).toList();
        }

        rows = list.map((b) => [
          b['busNo'] ?? '-',
          b['driverName'] ?? '-',
          b['driverPhone'] ?? '-',
          b['status'] ?? '-',
          b['capacity']?.toString() ?? '-',
        ]).toList();
        break;

      case 2:
        reportTitle = 'System Routes Directory Report';
        filenamePrefix = 'routes_report';
        headers = const ['Route Name', 'Start Location', 'End Location', 'Stops Count', 'Status'];
        
        var list = routes.where((r) => isWithinRange(_getDocDate(r, 'createdAt'))).toList();
        if (search.isNotEmpty) {
          list = list.where((r) {
            final name = (r['routeName'] ?? '').toString().toLowerCase();
            final startLoc = (r['startLocation'] ?? '').toString().toLowerCase();
            return name.contains(search) || startLoc.contains(search);
          }).toList();
        }

        rows = list.map((r) => [
          r['routeName'] ?? '-',
          r['startLocation'] ?? '-',
          r['endLocation'] ?? '-',
          (r['stops'] as List?)?.length.toString() ?? '0',
          r['status'] ?? '-',
        ]).toList();
        break;

      case 3:
        reportTitle = 'Student Payments History Report';
        filenamePrefix = 'payments_report';
        headers = const ['Receipt ID', 'Student Name', 'PRN', 'Amount', 'Payment Method', 'Date', 'Status'];
        
        var list = payments.where((p) => isWithinRange(_getDocDate(p, 'paymentDate') ?? _getDocDate(p, 'createdAt'))).toList();
        if (search.isNotEmpty) {
          list = list.where((p) {
            final id = (p['receiptId'] ?? '').toString().toLowerCase();
            final name = (p['studentName'] ?? '').toString().toLowerCase();
            return id.contains(search) || name.contains(search);
          }).toList();
        }

        rows = list.map((p) => [
          p['receiptId'] ?? '-',
          p['studentName'] ?? '-',
          p['prn'] ?? '-',
          '₹${p['amount'] ?? 0}',
          p['paymentMethod'] ?? '-',
          _formatDate(p['paymentDate'] ?? p['createdAt']),
          p['paymentStatus'] ?? '-',
        ]).toList();
        break;

      case 4:
        reportTitle = 'Issued Bus Passes Report';
        filenamePrefix = 'bus_passes_report';
        headers = const ['Pass ID', 'Student Name', 'PRN', 'Route Assigned', 'Expiry Date', 'Status'];
        
        var list = passes.where((ps) => isWithinRange(_getDocDate(ps, 'createdAt') ?? _getDocDate(ps, 'updatedAt'))).toList();
        if (search.isNotEmpty) {
          list = list.where((ps) {
            final passId = (ps['passId'] ?? '').toString().toLowerCase();
            final name = (ps['studentName'] ?? ps['fullName'] ?? '').toString().toLowerCase();
            return passId.contains(search) || name.contains(search);
          }).toList();
        }

        rows = list.map((ps) => [
          ps['passId'] ?? 'N/A',
          ps['studentName'] ?? ps['fullName'] ?? 'Unknown',
          ps['prn'] ?? 'N/A',
          ps['route'] ?? ps['routeName'] ?? 'N/A',
          _formatDate(ps['expiryDate']),
          ps['passStatus'] ?? 'N/A',
        ]).toList();
        break;
    }

    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No records available to export for this report tab and filter.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      if (isPdf) {
        final filename = '${filenamePrefix}_$timestamp.pdf';
        await ReportExporter.exportPdf(
          filename: filename,
          reportTitle: reportTitle,
          filterDescription: dateRangeStr,
          headers: headers,
          rows: rows,
        );
      } else {
        final filename = '${filenamePrefix}_$timestamp.csv';
        await ReportExporter.exportCsv(
          filename: filename,
          headers: headers,
          rows: rows,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully generated and opened share prompt for $reportTitle.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
