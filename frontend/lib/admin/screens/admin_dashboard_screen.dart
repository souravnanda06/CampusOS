import 'package:flutter/material.dart';

import '../../auth/models/user_model.dart';
import '../../auth/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import 'admin_shell_screen.dart';

/// CampusOS Admin Dashboard Entrypoint.
///
/// Delegates to the Apple-grade [AdminShellScreen] 4-item navigation experience.
class AdminDashboardScreen extends StatefulWidget {
  final UserModel? user;

  const AdminDashboardScreen({Key? key, this.user}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _currentUser = widget.user;
      _isLoading = false;
    } else {
      _loadUser();
    }
  }

  Future<void> _loadUser() async {
    final user =
        _authService.currentUser ?? await _authService.getUserDataFromStorage();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    return AdminShellScreen(user: _currentUser);
  }
}
