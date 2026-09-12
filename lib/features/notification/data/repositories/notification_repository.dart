import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Returns a real-time stream of all notifications sorted by creation date descending.
  Stream<List<Map<String, dynamic>>> getNotificationsStream() {
    return _firestore
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              data['notificationId'] = doc.id;
              return data;
            }).toList());
  }

  /// Creates a new notification document.
  Future<void> createNotification(Map<String, dynamic> data) async {
    final docRef = _firestore.collection('notifications').doc();
    data['notificationId'] = docRef.id;
    data['createdAt'] = FieldValue.serverTimestamp();
    // Default scheduledAt to now if not provided
    if (data['scheduledAt'] == null) {
      data['scheduledAt'] = FieldValue.serverTimestamp();
    }
    await docRef.set(data);
  }

  /// Updates an existing scheduled notification document.
  Future<void> updateNotification(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('notifications').doc(id).update(data);
  }

  /// Deletes a notification document.
  Future<void> deleteNotification(String id) async {
    await _firestore.collection('notifications').doc(id).delete();
  }
}
