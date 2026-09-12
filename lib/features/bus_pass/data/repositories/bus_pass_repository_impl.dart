import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/core/errors/failures.dart';
import 'package:icem_bus/features/bus_pass/data/models/bus_pass_model.dart';
import 'package:icem_bus/features/bus_pass/domain/entities/bus_pass_entity.dart';
import 'package:icem_bus/features/bus_pass/domain/repositories/bus_pass_repository.dart';

final busPassRepositoryProvider = Provider<BusPassRepository>((ref) {
  return BusPassRepositoryImpl(firestore: FirebaseFirestore.instance);
});

class BusPassRepositoryImpl implements BusPassRepository {
  final FirebaseFirestore firestore;

  BusPassRepositoryImpl({required this.firestore});

  @override
  Future<BusPassEntity?> getBusPass(String uid) async {
    try {
      final doc = await firestore.collection('bus_passes').doc(uid).get();
      if (!doc.exists) return null;

      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      final pass = BusPassModel.fromMap(data);
      _triggerQrGenerationIfNeeded(pass);
      return pass;
    } catch (e) {
      throw ServerFailure('Failed to fetch bus pass status: ${e.toString()}');
    }
  }

  @override
  Stream<BusPassEntity?> watchBusPass(String uid) {
    return firestore
        .collection('bus_passes')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      final pass = BusPassModel.fromMap(data);
      _triggerQrGenerationIfNeeded(pass);
      return pass;
    });
  }

  void _triggerQrGenerationIfNeeded(BusPassEntity pass) {
    final status = pass.status;
    final paymentStatus = pass.paymentStatus;

    final isPaid = paymentStatus == 'Paid' || paymentStatus == 'Success';
    final isActive = status == 'Active' || status == 'Approved';

    if (isPaid && isActive) {
      // Check if QR Code is already generated and matches current pass ID and expiration date
      if (pass.qrCode != null && pass.qrCode!.isNotEmpty) {
        try {
          final Map<String, dynamic> payload = jsonDecode(pass.qrCode!);
          if (payload['passId'] == pass.passId &&
              payload['validUntil'] == pass.expiryDate.toIso8601String() &&
              payload['passStatus'] == pass.status) {
            // Already generated, up-to-date, do not regenerate
            return;
          }
        } catch (_) {
          // JSON parsing failed, let's regenerate
        }
      }

      // Generate QR Code payload in the background
      _generateAndStoreQrCode(pass);
    }
  }

  Future<void> _generateAndStoreQrCode(BusPassEntity pass) async {
    try {
      // 1. Fetch student details from the users collection
      final studentDoc = await firestore.collection('users').doc(pass.uid).get();
      final Map<String, dynamic> studentData = studentDoc.data() ?? {};
      final String studentName = studentData['fullName'] ?? 'Student';
      final String prn = studentData['prn'] ?? 'N/A';

      // 2. Fetch assigned bus ID from the buses collection
      String busId = 'Not Assigned';
      if (pass.routeId.isNotEmpty) {
        final busesQuery = await firestore
            .collection('buses')
            .where('assignedRouteId', isEqualTo: pass.routeId)
            .limit(1)
            .get();
        if (busesQuery.docs.isNotEmpty) {
          busId = busesQuery.docs.first.id;
        }
      }

      final validFrom = pass.validFrom ?? DateTime.now();

      // 3. Build unique payload
      final Map<String, dynamic> qrPayloadMap = {
        'passId': pass.passId,
        'studentUid': pass.uid,
        'studentName': studentName,
        'prn': prn,
        'routeId': pass.routeId,
        'busId': busId,
        'validFrom': validFrom.toIso8601String(),
        'validUntil': pass.expiryDate.toIso8601String(),
        'passStatus': pass.status,
      };

      final String qrPayload = jsonEncode(qrPayloadMap);

      // 4. Update the bus pass document in Firestore
      await firestore.collection('bus_passes').doc(pass.uid).update({
        'qrCode': qrPayload,
        'validFrom': Timestamp.fromDate(validFrom),
        'busId': busId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Ignore background errors
    }
  }

  @override
  Future<BusPassEntity> applyForBusPass({
    required String uid,
    required String route,
    required String routeId,
    required String boardingStop,
    required String destinationStop,
    required double fare,
    String? distance,
    String? department,
  }) async {
    try {
      final passId = 'ICEM-PASS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      
      // Fetch student info
      final userDoc = await firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      
      final passModel = BusPassModel(
        uid: uid,
        passId: passId,
        route: route,
        routeId: routeId,
        boardingStop: boardingStop,
        destinationStop: destinationStop,
        fare: fare,
        busNumber: null, // Assigned later by Admin
        status: 'Pending Payment', // Resets/sets status to pending payment until paid
        paymentStatus: 'Pending', // Pending payment
        expiryDate: DateTime.now().add(const Duration(days: 180)),
        qrCode: null,
        validFrom: null,
        busId: null,
        distance: distance,
        department: department,
      );

      final Map<String, dynamic> appData = passModel.toMap();
      appData['applicationId'] = passId;
      appData['fullName'] = userData['fullName'] ?? 'Student';
      appData['email'] = userData['email'] ?? '';
      appData['prn'] = userData['prn'] ?? '';

      // Save to applications collection
      await firestore.collection('bus_pass_applications').doc(passId).set(appData);
      
      // We also update or create the bus_passes document so watchBusPass can see the pending status if it's the primary way to check status
      // Wait, Admin checks applications. But to keep UI working, we might still need to set it in bus_passes or let UI check applications.
      // We'll write to bus_passes as well to satisfy the existing logic that reads it.
      await firestore.collection('bus_passes').doc(uid).set(passModel.toMap());

      return passModel;
    } catch (e) {
      throw ServerFailure('Failed to register pass application: ${e.toString()}');
    }
  }

  @override
  Future<BusPassEntity> renewBusPass(String uid) async {
    try {
      final currentPass = await getBusPass(uid);
      if (currentPass == null) {
        throw const AuthFailure('No existing pass record found to renew.');
      }

      final renewedModel = BusPassModel(
        uid: currentPass.uid,
        passId: currentPass.passId,
        route: currentPass.route,
        routeId: currentPass.routeId,
        boardingStop: currentPass.boardingStop,
        destinationStop: currentPass.destinationStop,
        fare: currentPass.fare,
        busNumber: currentPass.busNumber,
        status: 'Pending Payment', // Resets to pending payment
        paymentStatus: 'Pending',
        expiryDate: DateTime.now().add(const Duration(days: 180)),
        department: currentPass.department,
        distance: currentPass.distance,
        qrCode: null,
        validFrom: null,
        busId: null,
      );

      await firestore.collection('bus_passes').doc(uid).set(renewedModel.toMap());
      return renewedModel;
    } catch (e) {
      throw ServerFailure('Failed to process pass renewal: ${e.toString()}');
    }
  }

  @override
  Future<BusPassEntity> updatePassPayment({
    required String uid,
    required bool isSuccess,
  }) async {
    try {
      final currentPass = await getBusPass(uid);
      if (currentPass == null) {
        throw const AuthFailure('No pass application found.');
      }

      final updatedModel = BusPassModel(
        uid: currentPass.uid,
        passId: currentPass.passId,
        route: currentPass.route,
        routeId: currentPass.routeId,
        boardingStop: currentPass.boardingStop,
        destinationStop: currentPass.destinationStop,
        fare: currentPass.fare,
        busNumber: currentPass.busNumber,
        status: isSuccess ? 'Active' : 'Pending Payment',
        paymentStatus: isSuccess ? 'Paid' : 'Pending',
        expiryDate: currentPass.expiryDate,
        department: currentPass.department,
        distance: currentPass.distance,
        qrCode: isSuccess ? currentPass.qrCode : null,
        validFrom: isSuccess ? currentPass.validFrom : null,
        busId: isSuccess ? currentPass.busId : null,
      );

      await firestore.collection('bus_passes').doc(uid).set(updatedModel.toMap());
      return updatedModel;
    } catch (e) {
      throw ServerFailure('Failed to update pass payment: ${e.toString()}');
    }
  }
}
