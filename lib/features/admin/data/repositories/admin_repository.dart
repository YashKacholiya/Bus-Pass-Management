import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository handling all Firestore operations for the Admin dashboard.
class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // -------------------------------------------------------
  // APPLICATION ACTIONS
  // -------------------------------------------------------

  /// Approve a bus pass application by document ID.
  ///
  /// Sets passStatus = "Approved", generates a unique Pass ID,
  /// records the approving admin UID and server timestamp.
  Future<void> approveApplication(
    String applicationId,
    String adminUid,
  ) async {
    final passId =
        'ICEM-PASS-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';

    await _firestore
        .collection('bus_pass_applications')
        .doc(applicationId)
        .update({
      'status': 'Approved',
      'passStatus': 'Approved',
      'passId': passId,
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reject a bus pass application by document ID.
  ///
  /// Stores passStatus = "Rejected", the rejection reason,
  /// and a server timestamp.
  Future<void> rejectApplication(
    String applicationId,
    String rejectionReason,
    String adminUid,
  ) async {
    await _firestore
        .collection('bus_pass_applications')
        .doc(applicationId)
        .update({
      'status': 'Rejected',
      'passStatus': 'Rejected',
      'rejectionReason': rejectionReason,
      'rejectedBy': adminUid,
      'rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Request correction on a bus pass application by document ID.
  ///
  /// Stores passStatus = "Correction Required" and the correction
  /// message for the student to act upon.
  Future<void> requestCorrection(
    String applicationId,
    String correctionMessage,
  ) async {
    await _firestore
        .collection('bus_pass_applications')
        .doc(applicationId)
        .update({
      'status': 'Correction Required',
      'passStatus': 'Correction Required',
      'correctionMessage': correctionMessage,
      'correctionRequestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // -------------------------------------------------------
  // ROUTE CRUD
  // -------------------------------------------------------

  Future<void> addRoute(Map<String, dynamic> routeData) async {
    routeData['createdAt'] = FieldValue.serverTimestamp();
    routeData['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('bus_routes').add(routeData);
  }

  Future<void> updateRoute(
      String routeId, Map<String, dynamic> routeData) async {
    routeData['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('bus_routes').doc(routeId).update(routeData);
  }

  Future<void> deleteRoute(String routeId) async {
    await _firestore.collection('bus_routes').doc(routeId).delete();
  }

  /// Returns true if the given route is referenced in bus_passes or
  /// bus_pass_applications (used to guard against deletion).
  Future<bool> checkRouteInUse(String routeId) async {
    final passesQuery = await _firestore
        .collection('bus_passes')
        .where('routeId', isEqualTo: routeId)
        .limit(1)
        .get();
    if (passesQuery.docs.isNotEmpty) return true;

    final appsQuery = await _firestore
        .collection('bus_pass_applications')
        .where('routeId', isEqualTo: routeId)
        .limit(1)
        .get();
    return appsQuery.docs.isNotEmpty;
  }

  // -------------------------------------------------------
  // BUS CRUD
  // -------------------------------------------------------

  Future<void> addBus(Map<String, dynamic> busData) async {
    final busRef = _firestore.collection('buses').doc();
    final busId = busRef.id;
    busData['busId'] = busId;
    busData['createdAt'] = FieldValue.serverTimestamp();
    busData['updatedAt'] = FieldValue.serverTimestamp();

    final batch = _firestore.batch();
    batch.set(busRef, busData);

    // If a route is assigned, link it on the route document
    final assignedRouteId = busData['assignedRouteId'] as String?;
    if (assignedRouteId != null && assignedRouteId.isNotEmpty) {
      final routeRef = _firestore.collection('bus_routes').doc(assignedRouteId);
      batch.update(routeRef, {
        'assignedBusId': busId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Clear any other bus currently assigned to this route
      final otherBusesQuery = await _firestore
          .collection('buses')
          .where('assignedRouteId', isEqualTo: assignedRouteId)
          .get();
      for (final doc in otherBusesQuery.docs) {
        batch.update(doc.reference, {
          'assignedRouteId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  Future<void> updateBus(
    String busId,
    Map<String, dynamic> busData, {
    String? oldRouteId,
  }) async {
    busData['updatedAt'] = FieldValue.serverTimestamp();
    final busRef = _firestore.collection('buses').doc(busId);
    final batch = _firestore.batch();
    batch.update(busRef, busData);

    final newRouteId = busData['assignedRouteId'] as String?;
    if (newRouteId != oldRouteId) {
      // Clear old route's assigned bus
      if (oldRouteId != null && oldRouteId.isNotEmpty) {
        final oldRouteRef = _firestore.collection('bus_routes').doc(oldRouteId);
        batch.update(oldRouteRef, {
          'assignedBusId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Set new route's assigned bus, and clear other buses assigned to new route
      if (newRouteId != null && newRouteId.isNotEmpty) {
        final newRouteRef = _firestore.collection('bus_routes').doc(newRouteId);
        batch.update(newRouteRef, {
          'assignedBusId': busId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final otherBusesQuery = await _firestore
            .collection('buses')
            .where('assignedRouteId', isEqualTo: newRouteId)
            .get();
        for (final doc in otherBusesQuery.docs) {
          if (doc.id != busId) {
            batch.update(doc.reference, {
              'assignedRouteId': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }

    await batch.commit();
  }

  Future<void> deleteBus(String busId, {String? assignedRouteId}) async {
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('buses').doc(busId));

    if (assignedRouteId != null && assignedRouteId.isNotEmpty) {
      final routeRef = _firestore.collection('bus_routes').doc(assignedRouteId);
      batch.update(routeRef, {
        'assignedBusId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Returns true if the bus is assigned to an active route (preventing deletion).
  Future<bool> checkBusInUse(String? assignedRouteId) async {
    if (assignedRouteId == null || assignedRouteId.isEmpty) return false;
    final doc = await _firestore.collection('bus_routes').doc(assignedRouteId).get();
    if (!doc.exists) return false;
    final status = doc.data()?['status'] ?? 'Active';
    return status == 'Active';
  }

  /// Verify a manual cash/transfer payment by document ID.
  /// Sets paymentStatus = "Paid" in receipts, updates the application,
  /// and activates the student's digital bus pass.
  Future<void> verifyManualPayment(
    String receiptId,
    String studentUid,
    String adminUid,
  ) async {
    final batch = _firestore.batch();

    // 1. Update the receipt document
    final receiptRef = _firestore.collection('receipts').doc(receiptId);
    batch.update(receiptRef, {
      'paymentStatus': 'Paid',
      'verifiedBy': adminUid,
      'verifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Update the pending application in bus_pass_applications
    final appQuery = await _firestore
        .collection('bus_pass_applications')
        .where('uid', isEqualTo: studentUid)
        .where('passStatus', isEqualTo: 'Pending Payment')
        .limit(1)
        .get();

    for (final doc in appQuery.docs) {
      batch.update(doc.reference, {
        'paymentStatus': 'Paid',
        'passStatus': 'Active',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 3. Update/create digital bus pass in bus_passes
    final passRef = _firestore.collection('bus_passes').doc(studentUid);
    batch.update(passRef, {
      'paymentStatus': 'Paid',
      'passStatus': 'Active',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Mark payment as failed.
  /// Updates paymentStatus to "Failed" and deactivates or sets the corresponding application and pass to "Failed".
  Future<void> markPaymentFailed(String receiptId, String studentUid) async {
    final batch = _firestore.batch();

    // 1. Update the receipt document
    final receiptRef = _firestore.collection('receipts').doc(receiptId);
    batch.update(receiptRef, {
      'paymentStatus': 'Failed',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Update the pending application in bus_pass_applications
    final appQuery = await _firestore
        .collection('bus_pass_applications')
        .where('uid', isEqualTo: studentUid)
        .where('passStatus', isEqualTo: 'Pending Payment')
        .limit(1)
        .get();

    for (final doc in appQuery.docs) {
      batch.update(doc.reference, {
        'paymentStatus': 'Failed',
        'passStatus': 'Failed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 3. Update digital bus pass in bus_passes if it exists
    final passRef = _firestore.collection('bus_passes').doc(studentUid);
    final passSnap = await passRef.get();
    if (passSnap.exists) {
      batch.update(passRef, {
        'paymentStatus': 'Failed',
        'passStatus': 'Failed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Refund a successful payment (Status Only).
  /// Updates paymentStatus to "Refunded" and marks the application and pass as "Refunded" / inactive.
  Future<void> refundPayment(String receiptId, String studentUid) async {
    final batch = _firestore.batch();

    // 1. Update the receipt document
    final receiptRef = _firestore.collection('receipts').doc(receiptId);
    batch.update(receiptRef, {
      'paymentStatus': 'Refunded',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Update all applications for the student to status "Refunded"
    final appQuery = await _firestore
        .collection('bus_pass_applications')
        .where('uid', isEqualTo: studentUid)
        .get();

    for (final doc in appQuery.docs) {
      batch.update(doc.reference, {
        'paymentStatus': 'Refunded',
        'passStatus': 'Refunded',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 3. Update/cancel digital bus pass in bus_passes
    final passRef = _firestore.collection('bus_passes').doc(studentUid);
    final passSnap = await passRef.get();
    if (passSnap.exists) {
      batch.update(passRef, {
        'paymentStatus': 'Refunded',
        'passStatus': 'Refunded',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }



  // -------------------------------------------------------
  // STUDENT ACTIONS
  // -------------------------------------------------------

  Future<void> suspendStudent(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> activateStudent(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteStudent(String uid) async {
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('users').doc(uid));
    batch.delete(_firestore.collection('bus_passes').doc(uid));
    final apps = await _firestore
        .collection('bus_pass_applications')
        .where('uid', isEqualTo: uid)
        .get();
    for (final doc in apps.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> approveStudentPass(String uid, String adminUid) async {
    final batch = _firestore.batch();
    final passRef = _firestore.collection('bus_passes').doc(uid);
    
    // Check if pass document exists, if not set/create, if yes update
    final passSnap = await passRef.get();
    if (passSnap.exists) {
      batch.update(passRef, {
        'passStatus': 'Active',
        'paymentStatus': 'Paid',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.set(passRef, {
        'uid': uid,
        'passStatus': 'Active',
        'paymentStatus': 'Paid',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final appQuery = await _firestore
        .collection('bus_pass_applications')
        .where('uid', isEqualTo: uid)
        .get();

    for (final doc in appQuery.docs) {
      batch.update(doc.reference, {
        'passStatus': 'Active',
        'paymentStatus': 'Paid',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> rejectStudentPass(String uid, String reason) async {
    final batch = _firestore.batch();
    final passRef = _firestore.collection('bus_passes').doc(uid);
    
    final passSnap = await passRef.get();
    if (passSnap.exists) {
      batch.update(passRef, {
        'passStatus': 'Rejected',
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.set(passRef, {
        'uid': uid,
        'passStatus': 'Rejected',
        'rejectionReason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final appQuery = await _firestore
        .collection('bus_pass_applications')
        .where('uid', isEqualTo: uid)
        .get();

    for (final doc in appQuery.docs) {
      batch.update(doc.reference, {
        'passStatus': 'Rejected',
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // -------------------------------------------------------
  // NOTIFICATION
  // -------------------------------------------------------

  Future<void> sendNotification({
    required String title,
    required String body,
    required String targetAudience,
  }) async {
    await _firestore.collection('notifications').add({
      'title': title,
      'body': body,
      'targetAudience': targetAudience,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }
}
