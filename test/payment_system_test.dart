import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/features/payment/data/models/payment_config_model.dart';
import 'package:icem_bus/features/payment/domain/entities/payment_entity.dart';
import 'package:icem_bus/features/payment/data/models/payment_model.dart';
import 'package:icem_bus/features/payment/presentation/views/student_payment_screen.dart';
import 'package:icem_bus/features/payment/presentation/views/pay_via_upi_qr_screen.dart';
import 'package:icem_bus/features/payment/presentation/views/payment_receipt_screen.dart';
import 'package:icem_bus/features/payment/data/repositories/payment_config_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Payment Config & Model Unit Tests', () {
    test('Default payment configuration contains correct fee and settings', () {
      final config = PaymentConfigModel.defaultConfig();
      expect(config.defaultFee, 4500.0);
      expect(config.feeInPaise, 450000);
      expect(config.currency, 'INR');
      expect(config.environment, 'TEST');
    });

    test('PaymentModel serializes and deserializes accurately with consistent ₹4500', () {
      final model = PaymentModel(
        paymentId: 'PAY-101',
        applicationId: 'APP-202',
        studentId: 'STU-303',
        studentName: 'Yash Kacholiya',
        routeId: 'ROUTE-01',
        routeName: 'Route 1 - Nigdi to ICEM',
        amount: 4500.0,
        currency: 'INR',
        paymentStatus: 'paid',
        paymentMethod: 'Razorpay',
        razorpayOrderId: 'order_12345',
        razorpayPaymentId: 'pay_67890',
        createdAt: DateTime(2026, 9, 28, 12, 0),
        paidAt: DateTime(2026, 9, 28, 12, 5),
      );

      final map = model.toMap();
      expect(map['amount'], 4500.0);
      expect(map['currency'], 'INR');
      expect(map['paymentStatus'], 'paid');
      expect(map['paymentMethod'], 'Razorpay');
      expect(map['razorpayOrderId'], 'order_12345');
      expect(map['razorpayPaymentId'], 'pay_67890');

      final fromMap = PaymentModel.fromMap(map, 'PAY-101');
      expect(fromMap.paymentId, 'PAY-101');
      expect(fromMap.amount, 4500.0);
      expect(fromMap.studentName, 'Yash Kacholiya');
      expect(fromMap.routeName, 'Route 1 - Nigdi to ICEM');
      expect(fromMap.fare, 4500.0);
    });
  });

  group('StudentPaymentScreen Razorpay Standard Checkout Tests', () {
    testWidgets('Renders simple and premium UI per Section 10 with PAY ₹4,500', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentConfigStreamProvider.overrideWith(
              (ref) => Stream.value(PaymentConfigModel.defaultConfig()),
            ),
          ],
          child: const MaterialApp(
            home: StudentPaymentScreen(
              testApplicationId: 'APP-TEST-999',
              testRouteName: 'Route 1 - Nigdi to ICEM',
              testStudentName: 'Yash Kacholiya',
              testStudentEmail: 'student@icem.edu',
              testStudentPhone: '9876543210',
              testRouteFee: 4500.0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and core items (Section 10)
      expect(find.text('ICEM BUS PASS PAYMENT'), findsOneWidget);
      expect(find.text('Route 1 - Nigdi to ICEM'), findsOneWidget);
      expect(find.text('Yash Kacholiya'), findsOneWidget);
      expect(find.text('₹4,500'), findsOneWidget);
      expect(find.text('Payment Pending'), findsWidgets);

      // Check primary button: PAY ₹4,500
      expect(find.text('PAY ₹4,500'), findsOneWidget);

      // Check small text: Secure payment powered by Razorpay
      expect(find.text('Secure payment powered by Razorpay'), findsOneWidget);

      // Verify custom manual UPI QR / UTR fields are REMOVED from the normal student payment screen
      expect(find.text('Pay via UPI QR'), findsNothing);
      expect(find.text('Direct UPI Transfer'), findsNothing);
      expect(find.text('Enter the 12-digit UTR'), findsNothing);
      expect(find.text('8766629441@axl'), findsNothing);
    });
  });

  group('Deprecated PayViaUpiQrScreen Test', () {
    testWidgets('Renders deprecation notice and redirect button to Razorpay checkout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PayViaUpiQrScreen(
            applicationId: 'APP-TEST-999',
            routeName: 'Route 1 - Nigdi to ICEM',
            routeId: 'ROUTE-01',
            studentName: 'Yash Kacholiya',
            amount: 4500.0,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Direct Razorpay Checkout Required'), findsOneWidget);
      expect(find.text('Proceed to Razorpay Checkout'), findsOneWidget);
    });
  });

  group('PaymentReceiptScreen Widget Tests', () {
    testWidgets('Renders Section 13 payment receipt details correctly', (tester) async {
      final receiptPayment = PaymentEntity(
        paymentId: 'RCPT-100234',
        applicationId: 'APP-ICEM-777',
        studentId: 'STU-999',
        studentName: 'Yash Kacholiya',
        routeId: 'ROUTE-01',
        routeName: 'Route 1 - Nigdi to ICEM',
        amount: 4500.0,
        currency: 'INR',
        paymentStatus: 'paid',
        paymentMethod: 'UPI / Razorpay',
        razorpayPaymentId: 'pay_test_887766',
        receiptId: 'RCPT-100234',
        createdAt: DateTime(2026, 9, 28, 14, 30),
        paidAt: DateTime(2026, 9, 28, 14, 32),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentReceiptScreen(
            paymentId: 'RCPT-100234',
            initialPayment: receiptPayment,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Section 13 elements
      expect(find.text('ICEM'), findsOneWidget);
      expect(find.text('Bus Pass Payment Receipt'), findsOneWidget);
      expect(find.text('Yash Kacholiya'), findsOneWidget);
      expect(find.text('APP-ICEM-777'), findsOneWidget);
      expect(find.text('Route 1 - Nigdi to ICEM'), findsOneWidget);
      expect(find.text('₹4,500'), findsWidgets);
      expect(find.text('UPI / Razorpay'), findsOneWidget);
      expect(find.text('pay_test_887766'), findsOneWidget);
      expect(find.text('PAID / VERIFIED'), findsWidgets);
      expect(find.text('RCPT-100234'), findsOneWidget);
    });
  });
}
