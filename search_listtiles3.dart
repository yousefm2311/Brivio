
import "dart:io";
void main() {
  var dir = Directory("d:/flutter_application_1/lib");
  var files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith(".dart"));
  var regex = RegExp(r"GlassCard\s*\([^)]*child:\s*(ListTile\s*\()");
  for (var file in files) {
    var content = file.readAsStringSync();
    if (regex.hasMatch(content)) {
      print(file.path);
    }
  }
}

