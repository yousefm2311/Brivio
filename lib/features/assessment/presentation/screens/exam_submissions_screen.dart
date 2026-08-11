import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../domain/models/assessment_models.dart';

class ExamSubmissionsScreen extends StatefulWidget {
  final Exam exam;

  const ExamSubmissionsScreen({super.key, required this.exam});

  @override
  State<ExamSubmissionsScreen> createState() => _ExamSubmissionsScreenState();
}

class _ExamSubmissionsScreenState extends State<ExamSubmissionsScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _submissions = [];

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await Supabase.instance.client
          .from('exam_submissions')
          .select('*, users(full_name, email)')
          .eq('exam_id', widget.exam.id)
          .order('submitted_at', ascending: false);

      if (mounted) {
        setState(() {
          _submissions = res as List<dynamic>;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Submissions for ${widget.exam.title}'),
      ),
      body: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: _submissions.isEmpty,
        emptyTitle: 'No submissions yet',
        emptySubtitle: 'Students have not submitted this exam.',
        emptyIcon: Icons.assignment_ind,
        onRetry: _loadSubmissions,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _submissions.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final sub = _submissions[i];
            final user = sub['users'] ?? {};
            final studentName = user['full_name'] ?? 'Unknown Student';
            final score = sub['total_score'] ?? 0;
            return PortalListCard(
              icon: Icons.person,
              accentColor: AppColors.adminRole,
              title: studentName,
              subtitle: 'Score: $score | Submitted: ${sub['submitted_at'] ?? 'N/A'}',
              trailing: [
                Text('Score: $score', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            );
          },
        ),
      ),
    );
  }
}
