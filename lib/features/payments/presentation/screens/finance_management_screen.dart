import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
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

  List<SubscriptionPlan> _plans = [];
  List<Invoice> _invoices = [];
  List<Receipt> _receipts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _planRepo = SupabaseSubscriptionPlanRepository(wrapper);
    _invoiceRepo = SupabaseInvoiceRepository(wrapper);
    _paymentRepo = SupabasePaymentRepository(wrapper);
    _receiptRepo = SupabaseReceiptRepository(wrapper);
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final p = await _planRepo.fetchPlans();
      final inv = await _invoiceRepo.fetchInvoicesForStudent(
        '90000000-0000-0000-0000-000000000001',
      );
      final rec = await _receiptRepo.fetchReceiptsForStudent(
        '90000000-0000-0000-0000-000000000001',
      );

      if (mounted) {
        setState(() {
          _plans = p;
          _invoices = inv;
          _receipts = rec;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showCreatePlanDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '3000');
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
                  final amtEgp = int.tryParse(amountCtrl.text) ?? 3000;
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
                        'p_student_id': '90000000-0000-0000-0000-000000000001',
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
    final notesCtrl = TextEditingController(text: 'Authorized Cash Settlement');

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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Finance & Billing Management'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.card_membership), text: 'Plans'),
              Tab(icon: Icon(Icons.assignment_ind), text: 'Assign'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Invoices'),
              Tab(icon: Icon(Icons.receipt), text: 'Receipts'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadFinanceData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Tab 1: Subscription Plans
                  Scaffold(
                    floatingActionButton: FloatingActionButton.extended(
                      onPressed: _showCreatePlanDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Plan'),
                    ),
                    body: _plans.isEmpty
                        ? const Center(
                            child: Text('No subscription plans found.'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _plans.length,
                            itemBuilder: (ctx, i) {
                              final p = _plans[i];
                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.card_membership),
                                  ),
                                  title: Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${p.description ?? ""}\nBilling: ${p.billingType.toUpperCase()} | Total: ${(p.totalAmountMinor / 100).toStringAsFixed(0)} EGP',
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  // Tab 2: Assign Subscription
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                          onPressed: _showAssignSubscriptionDialog,
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
                ],
              ),
      ),
    );
  }
}
