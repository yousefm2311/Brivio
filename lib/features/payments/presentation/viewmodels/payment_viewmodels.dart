import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/models/payment_models.dart';
import '../../domain/repositories/payment_repositories.dart';

enum PaymentViewState { initial, loading, loaded, submitting, failure }

class PlanManagementViewModel extends ChangeNotifier {
  final ISubscriptionPlanRepository _repository;
  PaymentViewState _status = PaymentViewState.initial;
  List<SubscriptionPlan> _plans = [];
  Failure? _failure;

  PlanManagementViewModel(this._repository);

  PaymentViewState get status => _status;
  List<SubscriptionPlan> get plans => _plans;
  Failure? get failure => _failure;

  Future<void> fetchPlans() async {
    _status = PaymentViewState.loading;
    notifyListeners();

    try {
      _plans = await _repository.fetchPlans();
      _status = PaymentViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = PaymentViewState.failure;
    }
    notifyListeners();
  }

  Future<void> createPlan(SubscriptionPlan plan) async {
    _status = PaymentViewState.submitting;
    notifyListeners();

    try {
      await _repository.createPlan(plan);
      await fetchPlans();
    } on Failure catch (f) {
      _failure = f;
      _status = PaymentViewState.failure;
      notifyListeners();
    }
  }
}

class InvoiceViewModel extends ChangeNotifier {
  final IInvoiceRepository _repository;
  final IPaymentRepository _paymentRepo;
  PaymentViewState _status = PaymentViewState.initial;
  List<Invoice> _invoices = [];
  FinancialSummary? _summary;
  Failure? _failure;

  InvoiceViewModel(this._repository, this._paymentRepo);

  PaymentViewState get status => _status;
  List<Invoice> get invoices => _invoices;
  FinancialSummary? get summary => _summary;
  Failure? get failure => _failure;

  Future<void> fetchInvoices(String studentId) async {
    _status = PaymentViewState.loading;
    notifyListeners();

    try {
      _invoices = await _repository.fetchInvoicesForStudent(studentId);
      _summary = await _paymentRepo.fetchStudentFinancialSummary(studentId);
      _status = PaymentViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = PaymentViewState.failure;
    }
    notifyListeners();
  }
}

class PaymentCheckoutViewModel extends ChangeNotifier {
  final IPaymentRepository _repository;
  PaymentViewState _status = PaymentViewState.initial;
  PaymentAttempt? _attempt;
  Failure? _failure;

  PaymentCheckoutViewModel(this._repository);

  PaymentViewState get status => _status;
  PaymentAttempt? get attempt => _attempt;
  Failure? get failure => _failure;

  Future<void> createPaymentIntent({
    required String invoiceId,
    required String provider,
    required String idempotencyKey,
  }) async {
    _status = PaymentViewState.submitting;
    notifyListeners();

    try {
      _attempt = await _repository.createPaymentIntent(
        invoiceId: invoiceId,
        provider: provider,
        idempotencyKey: idempotencyKey,
      );
      _status = PaymentViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = PaymentViewState.failure;
    }
    notifyListeners();
  }
}

class CashPaymentViewModel extends ChangeNotifier {
  final IPaymentRepository _repository;
  PaymentViewState _status = PaymentViewState.initial;
  Failure? _failure;

  CashPaymentViewModel(this._repository);

  PaymentViewState get status => _status;
  Failure? get failure => _failure;

  Future<void> recordManualPayment({
    required String invoiceId,
    required int amountMinor,
    String? notes,
  }) async {
    _status = PaymentViewState.submitting;
    notifyListeners();

    try {
      await _repository.recordManualPayment(
        invoiceId: invoiceId,
        amountMinor: amountMinor,
        notes: notes,
      );
      _status = PaymentViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = PaymentViewState.failure;
    }
    notifyListeners();
  }
}
