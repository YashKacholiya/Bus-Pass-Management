// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/features/admin/domain/admin_providers.dart';
import 'package:icem_bus/features/driver/domain/driver_providers.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_charts.dart';
import 'package:icem_bus/features/admin/presentation/views/report_exporter.dart';

/// Reports & Analytics Screen for Admin Console
///
/// Fully functional, production-ready dashboard calculating real-time metrics,
/// interactive charts, multi-level filters, directory views, and PDF/CSV export
/// directly from actual live Firestore collections: users, drivers, buses, bus_routes.
class AdminReportsTab extends ConsumerStatefulWidget {
  const AdminReportsTab({super.key});

  @override
  ConsumerState<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends ConsumerState<AdminReportsTab> {
  // Search & Filters State
  String _searchQuery = '';
  String _dateFilter = 'All Time'; // Default 'All Time' so existing data is never filtered out
  String _roleFilter = 'All Roles';
  String _statusFilter = 'All Statuses';

  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Selected Explorer Tab:
  // 0: Overview & Visual Analytics
  // 1: Users & Students
  // 2: Drivers
  // 3: Fleet & Buses
  // 4: Routes & Network
  // 5: Issued Passes (if data exists)
  // 6: Payments & Revenue (if data exists)
  int _selectedReportTab = 0;

  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _customStartDate = DateTime(now.year, now.month, 1);
    _customEndDate = DateTime(now.year, now.month + 1, 0);
  }

  /// Calculates the active DateTimeRange based on the selected filter type.
  /// Returns null for 'All Time' so no date boundaries are imposed.
  DateTimeRange? _getCurrentDateRange() {
    final now = DateTime.now();
    switch (_dateFilter) {
      case 'All Time':
        return null;
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
        return null;
    }
  }

  /// Date parser helper supporting Timestamp, ISO String, or int millis
  DateTime? _getDocDate(Map<String, dynamic> doc, [String preferredKey = 'createdAt']) {
    final keys = [preferredKey, 'createdAt', 'updatedAt', 'paymentDate', 'dateJoined'];
    for (final k in keys) {
      final val = doc[k];
      if (val != null) {
        if (val is Timestamp) return val.toDate();
        if (val is DateTime) return val;
        if (val is String) {
          final dt = DateTime.tryParse(val);
          if (dt != null) return dt;
        }
        if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      }
    }
    return null;
  }

  /// Date formatter helper
  String _formatDate(dynamic dateField) {
    if (dateField == null) return 'N/A';
    DateTime? dt;
    if (dateField is Timestamp) {
      dt = dateField.toDate();
    } else if (dateField is DateTime) {
      dt = dateField;
    } else if (dateField is String) {
      dt = DateTime.tryParse(dateField);
    } else if (dateField is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(dateField);
    }
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  /// Returns user-friendly date filter description
  String _getDateFilterDescription(DateTimeRange? range) {
    if (_dateFilter == 'All Time' || range == null) {
      return 'All Time (Complete History)';
    }
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
        _dateFilter = 'Custom Date Range';
      });
    }
  }

  /// Invalidate and refresh all real-time Firestore stream providers
  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      ref.invalidate(studentsListStreamProvider);
      ref.invalidate(allUsersListStreamProvider);
      ref.invalidate(driversListStreamProvider);
      ref.invalidate(busesListStreamProvider);
      ref.invalidate(routesListStreamProvider);
      ref.invalidate(paymentsListStreamProvider);
      ref.invalidate(busPassesListStreamProvider);
      ref.invalidate(applicationsListStreamProvider);

      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reports & Analytics data refreshed from live Firestore.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Watch actual live Firestore stream providers
    final usersAsync = ref.watch(allUsersListStreamProvider);
    final driversAsync = ref.watch(driversListStreamProvider);
    final busesAsync = ref.watch(busesListStreamProvider);
    final routesAsync = ref.watch(routesListStreamProvider);
    final paymentsAsync = ref.watch(paymentsListStreamProvider);
    final passesAsync = ref.watch(busPassesListStreamProvider);

    // Resolve raw lists safely
    final rawUsers = usersAsync.valueOrNull ?? [];
    final rawDrivers = driversAsync.valueOrNull ?? [];
    final rawBuses = busesAsync.valueOrNull ?? [];
    final rawRoutes = routesAsync.valueOrNull ?? [];
    final rawPayments = paymentsAsync.valueOrNull ?? [];
    final rawPasses = passesAsync.valueOrNull ?? [];

    // Date range filter helper
    final range = _getCurrentDateRange();
    bool isWithinDateRange(DateTime? date) {
      if (range == null) return true; // 'All Time'
      if (date == null) return false;
      return date.isAfter(range.start.subtract(const Duration(seconds: 1))) &&
          date.isBefore(range.end.add(const Duration(seconds: 1)));
    }

    // Role filter helper
    bool matchesRole(Map<String, dynamic> user) {
      if (_roleFilter == 'All Roles') return true;
      if (_roleFilter == 'Student') return UserEntity.isStudentUser(user);
      final role = (user['role'] ?? '').toString().toLowerCase();
      return role == _roleFilter.toLowerCase();
    }

    // Status filter helper
    bool matchesStatus(Map<String, dynamic> item, {bool isUser = false}) {
      if (_statusFilter == 'All Statuses') return true;
      if (isUser) {
        final isActive = item['isActive'] != false;
        if (_statusFilter == 'Active') return isActive;
        if (_statusFilter == 'Inactive') return !isActive;
        return true;
      }
      final status = (item['status'] ?? 'Active').toString().toLowerCase();
      if (_statusFilter == 'Active') return status == 'active';
      if (_statusFilter == 'Inactive') return status == 'inactive' || status == 'on leave';
      return true;
    }

    // Apply active filters to raw datasets
    final filteredUsers = rawUsers.where((u) {
      return isWithinDateRange(_getDocDate(u)) && matchesRole(u) && matchesStatus(u, isUser: true);
    }).toList();

    final filteredDrivers = rawDrivers.where((d) {
      return isWithinDateRange(_getDocDate(d)) && matchesStatus(d);
    }).toList();

    final filteredBuses = rawBuses.where((b) {
      return isWithinDateRange(_getDocDate(b)) && matchesStatus(b);
    }).toList();

    final filteredRoutes = rawRoutes.where((r) {
      return isWithinDateRange(_getDocDate(r)) && matchesStatus(r);
    }).toList();

    final filteredPayments = rawPayments.where((p) {
      return isWithinDateRange(_getDocDate(p, 'paymentDate') ?? _getDocDate(p, 'createdAt'));
    }).toList();

    final filteredPasses = rawPasses.where((ps) {
      return isWithinDateRange(_getDocDate(ps, 'createdAt') ?? _getDocDate(ps, 'updatedAt'));
    }).toList();

    // ── SEARCH FILTERING ──
    final search = _searchQuery.trim().toLowerCase();

    final searchedUsers = search.isEmpty
        ? filteredUsers
        : filteredUsers.where((u) {
            final name = (u['fullName'] ?? '').toString().toLowerCase();
            final email = (u['email'] ?? '').toString().toLowerCase();
            final prn = (u['prn'] ?? '').toString().toLowerCase();
            final collegeId = (u['collegeId'] ?? '').toString().toLowerCase();
            final course = (u['course'] ?? '').toString().toLowerCase();
            final dept = (u['department'] ?? '').toString().toLowerCase();
            final mobile = (u['mobile'] ?? '').toString().toLowerCase();
            return name.contains(search) ||
                email.contains(search) ||
                prn.contains(search) ||
                collegeId.contains(search) ||
                course.contains(search) ||
                dept.contains(search) ||
                mobile.contains(search);
          }).toList();

    final searchedDrivers = search.isEmpty
        ? filteredDrivers
        : filteredDrivers.where((d) {
            final name = (d['fullName'] ?? '').toString().toLowerCase();
            final driverId = (d['driverId'] ?? '').toString().toLowerCase();
            final mobile = (d['mobile'] ?? '').toString().toLowerCase();
            final license = (d['licenseNumber'] ?? '').toString().toLowerCase();
            final bus = (d['assignedBusNumber'] ?? '').toString().toLowerCase();
            return name.contains(search) ||
                driverId.contains(search) ||
                mobile.contains(search) ||
                license.contains(search) ||
                bus.contains(search);
          }).toList();

    final searchedBuses = search.isEmpty
        ? filteredBuses
        : filteredBuses.where((b) {
            final busNumber = (b['busNumber'] ?? b['busNo'] ?? '').toString().toLowerCase();
            final busName = (b['busName'] ?? '').toString().toLowerCase();
            final reg = (b['registrationNumber'] ?? '').toString().toLowerCase();
            final driver = (b['driverName'] ?? '').toString().toLowerCase();
            final phone = (b['driverPhone'] ?? '').toString().toLowerCase();
            return busNumber.contains(search) ||
                busName.contains(search) ||
                reg.contains(search) ||
                driver.contains(search) ||
                phone.contains(search);
          }).toList();

    final searchedRoutes = search.isEmpty
        ? filteredRoutes
        : filteredRoutes.where((r) {
            final name = (r['routeName'] ?? r['name'] ?? '').toString().toLowerCase();
            final number = (r['routeNumber'] ?? r['number'] ?? '').toString().toLowerCase();
            final origin = (r['origin'] ?? r['source'] ?? r['startLocation'] ?? '').toString().toLowerCase();
            final dest = (r['destination'] ?? r['dest'] ?? r['endLocation'] ?? '').toString().toLowerCase();
            return name.contains(search) || number.contains(search) || origin.contains(search) || dest.contains(search);
          }).toList();

    final searchedPayments = search.isEmpty
        ? filteredPayments
        : filteredPayments.where((p) {
            final receipt = (p['receiptId'] ?? p['id'] ?? '').toString().toLowerCase();
            final student = (p['studentName'] ?? '').toString().toLowerCase();
            final prn = (p['prn'] ?? '').toString().toLowerCase();
            return receipt.contains(search) || student.contains(search) || prn.contains(search);
          }).toList();

    final searchedPasses = search.isEmpty
        ? filteredPasses
        : filteredPasses.where((ps) {
            final passId = (ps['passId'] ?? ps['id'] ?? '').toString().toLowerCase();
            final name = (ps['studentName'] ?? ps['fullName'] ?? '').toString().toLowerCase();
            final route = (ps['route'] ?? ps['routeName'] ?? '').toString().toLowerCase();
            return passId.contains(search) || name.contains(search) || route.contains(search);
          }).toList();

    // ── METRIC COUNTS (Calculated dynamically strictly from Firestore data) ──
    final totalUsersCount = filteredUsers.length;
    final activeUsersCount = filteredUsers.where((u) => u['isActive'] != false).length;
    final inactiveUsersCount = filteredUsers.where((u) => u['isActive'] == false).length;
    final totalStudentsCount = filteredUsers.where((u) => (u['role']?.toString().toLowerCase() ?? 'student') == 'student').length;

    final totalDriversCount = filteredDrivers.length;
    final activeDriversCount = filteredDrivers.where((d) => (d['status']?.toString().toLowerCase() ?? 'active') == 'active').length;
    final onLeaveDriversCount = filteredDrivers.where((d) => (d['status']?.toString().toLowerCase() ?? '') == 'on leave').length;
    final inactiveDriversCount = filteredDrivers.where((d) => (d['status']?.toString().toLowerCase() ?? '') == 'inactive').length;
    final assignedDriversCount = filteredDrivers.where((d) => d['assignedBusId'] != null && d['assignedBusId'].toString().isNotEmpty).length;

    final totalBusesCount = filteredBuses.length;
    final activeBusesCount = filteredBuses.where((b) => (b['status']?.toString().toLowerCase() ?? 'active') == 'active').length;
    final maintenanceBusesCount = filteredBuses.where((b) => (b['status']?.toString().toLowerCase() ?? '') == 'maintenance').length;
    final inactiveBusesCount = filteredBuses.where((b) => (b['status']?.toString().toLowerCase() ?? '') == 'inactive').length;
    int totalFleetCapacity = 0;
    for (final b in filteredBuses) {
      final cap = b['capacity'];
      if (cap is num) {
        totalFleetCapacity += cap.toInt();
      } else if (cap is String) {
        totalFleetCapacity += int.tryParse(cap) ?? 0;
      }
    }
    final assignedBusesCount = filteredBuses.where((b) => b['assignedRouteId'] != null && b['assignedRouteId'].toString().isNotEmpty).length;

    final totalRoutesCount = filteredRoutes.length;
    final activeRoutesCount = filteredRoutes.where((r) => (r['status']?.toString().toLowerCase() ?? 'active') == 'active').length;
    final inactiveRoutesCount = filteredRoutes.where((r) => (r['status']?.toString().toLowerCase() ?? '') == 'inactive').length;
    double totalNetworkKm = 0.0;
    for (final r in filteredRoutes) {
      final dist = r['distanceKm'] ?? r['distance'];
      if (dist is num) {
        totalNetworkKm += dist.toDouble();
      } else if (dist is String) {
        totalNetworkKm += double.tryParse(dist) ?? 0.0;
      }
    }
    final avgRouteKm = totalRoutesCount > 0 ? (totalNetworkKm / totalRoutesCount) : 0.0;

    // Optional Collections Real Counts
    final realPassesCount = filteredPasses.length;
    final realActivePassesCount = filteredPasses.where((ps) => ps['passStatus'] == 'Active').length;
    double realRevenue = 0.0;
    for (final p in filteredPayments) {
      if (p['paymentStatus'] == 'Paid' || p['paymentStatus'] == 'Success') {
        final amt = p['amount'];
        if (amt is num) {
          realRevenue += amt.toDouble();
        } else if (amt is String) {
          realRevenue += double.tryParse(amt) ?? 0.0;
        }
      }
    }

    // ── CHARTS DATA CALCULATIONS (STRICTLY REAL DATA) ──
    // 1. Users by Role Donut
    final Map<String, double> usersByRole = {};
    for (final u in filteredUsers) {
      final role = (u['role'] ?? 'Student').toString();
      final capitalizedRole = role.isNotEmpty ? '${role[0].toUpperCase()}${role.substring(1).toLowerCase()}' : 'User';
      usersByRole[capitalizedRole] = (usersByRole[capitalizedRole] ?? 0.0) + 1.0;
    }

    // 2. User Status Donut
    final Map<String, double> usersByStatus = {};
    if (activeUsersCount > 0) usersByStatus['Active'] = activeUsersCount.toDouble();
    if (inactiveUsersCount > 0) usersByStatus['Inactive'] = inactiveUsersCount.toDouble();

    // 3. Driver Status Donut
    final Map<String, double> driversByStatus = {};
    if (activeDriversCount > 0) driversByStatus['Active'] = activeDriversCount.toDouble();
    if (onLeaveDriversCount > 0) driversByStatus['On Leave'] = onLeaveDriversCount.toDouble();
    if (inactiveDriversCount > 0) driversByStatus['Inactive'] = inactiveDriversCount.toDouble();

    // 4. Bus Fleet Status Donut
    final Map<String, double> busesByStatus = {};
    if (activeBusesCount > 0) busesByStatus['Active'] = activeBusesCount.toDouble();
    if (maintenanceBusesCount > 0) busesByStatus['Maintenance'] = maintenanceBusesCount.toDouble();
    if (inactiveBusesCount > 0) busesByStatus['Inactive'] = inactiveBusesCount.toDouble();

    // 5. Routes Status Donut
    final Map<String, double> routesByStatus = {};
    if (activeRoutesCount > 0) routesByStatus['Active'] = activeRoutesCount.toDouble();
    if (inactiveRoutesCount > 0) routesByStatus['Inactive'] = inactiveRoutesCount.toDouble();

    // 6. User Registration Trend Line Chart (Grouped by actual createdAt)
    final Map<String, double> usersByMonth = {};
    for (final u in filteredUsers) {
      final date = _getDocDate(u, 'createdAt');
      if (date != null) {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final key = '${months[date.month - 1]} ${date.year}';
        usersByMonth[key] = (usersByMonth[key] ?? 0.0) + 1.0;
      }
    }

    final userTrendPoints = usersByMonth.entries
        .map((e) => ChartDataPoint(e.key, e.value))
        .toList()
      ..sort((a, b) {
        // Chronological sorting
        final partsA = a.label.split(' ');
        final partsB = b.label.split(' ');
        if (partsA.length == 2 && partsB.length == 2) {
          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          final mA = months.indexOf(partsA[0]) + 1;
          final yA = int.tryParse(partsA[1]) ?? 2026;
          final mB = months.indexOf(partsB[0]) + 1;
          final yB = int.tryParse(partsB[1]) ?? 2026;
          return DateTime(yA, mA).compareTo(DateTime(yB, mB));
        }
        return a.label.compareTo(b.label);
      });

    // 7. Top Courses Horizontal Bar Chart
    final Map<String, double> coursesDistribution = {};
    for (final u in filteredUsers) {
      final course = (u['course'] ?? '').toString().trim();
      if (course.isNotEmpty) {
        coursesDistribution[course] = (coursesDistribution[course] ?? 0.0) + 1.0;
      }
    }
    final topCourses = coursesDistribution.entries
        .map((e) => ChartDataPoint(e.key, e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCourses5 = topCourses.take(5).toList();

    // 8. Top Routes by Distance Bar Chart
    final List<ChartDataPoint> topRoutesPoints = [];
    for (final r in filteredRoutes) {
      final name = (r['routeName'] ?? r['name'] ?? 'Route').toString();
      final dist = r['distanceKm'] ?? r['distance'];
      double d = 0.0;
      if (dist is num) {
        d = dist.toDouble();
      } else if (dist is String) {
        d = double.tryParse(dist) ?? 0.0;
      }
      if (d > 0) {
        topRoutesPoints.add(ChartDataPoint(name, d));
      }
    }
    topRoutesPoints.sort((a, b) => b.value.compareTo(a.value));
    final topRoutes5 = topRoutesPoints.take(5).toList();

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 950;
    final isTablet = width >= 650 && width < 950;

    final isInitialLoading = (usersAsync.isLoading && !usersAsync.hasValue) &&
        (driversAsync.isLoading && !driversAsync.hasValue) &&
        (busesAsync.isLoading && !busesAsync.hasValue) &&
        (routesAsync.isLoading && !routesAsync.hasValue);

    if (isInitialLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryCrimson),
            const SizedBox(height: 16),
            Text(
              'Loading live Firestore analytics...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final hasCriticalError = (usersAsync.hasError && !usersAsync.hasValue) &&
        (driversAsync.hasError && !driversAsync.hasValue) &&
        (busesAsync.hasError && !busesAsync.hasValue) &&
        (routesAsync.hasError && !routesAsync.hasValue);

    if (hasCriticalError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Unable to load analytics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your network connection and Firestore permissions.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _handleRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: AppColors.primaryCrimson,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.primaryCrimson,
      child: SingleChildScrollView(
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. HEADER SECTION & REFRESH ACTION ──
            if (width < 600)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/images/bus_logo.png', width: 24, height: 24, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      Text(
                        'Reports & Analytics',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live Firestore metrics, directory audits, dynamic charts, and exports.',
                    style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Refresh Analytics',
                        onPressed: _isRefreshing ? null : _handleRefresh,
                        icon: _isRefreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryCrimson),
                              )
                            : const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primaryCrimson),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _handleExportAction(
                          isPdf: false,
                          dateRangeStr: _getDateFilterDescription(range),
                          users: searchedUsers,
                          drivers: searchedDrivers,
                          buses: searchedBuses,
                          routes: searchedRoutes,
                          passes: searchedPasses,
                          payments: searchedPayments,
                        ),
                        icon: const Icon(Icons.grid_on_rounded, size: 14, color: AppColors.success),
                        label: const Text('CSV', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: const BorderSide(color: AppColors.success),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: () => _handleExportAction(
                          isPdf: true,
                          dateRangeStr: _getDateFilterDescription(range),
                          users: searchedUsers,
                          drivers: searchedDrivers,
                          buses: searchedBuses,
                          routes: searchedRoutes,
                          passes: searchedPasses,
                          payments: searchedPayments,
                        ),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 14, color: Colors.white),
                        label: const Text('PDF', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: AppColors.primaryCrimson,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset('assets/images/bus_logo.png', width: 24, height: 24, fit: BoxFit.contain),
                            const SizedBox(width: 8),
                            Text(
                              'Reports & Analytics',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Live Firestore metrics, directory audits, dynamic charts, and exports.',
                          style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Refresh Analytics',
                        onPressed: _isRefreshing ? null : _handleRefresh,
                        icon: _isRefreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryCrimson),
                              )
                            : const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primaryCrimson),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _handleExportAction(
                          isPdf: false,
                          dateRangeStr: _getDateFilterDescription(range),
                          users: searchedUsers,
                          drivers: searchedDrivers,
                          buses: searchedBuses,
                          routes: searchedRoutes,
                          passes: searchedPasses,
                          payments: searchedPayments,
                        ),
                        icon: const Icon(Icons.grid_on_rounded, size: 14, color: AppColors.success),
                        label: const Text('CSV', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: const BorderSide(color: AppColors.success),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: () => _handleExportAction(
                          isPdf: true,
                          dateRangeStr: _getDateFilterDescription(range),
                          users: searchedUsers,
                          drivers: searchedDrivers,
                          buses: searchedBuses,
                          routes: searchedRoutes,
                          passes: searchedPasses,
                          payments: searchedPayments,
                        ),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 14, color: Colors.white),
                        label: const Text('PDF', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: AppColors.primaryCrimson,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── 2. FILTERS AND SEARCH SECTION ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
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
                    // Active Filter Summary Badge
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: AppColors.primaryCrimson, size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'Active Range: ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                        Expanded(
                          child: Text(
                            _getDateFilterDescription(range),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.primaryCrimson),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_dateFilter == 'Custom Date Range')
                          TextButton(
                            onPressed: _selectCustomDateRange,
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Change Dates', style: TextStyle(fontSize: 12, color: AppColors.primaryCrimson)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Date Filters
                    AdminFilterChips(
                      filters: const ['All Time', 'Today', 'This Week', 'This Month', 'This Year', 'Custom Date Range'],
                      selected: _dateFilter,
                      onSelected: (val) async {
                        if (val == 'Custom Date Range') {
                          await _selectCustomDateRange();
                        } else {
                          setState(() => _dateFilter = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Secondary Filters: Role & Status
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          const Text('Role: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          ...['All Roles', 'Student', 'Driver', 'Admin'].map((r) {
                            final sel = _roleFilter == r;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(r),
                                selected: sel,
                                onSelected: (_) => setState(() => _roleFilter = r),
                                selectedColor: AppColors.primaryCrimson.withOpacity(0.12),
                                labelStyle: TextStyle(
                                  color: sel ? AppColors.primaryCrimson : theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11.5,
                                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: sel ? AppColors.primaryCrimson : theme.colorScheme.outlineVariant,
                                ),
                                backgroundColor: theme.colorScheme.surface,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          }),
                          const SizedBox(width: 8),
                          const Text('Status: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          ...['All Statuses', 'Active', 'Inactive'].map((st) {
                            final sel = _statusFilter == st;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(st),
                                selected: sel,
                                onSelected: (_) => setState(() => _statusFilter = st),
                                selectedColor: AppColors.primaryCrimson.withOpacity(0.12),
                                labelStyle: TextStyle(
                                  color: sel ? AppColors.primaryCrimson : theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11.5,
                                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: sel ? AppColors.primaryCrimson : theme.colorScheme.outlineVariant,
                                ),
                                backgroundColor: theme.colorScheme.surface,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search input
                    AdminSearchBar(
                      hintText: 'Search users, drivers, buses, routes...',
                      value: _searchQuery,
                      onChanged: (q) => setState(() => _searchQuery = q),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 3. REAL-TIME STATS OVERVIEW SECTION (STEP 3) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AdminSectionHeader(title: 'Live Operational KPIs'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 7, color: AppColors.success),
                        SizedBox(width: 4),
                        Text('Synced Live', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.success)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Responsive KPI Grid - aspect ratio 1.15 to prevent vertical RenderFlex overflow on Realme 15
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 4 : (isTablet ? 3 : 2),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 134,
                ),
                children: [
                  AdminStatCard(
                    label: 'Total Users',
                    value: usersAsync.isLoading ? '...' : totalUsersCount.toString(),
                    icon: Icons.people_alt_rounded,
                    color: AppColors.info,
                    isLoading: usersAsync.isLoading,
                  ),
                  AdminStatCard(
                    label: 'Active Users',
                    value: usersAsync.isLoading ? '...' : activeUsersCount.toString(),
                    icon: Icons.how_to_reg_rounded,
                    color: AppColors.success,
                    isLoading: usersAsync.isLoading,
                  ),
                  AdminStatCard(
                    label: 'Students Enrolled',
                    value: usersAsync.isLoading ? '...' : totalStudentsCount.toString(),
                    icon: Icons.school_rounded,
                    color: Colors.blueAccent,
                    isLoading: usersAsync.isLoading,
                  ),
                  AdminStatCard(
                    label: 'Inactive Users',
                    value: usersAsync.isLoading ? '...' : inactiveUsersCount.toString(),
                    icon: Icons.person_off_rounded,
                    color: AppColors.error,
                    isLoading: usersAsync.isLoading,
                  ),
                  AdminStatCard(
                    label: 'Total Drivers',
                    value: driversAsync.isLoading ? '...' : totalDriversCount.toString(),
                    icon: Icons.person_pin_circle_rounded,
                    color: Colors.blue,
                    isLoading: driversAsync.isLoading,
                  ),
                  AdminStatCard(
                    label: 'Active Drivers',
                    value: driversAsync.isLoading ? '...' : activeDriversCount.toString(),
                    icon: Icons.badge_rounded,
                    color: Colors.teal,
                    isLoading: driversAsync.isLoading,
                  ),
                  AdminStatCard(
                    label: 'Assigned Drivers',
                    value: driversAsync.isLoading ? '...' : '$assignedDriversCount of $totalDriversCount',
                    icon: Icons.airline_seat_recline_normal_rounded,
                    color: Colors.indigo,
                    isLoading: driversAsync.isLoading,
                  ),
                  AdminStatCard(
                    label: 'Total Buses',
                    value: busesAsync.isLoading ? '...' : totalBusesCount.toString(),
                    icon: Icons.directions_bus_rounded,
                    color: Colors.purple,
                    isLoading: busesAsync.isLoading,
                  ),
                  AdminStatCard(
                    label: 'Active Buses',
                    value: busesAsync.isLoading ? '...' : activeBusesCount.toString(),
                    icon: Icons.departure_board_rounded,
                    color: AppColors.success,
                    isLoading: busesAsync.isLoading,
                  ),
                  AdminStatCard(
                    label: 'Fleet Capacity',
                    value: busesAsync.isLoading ? '...' : '$totalFleetCapacity seats',
                    icon: Icons.event_seat_rounded,
                    color: AppColors.accentGold,
                    isLoading: busesAsync.isLoading,
                  ),
                  AdminStatCard(
                    label: 'Assigned Buses',
                    value: busesAsync.isLoading ? '...' : '$assignedBusesCount of $totalBusesCount',
                    icon: Icons.link_rounded,
                    color: Colors.teal,
                    isLoading: busesAsync.isLoading,
                  ),
                  AdminStatCard(
                    label: 'Total Routes',
                    value: routesAsync.isLoading ? '...' : totalRoutesCount.toString(),
                    icon: Icons.route_rounded,
                    color: Colors.deepOrange,
                    isLoading: routesAsync.isLoading,
                  ),
                  AdminStatCard(
                    label: 'Active Routes',
                    value: routesAsync.isLoading ? '...' : activeRoutesCount.toString(),
                    icon: Icons.check_circle_outline_rounded,
                    color: Colors.indigo,
                    isLoading: routesAsync.isLoading,
                  ),
                  AdminStatCard(
                    label: 'Avg Route Length',
                    value: routesAsync.isLoading ? '...' : '${avgRouteKm.toStringAsFixed(1)} KM',
                    icon: Icons.straighten_rounded,
                    color: Colors.blueGrey,
                    isLoading: routesAsync.isLoading,
                  ),
                  if (realPassesCount > 0)
                    AdminStatCard(
                      label: 'Active Passes',
                      value: '$realActivePassesCount of $realPassesCount',
                      icon: Icons.badge_outlined,
                      color: AppColors.success,
                    ),
                  if (realRevenue > 0)
                    AdminStatCard(
                      label: 'Total Revenue',
                      value: '₹${realRevenue.toStringAsFixed(0)}',
                      icon: Icons.currency_rupee_rounded,
                      color: Colors.teal,
                    ),
                ],
              ),
              const SizedBox(height: 28),

              // ── 4. VISUAL CHARTS SECTION (STEP 8) ──
              const AdminSectionHeader(title: 'Interactive Visual Analytics'),
              const SizedBox(height: 12),

              if (isDesktop) ...[
                // Desktop row 1: Users by Role & User Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DonutChartWidget(
                        data: usersByRole,
                        title: 'Users Distribution by Role',
                        colors: const [AppColors.primaryCrimson, Colors.blue, Colors.teal, AppColors.accentGold],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DonutChartWidget(
                        data: usersByStatus,
                        title: 'User Account Status',
                        colors: const [AppColors.success, AppColors.error],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Desktop row 2: Fleet Status & Route Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DonutChartWidget(
                        data: busesByStatus,
                        title: 'Bus Fleet Operational Status',
                        colors: const [AppColors.success, AppColors.warning, AppColors.error],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DonutChartWidget(
                        data: driversByStatus,
                        title: 'Driver Deployment Status',
                        colors: const [AppColors.info, AppColors.warning, AppColors.error],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DonutChartWidget(
                        data: routesByStatus,
                        title: 'Routes Status',
                        colors: const [AppColors.success, AppColors.error],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Desktop row 3: Registration Trend & Top Courses
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: LineAreaChart(
                        data: userTrendPoints,
                        title: 'User Registration Timeline (Actual createdAt)',
                        primaryColor: AppColors.primaryCrimson,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: HorizontalBarChart(
                        data: topCourses5,
                        title: 'Top Courses by Enrolled Students',
                        barColor: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Desktop row 4: Top Routes
                if (topRoutes5.isNotEmpty)
                  HorizontalBarChart(
                    data: topRoutes5,
                    title: 'Top Routes by Distance (KM)',
                    barColor: Colors.indigo,
                  ),
              ] else ...[
                // Mobile stacked layout:
                DonutChartWidget(
                  data: usersByRole,
                  title: 'Users Distribution by Role',
                  colors: const [AppColors.primaryCrimson, Colors.blue, Colors.teal, AppColors.accentGold],
                ),
                const SizedBox(height: 16),
                DonutChartWidget(
                  data: usersByStatus,
                  title: 'User Account Status',
                  colors: const [AppColors.success, AppColors.error],
                ),
                const SizedBox(height: 16),
                DonutChartWidget(
                  data: busesByStatus,
                  title: 'Bus Fleet Operational Status',
                  colors: const [AppColors.success, AppColors.warning, AppColors.error],
                ),
                const SizedBox(height: 16),
                DonutChartWidget(
                  data: driversByStatus,
                  title: 'Driver Deployment Status',
                  colors: const [AppColors.info, AppColors.warning, AppColors.error],
                ),
                const SizedBox(height: 16),
                DonutChartWidget(
                  data: routesByStatus,
                  title: 'Routes Status',
                  colors: const [AppColors.success, AppColors.error],
                ),
                const SizedBox(height: 16),
                LineAreaChart(
                  data: userTrendPoints,
                  title: 'User Registration Timeline (Actual createdAt)',
                  primaryColor: AppColors.primaryCrimson,
                ),
                const SizedBox(height: 16),
                if (topCourses5.isNotEmpty) ...[
                  HorizontalBarChart(
                    data: topCourses5,
                    title: 'Top Courses by Enrolled Students',
                    barColor: Colors.deepOrange,
                  ),
                  const SizedBox(height: 16),
                ],
                if (topRoutes5.isNotEmpty) ...[
                  HorizontalBarChart(
                    data: topRoutes5,
                    title: 'Top Routes by Distance (KM)',
                    barColor: Colors.indigo,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
              const SizedBox(height: 28),

              // ── 5. REPORTS DIRECTORY EXPLORER TABS (STEPS 4 - 7) ──
              const AdminSectionHeader(title: 'Entity Directories & Records'),
              const SizedBox(height: 12),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildReportTabButton(0, 'Overview KPIs', Icons.dashboard_outlined),
                    _buildReportTabButton(1, 'Users Directory ($totalUsersCount)', Icons.people_outline_rounded),
                    _buildReportTabButton(2, 'Drivers Directory ($totalDriversCount)', Icons.person_pin_circle_outlined),
                    _buildReportTabButton(3, 'Bus Fleet ($totalBusesCount)', Icons.directions_bus_outlined),
                    _buildReportTabButton(4, 'Routes Directory ($totalRoutesCount)', Icons.route_outlined),
                    if (rawPasses.isNotEmpty)
                      _buildReportTabButton(5, 'Passes ($realPassesCount)', Icons.badge_outlined),
                    if (rawPayments.isNotEmpty)
                      _buildReportTabButton(6, 'Receipts (${filteredPayments.length})', Icons.receipt_long_outlined),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Active Tab Content Container
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header of active tab
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _getReportTabTitle(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Showing filtered records',
                          style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(height: 1, color: theme.dividerColor),
                    const SizedBox(height: 14),

                    // Content switcher
                    _buildActiveReportView(
                      usersAsync: usersAsync,
                      driversAsync: driversAsync,
                      busesAsync: busesAsync,
                      routesAsync: routesAsync,
                      passesAsync: passesAsync,
                      paymentsAsync: paymentsAsync,
                      users: searchedUsers,
                      drivers: searchedDrivers,
                      buses: searchedBuses,
                      routes: searchedRoutes,
                      passes: searchedPasses,
                      payments: searchedPayments,
                      totalUsers: totalUsersCount,
                      activeUsers: activeUsersCount,
                      inactiveUsers: inactiveUsersCount,
                      totalDrivers: totalDriversCount,
                      activeDrivers: activeDriversCount,
                      totalBuses: totalBusesCount,
                      activeBuses: activeBusesCount,
                      totalRoutes: totalRoutesCount,
                      activeRoutes: activeRoutesCount,
                      totalCapacity: totalFleetCapacity,
                      totalKm: totalNetworkKm,
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

  Widget _buildReportTabButton(int index, String title, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = _selectedReportTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.primaryCrimson),
        label: Text(title),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedReportTab = index),
        selectedColor: AppColors.primaryCrimson,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12.5,
        ),
        backgroundColor: theme.colorScheme.surface,
        side: BorderSide(
          color: isSelected ? AppColors.primaryCrimson : theme.colorScheme.outlineVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _getReportTabTitle() {
    switch (_selectedReportTab) {
      case 0:
        return 'System Analytics Summary';
      case 1:
        return 'Registered Users & Students Directory';
      case 2:
        return 'System Drivers Directory';
      case 3:
        return 'Fleet & Buses Directory';
      case 4:
        return 'Bus Routes & Network Directory';
      case 5:
        return 'Issued Bus Passes';
      case 6:
        return 'Payment & Transaction Receipts';
      default:
        return 'Report Directory';
    }
  }

  Widget _buildActiveReportView({
    required AsyncValue usersAsync,
    required AsyncValue driversAsync,
    required AsyncValue busesAsync,
    required AsyncValue routesAsync,
    required AsyncValue passesAsync,
    required AsyncValue paymentsAsync,
    required List<Map<String, dynamic>> users,
    required List<Map<String, dynamic>> drivers,
    required List<Map<String, dynamic>> buses,
    required List<Map<String, dynamic>> routes,
    required List<Map<String, dynamic>> passes,
    required List<Map<String, dynamic>> payments,
    required int totalUsers,
    required int activeUsers,
    required int inactiveUsers,
    required int totalDrivers,
    required int activeDrivers,
    required int totalBuses,
    required int activeBuses,
    required int totalRoutes,
    required int activeRoutes,
    required int totalCapacity,
    required double totalKm,
  }) {
    switch (_selectedReportTab) {
      case 0:
        // Overview Summary Table
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Consolidated Summary of System Infrastructure',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            _buildScrollableTable(
              headers: const ['Category', 'Total Records', 'Active Units', 'Status / Utilization', 'Primary Metric'],
              rows: [
                ['Users / Students', '$totalUsers', '$activeUsers Active', '${((totalUsers > 0 ? (activeUsers / totalUsers * 100) : 0)).toStringAsFixed(1)}% active rate', '$inactiveUsers Inactive'],
                ['Drivers', '$totalDrivers', '$activeDrivers Active', '${((totalDrivers > 0 ? (activeDrivers / totalDrivers * 100) : 0)).toStringAsFixed(1)}% operational', '${totalDrivers - activeDrivers} on leave/inactive'],
                ['Buses Fleet', '$totalBuses', '$activeBuses Active', '${((totalBuses > 0 ? (activeBuses / totalBuses * 100) : 0)).toStringAsFixed(1)}% fleet readiness', '$totalCapacity Total Seats'],
                ['Routes Network', '$totalRoutes', '$activeRoutes Active', '${((totalRoutes > 0 ? (activeRoutes / totalRoutes * 100) : 0)).toStringAsFixed(1)}% routes active', '${totalKm.toStringAsFixed(1)} Total KM'],
              ],
            ),
          ],
        );

      case 1:
        // Users Table
        if (usersAsync.hasError) {
          return AdminErrorState(message: 'Failed to load users: ${usersAsync.error}');
        }
        if (usersAsync.isLoading && users.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }
        if (users.isEmpty) {
          return const AdminEmptyState(
            title: 'No user records match criteria',
            subtitle: 'Try adjusting your search query, role filter, or date range.',
            icon: Icons.people_alt_rounded,
          );
        }
        return _buildScrollableTable(
          headers: const ['Full Name', 'Role', 'Email', 'Course', 'Department', 'Status', 'Date Joined'],
          rows: users.map((u) {
            final role = u['role']?.toString().toUpperCase() ?? 'STUDENT';
            final isActive = u['isActive'] != false;
            return [
              u['fullName'] ?? '-',
              role,
              u['email'] ?? '-',
              u['course'] ?? '-',
              u['department'] ?? '-',
              isActive ? 'Active' : 'Suspended',
              _formatDate(u['createdAt']),
            ];
          }).toList(),
        );

      case 2:
        // Drivers Table
        if (driversAsync.hasError) {
          return AdminErrorState(message: 'Failed to load drivers: ${driversAsync.error}');
        }
        if (driversAsync.isLoading && drivers.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }
        if (drivers.isEmpty) {
          return const AdminEmptyState(
            title: 'No driver records match criteria',
            subtitle: 'Try adjusting your search query or filter criteria.',
            icon: Icons.person_pin_circle_rounded,
          );
        }
        return _buildScrollableTable(
          headers: const ['Driver Name', 'Driver ID', 'Mobile', 'License Number', 'Assigned Bus', 'Status'],
          rows: drivers.map((d) => [
            d['fullName'] ?? '-',
            d['driverId'] ?? '-',
            d['mobile'] ?? '-',
            d['licenseNumber'] ?? '-',
            d['assignedBusNumber'] ?? 'Unassigned',
            d['status'] ?? 'Active',
          ]).toList(),
        );

      case 3:
        // Buses Table
        if (busesAsync.hasError) {
          return AdminErrorState(message: 'Failed to load buses: ${busesAsync.error}');
        }
        if (busesAsync.isLoading && buses.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }
        if (buses.isEmpty) {
          return AdminEmptyState(
            title: 'No bus records match criteria',
            subtitle: 'Try adjusting your search query or filter criteria.',
            customIcon: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Image.asset('assets/images/bus_logo.png', width: 36, height: 36),
            ),
          );
        }
        return _buildScrollableTable(
          headers: const ['Bus Number', 'Bus Name', 'Reg Number', 'Driver Name', 'Capacity', 'Status'],
          rows: buses.map((b) => [
            b['busNumber'] ?? b['busNo'] ?? '-',
            b['busName'] ?? '-',
            b['registrationNumber'] ?? '-',
            b['driverName'] ?? 'Unassigned',
            b['capacity']?.toString() ?? '-',
            b['status'] ?? 'Active',
          ]).toList(),
        );

      case 4:
        // Routes Table
        if (routesAsync.hasError) {
          return AdminErrorState(message: 'Failed to load routes: ${routesAsync.error}');
        }
        if (routesAsync.isLoading && routes.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }
        if (routes.isEmpty) {
          return const AdminEmptyState(
            title: 'No route records match criteria',
            subtitle: 'Try adjusting your search query or filter criteria.',
            icon: Icons.route_rounded,
          );
        }
        return _buildScrollableTable(
          headers: const ['Route Name', 'Route Number', 'Origin / Source', 'Destination', 'Stops', 'Distance (KM)', 'Status'],
          rows: routes.map((r) {
            final stops = r['stops'];
            final stopsCount = stops is List ? stops.length : 0;
            final dist = r['distanceKm'] ?? r['distance'];
            final distStr = dist != null ? '$dist KM' : '-';
            return [
              r['routeName'] ?? r['name'] ?? '-',
              r['routeNumber'] ?? r['number'] ?? '-',
              r['origin'] ?? r['source'] ?? r['startLocation'] ?? '-',
              r['destination'] ?? r['dest'] ?? r['endLocation'] ?? '-',
              '$stopsCount stops',
              distStr,
              r['status'] ?? 'Active',
            ];
          }).toList(),
        );

      case 5:
        // Passes Table
        if (passes.isEmpty) {
          return const AdminEmptyState(
            title: 'No pass records found',
            subtitle: 'No bus passes have been issued yet in the database.',
            icon: Icons.badge_rounded,
          );
        }
        return _buildScrollableTable(
          headers: const ['Pass ID', 'Student Name', 'PRN', 'Route', 'Expiry Date', 'Status'],
          rows: passes.map((ps) => [
            ps['passId'] ?? ps['id'] ?? '-',
            ps['studentName'] ?? ps['fullName'] ?? 'Student',
            ps['prn'] ?? '-',
            ps['route'] ?? ps['routeName'] ?? '-',
            _formatDate(ps['expiryDate']),
            ps['passStatus'] ?? 'Active',
          ]).toList(),
        );

      case 6:
        // Payments Table
        if (payments.isEmpty) {
          return const AdminEmptyState(
            title: 'No payment records found',
            subtitle: 'No payment receipts recorded yet in the database.',
            icon: Icons.receipt_long_rounded,
          );
        }
        return _buildScrollableTable(
          headers: const ['Receipt ID', 'Student Name', 'Amount', 'Payment Method', 'Date', 'Status'],
          rows: payments.map((p) => [
            p['receiptId'] ?? p['id'] ?? '-',
            p['studentName'] ?? '-',
            '₹${p['amount'] ?? 0}',
            p['paymentMethod'] ?? 'Online',
            _formatDate(p['paymentDate'] ?? p['createdAt']),
            p['paymentStatus'] ?? 'Paid',
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
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)),
        dataRowColor: WidgetStateProperty.all(theme.colorScheme.surface),
        columnSpacing: 22.0,
        horizontalMargin: 10,
        headingRowHeight: 42,
        dataRowHeight: 46,
        border: TableBorder.symmetric(inside: BorderSide(color: theme.dividerColor, width: 0.8)),
        columns: headers.map((header) {
          return DataColumn(
            label: Text(
              header,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }).toList(),
        rows: rows.map((row) {
          return DataRow(
            cells: row.map((cell) {
              return DataCell(
                Text(
                  cell?.toString() ?? '',
                  style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurface),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  /// Exports report according to the active tab and filters
  Future<void> _handleExportAction({
    required bool isPdf,
    required String dateRangeStr,
    required List<Map<String, dynamic>> users,
    required List<Map<String, dynamic>> drivers,
    required List<Map<String, dynamic>> buses,
    required List<Map<String, dynamic>> routes,
    required List<Map<String, dynamic>> passes,
    required List<Map<String, dynamic>> payments,
  }) async {
    String reportTitle = '';
    String filenamePrefix = '';
    List<String> headers = [];
    List<List<dynamic>> rows = [];

    switch (_selectedReportTab) {
      case 0:
        reportTitle = 'ICEM Bus Portal - Executive Analytics Summary';
        filenamePrefix = 'executive_analytics_summary';
        headers = const ['Entity Category', 'Total Records', 'Active Units', 'Operational Rate', 'Key Metric'];
        rows = [
          ['Users / Students', '${users.length}', '${users.where((u) => u['isActive'] != false).length} Active', '${((users.isNotEmpty ? (users.where((u) => u['isActive'] != false).length / users.length * 100) : 0)).toStringAsFixed(1)}%', '${users.where((u) => u['isActive'] == false).length} Inactive'],
          ['Drivers', '${drivers.length}', '${drivers.where((d) => (d['status']?.toString().toLowerCase() ?? 'active') == 'active').length} Active', '${((drivers.isNotEmpty ? (drivers.where((d) => (d['status']?.toString().toLowerCase() ?? 'active') == 'active').length / drivers.length * 100) : 0)).toStringAsFixed(1)}%', '${drivers.where((d) => (d['status']?.toString().toLowerCase() ?? '') == 'on leave').length} On Leave'],
          ['Buses Fleet', '${buses.length}', '${buses.where((b) => (b['status']?.toString().toLowerCase() ?? 'active') == 'active').length} Active', '${((buses.isNotEmpty ? (buses.where((b) => (b['status']?.toString().toLowerCase() ?? 'active') == 'active').length / buses.length * 100) : 0)).toStringAsFixed(1)}%', '${buses.where((b) => (b['status']?.toString().toLowerCase() ?? '') == 'maintenance').length} In Maintenance'],
          ['Routes Network', '${routes.length}', '${routes.where((r) => (r['status']?.toString().toLowerCase() ?? 'active') == 'active').length} Active', '${((routes.isNotEmpty ? (routes.where((r) => (r['status']?.toString().toLowerCase() ?? 'active') == 'active').length / routes.length * 100) : 0)).toStringAsFixed(1)}%', '${routes.where((r) => r['assignedBusId'] != null).length} Assigned Buses'],
        ];
        break;

      case 1:
        reportTitle = 'ICEM Bus Portal - Users & Students Directory';
        filenamePrefix = 'users_directory_report';
        headers = const ['Full Name', 'Role', 'Email', 'Course', 'Department', 'Status', 'Date Joined'];
        rows = users.map((u) => [
          u['fullName'] ?? '-',
          (u['role'] ?? 'Student').toString().toUpperCase(),
          u['email'] ?? '-',
          u['course'] ?? '-',
          u['department'] ?? '-',
          (u['isActive'] != false) ? 'Active' : 'Suspended',
          _formatDate(u['createdAt']),
        ]).toList();
        break;

      case 2:
        reportTitle = 'ICEM Bus Portal - Drivers Directory Report';
        filenamePrefix = 'drivers_directory_report';
        headers = const ['Driver Name', 'Driver ID', 'Mobile', 'License Number', 'Assigned Bus', 'Status'];
        rows = drivers.map((d) => [
          d['fullName'] ?? '-',
          d['driverId'] ?? '-',
          d['mobile'] ?? '-',
          d['licenseNumber'] ?? '-',
          d['assignedBusNumber'] ?? 'Unassigned',
          d['status'] ?? 'Active',
        ]).toList();
        break;

      case 3:
        reportTitle = 'ICEM Bus Portal - Buses Fleet Report';
        filenamePrefix = 'buses_fleet_report';
        headers = const ['Bus Number', 'Bus Name', 'Reg Number', 'Driver Name', 'Capacity', 'Status'];
        rows = buses.map((b) => [
          b['busNumber'] ?? b['busNo'] ?? '-',
          b['busName'] ?? '-',
          b['registrationNumber'] ?? '-',
          b['driverName'] ?? 'Unassigned',
          b['capacity']?.toString() ?? '-',
          b['status'] ?? 'Active',
        ]).toList();
        break;

      case 4:
        reportTitle = 'ICEM Bus Portal - Routes Network Report';
        filenamePrefix = 'routes_network_report';
        headers = const ['Route Name', 'Route Number', 'Origin / Source', 'Destination', 'Stops', 'Distance (KM)', 'Status'];
        rows = routes.map((r) {
          final stops = r['stops'];
          final stopsCount = stops is List ? stops.length : 0;
          final dist = r['distanceKm'] ?? r['distance'];
          return [
            r['routeName'] ?? r['name'] ?? '-',
            r['routeNumber'] ?? r['number'] ?? '-',
            r['origin'] ?? r['source'] ?? r['startLocation'] ?? '-',
            r['destination'] ?? r['dest'] ?? r['endLocation'] ?? '-',
            '$stopsCount stops',
            dist != null ? '$dist KM' : '-',
            r['status'] ?? 'Active',
          ];
        }).toList();
        break;

      case 5:
        reportTitle = 'ICEM Bus Portal - Issued Bus Passes Report';
        filenamePrefix = 'issued_passes_report';
        headers = const ['Pass ID', 'Student Name', 'PRN', 'Route', 'Expiry Date', 'Status'];
        rows = passes.map((ps) => [
          ps['passId'] ?? ps['id'] ?? '-',
          ps['studentName'] ?? ps['fullName'] ?? 'Student',
          ps['prn'] ?? '-',
          ps['route'] ?? ps['routeName'] ?? '-',
          _formatDate(ps['expiryDate']),
          ps['passStatus'] ?? 'Active',
        ]).toList();
        break;

      case 6:
        reportTitle = 'ICEM Bus Portal - Payment Receipts Report';
        filenamePrefix = 'payment_receipts_report';
        headers = const ['Receipt ID', 'Student Name', 'Amount', 'Payment Method', 'Date', 'Status'];
        rows = payments.map((p) => [
          p['receiptId'] ?? p['id'] ?? '-',
          p['studentName'] ?? '-',
          '₹${p['amount'] ?? 0}',
          p['paymentMethod'] ?? 'Online',
          _formatDate(p['paymentDate'] ?? p['createdAt']),
          p['paymentStatus'] ?? 'Paid',
        ]).toList();
        break;
    }

    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No records available to export for this view.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
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
            content: Text('Generated report for $reportTitle successfully.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
