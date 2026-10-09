import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository();
});

class DriverRepository {
  final FirebaseFirestore _firestore;

  DriverRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream of all drivers from Firestore collection 'drivers'
  Stream<List<Map<String, dynamic>>> getDriversStream() {
    return _firestore
        .collection('drivers')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          list.sort((a, b) {
            final aDate = a['createdAt'];
            final bDate = b['createdAt'];
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
  }

  /// Add a new driver to Firestore
  Future<void> addDriver(Map<String, dynamic> driverData) async {
    driverData['createdAt'] = FieldValue.serverTimestamp();
    driverData['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('drivers').add(driverData);
  }

  /// Update an existing driver in Firestore
  Future<void> updateDriver(String id, Map<String, dynamic> driverData) async {
    driverData['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('drivers').doc(id).update(driverData);
  }

  /// Delete a driver from Firestore
  Future<void> deleteDriver(String id) async {
    await _firestore.collection('drivers').doc(id).delete();
  }
}
