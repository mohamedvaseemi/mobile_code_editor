import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static String? _workspacePath;

  // Workspace folder initialize செய்தல்
  static Future<String> getWorkspaceDir() async {
    if (_workspacePath != null) return _workspacePath!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/workspace');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      // Default files உருவாக்கல்
      File('${dir.path}/main.py').writeAsStringSync(
        '# Python 3 Environment\n\ndef run():\n    print("Hello from Mobile IDE!")\n\nrun()\n',
      );
      File('${dir.path}/app.js').writeAsStringSync(
        '// JavaScript Environment\nconsole.log("Mobile JS execution ready");\n',
      );
    }
    _workspacePath = dir.path;
    return _workspacePath!;
  }

  // Disk-ல் உள்ள files-ஐ வாசித்தல்
  static Future<List<File>> listFiles() async {
    final path = await getWorkspaceDir();
    final dir = Directory(path);
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => !f.path.split('/').last.startsWith('.'))
        .toList();
  }

  // புதிய கோப்பை உருவாக்குதல்
  static Future<File> createFile(String fileName) async {
    final path = await getWorkspaceDir();
    final file = File('$path/$fileName');
    if (!file.existsSync()) {
      file.writeAsStringSync('');
    }
    return file;
  }

  // File-ஐ நீக்குதல்
  static Future<void> deleteFile(String fileName) async {
    final path = await getWorkspaceDir();
    final file = File('$path/$fileName');
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  // File content-ஐ வாசித்தல்
  static Future<String> readFile(String fileName) async {
    final path = await getWorkspaceDir();
    final file = File('$path/$fileName');
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  // File-ஐ Disk-ல் சேமித்தல்
  static Future<void> saveFile(String fileName, String content) async {
    final path = await getWorkspaceDir();
    final file = File('$path/$fileName');
    file.writeAsStringSync(content);
  }

  // GitHub Credentials Secure Storage
  static Future<void> saveGitHubCredentials({
    required String owner,
    required String repo,
    required String token,
  }) async {
    await _storage.write(key: 'gh_owner', value: owner);
    await _storage.write(key: 'gh_repo', value: repo);
    await _storage.write(key: 'gh_token', value: token);
  }

  static Future<Map<String, String>> getGitHubCredentials() async {
    return {
      'owner': await _storage.read(key: 'gh_owner') ?? '',
      'repo': await _storage.read(key: 'gh_repo') ?? '',
      'token': await _storage.read(key: 'gh_token') ?? '',
    };
  }
}