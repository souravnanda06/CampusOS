import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:google_fonts/google_fonts.dart';

import '../auth/models/user_model.dart';
import '../auth/providers/user_provider.dart';
import '../auth/services/auth_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../router/app_routes.dart';
import '../shared/models/attendance_model.dart';
import '../shared/models/session_model.dart';
import '../shared/services/attendance_service.dart';
import '../shared/providers/attendance_provider.dart';
import '../shared/services/session_service.dart';
import '../student/screens/student_shell_screen.dart';
import '../teacher/screens/teacher_shell_screen.dart';
import '../admin/screens/admin_shell_screen.dart';
import '../mess/screens/mess_shell_screen.dart';
import '../security/screens/security_shell_screen.dart';
import '../warden/screens/warden_shell_screen.dart';
import '../core/mesh/campus_mesh_manager.dart';

class HomeScreen extends StatefulWidget {
  final AuthService? authService;

  const HomeScreen({Key? key, this.authService}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AuthService _authService;
  final SessionService _sessionService = SessionService();
  final AttendanceService _attendanceService = AttendanceService();

  UserModel? _user;
  bool _loading = true;

  // Teacher specific state
  List<SessionModel> _teacherActiveSessions = [];

  // Student specific state
  List<AttendanceModel> _recentAttendance = [];
  double _overallAttendance = 0.0;
  Map<String, dynamic>? _attendanceAnalytics;

  UserProvider? _userProvider;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _loadUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final provider = Provider.of<UserProvider>(context, listen: false);
      if (_userProvider != provider) {
        _userProvider?.removeListener(_handleUserProviderChange);
        _userProvider = provider;
        _userProvider?.addListener(_handleUserProviderChange);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _userProvider?.removeListener(_handleUserProviderChange);
    super.dispose();
  }

  void _handleUserProviderChange() {
    if (_user?.role == 'teacher') {
      _checkActiveSessions();
    }
  }

  Future<void> _loadUser() async {
    final user = await _authService.getUserDataFromStorage();
    if (!mounted) return;

    if (user == null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }

    setState(() {
      _user = user;
      _loading = false;
    });

    // Initialize CampusOS Mesh (M1-M7) for any authenticated role
    CampusMeshManager.instance.initialize(user: user);

    if (user.role == 'teacher') {
      _checkActiveSessions();
    } else if (user.role == 'student') {
      _loadRecentAttendance();
      _fetchStudentOverallStats(user.id);
    }
  }

  Future<void> _fetchStudentOverallStats(String? uid) async {
    if (uid == null) return;
    try {
      final data =
          await _attendanceService.getStudentComprehensiveAnalytics(uid);
      if (data != null && mounted) {
        setState(() {
          _attendanceAnalytics = data;
          _overallAttendance = (data['overallPercentage'] ?? 0).toDouble();

          if (_user != null) {
            _user!.attendancePercentage = _overallAttendance;
            context.read<UserProvider>().setUser(_user!);
          }
        });
        _syncAttendanceProvider();
      }
    } catch (e) {
      debugPrint("Error fetching home stats: $e");
    }
  }

  /// Pushes the latest Home stats into the shared AttendanceProvider so the
  /// attendance card updates live (e.g. right after Passport marks attendance).
  void _syncAttendanceProvider() {
    if (!mounted) return;
    try {
      context.read<AttendanceProvider>().seedData(
            overallAttendance: _overallAttendance,
            recentAttendance: _recentAttendance,
            attendanceAnalytics: _attendanceAnalytics,
            studentId: _user?.id,
          );
    } catch (_) {
      // Provider not available (e.g. isolated widget tests)
    }
  }

  Future<void> _checkActiveSessions() async {
    if (_user == null) return;

    try {
      final allActiveSessions = await _sessionService.getActiveSessions();
      final mySessions = allActiveSessions
          .where((s) => s.instructorName == _user?.name)
          .toList();

      if (mounted) {
        setState(() {
          _teacherActiveSessions = mySessions;
        });
      }
    } catch (e) {
      debugPrint("Error checking active sessions: $e");
    }
  }

  Future<void> _loadRecentAttendance() async {
    if (_user != null) {
      try {
        final list = await _attendanceService.getStudentAttendance(_user!.uid);
        list.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
        if (mounted) {
          setState(() {
            _recentAttendance = list.take(5).toList();
          });
          _syncAttendanceProvider();
        }
      } catch (e) {
        debugPrint("Error loading recent attendance: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _user == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
      );
    }

    final role = _user?.role.toLowerCase() ?? '';

    if (role == 'admin') {
      return AdminShellScreen(user: _user);
    }

    if (role == 'student') {
      return StudentShellScreen(
        user: _user,
        overallAttendance: _overallAttendance,
        recentAttendance: _recentAttendance,
        attendanceAnalytics: _attendanceAnalytics,
        loading: _loading,
      );
    }

    if (role == 'teacher') {
      return TeacherShellScreen(
        user: _user,
        activeSessions: _teacherActiveSessions,
        onRefreshSessions: _checkActiveSessions,
      );
    }

    if (role == 'mess_staff' || role == 'mess') {
      return MessShellScreen(user: _user);
    }

    if (role == 'security' || role == 'guard' || role == 'security_guard') {
      return SecurityShellScreen(user: _user);
    }

    if (role == 'warden') {
      return WardenShellScreen(user: _user);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('CampusOS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await AuthService.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Logged in as ${_user?.name} (${_user?.role})',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
