import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/services/notification_service.dart';

class AuthService {
  static const String baseUrl = AppConfig.baseUrl;
  static UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  @visibleForTesting
  static void setCurrentUserForTesting(UserModel? user) => _currentUser = user;

  final ApiClient _apiClient;

  AuthService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? registrationNumber,
    String? course,
    String? branch,
    String? year,
    String? deviceId,
  }) async {
    try {
      final response = await _apiClient.post(
        '/register',
        body: {
          'email': email,
          'password': password,
          'name': name,
          'role': role,
          'registrationNumber': registrationNumber,
          'course': course,
          'branch': branch,
          'year': year,
          'deviceId': deviceId,
        },
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _currentUser = UserModel.fromMap(data['user']);
        await _saveUserToStorage(data['user'], data['token']);
        ApiClient.instance.cacheToken(data['token']?.toString());
        if (_currentUser?.role == 'student') {
          await NotificationService.subscribeToTopic(
            _currentUser?.course,
            _currentUser?.branch,
            _currentUser?.year,
          );
        }
        if (_currentUser != null) {
          await NotificationService.syncDeviceTokenWithBackend(
            userId: _currentUser!.id,
          );
        }
        return _currentUser;
      } else {
        String errorMsg = 'Registration failed';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            errorMsg = data['message'];
          }
        } catch (_) {
          errorMsg = 'Server error (${response.statusCode})';
        }
        throw errorMsg;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> signIn({
    required String email,
    required String password,
    String? deviceId,
  }) async {
    try {
      debugPrint("🔐 [AUTH] Attempting sign in for: $email");

      final response = await _apiClient.post(
        '/login',
        body: {
          'email': email,
          'password': password,
          'deviceId': deviceId,
        },
      );

      debugPrint("🔐 [AUTH] Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = UserModel.fromMap(data['user']);
        await _saveUserToStorage(data['user'], data['token']);
        ApiClient.instance.cacheToken(data['token']?.toString());
        if (_currentUser?.role == 'student') {
          await NotificationService.subscribeToTopic(
            _currentUser?.course,
            _currentUser?.branch,
            _currentUser?.year,
          );
        }
        if (_currentUser != null) {
          await NotificationService.syncDeviceTokenWithBackend(
            userId: _currentUser!.id,
          );
        }
        return _currentUser;
      } else {
        debugPrint("❌ [AUTH] Sign in failed: ${response.body}");
        String errorMsg = 'Invalid credentials';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            errorMsg = data['message'];
          }
        } catch (_) {
          errorMsg = 'Server error (${response.statusCode})';
        }
        throw errorMsg;
      }
    } catch (e) {
      debugPrint("❌ [AUTH] Sign in error: $e");
      rethrow;
    }
  }

  static Future<void> signOut() async {
    if (_currentUser != null) {
      if (_currentUser?.role == 'student') {
        try {
          await NotificationService.unsubscribeFromTopic(
            _currentUser?.course,
            _currentUser?.branch,
            _currentUser?.year,
          );
        } catch (e) {
          debugPrint('Notice unsub error during sign out: $e');
        }
      }
      try {
        await NotificationService.removeDeviceTokenFromBackend(
          userId: _currentUser!.id,
        );
      } catch (e) {
        debugPrint('Device token remove error during sign out: $e');
      }
    }
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    // Carefully remove only authentication session keys.
    // Non-sensitive preferences, Passport cryptographic keys in secure storage,
    // and offline attendance queues are preserved.
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    await prefs.remove('current_hosting_session_id');
    ApiClient.instance.clearToken();
  }

  Future<void> _saveUserToStorage(
    Map<String, dynamic> userJson,
    String token,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_data', jsonEncode(userJson));
  }

  Future<UserModel?> getUserDataFromStorage() async {
    if (_currentUser != null) return _currentUser;
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user_data');
    if (userStr != null) {
      try {
        final decoded = jsonDecode(userStr);
        if (decoded is Map<String, dynamic> && decoded['id'] != null) {
          _currentUser = UserModel.fromMap(decoded);
          return _currentUser;
        }
      } catch (e) {
        await clearInvalidSession();
        return null;
      }
    }
    return null;
  }

  Future<UserModel?> getUserData(String uid) async {
    return getUserDataFromStorage();
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      await clearInvalidSession();
      return false;
    }
    final user = await getUserDataFromStorage();
    if (user == null) {
      await clearInvalidSession();
      return false;
    }
    // Warm the in-memory token cache so every API call is authenticated
    ApiClient.instance.cacheToken(token);
    return true;
  }

  Future<void> clearInvalidSession() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    await prefs.remove('current_hosting_session_id');
    ApiClient.instance.clearToken();
  }
}
