import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      .map((s) => s.docs.length);
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
      .where('status', isEqualTo: 'Pending')
      .snapshots()
      .map((s) => s.docs.length);
});

final approvedPassesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .where('status', isEqualTo: 'Approved')
      .snapshots()
      .map((s) => s.docs.length);
});

final rejectedPassesStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('bus_pass_applications')
      .where('status', isEqualTo: 'Rejected')
      .snapshots()
      .map((s) => s.docs.length);
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
  Query<Map<String, dynamic>> query =
      FirebaseFirestore.instance.collection('bus_pass_applications');

  if (statusFilter != 'All') {
    query = query.where('status', isEqualTo: statusFilter);
  }

  return query.orderBy('createdAt', descending: true).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList());
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
      .collection('receipts')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList());
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
