import 'package:flutter/material.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../../design_system/components/glass_card.dart';

class HelpdeskManagementScreen extends StatefulWidget {
  const HelpdeskManagementScreen({super.key});

  @override
  State<HelpdeskManagementScreen> createState() => _HelpdeskManagementScreenState();
}

class _HelpdeskManagementScreenState extends State<HelpdeskManagementScreen> {
  // Dummy data for UI
  final List<Map<String, dynamic>> _tickets = [
    {
      'id': 'TKT-1001',
      'title': 'Cannot access Gradebook',
      'submitter': 'Sarah Connor (Teacher)',
      'status': 'Open',
      'priority': 'High',
      'date': '10 mins ago',
      'avatarColor': Colors.purple,
    },
    {
      'id': 'TKT-1002',
      'title': 'Payment gateway error',
      'submitter': 'John Doe (Parent)',
      'status': 'Open',
      'priority': 'Critical',
      'date': '1 hour ago',
      'avatarColor': Colors.red,
    },
    {
      'id': 'TKT-1003',
      'title': 'Request new curriculum materials',
      'submitter': 'Alan Smith (Teacher)',
      'status': 'In Progress',
      'priority': 'Low',
      'date': '1 day ago',
      'avatarColor': Colors.blue,
    },
    {
      'id': 'TKT-1004',
      'title': 'Reset password for student',
      'submitter': 'Emma Watson (Student)',
      'status': 'Closed',
      'priority': 'Medium',
      'date': '3 days ago',
      'avatarColor': Colors.green,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: PortalPageShell(
        title: 'Helpdesk Ticketing',
        subtitle: 'Manage user support requests and technical issues.',
        icon: Icons.support_agent,
        accentColor: AppColors.info,
        actions: [
          PortalAction(
            icon: Icons.search,
            label: 'Search',
            onPressed: () {},
          ),
          PortalAction(
            icon: Icons.filter_list,
            label: 'Filter',
            onPressed: () {},
          ),
        ],
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.info.withOpacity(0.15),
                ),
                labelColor: AppColors.info,
                unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
                tabs: const [
                  Tab(text: 'Open Tickets (2)'),
                  Tab(text: 'In Progress (1)'),
                  Tab(text: 'Closed (1)'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _TicketList(tickets: _tickets.where((t) => t['status'] == 'Open').toList()),
                  _TicketList(tickets: _tickets.where((t) => t['status'] == 'In Progress').toList()),
                  _TicketList(tickets: _tickets.where((t) => t['status'] == 'Closed').toList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  final List<Map<String, dynamic>> tickets;

  const _TicketList({required this.tickets});

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return const Center(child: Text('No tickets found in this category.'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: tickets.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final t = tickets[i];
        
        Color priorityColor = Colors.grey;
        if (t['priority'] == 'Critical') priorityColor = Colors.red;
        if (t['priority'] == 'High') priorityColor = Colors.orange;
        if (t['priority'] == 'Medium') priorityColor = Colors.blue;
        if (t['priority'] == 'Low') priorityColor = Colors.green;

        return FadeInSlide(
          delay: Duration(milliseconds: 50 * i),
          child: GlassCard(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            child: InkWell(
              onTap: () => _showTicketDetails(context, t),
              borderRadius: BorderRadius.circular(24), // matching glass card default
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: (t['avatarColor'] as Color).withOpacity(0.15),
                      child: Icon(Icons.person, color: t['avatarColor']),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                t['id'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                t['date'],
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t['title'],
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t['submitter'],
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: priorityColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: priorityColor.withOpacity(0.5)),
                                ),
                                child: Text(
                                  t['priority'],
                                  style: TextStyle(
                                    color: priorityColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              PortalStatusChip(status: t['status']),
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

  void _showTicketDetails(BuildContext context, Map<String, dynamic> ticket) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
              borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                                ticket['id'],
                                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                ticket['title'],
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                            backgroundColor: (ticket['avatarColor'] as Color).withOpacity(0.15),
                            child: Icon(Icons.person, color: ticket['avatarColor']),
                          ),
                          title: Text(ticket['submitter']),
                          subtitle: Text('Submitted: ${ticket['date']}'),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Description',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'I am experiencing an issue where I cannot access my gradebook. It gives me a 403 Forbidden error every time I try to open the class for Section B. Please advise.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Activity',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        // Fake activity log
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey,
                              child: Icon(Icons.support_agent, size: 16, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.info.withOpacity(0.2)),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('System Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    SizedBox(height: 4),
                                    Text('We are looking into this. It appears to be an issue with role permissions caching.'),
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
                              decoration: InputDecoration(
                                hintText: 'Type a reply...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FloatingActionButton(
                            onPressed: () {},
                            mini: true,
                            backgroundColor: AppColors.info,
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
