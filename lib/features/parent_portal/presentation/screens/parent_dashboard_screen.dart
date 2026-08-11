import 'package:flutter/material.dart';
import 'child_details_screen.dart';

class ParentDashboardScreen extends StatelessWidget {
  final String parentId;

  ParentDashboardScreen({Key? key, this.parentId = 'p1'}) : super(key: key);

  final List<Map<String, dynamic>> _allChildren = [
    {'id': '1', 'parentId': 'p1', 'name': 'Alice Smith', 'grade': '10th Grade', 'avatar': 'A'},
    {'id': '2', 'parentId': 'p1', 'name': 'Bob Smith', 'grade': '8th Grade', 'avatar': 'B'},
    {'id': '3', 'parentId': 'p2', 'name': 'Charlie Jones', 'grade': '9th Grade', 'avatar': 'C'},
  ];

  @override
  Widget build(BuildContext context) {
    final children = _allChildren.where((c) => c['parentId'] == parentId).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Parent Dashboard')),
      body: ListView.builder(
        itemCount: children.length,
        itemBuilder: (context, index) {
          final child = children[index];
          return ListTile(
            leading: CircleAvatar(child: Text(child['avatar'])),
            title: Text(child['name']),
            subtitle: Text(child['grade']),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChildDetailsScreen(childData: child),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
