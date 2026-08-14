import 'package:flutter/material.dart';
import 'child_details_screen.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';

class ParentDashboardScreen extends StatefulWidget {
  final String parentId;

  const ParentDashboardScreen({super.key, this.parentId = 'p1'});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  final List<Map<String, dynamic>> _allChildren = [
    {
      'id': '1',
      'parentId': 'p1',
      'name': 'Alice Smith',
      'grade': '10th Grade',
      'avatar': 'A',
      'gpa': '3.8',
      'attendance': '98%',
    },
    {
      'id': '2',
      'parentId': 'p1',
      'name': 'Bob Smith',
      'grade': '8th Grade',
      'avatar': 'B',
      'gpa': '3.5',
      'attendance': '95%',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final children = _allChildren
        .where((c) => c['parentId'] == widget.parentId)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.purple.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.2),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const FadeInSlide(
                        delay: Duration(milliseconds: 100),
                        child: SectionHeader(
                          title: 'Your Children',
                          actionLabel: 'View All',
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...children.asMap().entries.map((entry) {
                        int index = entry.key;
                        var child = entry.value;
                        return FadeInSlide(
                          delay: Duration(milliseconds: 150 + (index * 100)),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: GlassCard(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ChildDetailsScreen(childData: child),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: AppColors.primarySubtle,
                                    child: Text(
                                      child['avatar'],
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          child['name'],
                                          style: const TextStyle(
                                            color: AppColors.darkTextPrimary,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          child['grade'],
                                          style: const TextStyle(
                                            color: AppColors.darkTextSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      StatusChip(
                                        label: 'GPA ${child['gpa']}',
                                        status: ChipStatus.success,
                                        small: true,
                                      ),
                                      const SizedBox(height: 4),
                                      StatusChip(
                                        label: '${child['attendance']}',
                                        status: ChipStatus.info,
                                        small: true,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 24),
                      const FadeInSlide(
                        delay: Duration(milliseconds: 300),
                        child: SectionHeader(title: 'Quick Actions'),
                      ),
                      const SizedBox(height: 12),
                      FadeInSlide(
                        delay: const Duration(milliseconds: 400),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildQuickAction(
                              Icons.grade_outlined,
                              'Grades',
                              AppColors.purple,
                            ),
                            _buildQuickAction(
                              Icons.calendar_month_outlined,
                              'Attendance',
                              AppColors.primary,
                            ),
                            _buildQuickAction(
                              Icons.account_balance_wallet_outlined,
                              'Finances',
                              AppColors.success,
                            ),
                            _buildQuickAction(
                              Icons.event_outlined,
                              'Events',
                              AppColors.warning,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      const FadeInSlide(
                        delay: Duration(milliseconds: 500),
                        child: SectionHeader(title: 'Upcoming Events'),
                      ),
                      const SizedBox(height: 12),
                      FadeInSlide(
                        delay: const Duration(milliseconds: 600),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildEventItem(
                                'Parent-Teacher Meeting',
                                'Tomorrow, 4:00 PM',
                                AppColors.primary,
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(
                                  color: AppColors.glassBorder,
                                  height: 1,
                                ),
                              ),
                              _buildEventItem(
                                'Science Fair',
                                'Friday, 9:00 AM',
                                AppColors.purple,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      expandedHeight: 80,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: const FadeInSlide(
          delay: Duration(milliseconds: 0),
          child: Text(
            'Parent Portal',
            style: TextStyle(
              color: AppColors.darkTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      actions: [
        FadeInSlide(
          delay: const Duration(milliseconds: 50),
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: AppColors.glassMedium,
              child: const Icon(
                Icons.notifications_outlined,
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color) {
    return Column(
      children: [
        GlowContainer(
          glowColor: color,
          glowOpacity: 0.2,
          padding: const EdgeInsets.all(16),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.darkTextSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEventItem(String title, String time, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.darkTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: const TextStyle(
                  color: AppColors.darkTextSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
