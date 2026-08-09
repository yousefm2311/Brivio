import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';

class TeacherFinanceScreen extends StatefulWidget {
  final String teacherId;

  const TeacherFinanceScreen({super.key, required this.teacherId});

  @override
  State<TeacherFinanceScreen> createState() => _TeacherFinanceScreenState();
}

class _TeacherFinanceScreenState extends State<TeacherFinanceScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<_TeacherFinanceGroup> _groups = [];

  int get _totalRequired =>
      _groups.fold(0, (sum, group) => sum + group.totalAmountMinor);
  int get _totalPaid =>
      _groups.fold(0, (sum, group) => sum + group.paidAmountMinor);
  int get _totalRemaining =>
      _groups.fold(0, (sum, group) => sum + group.remainingAmountMinor);
  int get _unpaidStudents =>
      _groups.fold(0, (sum, group) => sum + group.unpaidStudents);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'get_teacher_financial_overview',
        params: {'p_teacher_id': widget.teacherId},
      );
      final rows = response is List ? response : <dynamic>[];
      if (!mounted) return;
      setState(() {
        _groups = rows
            .whereType<Map>()
            .map((row) => _TeacherFinanceGroup.fromJson(row))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openGroupRoster(_TeacherFinanceGroup group) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _TeacherFinanceRosterSheet(group: group, onChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'Teacher Finance',
      subtitle: 'Paid, unpaid, discounts, and exemptions for your groups.',
      icon: Icons.payments,
      accentColor: AppColors.teacherRole,
      actions: [
        PortalAction(label: 'Refresh', icon: Icons.refresh, onPressed: _load),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: _groups.isEmpty,
        emptyTitle: 'No financial data yet',
        emptySubtitle:
            'Financial totals appear after students are enrolled in your groups.',
        emptyIcon: Icons.payments_outlined,
        onRetry: _load,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            children: [
              PortalMetricGrid(
                children: [
                  PortalMetricCard(
                    label: 'Required',
                    value: _money(_totalRequired),
                    icon: Icons.request_quote,
                    accentColor: AppColors.teacherRole,
                  ),
                  PortalMetricCard(
                    label: 'Paid Cash',
                    value: _money(_totalPaid),
                    icon: Icons.price_check,
                    accentColor: Colors.green,
                  ),
                  PortalMetricCard(
                    label: 'Remaining',
                    value: _money(_totalRemaining),
                    icon: Icons.pending_actions,
                    accentColor: Colors.orange,
                  ),
                  PortalMetricCard(
                    label: 'Unpaid Students',
                    value: '$_unpaidStudents',
                    icon: Icons.person_off,
                    accentColor: Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const PortalSectionTitle(
                title: 'Groups',
                subtitle:
                    'Open a group to review students and request discounts.',
              ),
              const SizedBox(height: 10),
              ..._groups.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PortalListCard(
                    icon: Icons.group,
                    accentColor: AppColors.teacherRole,
                    title: group.groupName,
                    subtitle:
                        '${group.subjectName} - ${group.paidStudents}/${group.totalStudents} paid - Remaining ${_money(group.remainingAmountMinor, group.currency)}',
                    trailing: [
                      PortalStatusChip(
                        status: group.unpaidStudents == 0
                            ? 'paid'
                            : '${group.unpaidStudents} unpaid',
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                    onTap: () => _openGroupRoster(group),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherFinanceRosterSheet extends StatefulWidget {
  final _TeacherFinanceGroup group;
  final VoidCallback onChanged;

  const _TeacherFinanceRosterSheet({
    required this.group,
    required this.onChanged,
  });

  @override
  State<_TeacherFinanceRosterSheet> createState() =>
      _TeacherFinanceRosterSheetState();
}

class _TeacherFinanceRosterSheetState
    extends State<_TeacherFinanceRosterSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<_TeacherFinanceStudent> _students = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'get_teacher_group_finance_roster',
        params: {'p_group_id': widget.group.groupId},
      );
      final rows = response is List ? response : <dynamic>[];
      if (!mounted) return;
      setState(() {
        _students = rows
            .whereType<Map>()
            .map((row) => _TeacherFinanceStudent.fromJson(row))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _requestAdjustment(_TeacherFinanceStudent student) async {
    final result = await showDialog<_AdjustmentDraft>(
      context: context,
      builder: (_) => _AdjustmentDialog(student: student),
    );
    if (result == null || !mounted) return;

    try {
      await Supabase.instance.client.rpc(
        'request_teacher_payment_adjustment',
        params: {
          'p_enrollment_id': student.enrollmentId,
          'p_discount_minor': result.discountMinor,
          'p_reason': result.reason,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Adjustment request sent.')));
      await _load();
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .82,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.group.groupName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: PortalStateView(
                  isLoading: _isLoading,
                  errorMessage: _errorMessage,
                  isEmpty: _students.isEmpty,
                  emptyTitle: 'No students enrolled',
                  emptySubtitle:
                      'Students appear here after enrollment in this group.',
                  emptyIcon: Icons.group_off,
                  onRetry: _load,
                  child: ListView.separated(
                    itemCount: _students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final canRequest =
                          student.remainingAmountMinor > 0 &&
                          student.pendingAdjustmentCount == 0;
                      return PortalListCard(
                        icon: student.isPaid
                            ? Icons.verified
                            : Icons.pending_actions,
                        accentColor: student.isPaid
                            ? Colors.green
                            : Colors.orange,
                        title: student.studentName,
                        subtitle:
                            '${student.studentCode} - Final ${_money(student.finalPriceMinor, student.currency)} - Paid ${_money(student.paidAmountMinor, student.currency)} - Remaining ${_money(student.remainingAmountMinor, student.currency)}',
                        trailing: [
                          PortalStatusChip(
                            status: student.paymentExempt
                                ? 'exempt'
                                : student.paymentStatus,
                          ),
                          if (student.pendingAdjustmentCount > 0)
                            const PortalStatusChip(status: 'pending request'),
                          IconButton.filledTonal(
                            tooltip: 'Request discount or exemption',
                            onPressed: canRequest
                                ? () => _requestAdjustment(student)
                                : null,
                            icon: const Icon(Icons.percent),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdjustmentDialog extends StatefulWidget {
  final _TeacherFinanceStudent student;

  const _AdjustmentDialog({required this.student});

  @override
  State<_AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<_AdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _discountController;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _discountController = TextEditingController(
      text: (widget.student.remainingAmountMinor / 100).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _discountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final value = double.tryParse(_discountController.text.trim()) ?? 0;
    Navigator.pop(
      context,
      _AdjustmentDraft(
        discountMinor: (value * 100).round(),
        reason: _reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Request adjustment for ${widget.student.studentName}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Discount amount (${widget.student.currency})',
                prefixIcon: const Icon(Icons.percent),
                helperText:
                    'Use ${_money(widget.student.finalPriceMinor, widget.student.currency)} for full exemption.',
              ),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                if (amount == null || amount < 0) {
                  return 'Enter a valid amount';
                }
                if ((amount * 100).round() > widget.student.finalPriceMinor) {
                  return 'Discount cannot exceed final price';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send),
          label: const Text('Send request'),
        ),
      ],
    );
  }
}

class _AdjustmentDraft {
  final int discountMinor;
  final String reason;

  const _AdjustmentDraft({required this.discountMinor, required this.reason});
}

class _TeacherFinanceGroup {
  final String groupId;
  final String groupName;
  final String groupCode;
  final String subjectName;
  final int totalStudents;
  final int paidStudents;
  final int unpaidStudents;
  final int totalAmountMinor;
  final int paidAmountMinor;
  final int remainingAmountMinor;
  final String currency;

  const _TeacherFinanceGroup({
    required this.groupId,
    required this.groupName,
    required this.groupCode,
    required this.subjectName,
    required this.totalStudents,
    required this.paidStudents,
    required this.unpaidStudents,
    required this.totalAmountMinor,
    required this.paidAmountMinor,
    required this.remainingAmountMinor,
    required this.currency,
  });

  factory _TeacherFinanceGroup.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _TeacherFinanceGroup(
      groupId: json['group_id']?.toString() ?? '',
      groupName: json['group_name']?.toString() ?? 'Group',
      groupCode: json['group_code']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? 'Subject',
      totalStudents: _asInt(json['total_students']),
      paidStudents: _asInt(json['paid_students']),
      unpaidStudents: _asInt(json['unpaid_students']),
      totalAmountMinor: _asInt(json['total_amount_minor']),
      paidAmountMinor: _asInt(json['paid_amount_minor']),
      remainingAmountMinor: _asInt(json['remaining_amount_minor']),
      currency: json['currency']?.toString() ?? 'EGP',
    );
  }
}

class _TeacherFinanceStudent {
  final String enrollmentId;
  final String studentName;
  final String studentCode;
  final int finalPriceMinor;
  final int paidAmountMinor;
  final int remainingAmountMinor;
  final String currency;
  final String paymentStatus;
  final bool paymentExempt;
  final int pendingAdjustmentCount;

  const _TeacherFinanceStudent({
    required this.enrollmentId,
    required this.studentName,
    required this.studentCode,
    required this.finalPriceMinor,
    required this.paidAmountMinor,
    required this.remainingAmountMinor,
    required this.currency,
    required this.paymentStatus,
    required this.paymentExempt,
    required this.pendingAdjustmentCount,
  });

  bool get isPaid =>
      remainingAmountMinor <= 0 ||
      paymentStatus == 'paid' ||
      paymentStatus == 'exempt' ||
      paymentExempt;

  factory _TeacherFinanceStudent.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _TeacherFinanceStudent(
      enrollmentId: json['enrollment_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Student',
      studentCode: json['student_code']?.toString() ?? '',
      finalPriceMinor: _asInt(json['final_price_minor']),
      paidAmountMinor: _asInt(json['paid_amount_minor']),
      remainingAmountMinor: _asInt(json['remaining_amount_minor']),
      currency: json['currency']?.toString() ?? 'EGP',
      paymentStatus: json['payment_status']?.toString() ?? 'paid',
      paymentExempt: json['payment_exempt'] == true,
      pendingAdjustmentCount: _asInt(json['pending_adjustment_count']),
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
