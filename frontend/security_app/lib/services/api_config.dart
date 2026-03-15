import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _customUrlKey = 'custom_backend_url';

  // ── Always reads fresh from SharedPreferences ─────────────────
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_customUrlKey);
    if (saved != null && saved.isNotEmpty) return saved;
    return _defaultUrl;
  }

  // ── Save custom URL ───────────────────────────────────────────
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customUrlKey, url.trim());
  }

  // ── Reset to default ──────────────────────────────────────────
  static Future<void> resetUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customUrlKey);
  }

  // ── init() kept so main.dart doesn't break ────────────────────
  static Future<void> init() async {}

  // ── Sync getter — fallback only, do NOT use for network calls ─
  static String get baseUrl => _defaultUrl;

  // ── Smart default ─────────────────────────────────────────────
  static String get _defaultUrl {
    if (kIsWeb) return "http://localhost:8000";
    if (Platform.isAndroid) return "http://10.0.2.2:8000";
    return "http://localhost:8000";
  }
}
