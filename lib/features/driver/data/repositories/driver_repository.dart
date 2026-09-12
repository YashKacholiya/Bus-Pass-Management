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
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
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
