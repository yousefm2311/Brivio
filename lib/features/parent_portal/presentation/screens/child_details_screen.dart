import 'dart:ui';
import 'package:flutter/material.dart';

class AcademicsViewModel {
  final String childName;
  final List<ExamScore> recentExams;
  final List<ReportCard> reportCards;
  final List<ChartData> performanceHistory;

  AcademicsViewModel({
    required this.childName,
    required this.recentExams,
    required this.reportCards,
    required this.performanceHistory,
  });

  // Factory for mock data
  factory AcademicsViewModel.mock(String name) {
    return AcademicsViewModel(
      childName: name,
      recentExams: [
        ExamScore(
          subject: 'Mathematics',
          score: 92,
          maxScore: 100,
          date: 'Oct 12, 2026',
          grade: 'A',
        ),
        ExamScore(
          subject: 'Physics',
          score: 88,
          maxScore: 100,
          date: 'Oct 10, 2026',
          grade: 'B+',
        ),
        ExamScore(
          subject: 'Literature',
          score: 95,
          maxScore: 100,
          date: 'Oct 08, 2026',
          grade: 'A+',
        ),
      ],
      reportCards: [
        ReportCard(term: 'Fall 2026 Midterm', gpa: 3.8, status: 'Available'),
        ReportCard(term: 'Spring 2026 Final', gpa: 3.9, status: 'Available'),
      ],
      performanceHistory: [
        ChartData(month: 'Sep', value: 85),
        ChartData(month: 'Oct', value: 92),
        ChartData(month: 'Nov', value: 89),
        ChartData(month: 'Dec', value: 95),
      ],
    );
  }
}

class ExamScore {
  final String subject;
  final int score;
  final int maxScore;
  final String date;
  final String grade;
  ExamScore({
    required this.subject,
    required this.score,
    required this.maxScore,
    required this.date,
    required this.grade,
  });
}

class ReportCard {
  final String term;
  final double gpa;
  final String status;
  ReportCard({required this.term, required this.gpa, required this.status});
}

class ChartData {
  final String month;
  final double value;
  ChartData({required this.month, required this.value});
}

class ChildDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> childData;

  const ChildDetailsScreen({super.key, required this.childData});

  @override
  State<ChildDetailsScreen> createState() => _ChildDetailsScreenState();
}

class _ChildDetailsScreenState extends State<ChildDetailsScreen> {
  late AcademicsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AcademicsViewModel.mock(widget.childData['name'] ?? 'Student');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          '${_viewModel.childName} - Academics',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A2980), Color(0xFF26D0CE)], // Premium gradient
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSectionTitle('Performance Overview'),
              const SizedBox(height: 12),
              _buildPerformanceChart(),
              const SizedBox(height: 24),

              _buildSectionTitle('Recent Exam Scores'),
              const SizedBox(height: 12),
              ..._viewModel.recentExams.map((exam) => _buildExamCard(exam)),
              const SizedBox(height: 24),

              _buildSectionTitle('Report Cards'),
              const SizedBox(height: 12),
              ..._viewModel.reportCards.map(
                (report) => _buildReportCard(report),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildGlassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double height = -1,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          height: height > 0 ? height : null,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildPerformanceChart() {
    return _buildGlassContainer(
      height: 220,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Overall Average',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                '91%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _viewModel.performanceHistory.map((data) {
                return _buildChartBar(data);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar(ChartData data) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Tooltip(
          message: 'Score: ${data.value}%',
          child: Container(
            width: 40,
            height: (data.value / 100) * 120, // max height approx 120
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          data.month,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildExamCard(ExamScore exam) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: _buildGlassContainer(
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  exam.grade,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.subject,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exam.date,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${exam.score}/${exam.maxScore}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Score',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(ReportCard report) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: _buildGlassContainer(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.picture_as_pdf,
            color: Colors.white,
            size: 36,
          ),
          title: Text(
            report.term,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            'GPA: ${report.gpa} • ${report.status}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () {
              // Placeholder download logic
            },
          ),
        ),
      ),
    );
  }
}
