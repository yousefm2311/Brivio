import 'package:flutter/foundation.dart';

enum StudyMaterialType { pdf, video, summary }

class StudyMaterial {
  final String id;
  final String title;
  final StudyMaterialType type;
  final String size;
  final DateTime uploadedAt;

  StudyMaterial({
    required this.id,
    required this.title,
    required this.type,
    required this.size,
    required this.uploadedAt,
  });
}

class WorkspaceViewModel extends ChangeNotifier {
  final List<StudyMaterial> _materials = [
    StudyMaterial(
      id: '1',
      title: 'Chapter 1: Intro to Physics',
      type: StudyMaterialType.pdf,
      size: '2.4 MB',
      uploadedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    StudyMaterial(
      id: '2',
      title: 'Lecture 1 Recording',
      type: StudyMaterialType.video,
      size: '245 MB',
      uploadedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    StudyMaterial(
      id: '3',
      title: 'Midterm Summary',
      type: StudyMaterialType.summary,
      size: '1.1 MB',
      uploadedAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    StudyMaterial(
      id: '4',
      title: 'Advanced Mechanics',
      type: StudyMaterialType.pdf,
      size: '4.8 MB',
      uploadedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  List<StudyMaterial> get materials => _materials;

  void uploadMaterial(String title, StudyMaterialType type, String size) {
    _materials.insert(
      0,
      StudyMaterial(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        type: type,
        size: size,
        uploadedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void deleteMaterial(String id) {
    _materials.removeWhere((m) => m.id == id);
    notifyListeners();
  }
}
