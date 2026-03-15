import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class AuthService {
  // ─────────────────────────────────────────────────────────────
  // Validate Token
  // ─────────────────────────────────────────────────────────────
  static Future<bool> validateToken(String token) async {
    try {
      final url = await ApiConfig.getBaseUrl(); // ✅ always fresh
      final response = await http
          .get(
            Uri.parse("$url/history"),
            headers: {"Authorization": "Bearer $token"},
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Register
  // ─────────────────────────────────────────────────────────────
  static Future<void> register(String email, String password) async {
    try {
      final url = await ApiConfig.getBaseUrl(); // ✅ always fresh
      final response = await http
          .post(
            Uri.parse("$url/register"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 422) {
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          final List<dynamic> details = errorData["detail"];
          if (details.isNotEmpty) throw Exception("Invalid email format");
        } catch (_) {
          throw Exception("Validation error");
        }
      } else {
        try {
          final data = jsonDecode(response.body);
          throw Exception(data["detail"] ?? "Registration failed");
        } catch (e) {
          throw Exception(
            "Server Error (${response.statusCode}): Could not connect properly.",
          );
        }
      }
    } on TimeoutException {
      throw Exception("Connection timed out. Check your server is running.");
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Connection refused') ||
          msg.contains('SocketException') ||
          msg.contains('ClientException') ||
          msg.contains('errno = 111') ||
          msg.contains('Failed to fetch')) {
        // ✅ Show the actual URL being used — for debugging
        final currentUrl = await ApiConfig.getBaseUrl();
        throw Exception("Cannot reach: $currentUrl\nError: $msg");
      }
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Login
  // ─────────────────────────────────────────────────────────────
  static Future<String> login(String email, String password) async {
    try {
      final url = await ApiConfig.getBaseUrl(); // ✅ always fresh
      final response = await http
          .post(
            Uri.parse("$url/login"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data["access_token"];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", token);
        return token;
      } else if (response.statusCode == 422) {
        throw Exception("Invalid email format");
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data["detail"] ?? "Invalid credentials");
      }
    } on TimeoutException {
      throw Exception("Connection timed out. Check your server is running.");
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Connection refused') ||
          msg.contains('SocketException') ||
          msg.contains('ClientException') ||
          msg.contains('errno = 111') ||
          msg.contains('Failed to fetch')) {
        throw Exception(
          "Cannot reach server.\nGo to Settings ⚙ and select the correct environment:\n• Emulator → use Emulator preset\n• Real device → enter your PC's IP\n• Web → use Localhost preset",
        );
      }
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Get Stored Token
  // ─────────────────────────────────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token");
  }

  // ─────────────────────────────────────────────────────────────
  // Logout
  // ─────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
  }
}
