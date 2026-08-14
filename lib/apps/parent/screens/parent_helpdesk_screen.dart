import 'package:flutter/material.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../features/helpdesk/data/models/support_ticket.dart';
import '../../../../features/helpdesk/data/repositories/helpdesk_repository.dart';
import 'package:timeago/timeago.dart' as timeago;

class ParentHelpdeskScreen extends StatefulWidget {
  const ParentHelpdeskScreen({super.key});

  @override
  State<ParentHelpdeskScreen> createState() => _ParentHelpdeskScreenState();
}

class _ParentHelpdeskScreenState extends State<ParentHelpdeskScreen> {
  final HelpdeskRepository _repository = HelpdeskRepository();
  late Future<List<SupportTicket>> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  void _loadTickets() {
    setState(() {
      _ticketsFuture = _repository.getTickets();
    });
  }

  void _showCreateTicketDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String priority = 'normal';
    String? selectedGroupId;
    final groupsFuture = _repository.getAvailableGroups();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.tr('Create Ticket')),
              content: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: context.tr('Subject'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: context.tr('Description'),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<HelpdeskGroupOption>>(
                      future: groupsFuture,
                      builder: (context, snapshot) {
                        final groups = snapshot.data ?? const [];
                        if (selectedGroupId == null && groups.isNotEmpty) {
                          selectedGroupId = groups.first.id;
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: selectedGroupId,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(context.tr('General Support')),
                            ),
                            ...groups.map(
                              (g) => DropdownMenuItem<String>(
                                value: g.id,
                                child: Text(
                                  g.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) =>
                              setDialogState(() => selectedGroupId = val),
                          decoration: InputDecoration(
                            labelText: context.tr('Related Group/Class'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      isExpanded: true,
                      items: ['low', 'normal', 'high', 'urgent']
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(context.tr(p)),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) priority = val;
                      },
                      decoration: InputDecoration(
                        labelText: context.tr('Priority'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('Cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isNotEmpty &&
                        descriptionController.text.isNotEmpty) {
                      Navigator.pop(context);
                      await _repository.createTicket(
                        subject: titleController.text,
                        description: descriptionController.text,
                        priority: priority,
                        groupId: selectedGroupId,
                      );
                      _loadTickets();
                    }
                  },
                  child: Text(context.tr('Submit')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: PortalPageShell(
        title: context.tr('Helpdesk Ticketing'),
        subtitle: context.tr(
          'Manage support requests for you and your children.',
        ),
        icon: Icons.support_agent,
        accentColor: AppColors.primary,
        actions: [
          PortalAction(
            icon: Icons.add,
            label: context.tr('New Ticket'),
            onPressed: _showCreateTicketDialog,
          ),
          PortalAction(
            icon: Icons.refresh,
            label: context.tr('Refresh'),
            onPressed: _loadTickets,
          ),
        ],
        child: FutureBuilder<List<SupportTicket>>(
          future: _ticketsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  context.tr(
                    'Unable to load support tickets. Please try again.',
                  ),
                ),
              );
            }

            final allTickets = snapshot.data ?? [];
            final openTickets = allTickets
                .where((t) => t.status == 'open')
                .toList();
            final inProgressTickets = allTickets
                .where((t) => t.status == 'in_progress')
                .toList();
            final closedTickets = allTickets
                .where((t) => t.status == 'resolved' || t.status == 'closed')
                .toList();

            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color,
                    tabs: [
                      Tab(
                        text: '${context.tr('Open')} (${openTickets.length})',
                      ),
                      Tab(
                        text:
                            '${context.tr('In Progress')} (${inProgressTickets.length})',
                      ),
                      Tab(
                        text:
                            '${context.tr('Closed')} (${closedTickets.length})',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _TicketList(
                        tickets: openTickets,
                        onStatusChange: _loadTickets,
                        accentColor: AppColors.primary,
                      ),
                      _TicketList(
                        tickets: inProgressTickets,
                        onStatusChange: _loadTickets,
                        accentColor: AppColors.primary,
                      ),
                      _TicketList(
                        tickets: closedTickets,
                        onStatusChange: _loadTickets,
                        accentColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  final List<SupportTicket> tickets;
  final VoidCallback onStatusChange;
  final Color accentColor;

  const _TicketList({
    required this.tickets,
    required this.onStatusChange,
    required this.accentColor,
  });

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'normal':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getAvatarColor(String id) {
    final colors = [
      Colors.purple,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
    ];
    return colors[id.hashCode % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return Center(
        child: Text(context.tr('No tickets found in this category.')),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: tickets.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final t = tickets[i];
        final priorityColor = _getPriorityColor(t.priority);
        final avatarColor = _getAvatarColor(t.userId);
        final dateFormatted = timeago.format(t.createdAt);

        return FadeInSlide(
          delay: Duration(milliseconds: 50 * i),
          child: GlassCard(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            child: InkWell(
              onTap: () =>
                  _showTicketDetails(context, t, avatarColor, dateFormatted),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: avatarColor.withValues(alpha: 0.15),
                      child: Icon(Icons.person, color: avatarColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                t.id.substring(0, 8).toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                dateFormatted,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.subject,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${context.tr('User ID')}: ${t.userId.substring(0, 8)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: priorityColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: priorityColor.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  t.priority.toUpperCase(),
                                  style: TextStyle(
                                    color: priorityColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              PortalStatusChip(status: t.status),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTicketDetails(
    BuildContext context,
    SupportTicket ticket,
    Color avatarColor,
    String dateFormatted,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final replyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return GlassCard(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderColor: isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              padding: const EdgeInsets.all(0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ticket.id,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ticket.subject,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: avatarColor.withValues(
                              alpha: 0.15,
                            ),
                            child: Icon(Icons.person, color: avatarColor),
                          ),
                          title: Text(
                            '${context.tr('User ID')}: ${ticket.userId}',
                          ),
                          subtitle: Text(
                            '${context.tr('Submitted')}: $dateFormatted',
                          ),
                          trailing: DropdownButton<String>(
                            value: ticket.status,
                            items: ['open', 'in_progress', 'resolved', 'closed']
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.toUpperCase()),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) async {
                              if (val != null) {
                                final repo = HelpdeskRepository();
                                await repo.updateTicketStatus(ticket.id, val);
                                if (context.mounted) Navigator.pop(context);
                                onStatusChange();
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.tr('Description'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ticket.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          context.tr('Activity'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey,
                              child: const Icon(
                                Icons.support_agent,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('System'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.tr('Ticket logged successfully.'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: replyController,
                              decoration: InputDecoration(
                                hintText: context.tr('Type a reply...'),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FloatingActionButton(
                            onPressed: () {
                              if (replyController.text.isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.tr(
                                        'Reply feature is coming soon!',
                                      ),
                                    ),
                                  ),
                                );
                                replyController.clear();
                              }
                            },
                            mini: true,
                            backgroundColor: accentColor,
                            elevation: 0,
                            child: const Icon(Icons.send, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
