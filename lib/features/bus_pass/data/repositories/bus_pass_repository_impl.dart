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
    if (pass.isActive) {
      if (pass.qrCode != null && pass.qrCode!.isNotEmpty) {
        try {
          final Map<String, dynamic> payload = jsonDecode(pass.qrCode!);
          if (payload['passNumber'] == pass.effectivePassNumber &&
              payload['passId'] == pass.passId &&
              payload['validUntil'] == pass.effectiveValidUntil.toIso8601String() &&
              payload['passStatus'] == pass.status) {
            return;
          }
        } catch (_) {}
      }

      _generateAndStoreQrCode(pass);
    }
  }

  Future<void> _generateAndStoreQrCode(BusPassEntity pass) async {
    try {
      final validFrom = pass.validFrom ?? DateTime.now();
      final validUntil = pass.effectiveValidUntil;

      // Secure payload with unique references (no passwords, secrets or private data)
      final Map<String, dynamic> qrPayloadMap = {
        'type': 'ICEM_BUS_PASS',
        'passNumber': pass.effectivePassNumber,
        'passId': pass.passId,
        'studentId': pass.uid,
        'routeId': pass.routeId,
        'validUntil': validUntil.toIso8601String(),
        'passStatus': pass.status,
      };

      final String qrPayload = jsonEncode(qrPayloadMap);

      await firestore.collection('bus_passes').doc(pass.uid).update({
        'qrCode': qrPayload,
        'validFrom': Timestamp.fromDate(validFrom),
        'validUntil': Timestamp.fromDate(validUntil),
        'expiryDate': Timestamp.fromDate(validUntil),
        'passNumber': pass.effectivePassNumber,
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
        status: 'Payment Pending', // Initial application status must be: Payment Pending
        paymentStatus: 'Pending', // Pending payment
        expiryDate: DateTime.now().add(const Duration(days: 180)),
        qrCode: null,
        validFrom: null,
        busId: null,
        distance: distance,
        department: department ?? userData['department'],
      );

      final Map<String, dynamic> appData = passModel.toMap();
      appData['applicationId'] = passId;
      appData['passId'] = passId;
      appData['uid'] = uid;
      appData['studentId'] = uid;
      appData['fullName'] = userData['fullName'] ?? 'Student';
      appData['email'] = userData['email'] ?? '';
      appData['prn'] = userData['prn'] ?? '';
      appData['mobile'] = userData['mobile'] ?? '';
      appData['collegeId'] = userData['collegeId'] ?? '';
      appData['department'] = department ?? userData['department'] ?? '';
      appData['course'] = userData['course'] ?? '';
      appData['year'] = userData['year'] ?? '';
      appData['semester'] = userData['semester'] ?? '';
      appData['status'] = 'Payment Pending';
      appData['passStatus'] = 'Payment Pending';
      appData['paymentStatus'] = 'Pending';
      appData['createdAt'] = FieldValue.serverTimestamp();
      appData['updatedAt'] = FieldValue.serverTimestamp();

      // Save to applications collection
      await firestore.collection('bus_pass_applications').doc(passId).set(appData);
      
      // Update/create the bus_passes document (Pass is NOT active, payment is pending)
      final Map<String, dynamic> passDocData = passModel.toMap();
      passDocData['status'] = 'Payment Pending';
      passDocData['passStatus'] = 'Payment Pending';
      passDocData['paymentStatus'] = 'Pending';
      passDocData['createdAt'] = FieldValue.serverTimestamp();
      passDocData['updatedAt'] = FieldValue.serverTimestamp();
      await firestore.collection('bus_passes').doc(uid).set(passDocData);

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
        status: 'Payment Pending', // Resets to Payment Pending
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

      // CRITICAL SECURITY FIX:
      // When payment is successful, status becomes 'Pending' (waiting for Admin approval).
      // It MUST NOT become 'Active' or 'Approved' before Admin approval!
      final updatedModel = BusPassModel(
        uid: currentPass.uid,
        passId: currentPass.passId,
        route: currentPass.route,
        routeId: currentPass.routeId,
        boardingStop: currentPass.boardingStop,
        destinationStop: currentPass.destinationStop,
        fare: currentPass.fare,
        busNumber: currentPass.busNumber,
        status: isSuccess ? 'Pending' : 'Payment Pending',
        paymentStatus: isSuccess ? 'Paid' : 'Pending',
        expiryDate: currentPass.expiryDate,
        department: currentPass.department,
        distance: currentPass.distance,
        qrCode: null, // Blocked until Admin approval
        validFrom: null, // Blocked until Admin approval
        busId: currentPass.busId,
      );

      await firestore.collection('bus_passes').doc(uid).set(updatedModel.toMap());
      return updatedModel;
    } catch (e) {
      throw ServerFailure('Failed to update pass payment: ${e.toString()}');
    }
  }
}
