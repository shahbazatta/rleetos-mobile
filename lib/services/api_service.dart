import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ApiService {
  static String? _token;

  static void setToken(String? token) => _token = token;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final resp = await http.post(
      Uri.parse('${AppConfig.baseUrl}$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      throw ApiException(data['error'] ?? 'Request failed (${resp.statusCode})');
    }
    return data;
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final resp = await http.get(
      Uri.parse('${AppConfig.baseUrl}$path'),
      headers: _headers,
    );
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      throw ApiException(data['error'] ?? 'Request failed (${resp.statusCode})');
    }
    return data;
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}
