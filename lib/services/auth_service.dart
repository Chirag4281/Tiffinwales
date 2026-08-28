// services/auth_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  final String apiUrl = 'https://quantorra.co/tiffinwales/Login.php';

  // Check if user is authenticated
  Future<bool> checkAuthentication() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      final password = prefs.getString('user_password');

      return email != null && password != null;
    } catch (e) {
      return false;
    }
  }

  // Get user data from shared preferences
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return {
        'email': prefs.getString('user_email') ?? '',
        'username': prefs.getString('user_username') ?? 'User',
        'location': prefs.getString('user_location') ?? '',
        'role': prefs.getString('user_role') ?? 'user',
        'user_type': prefs.getString('user_user_type') ?? 'normal',
        'password': prefs.getString('user_password') ?? '',
      };
    } catch (e) {
      return null;
    }
  }

  // Auto login with saved credentials
  Future<Map<String, dynamic>?> autoLogin({
    required String email,
    required String password,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields['action'] = 'login';
      request.fields['email'] = email;
      request.fields['password'] = password;

      var response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (data['status'] == 'success') {
        final userData = data['data'] ?? {};
        await _saveUserSession(
          email: email,
          password: password,
          username: userData['name'] ?? 'User',
          location: userData['location_name'] ?? '',
          role: userData['role'] ?? 'user',
          userType: userData['user_type'] ?? 'normal',
        );
        return userData;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Save user session
  Future<void> _saveUserSession({
    required String email,
    required String password,
    required String username,
    required String location,
    required String role,
    required String userType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
    await prefs.setString('user_password', password);
    await prefs.setString('user_username', username);
    await prefs.setString('user_location', location);
    await prefs.setString('user_role', role);
    await prefs.setString('user_user_type', userType);
    await prefs.setBool('is_logged_in', true);
  }

  // Clear user session
  Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.remove('user_password');
    await prefs.remove('user_username');
    await prefs.remove('user_location');
    await prefs.remove('user_role');
    await prefs.remove('user_user_type');
    await prefs.setBool('is_logged_in', false);
  }

  // Login method for login screen
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields['action'] = 'login';
      request.fields['email'] = email;
      request.fields['password'] = password;

      var response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (data['status'] == 'success') {
        final userData = data['data'] ?? {};
        await _saveUserSession(
          email: email,
          password: password,
          username: userData['name'] ?? 'User',
          location: userData['location_name'] ?? '',
          role: userData['role'] ?? 'user',
          userType: userData['user_type'] ?? 'normal',
        );
        return {'status': 'success', 'data': userData};
      }

      return {'status': 'error', 'message': data['message'] ?? 'Login failed'};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }
}