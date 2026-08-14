import 'package:flutter/foundation.dart';

class GroupsSchedulesViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _groupsData = [];
  List<Map<String, dynamic>> get groupsData => _groupsData;

  void fetchGroupsData() {
    _isLoading = true;
    notifyListeners();

    // Mock data for Groups & Schedules
    Future.delayed(const Duration(milliseconds: 500), () {
      _groupsData = [
        {
          'group_name': 'Math 101',
          'timing': 'Mon/Wed 10:00 AM',
          'teacher': 'Mr. Smith',
          'is_active': true,
        },
        {
          'group_name': 'Physics Advanced',
          'timing': 'Tue/Thu 2:00 PM',
          'teacher': 'Mrs. Doe',
          'is_active': true,
        },
        {
          'group_name': 'Chemistry Basics',
          'timing': 'Fri 9:00 AM',
          'teacher': 'Dr. White',
          'is_active': false,
        },
        {
          'group_name': 'History 201',
          'timing': 'Mon/Wed 1:00 PM',
          'teacher': 'Mr. Brown',
          'is_active': true,
        },
      ];
      _isLoading = false;
      notifyListeners();
    });
  }
}
