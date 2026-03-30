import 'package:flutter/material.dart';

class AppConfig {
  static const String baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://api.fleet.cloudnext.solutions/api',  // ← change this
  );


  static const Color primaryColor = Color(0xFF00D4E8);
  static const Color bgColor = Color(0xFF050D1A);
  static const Color surfaceColor = Color(0xFF0A1828);
  static const Color textColor = Color(0xFFE8EAF0);
  static const Color mutedColor = Color(0xFF5D7A9A);
  static const Color greenColor = Color(0xFF22C55E);
  static const Color redColor = Color(0xFFEF4444);
  static const Color amberColor = Color(0xFFF59E0B);
}
