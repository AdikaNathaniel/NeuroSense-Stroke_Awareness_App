import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';

class UnauthorizedException implements Exception {
  const UnauthorizedException();
}

class ApiService {
  static const String baseUrl = 'https://neurosense-api.fly.dev/api/v1';
  static const _storage = FlutterSecureStorage();

  // ── Token + user helpers ────────────────────────────────────────────────────
  static Future<String?> getToken() => _storage.read(key: 'token');
  static Future<void> saveToken(String token) => _storage.write(key: 'token', value: token);
  static Future<void> deleteToken() => _storage.delete(key: 'token');

  static Future<String?> getUserEmail() => _storage.read(key: 'user_email');
  static Future<String?> getUserName()  => _storage.read(key: 'user_name');

  static Future<void> logout() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'user_email');
    await _storage.delete(key: 'user_name');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// If [res] is a 401 from a protected endpoint, clear the stored session and
  /// silently route the user back to the login screen, then throw
  /// [UnauthorizedException] so callers stop processing the (errored) body.
  static Future<void> _checkAuth(http.Response res) async {
    if (res.statusCode != 401) return;
    await logout();
    final nav = NeuroSenseApp.navigatorKey.currentState;
    if (nav != null) {
      // Defer one frame so we don't navigate during a build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nav.pushNamedAndRemoveUntil('/login', (_) => false);
      });
    }
    throw const UnauthorizedException();
  }

  // ── Auth ────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'phone': phone, 'password': password}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> verifyEmail(String otp, String email) async {
    final res = await http.get(Uri.parse('$baseUrl/users/verify-email/$otp/$email'));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> resendOtp(String email) async {
    final res = await http.get(Uri.parse('$baseUrl/users/send-otp/$email'));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      await saveToken(data['token']);
      final user = data['user'];
      if (user != null) {
        if (user['email'] != null) await _storage.write(key: 'user_email', value: user['email']);
        if (user['name']  != null) await _storage.write(key: 'user_name',  value: user['name']);
      }
    }
    return data;
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final res = await http.get(Uri.parse('$baseUrl/users/forgot-password/$email'));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updatePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    final headers = await _authHeaders();
    final res = await http.patch(
      Uri.parse('$baseUrl/users/update-password'),
      headers: headers,
      body: jsonEncode({'email': email, 'oldPassword': oldPassword, 'newPassword': newPassword}),
    );
    await _checkAuth(res);
    return jsonDecode(res.body);
  }

  // ── Prediction ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> predict(Map<String, dynamic> features) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/predict'),
      headers: headers,
      body: jsonEncode(features),
    );
    await _checkAuth(res);
    return jsonDecode(res.body);
  }

  // ── History ─────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getHistory() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$baseUrl/history/me'), headers: headers);
    await _checkAuth(res);
    return jsonDecode(res.body);
  }

  // ── Translation (public, no JWT required) ──────────────────────────────────
  static Future<List<String>> translate(List<String> texts, String targetLanguage) async {
    final res = await http.post(
      Uri.parse('$baseUrl/translate'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'texts': texts, 'targetLanguage': targetLanguage}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Translate failed (HTTP ${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body);
    return List<String>.from(data['translations'] ?? const []);
  }

  // ── Chatbot ─────────────────────────────────────────────────────────────────
  static Future<String> chat(List<Map<String, String>> messages) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: headers,
      body: jsonEncode({'messages': messages}),
    );
    await _checkAuth(res);
    final data = jsonDecode(res.body);
    return data['reply'] ?? 'Sorry, I could not get a response.';
  }
}
