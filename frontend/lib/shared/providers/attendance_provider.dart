import 'package:flutter/material.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';

/// Single source of truth for the student's attendance stats shown on Home
/// (attendance card %, streak, recent activity).
///
/// - Seeded by HomeScreen on startup.
/// - Optimistically updated the instant Passport verifies attendance over BLE.
/// - Re-synced silently from the backend afterwards (authoritative values win).
class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _attendanceService;

  AttendanceProvider({AttendanceService? attendanceService})
      : _attendanceService = attendanceService ?? AttendanceService();

  int _refreshKey = 0;
  int get refreshKey => _refreshKey;

  double _overallAttendance = 0.0;
  double get overallAttendance => _overallAttendance;

  List<AttendanceModel> _recentAttendance = [];
  List<AttendanceModel> get recentAttendance =>
      List.unmodifiable(_recentAttendance);

  Map<String, dynamic>? _attendanceAnalytics;
  Map<String, dynamic>? get attendanceAnalytics => _attendanceAnalytics;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasData = false;
  bool get hasData => _hasData;

  String? _lastStudentId;
  final Set<String> _locallyRecordedSessions = <String>{};
  final Set<String> _attendedSessionIds = <String>{};
  bool _isFetching = false;

  /// Checks whether a specific session has already been recorded as attended
  /// either through local BLE verification or fetched attendance history.
  bool isSessionAttended(String sessionId) {
    if (sessionId.isEmpty) return false;
    return _attendedSessionIds.contains(sessionId) ||
        _locallyRecordedSessions.contains(sessionId) ||
        _recentAttendance.any((a) => a.sessionId == sessionId);
  }

  /// Seeds the provider with initial data (e.g. from HomeScreen on startup).
  void seedData({
    required double overallAttendance,
    required List<AttendanceModel> recentAttendance,
    Map<String, dynamic>? attendanceAnalytics,
    String? studentId,
  }) {
    _overallAttendance = overallAttendance;
    _recentAttendance = List.from(recentAttendance);
    if (recentAttendance.isNotEmpty) {
      _attendedSessionIds.addAll(recentAttendance.map((a) => a.sessionId));
    }
    if (attendanceAnalytics != null) {
      _attendanceAnalytics = Map<String, dynamic>.from(attendanceAnalytics);
    }
    if (studentId != null && studentId.isNotEmpty) {
      _lastStudentId = studentId;
    }
    _hasData = true;
    notifyListeners();
  }

  /// Immediately reflects a BLE-verified attendance on the Home screen,
  /// then fetches authoritative analytics from the backend in the background.
  void recordAttendanceLocally({
    required String sessionId,
    String? studentId,
    String? subjectName,
  }) {
    _refreshKey++;
    final resolvedStudentId = studentId ?? _lastStudentId;
    if (resolvedStudentId != null && resolvedStudentId.isNotEmpty) {
      _lastStudentId = resolvedStudentId;
    }

    final alreadyCounted = _locallyRecordedSessions.contains(sessionId) ||
        _recentAttendance.any((a) => a.sessionId == sessionId);

    if (!alreadyCounted) {
      _locallyRecordedSessions.add(sessionId);
      _attendedSessionIds.add(sessionId);

      // 1. Optimistic recalculation: new session counts as +1 total, +1 attended
      final analytics = _attendanceAnalytics != null
          ? Map<String, dynamic>.from(_attendanceAnalytics!)
          : <String, dynamic>{};

      final attended = (analytics['attendedClasses'] as num?)?.toInt() ?? 0;
      final total = (analytics['totalClasses'] as num?)?.toInt() ?? 0;
      final newAttended = attended + 1;
      final newTotal = (total + 1) < newAttended ? newAttended : total + 1;
      final newPercentage =
          double.parse(((newAttended / newTotal) * 100).toStringAsFixed(1));

      analytics['attendedClasses'] = newAttended;
      analytics['totalClasses'] = newTotal;
      analytics['overallPercentage'] = newPercentage;
      analytics['streak'] = ((analytics['streak'] as num?)?.toInt() ?? 0) + 1;

      _attendanceAnalytics = analytics;
      _overallAttendance = newPercentage;

      // 2. Optimistic entry in recent activity
      _recentAttendance = [
        AttendanceModel(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          userId: resolvedStudentId ?? '',
          studentName: '',
          sessionId: sessionId,
          sessionName: (subjectName != null && subjectName.isNotEmpty)
              ? subjectName
              : 'Class Session',
          checkInTime: DateTime.now(),
          location: 'BLE Verified',
          status: 'present',
        ),
        ..._recentAttendance.take(4),
      ];

      _hasData = true;
      notifyListeners();
    }

    // 3. Background authoritative sync (slight delay lets the backend commit the mark)
    if (resolvedStudentId != null && resolvedStudentId.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        fetchAttendanceData(resolvedStudentId, silent: true);
      });
    }
  }

  /// Fetches comprehensive analytics and recent attendance from the backend.
  /// On failure (e.g. offline), the current/optimistic values are kept.
  Future<void> fetchAttendanceData(String? studentId,
      {bool silent = false}) async {
    final uid = studentId ?? _lastStudentId;
    if (uid == null || uid.isEmpty) return;
    if (_isFetching) return;
    _lastStudentId = uid;
    _isFetching = true;

    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final results = await Future.wait<dynamic>([
        _attendanceService.getStudentComprehensiveAnalytics(uid),
        _attendanceService.getStudentAttendance(uid),
      ]);

      final analytics = results[0] as Map<String, dynamic>?;
      final attendanceList = (results[1] as List<AttendanceModel>?) ?? [];

      if (analytics != null) {
        _attendanceAnalytics = analytics;
        _overallAttendance =
            (analytics['overallPercentage'] as num?)?.toDouble() ?? 0.0;
      }

      if (attendanceList.isNotEmpty) {
        attendanceList.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
        _recentAttendance = attendanceList.take(5).toList();
        _attendedSessionIds.addAll(attendanceList.map((a) => a.sessionId));
        // Server now knows these sessions; stop tracking them locally
        _locallyRecordedSessions
            .removeWhere((id) => attendanceList.any((a) => a.sessionId == id));
      }

      if (analytics != null || attendanceList.isNotEmpty) {
        _hasData = true;
        _refreshKey++;
      }
    } catch (e) {
      debugPrint("⚠️ [ATTENDANCE_PROVIDER] Error fetching attendance data: $e");
    } finally {
      _isFetching = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Signals a refresh and re-syncs from the backend.
  void refreshAttendance({String? studentId}) {
    _refreshKey++;
    notifyListeners();
    final uid = studentId ?? _lastStudentId;
    if (uid != null && uid.isNotEmpty) {
      fetchAttendanceData(uid, silent: true);
    }
  }
}
