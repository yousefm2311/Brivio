import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_payment_repositories.dart';
import '../../domain/models/payment_models.dart';

class FinanceManagementScreen extends StatefulWidget {
  const FinanceManagementScreen({super.key});

  @override
  State<FinanceManagementScreen> createState() =>
      _FinanceManagementScreenState();
}

class _FinanceManagementScreenState extends State<FinanceManagementScreen> {
  late final SupabaseSubscriptionPlanRepository _planRepo;
  late final SupabaseInvoiceRepository _invoiceRepo;
  late final SupabasePaymentRepository _paymentRepo;
  late final SupabaseReceiptRepository _receiptRepo;
  late final SupabaseStudentRepository _studentRepo;

  List<Student> _students = [];
  Student? _selectedStudent;
  List<SubscriptionPlan> _plans = [];
  List<Invoice> _invoices = [];
  List<Receipt> _receipts = [];
  List<_PaymentAdjustmentRequest> _adjustmentRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _planRepo = SupabaseSubscriptionPlanRepository(wrapper);
    _invoiceRepo = SupabaseInvoiceRepository(wrapper);
    _paymentRepo = SupabasePaymentRepository(wrapper);
    _receiptRepo = SupabaseReceiptRepository(wrapper);
    _studentRepo = SupabaseStudentRepository(wrapper);
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final p = await _planRepo.fetchPlans();
      final studentsPage = await _studentRepo.fetchStudents(pageSize: 100);
      final selected =
          _selectedStudent ??
          (studentsPage.data.isEmpty ? null : studentsPage.data.first);
      final inv = selected == null
          ? <Invoice>[]
          : await _invoiceRepo.fetchInvoicesForStudent(selected.id);
      final rec = selected == null
          ? <Receipt>[]
          : await _receiptRepo.fetchReceiptsForStudent(selected.id);
      final adjustmentsResponse = await Supabase.instance.client.rpc(
        'get_payment_adjustment_requests',
        params: {'p_status': null},
      );
      final adjustments = adjustmentsResponse is List
          ? adjustmentsResponse
                .whereType<Map>()
                .map((row) => _PaymentAdjustmentRequest.fromJson(row))
                .toList()
          : <_PaymentAdjustmentRequest>[];

      if (mounted) {
        setState(() {
          _students = studentsPage.data;
          _selectedStudent = selected;
          _plans = p;
          _invoices = inv;
          _receipts = rec;
          _adjustmentRequests = adjustments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showCreatePlanDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String billingType = 'installment';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Create Subscription Plan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Plan Name (e.g. Full Semester CS 101)',
                    ),
                  ),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: billingType,
                    decoration: const InputDecoration(
                      labelText: 'Billing Type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'installment',
                        child: Text('Installments'),
                      ),
                      DropdownMenuItem(
                        value: 'one_time',
                        child: Text('One-Time Payment'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => billingType = v);
                    },
                  ),
                  TextField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Total Amount (EGP)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;

                  final nav = Navigator.of(ctx);
                  final amtEgp = int.tryParse(amountCtrl.text);
                  if (amtEgp == null || amtEgp <= 0) return;
                  try {
                    await Supabase.instance.client
                        .from('subscription_plans')
                        .insert({
                          'name': nameCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                          'billing_type': billingType,
                          'total_amount_minor': amtEgp * 100,
                          'currency': 'EGP',
                          'installment_count': billingType == 'installment'
                              ? 3
                              : 1,
                          'status': 'active',
                        });
                    nav.pop();
                    _loadFinanceData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Subscription plan created!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Creation failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Create Plan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAssignSubscriptionDialog() {
    final selectedStudent = _selectedStudent;
    if (selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create an active student first.')),
      );
      return;
    }
    String? selectedPlanId = _plans.isNotEmpty ? _plans.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Assign Subscription to Student'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_plans.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedPlanId,
                    decoration: const InputDecoration(labelText: 'Select Plan'),
                    items: _plans
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setStateDialog(() => selectedPlanId = v),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedPlanId == null) return;
                  final nav = Navigator.of(ctx);
                  try {
                    await Supabase.instance.client.rpc(
                      'assign_student_subscription',
                      params: {
                        'p_student_id': selectedStudent.id,
                        'p_plan_id': selectedPlanId,
                      },
                    );
                    nav.pop();
                    _loadFinanceData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Subscription assigned and invoice generated!',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Assignment failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Assign Subscription'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRecordPaymentDialog(Invoice inv) {
    final amountCtrl = TextEditingController(
      text: (inv.totalMinor / 100).toStringAsFixed(0),
    );
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record Manual Cash Payment (${inv.invoiceNumber})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Payment Amount (EGP)',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes / Reference'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final amtEgp =
                  double.tryParse(amountCtrl.text) ?? (inv.totalMinor / 100);
              try {
                await _paymentRepo.recordManualPayment(
                  invoiceId: inv.id,
                  amountMinor: (amtEgp * 100).round(),
                  paymentMethod: 'cash',
                  notes: notesCtrl.text.trim(),
                );
                nav.pop();
                _loadFinanceData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Manual cash payment recorded & settled!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Payment failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Record Cash Payment'),
          ),
        ],
      ),
    );
  }

  Future<void> _decideAdjustment(
    _PaymentAdjustmentRequest request,
    bool approve,
  ) async {
    try {
      await Supabase.instance.client.rpc(
        'apply_payment_adjustment_request',
        params: {
          'p_request_id': request.id,
          'p_approve': approve,
          'p_decision_note': approve
              ? 'Approved from finance management.'
              : 'Rejected from finance management.',
        },
      );
      await _loadFinanceData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'Adjustment applied.' : 'Request rejected.',
            ),
            backgroundColor: approve ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Adjustment decision failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: PortalPageShell(
        title: 'Finance & Billing',
        subtitle: 'Plans, subscriptions, invoices, payments, and receipts.',
        icon: Icons.monetization_on,
        accentColor: AppColors.adminRole,
        actions: [
          PortalAction(
            icon: Icons.refresh,
            label: 'Refresh',
            onPressed: _loadFinanceData,
          ),
          PortalAction(
            icon: Icons.add,
            label: 'Add Plan',
            onPressed: _showCreatePlanDialog,
            primary: true,
          ),
        ],
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(icon: Icon(Icons.card_membership), text: 'Plans'),
                Tab(icon: Icon(Icons.assignment_ind), text: 'Assign'),
                Tab(icon: Icon(Icons.receipt_long), text: 'Invoices'),
                Tab(icon: Icon(Icons.receipt), text: 'Receipts'),
                Tab(icon: Icon(Icons.percent), text: 'Adjustments'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PortalStateView(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: false,
                emptyTitle: 'No finance data',
                emptySubtitle: 'Create plans and students before billing.',
                emptyIcon: Icons.monetization_on,
                onRetry: _loadFinanceData,
                child: TabBarView(
                  children: [
                    _plans.isEmpty
                        ? const Center(
                            child: Text('No subscription plans found.'),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _plans.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final p = _plans[i];
                              return PortalListCard(
                                icon: Icons.card_membership,
                                accentColor: AppColors.adminRole,
                                title: p.name,
                                subtitle:
                                    '${p.description ?? ""}\nBilling: ${p.billingType.toUpperCase()} | Total: ${(p.totalAmountMinor / 100).toStringAsFixed(0)} EGP',
                                trailing: [PortalStatusChip(status: p.status)],
                              );
                            },
                          ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_students.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              child: DropdownButtonFormField<Student>(
                                initialValue: _selectedStudent,
                                decoration: const InputDecoration(
                                  labelText: 'Student',
                                  border: OutlineInputBorder(),
                                ),
                                items: _students
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(
                                          '${s.fullName} (${s.studentCode})',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (student) {
                                  if (student == null) return;
                                  setState(() => _selectedStudent = student);
                                  _loadFinanceData();
                                },
                              ),
                            ),
                          const Icon(
                            Icons.assignment_ind,
                            size: 64,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Assign Tuition & Subscription Plans to Students',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed:
                                _selectedStudent == null || _plans.isEmpty
                                ? null
                                : _showAssignSubscriptionDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Assign Subscription to Student'),
                          ),
                        ],
                      ),
                    ),
                    // Tab 3: Invoices
                    _invoices.isEmpty
                        ? const Center(child: Text('No invoices found.'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _invoices.length,
                            separatorBuilder: (ctx, i) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final inv = _invoices[i];
                              final isUnpaid = inv.status != 'paid';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isUnpaid
                                      ? Colors.orange.shade100
                                      : Colors.green.shade100,
                                  child: Icon(
                                    Icons.receipt_long,
                                    color: isUnpaid
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                                ),
                                title: Text(
                                  inv.invoiceNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Total: ${(inv.totalMinor / 100).toStringAsFixed(0)} EGP | Paid: ${(inv.amountPaidMinor / 100).toStringAsFixed(0)} EGP\nStatus: ${inv.status.toUpperCase()}',
                                ),
                                trailing: isUnpaid
                                    ? ElevatedButton(
                                        onPressed: () =>
                                            _showRecordPaymentDialog(inv),
                                        child: const Text('Record Payment'),
                                      )
                                    : const Chip(
                                        label: Text(
                                          'SETTLED',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                              );
                            },
                          ),
                    // Tab 4: Receipts
                    _receipts.isEmpty
                        ? const Center(
                            child: Text('No payment receipts generated yet.'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _receipts.length,
                            separatorBuilder: (ctx, i) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final rec = _receipts[i];
                              return ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.receipt),
                                ),
                                title: Text(
                                  'Receipt #${rec.id.substring(0, 8)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Amount Paid: ${(rec.amountMinor / 100).toStringAsFixed(0)} ${rec.currency}\nIssued: ${rec.issuedAt.year}-${rec.issuedAt.month}-${rec.issuedAt.day}',
                                ),
                              );
                            },
                          ),
                    _adjustmentRequests.isEmpty
                        ? const Center(
                            child: Text('No discount or exemption requests.'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _adjustmentRequests.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final req = _adjustmentRequests[i];
                              final isPending = req.status == 'pending';
                              return PortalListCard(
                                icon: req.adjustmentType == 'exemption'
                                    ? Icons.volunteer_activism
                                    : Icons.percent,
                                accentColor: isPending
                                    ? Colors.orange
                                    : AppColors.adminRole,
                                title: '${req.studentName} - ${req.groupName}',
                                subtitle:
                                    'Teacher: ${req.teacherName}\nOriginal ${_money(req.originalPriceMinor, req.currency)} | Discount ${_money(req.requestedDiscountMinor, req.currency)} | Final ${_money(req.requestedFinalPriceMinor, req.currency)}${req.reason.isEmpty ? '' : '\nReason: ${req.reason}'}',
                                trailing: [
                                  PortalStatusChip(status: req.status),
                                  if (isPending)
                                    IconButton.filledTonal(
                                      tooltip: 'Reject',
                                      onPressed: () =>
                                          _decideAdjustment(req, false),
                                      icon: const Icon(Icons.close),
                                    ),
                                  if (isPending)
                                    FilledButton.icon(
                                      onPressed: () =>
                                          _decideAdjustment(req, true),
                                      icon: const Icon(Icons.check),
                                      label: const Text('Approve'),
                                    ),
                                ],
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentAdjustmentRequest {
  final String id;
  final String studentName;
  final String groupName;
  final String teacherName;
  final String adjustmentType;
  final int originalPriceMinor;
  final int requestedDiscountMinor;
  final int requestedFinalPriceMinor;
  final String currency;
  final String reason;
  final String status;

  const _PaymentAdjustmentRequest({
    required this.id,
    required this.studentName,
    required this.groupName,
    required this.teacherName,
    required this.adjustmentType,
    required this.originalPriceMinor,
    required this.requestedDiscountMinor,
    required this.requestedFinalPriceMinor,
    required this.currency,
    required this.reason,
    required this.status,
  });

  factory _PaymentAdjustmentRequest.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _PaymentAdjustmentRequest(
      id: json['request_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Student',
      groupName: json['group_name']?.toString() ?? 'Group',
      teacherName: json['teacher_name']?.toString() ?? 'Teacher',
      adjustmentType: json['adjustment_type']?.toString() ?? 'discount',
      originalPriceMinor: _asInt(json['original_price_minor']),
      requestedDiscountMinor: _asInt(json['requested_discount_minor']),
      requestedFinalPriceMinor: _asInt(json['requested_final_price_minor']),
      currency: json['currency']?.toString() ?? 'EGP',
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _money(int minor, [String currency = 'EGP']) {
  final amount = minor / 100;
  final formatted = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return '$formatted $currency';
}
