import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class LocalPaths {
  static Future<String> get recordingsDir async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'recordings');
  }

  static Future<String> get transcriptsDir async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'transcripts');
  }

  static Future<String> get exportsDir async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'exports');
  }
}
