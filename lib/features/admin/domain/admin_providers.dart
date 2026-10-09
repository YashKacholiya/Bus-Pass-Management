import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';

// ============================================================
// TAB / SEARCH / FILTER STATE PROVIDERS
// ============================================================

/// Currently selected sidebar tab index (persisted across rebuilds)
final adminTabProvider = StateProvider<int>((ref) => 0);

/// Dashboard search query (name / PRN / college ID)
final dashboardSearchQueryProvider =
    StateProvider.autoDispose<String>((ref) => '');

/// Dashboard status filter chip selection
final dashboardStatusFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'All');

/// Routes tab — status filter chip: 'All', 'Active', 'Inactive'
final routeStatusFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'All');

/// Routes tab — search query
final routeSearchQueryProvider =
    StateProvider.autoDispose<String>((ref) => '');

/// Buses tab — status filter chip: 'All', 'Active', 'Maintenance', 'Inactive'
final busStatusFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'All');

/// Buses tab — search query
final busSearchQueryProvider =
    StateProvider.autoDispose<String>((ref) => '');


// ============================================================
// LIVE FIRESTORE STREAM PROVIDERS — SUMMARY CARD COUNTS
// ============================================================

final totalStudentsStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((s) => s.docs.where((d) => UserEntity.isStudentUser(d.data())).length);
});

final activePassesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_passes')
      .where('passStatus', isEqualTo: 'Active')
      .snapshots()
      .map((s) => s.docs.length);
});

final pendingAppsStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .snapshots()
      .map((s) => s.docs.where((d) {
            final st = (d.data()['status'] ?? d.data()['passStatus'] ?? '').toString();
            return st == 'Pending' || st == 'Payment Pending' || st == 'Pending Approval' || st == 'Pending Payment';
          }).length);
});

final approvedPassesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .snapshots()
      .map((s) => s.docs.where((d) {
            final st = (d.data()['status'] ?? d.data()['passStatus'] ?? '').toString();
            return st == 'Approved' || st == 'Active';
          }).length);
});

final rejectedPassesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .snapshots()
      .map((s) => s.docs.where((d) {
            final st = (d.data()['status'] ?? d.data()['passStatus'] ?? '').toString();
            return st == 'Rejected';
          }).length);
});

final expiredPassesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_passes')
      .where('passStatus', isEqualTo: 'Expired')
      .snapshots()
      .map((s) => s.docs.length);
});

final correctionRequiredStreamProvider =
    StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .where('status', isEqualTo: 'Correction Required')
      .snapshots()
      .map((s) => s.docs.length);
});

final totalRoutesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_routes')
      .snapshots()
      .map((s) => s.docs.length);
});

final totalBusesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('buses')
      .snapshots()
      .map((s) => s.docs.length);
});

// ============================================================
// RECENT APPLICATIONS (latest 10)
// ============================================================

final recentApplicationsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList());
});

// ============================================================
// FILTERED APPLICATIONS STREAM (for applications tab)
// ============================================================

final filteredApplicationsStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, statusFilter) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final pStatus = (data['paymentStatus'] as String? ?? '').toLowerCase();
      final aStatus = (data['status'] as String? ?? data['passStatus'] as String? ?? '').toLowerCase();
      if ((aStatus == 'approved' || aStatus == 'active') && pStatus != 'paid' && pStatus != 'success') {
        // Diagnostic warning for historical inconsistent records
        debugPrint('🚨 [INCONSISTENT APPLICATION DETECTED]: ID: ${doc.id}, Application Status: ${data['status']}, Payment Status: ${data['paymentStatus']}, Student: ${data['fullName'] ?? data['studentName']}');
      }
    }

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).where((app) {
      if (statusFilter == 'All') return true;
      final st = (app['status'] ?? app['passStatus'] ?? '').toString();
      final pStatus = (app['paymentStatus'] ?? '').toString().toLowerCase();
      final isPaid = pStatus == 'paid' || pStatus == 'success';

      if (statusFilter == 'Pending') {
        return st == 'Pending' || st == 'Pending Approval' || st == 'Payment Pending' || st == 'Pending Payment';
      } else if (statusFilter == 'Approved') {
        return st == 'Approved' || st == 'Active';
      } else if (statusFilter == 'Rejected') {
        return st == 'Rejected';
      } else if (statusFilter == 'Payment Pending') {
        return !isPaid && (st == 'Payment Pending' || st == 'Pending Payment' || st == 'Pending');
      }
      return st == statusFilter;
    }).toList();
  });
});

// ============================================================
// ROUTES, BUSES, STUDENTS LIST STREAMS
// ============================================================

final routesListStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_routes')
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList());
});

final busesListStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('buses')
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList());
});

final studentsListStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((s) => s.docs
          .where((d) => UserEntity.isStudentUser(d.data()))
          .map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList());
});

final allUsersListStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList());
});

// ============================================================
// SINGLE APPLICATION STREAM (for detail screen)
// ============================================================

final singleApplicationStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, applicationId) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .doc(applicationId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return data;
  });
});

final paymentsListStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('payments')
      .snapshots()
      .asyncMap((paymentsSnap) async {
        final paymentsMap = <String, Map<String, dynamic>>{};
        for (final doc in paymentsSnap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          paymentsMap[doc.id] = data;
        }

        try {
          final receiptsSnap =
              await FirebaseFirestore.instance.collection('receipts').get();
          for (final doc in receiptsSnap.docs) {
            if (!paymentsMap.containsKey(doc.id)) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              paymentsMap[doc.id] = data;
            }
          }
        } catch (_) {}

        final list = paymentsMap.values.toList();
        list.sort((a, b) {
          final aDate = a['createdAt'] ?? a['paymentDate'];
          final bDate = b['createdAt'] ?? b['paymentDate'];
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          if (aDate is Timestamp && bDate is Timestamp) {
            return bDate.compareTo(aDate);
          }
          return 0;
        });
        return list;
      });
});

final busPassesListStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_passes')
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList());
});

final applicationsListStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList());
});
