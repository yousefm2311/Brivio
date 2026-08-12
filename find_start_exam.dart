import 'dart:io';

void main() {
  final dir = Directory('C:/Users/Yousef/.gemini/antigravity/brain/6089111a-28ea-4072-8650-d1e8ef8e97f2/scratch');
  for (var file in dir.listSync()) {
    if (file is File && file.path.endsWith('.sql')) {
      final text = file.readAsStringSync();
      if (text.contains('CREATE OR REPLACE FUNCTION public.start_exam')) {
        print('FOUND IN: ${file.path}');
        
        final lines = text.split('\n');
        int start = lines.indexWhere((l) => l.contains('public.start_exam'));
        for(int i = start; i < start + 30 && i < lines.length; i++) {
          print(lines[i]);
        }
      }
    }
  }
}
