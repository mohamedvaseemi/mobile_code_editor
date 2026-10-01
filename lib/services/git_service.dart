import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class GitService {
  Future<void> initOrOpenRepo(String projectName) async {}

  Future<void> saveLocally({
    required String fileName,
    required String content,
  }) async {
    await StorageService.saveFile(fileName, content);
  }

  Future<List<String>> cloneGitHubRepo({
    required String repoOwner,
    required String repoName,
    required String personalAccessToken,
    String branch = 'main',
  }) async {
    final treeUrl = Uri.parse(
      'https://api.github.com/repos/$repoOwner/$repoName/git/trees/$branch?recursive=1',
    );

    final headers = {
      if (personalAccessToken.isNotEmpty)
        'Authorization': 'Bearer $personalAccessToken',
      'Accept': 'application/vnd.github.v3+json',
    };

    final res = await http.get(treeUrl, headers: headers);

    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['message'] ?? 'Failed to fetch repository (HTTP ${res.statusCode})');
    }

    final data = jsonDecode(res.body);
    final List tree = data['tree'] ?? [];
    final List<String> downloadedFiles = [];

    for (final item in tree) {
      if (item['type'] == 'blob' && !item['path'].toString().startsWith('.')) {
        final filePath = item['path'] as String;
        final contentUrl = Uri.parse(
          'https://api.github.com/repos/$repoOwner/$repoName/contents/$filePath?ref=$branch',
        );

        final fileRes = await http.get(
          contentUrl,
          headers: {
            if (personalAccessToken.isNotEmpty)
              'Authorization': 'Bearer $personalAccessToken',
            'Accept': 'application/vnd.github.raw',
          },
        );

        if (fileRes.statusCode == 200) {
          await saveLocally(fileName: filePath, content: fileRes.body);
          downloadedFiles.add(filePath);
        }
      }
    }
    return downloadedFiles;
  }

  Future<void> commitAndPushToGitHub({
    required String repoOwner,
    required String repoName,
    required String filePath,
    required String content,
    required String commitMessage,
    required String personalAccessToken,
    String branch = 'main',
  }) async {
    await saveLocally(fileName: filePath, content: content);

    final url = Uri.parse(
      'https://api.github.com/repos/$repoOwner/$repoName/contents/$filePath',
    );
    final headers = {
      if (personalAccessToken.isNotEmpty)
        'Authorization': 'Bearer $personalAccessToken',
      'Accept': 'application/vnd.github.v3+json',
      'Content-Type': 'application/json',
    };

    String? fileSha;
    final getRes = await http.get(Uri.parse('$url?ref=$branch'), headers: headers);
    if (getRes.statusCode == 200) {
      final fileData = jsonDecode(getRes.body);
      fileSha = fileData['sha'];
    }

    final base64Content = base64Encode(utf8.encode(content));
    final body = {
      'message': commitMessage,
      'content': base64Content,
      'branch': branch,
      'sha': ?fileSha,
    };

    final putRes = await http.put(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    if (putRes.statusCode != 200 && putRes.statusCode != 201) {
      final err = jsonDecode(putRes.body);
      throw Exception(err['message'] ?? 'GitHub push failed (${putRes.statusCode})');
    }
  }
}