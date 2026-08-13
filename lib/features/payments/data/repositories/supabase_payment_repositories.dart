import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../../core/errors/failures.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/payment_models.dart';
import '../../domain/repositories/payment_repositories.dart';

class SupabaseSubscriptionPlanRepository
    implements ISubscriptionPlanRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseSubscriptionPlanRepository(this._wrapper);

  @override
  Future<List<SubscriptionPlan>> fetchPlans() async {
    try {
      final response = await _wrapper.client
          .from('subscription_plans')
          .select()
          .eq('status', 'active')
          .order('total_amount_minor');
      return (response as List)
          .map((j) => SubscriptionPlan.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch subscription plans: ${e.toString()}',
      );
    }
  }

  @override
  Future<SubscriptionPlan> createPlan(SubscriptionPlan plan) async {
    try {
      final response = await _wrapper.client
          .from('subscription_plans')
          .insert({
            'name': plan.name,
            'description': plan.description,
            'billing_type': plan.billingType,
            'total_amount_minor': plan.totalAmountMinor,
            'currency': plan.currency,
            'installment_count': plan.installmentCount,
            'status': plan.status,
          })
          .select()
          .single();
      return SubscriptionPlan.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to create subscription plan: ${e.toString()}',
      );
    }
  }
}

class SupabaseInvoiceRepository implements IInvoiceRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseInvoiceRepository(this._wrapper);

  @override
  Future<List<Invoice>> fetchInvoicesForStudent(String studentId) async {
    try {
      final response = await _wrapper.withFreshSession(
        (client) => client
            .from('invoices')
            .select()
            .eq('student_id', studentId)
            .order('issued_at', ascending: false),
      );
      return (response as List)
          .map((j) => Invoice.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch invoices: ${e.toString()}',
      );
    }
  }

  @override
  Future<Invoice> fetchInvoiceById(String invoiceId) async {
    try {
      final response = await _wrapper.withFreshSession(
        (client) =>
            client.from('invoices').select().eq('id', invoiceId).single(),
      );
      return Invoice.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch invoice details: ${e.toString()}',
      );
    }
  }
}

class SupabasePaymentRepository implements IPaymentRepository {
  final SupabaseClientWrapper _wrapper;
  SupabasePaymentRepository(this._wrapper);

  @override
  Future<PaymentAttempt> createPaymentIntent({
    required String invoiceId,
    required String provider,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _wrapper.client.rpc(
        'create_payment_intent',
        params: {
          'p_invoice_id': invoiceId,
          'p_provider': provider,
          'p_idempotency_key': idempotencyKey,
        },
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(
          message: 'Create payment intent operation failed',
        );
      }

      final attemptId = jsonMap['attempt_id'] as String;
      final attRes = await _wrapper.client
          .from('payment_attempts')
          .select()
          .eq('id', attemptId)
          .single();

      return PaymentAttempt.fromJson(attRes);
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Create payment intent failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> recordManualPayment({
    required String invoiceId,
    required int amountMinor,
    String paymentMethod = 'cash',
    String? notes,
  }) async {
    try {
      final response = await _wrapper.withFreshSession(
        (client) => client.rpc(
          'record_manual_payment',
          params: {
            'p_invoice_id': invoiceId,
            'p_amount_minor': amountMinor,
            'p_payment_method': paymentMethod,
            'p_notes': notes,
          },
        ),
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(
          message: 'Record manual payment operation failed',
        );
      }
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Record manual payment failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<FinancialSummary> fetchStudentFinancialSummary(
    String studentId,
  ) async {
    try {
      final response = await _wrapper.client.rpc(
        'get_student_financial_summary',
        params: {'p_student_id': studentId},
      );

      return FinancialSummary.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch financial summary: ${e.toString()}',
      );
    }
  }

  @override
  Future<SystemFinancialSummary> fetchSystemFinancialSummary() async {
    try {
      final response = await _wrapper.client.rpc('get_financial_summary');
      final listResponse = response as List;
      if (listResponse.isEmpty) {
        return SystemFinancialSummary(
          totalOutstandingMinor: 0,
          totalCollectedMinor: 0,
          expectedMonthlyRevenueMinor: 0,
          totalAdjustmentsMinor: 0,
        );
      }
      return SystemFinancialSummary.fromJson(
        Map<String, dynamic>.from(listResponse.first as Map),
      );
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch system financial summary: ${e.toString()}',
      );
    }
  }
}

class SupabaseReceiptRepository implements IReceiptRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseReceiptRepository(this._wrapper);

  @override
  Future<List<Receipt>> fetchReceiptsForStudent(String studentId) async {
    try {
      final response = await _wrapper.withFreshSession(
        (client) => client
            .from('receipts')
            .select()
            .eq('student_id', studentId)
            .order('issued_at', ascending: false),
      );
      return (response as List)
          .map((j) => Receipt.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch receipts: ${e.toString()}',
      );
    }
  }
}
