import 'package:flutter/foundation.dart';

class Invoice {
  final String id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final bool isPaid;

  Invoice({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
  });
}

class PaymentHistory {
  final String id;
  final String description;
  final double amount;
  final DateTime date;

  PaymentHistory({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
  });
}

class ParentFinanceViewModel extends ChangeNotifier {
  double _outstandingBalance = 1500.00;
  double get outstandingBalance => _outstandingBalance;

  List<Invoice> _invoices = [
    Invoice(
      id: 'INV-2026-08-01',
      title: 'Fall Term Tuition',
      amount: 1500.00,
      dueDate: DateTime.now().add(const Duration(days: 15)),
    ),
    Invoice(
      id: 'INV-2026-07-01',
      title: 'Library Fees',
      amount: 50.00,
      dueDate: DateTime.now().subtract(const Duration(days: 10)),
      isPaid: true,
    ),
  ];
  List<Invoice> get invoices => _invoices;

  List<PaymentHistory> _paymentHistory = [
    PaymentHistory(
      id: 'PAY-89234',
      description: 'Spring Term Tuition',
      amount: 1500.00,
      date: DateTime.now().subtract(const Duration(days: 90)),
    ),
    PaymentHistory(
      id: 'PAY-89235',
      description: 'Library Fees',
      amount: 50.00,
      date: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];
  List<PaymentHistory> get paymentHistory => _paymentHistory;

  void payNow() {
    if (_outstandingBalance > 0) {
      _paymentHistory.insert(
        0,
        PaymentHistory(
          id: 'PAY-${DateTime.now().millisecondsSinceEpoch}',
          description: 'Payment - Online',
          amount: _outstandingBalance,
          date: DateTime.now(),
        ),
      );
      
      _invoices = _invoices.map((inv) => Invoice(
        id: inv.id,
        title: inv.title,
        amount: inv.amount,
        dueDate: inv.dueDate,
        isPaid: true,
      )).toList();

      _outstandingBalance = 0;
      notifyListeners();
    }
  }
}
