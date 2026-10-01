import 'dart:convert';
import 'package:http/http.dart' as http;

class ExecutionResponse {
  final String stdout;
  final String stderr;
  final int exitCode;
  final int durationMs;
  final bool cached;

  ExecutionResponse({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.durationMs,
    required this.cached,
  });

  factory ExecutionResponse.fromJson(Map<String, dynamic> json) {
    return ExecutionResponse(
      stdout: json['stdout'] ?? '',
      stderr: json['stderr'] ?? '',
      exitCode: json['exitCode'] ?? 0,
      durationMs: json['durationMs'] ?? 0,
      cached: json['cached'] ?? false,
    );
  }
}

class ApiService {
  // Linux Desktop / Chrome / USB reverse: 'http://localhost:3000/api'
  // Android Emulator: 'http://10.0.2.2:3000/api'
  static const String baseUrl = 'http://localhost:3000/api';

  static Future<ExecutionResponse> executeCode({
    required String language,
    required String code,
    String stdin = '',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/execute'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'language': language,
          'code': code,
          'stdin': stdin,
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return ExecutionResponse.fromJson(data);
      } else {
        throw Exception(data['error'] ?? 'Execution failed (${res.statusCode})');
      }
    } catch (e) {
      throw Exception('Backend connection error: $e');
    }
  }
}