import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_widgets.dart';

void main() {
  group('AdminApplicationCard Security & State Tests', () {
    testWidgets('Unpaid application has disabled/locked approve button and shows warning', (tester) async {
      bool approved = false;

      final unpaidApp = {
        'id': 'APP-UNPAID-001',
        'studentName': 'Rahul Sharma',
        'prn': 'PRN12345',
        'collegeId': 'ENG001',
        'course': 'Computer Engineering',
        'routeName': 'Route 1 - Nigdi to ICEM',
        'boardingStop': 'Nigdi',
        'destinationStop': 'ICEM Campus',
        'fare': 4500.0,
        'paymentStatus': 'Pending',
        'passStatus': 'Payment Pending',
        'status': 'Payment Pending',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminApplicationCard(
              application: unpaidApp,
              onApprove: () {
                approved = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check displayed statuses
      expect(find.text('Status: Payment Pending'), findsOneWidget);
      expect(find.text('Payment: Unpaid'), findsOneWidget);

      // Check security warning
      expect(find.text('Payment required before approval'), findsOneWidget);

      // Verify Approve button is locked as 'Payment Required'
      expect(find.text('Payment Required'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);

      // Tap the locked button
      await tester.tap(find.text('Payment Required'));
      await tester.pumpAndSettle();

      // Verify onApprove was NOT called
      expect(approved, isFalse);

      // Verify SnackBar was shown
      expect(find.textContaining('Payment required before approval'), findsWidgets);
    });

    testWidgets('Verified paid application enables Approve button and triggers onApprove', (tester) async {
      bool approved = false;

      final paidApp = {
        'id': 'APP-PAID-002',
        'studentName': 'Priya Patil',
        'prn': 'PRN67890',
        'collegeId': 'ENG002',
        'course': 'IT Engineering',
        'routeName': 'Route 2 - Hinjewadi to ICEM',
        'boardingStop': 'Hinjewadi Phase 1',
        'destinationStop': 'ICEM Campus',
        'fare': 4500.0,
        'paymentStatus': 'Paid',
        'passStatus': 'Pending',
        'status': 'Pending',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminApplicationCard(
              application: paidApp,
              onApprove: () {
                approved = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check displayed statuses
      expect(find.text('Status: Pending Approval'), findsOneWidget);
      expect(find.text('Payment: Paid'), findsOneWidget);

      // Warning should NOT be present for paid application
      expect(find.text('Payment required before approval'), findsNothing);

      // Verify Approve button is enabled
      expect(find.text('Approve'), findsOneWidget);

      // Tap Approve
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      // Verify onApprove was called
      expect(approved, isTrue);
    });

    testWidgets('Approved application displays Approved status and does not show approve button', (tester) async {
      final approvedApp = {
        'id': 'APP-APPROVED-003',
        'studentName': 'Amit Deshmukh',
        'prn': 'PRN11223',
        'collegeId': 'ENG003',
        'course': 'Mechanical Engineering',
        'routeName': 'Route 1 - Nigdi to ICEM',
        'boardingStop': 'Akurdi',
        'destinationStop': 'ICEM Campus',
        'fare': 4500.0,
        'paymentStatus': 'Paid',
        'passStatus': 'Approved',
        'status': 'Approved',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminApplicationCard(
              application: approvedApp,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Status: Approved'), findsOneWidget);
      expect(find.text('Payment: Paid'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Payment Required'), findsNothing);
    });

    testWidgets('Unpaid application with pending status prevents approval and displays error toast', (tester) async {
      bool approved = false;

      final unpaidPendingApp = {
        'id': 'APP-UNPAID-004',
        'studentName': 'Sneha More',
        'prn': 'PRN99887',
        'collegeId': 'ENG004',
        'course': 'Civil Engineering',
        'routeName': 'Route 3 - Kothrud to ICEM',
        'boardingStop': 'Chandani Chowk',
        'destinationStop': 'ICEM Campus',
        'fare': 4500.0,
        'paymentStatus': 'Unpaid',
        'passStatus': 'Payment Pending',
        'status': 'Payment Pending',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminApplicationCard(
              application: unpaidPendingApp,
              onApprove: () {
                approved = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure button says Payment Required
      final paymentReqBtn = find.text('Payment Required');
      expect(paymentReqBtn, findsOneWidget);

      // Attempt to tap
      await tester.tap(paymentReqBtn);
      await tester.pumpAndSettle();

      // Must NOT be approved
      expect(approved, isFalse);

      // SnackBar with required text displayed
      expect(find.text('Payment required before approval. Student must complete verified payment first.'), findsOneWidget);
    });
  });
}
