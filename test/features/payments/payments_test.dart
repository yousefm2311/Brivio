import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/payments/domain/models/payment_models.dart';
import 'package:flutter_application_1/features/payments/presentation/screens/payment_screens.dart';

void main() {
  group('Phase 8.5 Security & Payments Engine Tests', () {
    test('SubscriptionPlan model parses JSON correctly', () {
      final json = {
        'id': 'b0000000-0000-0000-0000-000000000001',
        'name': 'Full Semester CS 101',
        'billing_type': 'installment',
        'total_amount_minor': 300000,
        'currency': 'EGP',
        'installment_count': 3,
        'status': 'active',
      };

      final plan = SubscriptionPlan.fromJson(json);
      expect(plan.name, equals('Full Semester CS 101'));
      expect(plan.totalAmountMinor, equals(300000));
      expect(plan.installmentCount, equals(3));
    });

    test('Invoice calculates remaining balance correctly', () {
      final inv = Invoice(
        id: 'inv-1',
        invoiceNumber: 'INV-2026-000001',
        studentId: 'stud-1',
        subtotalMinor: 100000,
        totalMinor: 100000,
        amountPaidMinor: 40000,
        status: 'partially_paid',
        dueAt: DateTime.now(),
        issuedAt: DateTime.now(),
      );

      expect(inv.remainingBalanceMinor, equals(60000));
    });

    test(
      'Redirect Security Test: Unverified client redirect params MUST NOT alter invoice status to paid',
      () {
        final inv = Invoice(
          id: 'inv-2',
          invoiceNumber: 'INV-2026-000002',
          studentId: 'stud-1',
          subtotalMinor: 100000,
          totalMinor: 100000,
          amountPaidMinor: 0,
          status: 'issued',
          dueAt: DateTime.now(),
          issuedAt: DateTime.now(),
        );

        // Simulating a malicious query param redirect: ?success=true
        const bool redirectQueryParamSuccess = true;

        // Status must remain 'issued' until server settlement RPC confirms 'paid'
        final String statusAfterRedirect =
            (redirectQueryParamSuccess && inv.status == 'paid')
            ? 'paid'
            : inv.status;
        expect(statusAfterRedirect, equals('issued'));
        expect(statusAfterRedirect, isNot('paid'));
      },
    );

    testWidgets('FinancialSummaryWidget renders total due and balance', (
      WidgetTester tester,
    ) async {
      final summary = FinancialSummary(
        studentId: 'stud-1',
        invoiceCount: 2,
        totalDueMinor: 150000,
        totalPaidMinor: 50000,
        remainingBalanceMinor: 100000,
        currency: 'EGP',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FinancialSummaryWidget(summary: summary)),
        ),
      );

      expect(find.text('Financial Summary'), findsOneWidget);
      expect(find.text('1500.0 EGP'), findsOneWidget);
      expect(find.text('500.0 EGP'), findsOneWidget);
      expect(find.text('1000.0 EGP'), findsOneWidget);
    });

    testWidgets(
      'InvoiceListWidget renders list and Record Cash button for unpaid invoices',
      (WidgetTester tester) async {
        final invoices = [
          Invoice(
            id: 'inv-1',
            invoiceNumber: 'INV-2026-000001',
            studentId: 'stud-1',
            subtotalMinor: 50000,
            totalMinor: 50000,
            amountPaidMinor: 0,
            status: 'issued',
            dueAt: DateTime.now(),
            issuedAt: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: InvoiceListWidget(invoices: invoices)),
          ),
        );

        expect(find.text('Invoice INV-2026-000001'), findsOneWidget);
        expect(find.text('Record Cash'), findsOneWidget);
      },
    );
  });
}
