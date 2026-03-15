import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class ApiService {
  // ─── Login ────────────────────────────────────────────────────
  static Future<String> login(String email, String password) async {
    final url = await ApiConfig.getBaseUrl();
    final response = await http.post(
      Uri.parse("$url/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data["access_token"] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("token", token);
      return token;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data["detail"] ?? "Invalid credentials");
    }
  }

  // ─── Register ─────────────────────────────────────────────────
  static Future<void> register(String email, String password) async {
    final url = await ApiConfig.getBaseUrl();
    final response = await http.post(
      Uri.parse("$url/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data["detail"] ?? "Registration failed");
    }
  }

  // ─── Token helpers ────────────────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token");
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
  }

  // ─── Get History ──────────────────────────────────────────────
  static Future<List<dynamic>> getHistory(String token) async {
    final url = await ApiConfig.getBaseUrl();
    final response = await http.get(
      Uri.parse("$url/history"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        "Failed to load audit log. Status: ${response.statusCode}",
      );
    }
  }

  // ─── Delete History ───────────────────────────────────────────
  static Future<bool> deleteHistoryRecord(String recordId, String token) async {
    final url = await ApiConfig.getBaseUrl();
    final response = await http.delete(
      Uri.parse("$url/history/$recordId"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception("Failed to delete record");
    }
  }

  // ─── Analyze File ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> analyzeFile(
    String? filePath,
    String token, {
    Uint8List? fileBytes,
    String? fileName,
    Duration pollInterval = const Duration(seconds: 2),
    void Function(String)? onProgress,
  }) async {
    final url = await ApiConfig.getBaseUrl();
    final request = http.MultipartRequest('POST', Uri.parse("$url/analyze"));
    request.headers["Authorization"] = "Bearer $token";

    if (fileBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName ?? 'upload.csv',
        ),
      );
    } else if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
    } else {
      throw Exception("No file provided");
    }

    final streamedResponse = await request.send();
    final submitBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      throw Exception("Submit failed: $submitBody");
    }

    final submitData = jsonDecode(submitBody) as Map<String, dynamic>;
    final jobId = submitData["job_id"] as String;

    const messages = [
      "Reading network traffic...",
      "Aligning ML features...",
      "Running Random Forest...",
      "Computing anomaly scores...",
      "Calculating SHAP values...",
      "Building flow profiles...",
      "Finalising intelligence...",
    ];

    int tick = 0;

    while (true) {
      await Future.delayed(pollInterval);
      onProgress?.call(messages[tick % messages.length]);
      tick++;

      final pollUrl = await ApiConfig.getBaseUrl();
      final statusResponse = await http.get(
        Uri.parse("$pollUrl/status/$jobId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (statusResponse.statusCode == 200) {
        final statusData =
            jsonDecode(statusResponse.body) as Map<String, dynamic>;
        final status = statusData["status"] as String;
        if (status == "done")
          return statusData["result"] as Map<String, dynamic>;
        if (status == "error")
          throw Exception(statusData["error"] ?? "Inference failed");
      } else {
        throw Exception("Status check failed: ${statusResponse.statusCode}");
      }
    }
  }

  // ─── Health Check ─────────────────────────────────────────────
  static Future<bool> checkBackend() async {
    try {
      final url = await ApiConfig.getBaseUrl();
      final response = await http
          .get(Uri.parse("$url/health"))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
