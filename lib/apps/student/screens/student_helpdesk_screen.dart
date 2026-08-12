import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../features/helpdesk/data/repositories/helpdesk_repository.dart';
import '../../../../features/helpdesk/data/models/support_ticket.dart';
import '../../../../features/helpdesk/data/models/ticket_reply.dart';

class StudentHelpdeskScreen extends StatefulWidget {
  const StudentHelpdeskScreen({super.key});

  @override
  State<StudentHelpdeskScreen> createState() => _StudentHelpdeskScreenState();
}

class _StudentHelpdeskScreenState extends State<StudentHelpdeskScreen> {
  final HelpdeskRepository _repo = HelpdeskRepository();
  bool _isLoading = true;
  List<SupportTicket> _tickets = [];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final tickets = await _repo.getTickets();
      setState(() {
        _tickets = tickets;
      });
    } catch (e) {
      debugPrint('Error loading tickets: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateTicketDialog(
        repo: _repo,
        onCreated: () {
          Navigator.pop(context);
          _loadTickets();
        },
      ),
    );
  }

  void _viewTicket(SupportTicket ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TicketDetailsSheet(
        ticket: ticket,
        repo: _repo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'Helpdesk',
      subtitle: 'Manage your support tickets and requests',
      icon: Icons.headset_mic,
      accentColor: AppColors.primary,
      actions: [
        PortalAction(
          icon: Icons.add,
          label: 'Create Ticket',
          onPressed: _showCreateDialog,
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
              ? _buildEmptyState()
              : _buildTicketsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleIcon(
            icon: Icons.local_play,
            color: AppColors.darkTextSecondary,
            size: 64,
            iconSize: 32,
          ),
          const SizedBox(height: 16),
          const Text(
            'No tickets yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a ticket to get help with your courses or account.',
            style: TextStyle(color: AppColors.darkTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsList() {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        return GlassCard(
          onTap: () => _viewTicket(ticket),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleIcon(
                icon: Icons.chat_bubble_outline,
                color: _getStatusColor(ticket.status),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            ticket.subject,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkTextPrimary,
                            ),
                          ),
                        ),
                        StatusChip(
                          label: ticket.status.toUpperCase(),
                          status: _getChipStatus(ticket.status),
                          small: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ticket.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Priority: ${ticket.priority} \u2022 ${_formatDate(ticket.createdAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.darkTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    return switch (status.toLowerCase()) {
      'open' => AppColors.warning,
      'in_progress' => AppColors.primary,
      'closed' => AppColors.success,
      _ => AppColors.darkTextSecondary,
    };
  }

  ChipStatus _getChipStatus(String status) {
    return switch (status.toLowerCase()) {
      'open' => ChipStatus.warning,
      'in_progress' => ChipStatus.info,
      'closed' => ChipStatus.success,
      _ => ChipStatus.neutral,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _CreateTicketDialog extends StatefulWidget {
  final HelpdeskRepository repo;
  final VoidCallback onCreated;

  const _CreateTicketDialog({required this.repo, required this.onCreated});

  @override
  State<_CreateTicketDialog> createState() => _CreateTicketDialogState();
}

class _CreateTicketDialogState extends State<_CreateTicketDialog> {
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedPriority = 'Normal';
  String _selectedGroup = 'group-1';
  bool _isSubmitting = false;

  final _mockGroups = {
    'group-1': 'CS 101 - Intro to Programming',
    'group-2': 'MATH 201 - Linear Algebra',
    'group-3': 'General Support',
  };

  Future<void> _submit() async {
    if (_subjectCtrl.text.isEmpty || _descCtrl.text.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.repo.createTicket(
        subject: _subjectCtrl.text,
        description: _descCtrl.text,
        priority: _selectedPriority,
        groupId: _selectedGroup,
      );
      widget.onCreated();
    } catch (e) {
      debugPrint('Error creating ticket: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Create Support Ticket'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _subjectCtrl,
              label: 'Subject',
              hint: 'Briefly describe the issue',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _descCtrl,
              label: 'Description',
              hint: 'Provide details...',
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedGroup,
              dropdownColor: AppColors.darkSurface,
              decoration: _inputDecoration('Related Group/Class'),
              style: const TextStyle(color: AppColors.darkTextPrimary),
              items: _mockGroups.entries.map((e) {
                return DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedGroup = val);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedPriority,
              dropdownColor: AppColors.darkSurface,
              decoration: _inputDecoration('Priority'),
              style: const TextStyle(color: AppColors.darkTextPrimary),
              items: ['Low', 'Normal', 'High', 'Urgent'].map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text(p),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedPriority = val);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.darkTextPrimary),
      decoration: _inputDecoration(label).copyWith(hintText: hint),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
      hintStyle: const TextStyle(color: AppColors.darkTextTertiary),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}

class _TicketDetailsSheet extends StatefulWidget {
  final SupportTicket ticket;
  final HelpdeskRepository repo;

  const _TicketDetailsSheet({required this.ticket, required this.repo});

  @override
  State<_TicketDetailsSheet> createState() => _TicketDetailsSheetState();
}

class _TicketDetailsSheetState extends State<_TicketDetailsSheet> {
  List<TicketReply> _replies = [];
  bool _isLoading = true;
  final _replyCtrl = TextEditingController();
  bool _isReplying = false;

  @override
  void initState() {
    super.initState();
    _loadReplies();
  }

  Future<void> _loadReplies() async {
    setState(() => _isLoading = true);
    try {
      final replies = await widget.repo.getReplies(widget.ticket.id);
      setState(() => _replies = replies);
    } catch (e) {
      debugPrint('Error loading replies: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReply() async {
    if (_replyCtrl.text.isEmpty) return;
    setState(() => _isReplying = true);
    try {
      final newReply = await widget.repo.addReply(widget.ticket.id, _replyCtrl.text);
      setState(() {
        _replies.add(newReply);
        _replyCtrl.clear();
      });
    } catch (e) {
      debugPrint('Error sending reply: $e');
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppColors.darkBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(t),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildRepliesList(),
          ),
          _buildReplyInput(),
        ],
      ),
    );
  }

  Widget _buildHeader(SupportTicket t) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  t.subject,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
              StatusChip(
                label: t.status.toUpperCase(),
                status: _getChipStatus(t.status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t.description,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.darkTextSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepliesList() {
    if (_replies.isEmpty) {
      return const Center(
        child: Text(
          'No replies yet',
          style: TextStyle(color: AppColors.darkTextSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _replies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final reply = _replies[index];
        final isMine = reply.userId == widget.ticket.userId; // Mock check
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMine ? AppColors.primary : AppColors.darkSurface,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isMine ? Radius.zero : const Radius.circular(16),
                bottomLeft: !isMine ? Radius.zero : const Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reply.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${reply.createdAt.hour}:${reply.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplyInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkBackground,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyCtrl,
              style: const TextStyle(color: AppColors.darkTextPrimary),
              decoration: InputDecoration(
                hintText: 'Type your reply...',
                hintStyle: const TextStyle(color: AppColors.darkTextTertiary),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: _isReplying ? null : _sendReply,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: _isReplying
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  ChipStatus _getChipStatus(String status) {
    return switch (status.toLowerCase()) {
      'open' => ChipStatus.warning,
      'in_progress' => ChipStatus.info,
      'closed' => ChipStatus.success,
      _ => ChipStatus.neutral,
    };
  }
}
