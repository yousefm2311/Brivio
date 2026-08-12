import 'dart:io';

void main() async {
  final dir = Directory('C:/Users/Yousef/.gemini/antigravity/brain/6089111a-28ea-4072-8650-d1e8ef8e97f2/scratch');
  for (var file in dir.listSync()) {
    if (file is File && file.path.endsWith('.sql')) {
      final text = file.readAsStringSync();
      if (text.contains('submit_exam_attempt')) {
        print('FOUND submit_exam_attempt IN: ${file.path}');
      }
    }
  }
}
