import 'package:flutter/material.dart';
import '../../../features/analytics/presentation/screens/teacher_analytics_screen.dart';

class AnalyticsTab extends StatelessWidget {
  final String profileId;

  const AnalyticsTab({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    return TeacherAnalyticsScreen(profileId: profileId);
  }
}
