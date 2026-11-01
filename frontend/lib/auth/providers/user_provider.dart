import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../../core/services/notification_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  String? _currentSessionId; // Global variable for the session
  final AuthService _authService = AuthService();

  UserModel? get user => _user;
  String? get currentSessionId => _currentSessionId;

  // The magic check: Is there a session ID?
  bool get isSessionActive =>
      _currentSessionId != null && _currentSessionId!.isNotEmpty;

  Future<void> loadUser() async {
    _user = await _authService.getUserDataFromStorage();

    // Load session from disk on startup
    final prefs = await SharedPreferences.getInstance();
    _currentSessionId = prefs.getString('current_hosting_session_id');

    // FIX: Ensure we subscribe to notifications on auto-login and sync FCM device token
    if (_user != null) {
      if (_user!.role == 'student') {
        await NotificationService.subscribeToTopic(
            _user!.course, _user!.branch, _user!.year);
      }
      await NotificationService.syncDeviceTokenWithBackend(userId: _user!.id);
      NotificationService.processPendingNotice();
    }

    notifyListeners();
  }

  Future<void> setUser(UserModel user) async {
    _user = user;
    await NotificationService.syncDeviceTokenWithBackend(userId: user.id);
    NotificationService.processPendingNotice();
    notifyListeners();
  }

  // Called when you START a session
  Future<void> setSessionId(String sessionId) async {
    _currentSessionId = sessionId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_hosting_session_id', sessionId);
    notifyListeners(); // Tells Home Screen to update!
  }

  // Called when you STOP a session
  Future<void> clearSessionId() async {
    _currentSessionId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_hosting_session_id');
    notifyListeners(); // Tells Home Screen to update!
  }

  void clearUser() {
    _user = null;
    _currentSessionId = null;
    notifyListeners();
  }
}
