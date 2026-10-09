// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum VerificationStatus {
  valid,
  invalid,
  expired,
  revoked,
  notActive,
}

class VerificationResult {
  final VerificationStatus status;
  final String title;
  final String? studentName;
  final String? passNumber;
  final String? route;
  final String? boardingStop;
  final String? validUntil;
  final String? message;

  const VerificationResult({
    required this.status,
    required this.title,
    this.studentName,
    this.passNumber,
    this.route,
    this.boardingStop,
    this.validUntil,
    this.message,
  });
}

class QrVerificationScreen extends ConsumerStatefulWidget {
  const QrVerificationScreen({super.key});

  @override
  ConsumerState<QrVerificationScreen> createState() =>
      _QrVerificationScreenState();
}

class _QrVerificationScreenState extends ConsumerState<QrVerificationScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        _verifyCode(rawValue.trim());
        break;
      }
    }
  }

  Future<void> _verifyCode(String rawCode) async {
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await _performBackendVerification(rawCode);
      if (!mounted) return;
      _showResultBottomSheet(result);
    } catch (e) {
      if (!mounted) return;
      _showResultBottomSheet(VerificationResult(
        status: VerificationStatus.invalid,
        title: '✕ Invalid Pass',
        message: 'Verification check failed: $e',
      ));
    }
  }

  Future<VerificationResult> _performBackendVerification(String raw) async {
    String passNumber = '';
    String passId = '';
    String studentId = '';

    // 1. Try parsing as JSON payload
    try {
      if (raw.startsWith('{') && raw.endsWith('}')) {
        final Map<String, dynamic> data = jsonDecode(raw);
        passNumber = (data['passNumber'] as String? ?? '').trim();
        passId = (data['passId'] as String? ?? '').trim();
        studentId = (data['studentId'] as String? ??
                data['studentUid'] as String? ??
                '')
            .trim();
      }
    } catch (_) {}

    // 2. Try parsing plain string
    if (passNumber.isEmpty && passId.isEmpty && studentId.isEmpty) {
      if (raw.startsWith('ICEM_PASS:')) {
        passNumber = raw.replaceFirst('ICEM_PASS:', '').trim();
      } else if (raw.startsWith('ICEM-BP-')) {
        passNumber = raw;
      } else if (raw.startsWith('ICEM-PASS-')) {
        passId = raw;
      } else {
        studentId = raw;
      }
    }

    final firestore = FirebaseFirestore.instance;
    Map<String, dynamic>? passData;

    // A) Search in bus_passes
    if (passNumber.isNotEmpty) {
      final snap = await firestore
          .collection('bus_passes')
          .where('passNumber', isEqualTo: passNumber)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) passData = snap.docs.first.data();
    }

    if (passData == null && passId.isNotEmpty) {
      final snap = await firestore
          .collection('bus_passes')
          .where('passId', isEqualTo: passId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) passData = snap.docs.first.data();
    }

    if (passData == null && studentId.isNotEmpty) {
      final doc = await firestore.collection('bus_passes').doc(studentId).get();
      if (doc.exists && doc.data() != null) passData = doc.data()!;
    }

    // B) Fallback: Search in bus_pass_applications
    if (passData == null) {
      if (passNumber.isNotEmpty) {
        final snap = await firestore
            .collection('bus_pass_applications')
            .where('passNumber', isEqualTo: passNumber)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) passData = snap.docs.first.data();
      }
      if (passData == null && passId.isNotEmpty) {
        final doc = await firestore
            .collection('bus_pass_applications')
            .doc(passId)
            .get();
        if (doc.exists && doc.data() != null) passData = doc.data()!;
      }
      if (passData == null && (passNumber.isNotEmpty || raw.isNotEmpty)) {
        final queryVal = passNumber.isNotEmpty ? passNumber : raw;
        final snap = await firestore
            .collection('bus_pass_applications')
            .where('applicationId', isEqualTo: queryVal)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) passData = snap.docs.first.data();
      }
    }

    // Result 1: Not found -> INVALID PASS
    if (passData == null) {
      return const VerificationResult(
        status: VerificationStatus.invalid,
        title: '✕ Invalid Pass',
        message: 'No bus pass record found in the ICEM database for this code.',
      );
    }

    // Extract student name
    String studentName = passData['fullName'] as String? ??
        passData['studentName'] as String? ??
        '';
    final uid = passData['uid'] as String? ?? passData['studentId'] as String? ?? '';
    if (studentName.isEmpty && uid.isNotEmpty) {
      final uDoc = await firestore.collection('users').doc(uid).get();
      if (uDoc.exists && uDoc.data() != null) {
        studentName = uDoc.data()?['fullName'] as String? ?? '';
      }
    }
    if (studentName.isEmpty) studentName = 'Student';

    final effectivePassNo = (passData['passNumber'] as String? ?? '').isNotEmpty
        ? passData['passNumber'] as String
        : (passData['passId'] as String? ?? 'N/A');

    final route = (passData['routeName'] as String? ??
            passData['route'] as String? ??
            'General Route')
        .toString();
    final boardingStop =
        (passData['boardingStop'] as String? ?? 'Campus').toString();

    // Validity date
    DateTime? validUntilDate;
    final vu = passData['validUntil'] ?? passData['expiryDate'];
    if (vu is Timestamp) {
      validUntilDate = vu.toDate();
    } else if (vu is String && vu.isNotEmpty) {
      validUntilDate = DateTime.tryParse(vu);
    }

    final validUntilFormatted = validUntilDate != null
        ? '${validUntilDate.day.toString().padLeft(2, '0')}/${validUntilDate.month.toString().padLeft(2, '0')}/${validUntilDate.year}'
        : 'N/A';

    final passStatus = (passData['passStatus'] as String? ??
            passData['status'] as String? ??
            '')
        .trim();
    final passStatusLower = passStatus.toLowerCase();

    final paymentStatus = (passData['paymentStatus'] as String? ?? '').trim();
    final isPaid = paymentStatus.toLowerCase() == 'paid' ||
        paymentStatus.toLowerCase() == 'success';

    final appStatus = (passData['applicationStatus'] as String? ??
            passData['status'] as String? ??
            '')
        .trim();
    final isApproved = appStatus.toLowerCase() == 'approved' ||
        passStatusLower == 'approved' ||
        passStatusLower == 'active';

    // Result 2: Revoked -> PASS REVOKED
    if (passStatusLower == 'revoked') {
      return VerificationResult(
        status: VerificationStatus.revoked,
        title: 'PASS REVOKED',
        studentName: studentName,
        passNumber: effectivePassNo,
        route: route,
        boardingStop: boardingStop,
        validUntil: validUntilFormatted,
        message: 'This pass has been revoked by ICEM administration.',
      );
    }

    // Result 3: Expired -> PASS EXPIRED
    if (validUntilDate != null && DateTime.now().isAfter(validUntilDate)) {
      return VerificationResult(
        status: VerificationStatus.expired,
        title: 'PASS EXPIRED',
        studentName: studentName,
        passNumber: effectivePassNo,
        route: route,
        boardingStop: boardingStop,
        validUntil: validUntilFormatted,
        message: 'This pass expired on $validUntilFormatted.',
      );
    }

    // Result 4: Unpaid or Unapproved -> PASS NOT ACTIVE
    if (!isPaid || !isApproved || (passStatusLower != 'active' && passStatusLower != 'approved')) {
      final String reason = !isPaid
          ? 'Payment has not been completed or verified.'
          : 'Application is awaiting administrative approval.';
      return VerificationResult(
        status: VerificationStatus.notActive,
        title: 'PASS NOT ACTIVE',
        studentName: studentName,
        passNumber: effectivePassNo,
        route: route,
        boardingStop: boardingStop,
        validUntil: validUntilFormatted,
        message: reason,
      );
    }

    // Result 5: Valid -> VALID PASS (✓ ACTIVE)
    return VerificationResult(
      status: VerificationStatus.valid,
      title: 'VALID PASS',
      studentName: studentName,
      passNumber: effectivePassNo,
      route: route,
      boardingStop: boardingStop,
      validUntil: validUntilFormatted,
      message: '✓ ACTIVE',
    );
  }

  void _showResultBottomSheet(VerificationResult result) {
    Color headerColor;
    Color bgColor;
    IconData icon;

    switch (result.status) {
      case VerificationStatus.valid:
        headerColor = AppColors.success;
        bgColor = AppColors.success.withValues(alpha: 0.12);
        icon = Icons.check_circle_rounded;
        break;
      case VerificationStatus.expired:
        headerColor = AppColors.warning;
        bgColor = AppColors.warning.withValues(alpha: 0.12);
        icon = Icons.warning_amber_rounded;
        break;
      case VerificationStatus.revoked:
      case VerificationStatus.invalid:
      case VerificationStatus.notActive:
        headerColor = AppColors.error;
        bgColor = AppColors.error.withValues(alpha: 0.12);
        icon = Icons.cancel_rounded;
        break;
    }

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 28,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Status Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: headerColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: headerColor, size: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.title,
                            style: TextStyle(
                              color: headerColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (result.message != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              result.message!,
                              style: TextStyle(
                                color: headerColor.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Details section (if student details present)
              if (result.studentName != null) ...[
                _buildVerificationRow('Student', result.studentName!),
                const Divider(height: 18, color: AppColors.borderSubtle),
                _buildVerificationRow('Pass', result.passNumber ?? 'N/A'),
                const Divider(height: 18, color: AppColors.borderSubtle),
                _buildVerificationRow('Route', result.route ?? 'N/A'),
                const Divider(height: 18, color: AppColors.borderSubtle),
                _buildVerificationRow('Boarding Stop', result.boardingStop ?? 'N/A'),
                const Divider(height: 18, color: AppColors.borderSubtle),
                _buildVerificationRow('Valid Until', result.validUntil ?? 'N/A'),
                const Divider(height: 18, color: AppColors.borderSubtle),
                _buildVerificationRow(
                  'Status',
                  result.status == VerificationStatus.valid
                      ? '✓ ACTIVE'
                      : (result.status == VerificationStatus.expired
                          ? 'EXPIRED'
                          : (result.status == VerificationStatus.revoked
                              ? 'REVOKED'
                              : 'NOT ACTIVE')),
                  isStatus: true,
                  statusColor: headerColor,
                ),
                const SizedBox(height: 24),
              ],

              // Scan next button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _isProcessing = false);
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                label: const Text(
                  'Scan Next Pass',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCrimson,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  Widget _buildVerificationRow(
    String label,
    String value, {
    bool isStatus = false,
    Color? statusColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isStatus)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: (statusColor ?? AppColors.primaryCrimson).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (statusColor ?? AppColors.primaryCrimson).withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: statusColor ?? AppColors.primaryCrimson,
              ),
            ),
          )
        else
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
      ],
    );
  }

  void _showManualInputDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Enter Pass Identifier',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Student Pass Number (e.g. ICEM-BP-2026-XXXXXX), Pass ID, or Student UID to verify against database:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'ICEM-BP-2026-...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.badge_rounded, color: AppColors.primaryCrimson),
                filled: true,
                fillColor: AppColors.elevatedSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primaryCrimson, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              _verifyCode(text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCrimson,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'ICEM Pass Verification',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? AppColors.accentGold : Colors.white,
            ),
            onPressed: () async {
              await _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Custom Framing Reticle
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity(0.55),
                child: Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isProcessing
                            ? AppColors.accentGold
                            : AppColors.primaryCrimson,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Instruction Text
          Positioned(
            top: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                _isProcessing ? 'Verifying with database...' : 'Align Student Pass QR inside frame',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Manual Enter Button at bottom
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              children: [
                if (_isProcessing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: CircularProgressIndicator(color: AppColors.primaryCrimson),
                  ),
                OutlinedButton.icon(
                  onPressed: _showManualInputDialog,
                  icon: const Icon(Icons.keyboard_alt_rounded, color: Colors.white),
                  label: const Text(
                    'Enter Pass ID / Number Manually',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.black54,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
