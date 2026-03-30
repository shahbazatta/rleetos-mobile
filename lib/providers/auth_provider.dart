import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isLoading => _isLoading;
  bool get isDriver => _user?['role'] == 'driver';
  bool get isSupervisor => _user?['role'] == 'supervisor' || _user?['role'] == 'admin';

  Future<void> loadStoredToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userJson = prefs.getString('auth_user');
      if (token != null && userJson != null) {
        _token = token;
        _user = jsonDecode(userJson) as Map<String, dynamic>;
        ApiService.setToken(token);
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    try {
      final data = await ApiService.post('/auth/login', {
        'email': email,
        'password': password,
      });
      _token = data['token'] as String;
      _user = data['user'] as Map<String, dynamic>;
      ApiService.setToken(_token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      await prefs.setString('auth_user', jsonEncode(_user));
      notifyListeners();
      return null; // success
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    ApiService.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    notifyListeners();
  }
}
