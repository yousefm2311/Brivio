import 'package:flutter/material.dart';

class ChildDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> childData;

  const ChildDetailsScreen({Key? key, required this.childData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${childData['name']} - Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildStatCard('Attendance', '95%', Colors.green),
          _buildStatCard('Recent Exam Grade', 'B+', Colors.blue),
          _buildStatCard('Homework Completion', '88%', Colors.orange),
          _buildStatCard('Study Habits', 'Good focus, needs work on Math', Colors.purple),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color, radius: 10),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
