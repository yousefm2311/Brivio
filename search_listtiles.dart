
import "dart:io";
void main() {
  var dir = Directory("d:/flutter_application_1/lib");
  var files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith(".dart"));
  for (var file in files) {
    var content = file.readAsStringSync();
    if (content.contains("GlassCard") && content.contains("ListTile")) {
      print("File: \${file.path}");
    }
  }
}

