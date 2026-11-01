import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user_model.dart';
import '../../auth/providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../router/app_routes.dart';
import '../../shared/models/session_model.dart';
import '../../shared/services/session_service.dart';
import '../../core/localization/app_localizations.dart';
import 'post_class_update_dialog.dart';

/// CampusOS Teacher Home Content â€” Apple-grade minimalist operations launchpad.
///
/// Philosophy: "ONE TAP TO START. ONE GLANCE TO KNOW."
///
/// Features:
/// 1. Personalized Greeting with dynamic time-of-day and verified instructor indicator.
/// 2. Active Session Live Banner (if a session is already in progress).
/// 3. Quick Start Hero Card with Smart Defaults, remembered class presets,
///    and Apple-style segmented Tx Power / Range selector (Low / Medium / High).
/// 4. Today's Assigned Classes with direct one-tap start actions.
/// 5. Recent Sessions history with real attendance figures.
/// 6. Campus Operations shortcuts (Notices, Mess, Verifier).
class TeacherHomeContent extends StatefulWidget {
  final UserModel? user;
  final List<SessionModel> activeSessions;
  final VoidCallback onRefreshSessions;
  final void Function(int) onNavigateToTab;
  final List<Map<String, String?>>? initialPresets;
  final bool? isLoadingPresets;
  final String? presetsErrorMessage;

  const TeacherHomeContent({
    Key? key,
    required this.user,
    required this.activeSessions,
    required this.onRefreshSessions,
    required this.onNavigateToTab,
    this.initialPresets,
    this.isLoadingPresets,
    this.presetsErrorMessage,
  }) : super(key: key);

  @override
  State<TeacherHomeContent> createState() => _TeacherHomeContentState();
}

class _TeacherHomeContentState extends State<TeacherHomeContent> {
  final SessionService _sessionService = SessionService();

  // Smart Default Session State
  String _selectedSubject = 'Data Structures';
  String _selectedCourse = 'B.Tech';
  String _selectedBranch = 'CSE';
  String _selectedYear = '3rd';
  String _selectedRoom = 'Room 204';
  int _selectedTxPower = 2; // 1 = Low, 2 = Medium, 3 = High

  List<Map<String, String?>> _savedPresets = [];
  List<SessionModel> _recentSessions = [];
  bool _isStartingSession = false;
  bool _isLoadingPresets = false;
  String? _presetsError;

  @override
  void initState() {
    super.initState();
    if (widget.initialPresets != null) {
      _savedPresets = List.from(widget.initialPresets!);
      _isLoadingPresets = widget.isLoadingPresets ?? false;
      _presetsError = widget.presetsErrorMessage;
      if (_savedPresets.isNotEmpty) {
        final first = _savedPresets.first;
        _selectedSubject = first['subject'] ?? _selectedSubject;
        _selectedCourse = first['course'] ?? _selectedCourse;
        _selectedBranch = first['branch'] ?? _selectedBranch;
        _selectedYear = first['year'] ?? _selectedYear;
        _selectedRoom = first['room'] ?? _selectedRoom;
      }
    } else {
      _loadSmartDefaults();
    }
    _loadRecentSessions();
  }

  Future<void> _loadSmartDefaults() async {
    final userId = widget.user?.id;
    if (userId == null || userId.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingPresets = true;
      _presetsError = null;
    });

    try {
      final tokens = await _sessionService.getQuickStartTokens(userId);
      if (mounted) {
        setState(() {
          _savedPresets = tokens;
          _isLoadingPresets = false;
          if (tokens.isNotEmpty) {
            final first = tokens.first;
            _selectedSubject = first['subject'] ?? _selectedSubject;
            _selectedCourse = first['course'] ?? _selectedCourse;
            _selectedBranch = first['branch'] ?? _selectedBranch;
            _selectedYear = first['year'] ?? _selectedYear;
            _selectedRoom = first['room'] ?? _selectedRoom;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPresets = false;
          _presetsError = 'Failed to load assigned classes';
        });
      }
    }
  }

  Future<void> _loadRecentSessions() async {
    final teacherName = widget.user?.name;
    if (teacherName == null || teacherName.isEmpty) return;

    try {
      final list = await _sessionService.getSessionsByDate(
        instructorName: teacherName,
        date: DateTime.now(),
      );
      if (mounted) {
        setState(() {
          _recentSessions = list.take(5).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _startSessionWithDefaults({
    String? subject,
    String? course,
    String? branch,
    String? year,
    String? room,
  }) async {
    setState(() => _isStartingSession = true);
    AppHaptics.mediumImpact();

    final targetSubject = subject ?? _selectedSubject;
    final targetCourse = course ?? _selectedCourse;
    final targetBranch = branch ?? _selectedBranch;
    final targetYear = year ?? _selectedYear;
    final targetRoom = room ?? _selectedRoom;

    final teacher = widget.user;
    if (teacher == null) {
      setState(() => _isStartingSession = false);
      return;
    }

    try {
      final sessionId = await _sessionService.createSession(
        name: targetSubject,
        instructorName: teacher.name,
        course: targetCourse,
        branch: targetBranch,
        year: targetYear,
        location: targetRoom,
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(minutes: 60)),
        txPowerLevel: _selectedTxPower,
      );

      // Persist as latest quick start token
      await _sessionService.saveQuickStartToken(
        userId: teacher.id,
        course: targetCourse,
        branch: targetBranch,
        year: targetYear,
        subject: targetSubject,
      );

      final newSession = SessionModel(
        id: sessionId,
        name: targetSubject,
        instructorName: teacher.name,
        course: targetCourse,
        branch: targetBranch,
        year: targetYear,
        location: targetRoom,
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(minutes: 60)),
        isActive: true,
        txPowerLevel: _selectedTxPower,
      );

      if (mounted) {
        await context.read<UserProvider>().setSessionId(sessionId);
        if (!mounted) return;
        widget.onRefreshSessions();
        Navigator.pushNamed(
          context,
          AppRoutes.teacherBroadcasting,
          arguments: {
            'user': teacher,
            'session': newSession,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to start session: $e",
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingSession = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }

  @override
  Widget build(BuildContext context) {
    final teacherDisplayName = widget.user?.name ?? 'Professor';
    final dateFormatted = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            widget.onRefreshSessions();
            await _loadRecentSessions();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(context, teacherDisplayName, dateFormatted),
                const SizedBox(height: 16),

                // Active Live Session Banner (if running)
                if (widget.activeSessions.isNotEmpty) ...[
                  _buildLiveSessionBanner(context, widget.activeSessions.first),
                  const SizedBox(height: 16),
                ],

                // Quick Start Hero Card
                _buildQuickStartHero(context),
                const SizedBox(height: 24),

                // CampusOS Mesh (M1-M7) Network Showcase
                _buildCampusMeshSection(context),
                const SizedBox(height: 24),

                // Today's Classes Section
                _buildTodayClassesSection(context),
                const SizedBox(height: 24),

                // Quick Actions (Notices, Classes, Analytics, Mess)
                _buildQuickActionsSection(context),
                const SizedBox(height: 24),

                // Recent Sessions Section (Recent Activity)
                _buildRecentSessionsSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String firstName, String dateFormatted) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${_getGreeting().tr(context)}, $firstName",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                dateFormatted,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mesh Hub Antenna shortcut
            InkWell(
              onTap: () {
                AppHaptics.lightImpact();
                Navigator.pushNamed(context, AppRoutes.meshHub);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.settings_input_antenna_rounded,
                  color: Color(0xFF6366F1),
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Notification Bell affordance
            InkWell(
              onTap: () {
                AppHaptics.lightImpact();
                Navigator.pushNamed(context, AppRoutes.noticeManagement,
                    arguments: widget.user);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Verified Teacher Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user_rounded,
                      color: AppColors.primary, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    "Faculty".tr(context),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _buildLiveSessionBanner(BuildContext context, SessionModel liveSession) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED), // Subtle warm amber
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sensors_rounded,
                color: AppColors.warning, size: 18)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Session Live: ${liveSession.name}",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9A3412),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "${liveSession.location.isNotEmpty ? liveSession.location : 'Room 204'} Â· Broadcasting BLE beacon",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFFC2410C),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.teacherBroadcasting,
                arguments: {
                  'user': widget.user,
                  'session': liveSession,
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              "Resume",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStartHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle and preset picker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "QUICK START".tr(context),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.teacherCreateSession)
                      .then((_) => widget.onRefreshSessions());
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        "Custom".tr(context),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.tune_rounded,
                          size: 13, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Subject Name
          Text(
            _selectedSubject,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),

          // Class Details Pill
          Row(
            children: [
              Text(
                "$_selectedCourse Â· $_selectedBranch $_selectedYear Year",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  color: AppColors.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _selectedRoom,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Apple-style Tx Power Segmented Control
          Text(
            "BROADCAST RANGE",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          _buildTxPowerSegmentedControl(),
          const SizedBox(height: 20),

          // Action Button: One-Tap Start
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isStartingSession
                  ? null
                  : () => _startSessionWithDefaults(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isStartingSession
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Start Attendance".tr(context),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 300.ms);
  }

  Widget _buildTxPowerSegmentedControl() {
    final options = [
      {'val': 1, 'title': 'Low', 'sub': 'Small room'},
      {'val': 2, 'title': 'Medium', 'sub': 'Classroom'},
      {'val': 3, 'title': 'High', 'sub': 'Lecture hall'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final segmentWidth = totalWidth / options.length;
          final selectedIndex = (_selectedTxPower - 1).clamp(0, options.length - 1);

          return Stack(
            children: [
              // Smooth sliding active thumb capsule
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                left: selectedIndex * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),

              // Interactive Segment Options
              Row(
                children: options.map((opt) {
                  final isSelected = _selectedTxPower == opt['val'];
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        AppHaptics.selectionClick();
                        setState(() => _selectedTxPower = opt['val'] as int);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                              child: Text((opt['title'] as String).tr(context)),
                            ),
                            const SizedBox(height: 2),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textTertiary,
                              ),
                              child: Text((opt['sub'] as String).tr(context)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTodayClassesSection(BuildContext context) {
    final classes = _savedPresets;
    final isLoading = widget.isLoadingPresets ?? _isLoadingPresets;
    final error = widget.presetsErrorMessage ?? _presetsError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Assigned Classes".tr(context),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (classes.isNotEmpty)
              InkWell(
                onTap: () => widget.onNavigateToTab(1), // Go to Classes tab
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    "See All".tr(context),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (isLoading)
          Container(
            key: const Key('teacher_classes_loading'),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (error != null)
          Container(
            key: const Key('teacher_classes_error'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadSmartDefaults,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            ),
          )
        else if (classes.isEmpty)
          Container(
            key: const Key('teacher_empty_classes_container'),
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_busy_rounded,
                      color: AppColors.textTertiary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "No classes assigned today",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "You have no scheduled class sessions for today.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: classes.take(3).length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final c = classes[index];
            final subj = c['subject'] ?? 'Class Session';
            final course = c['course'] ?? 'B.Tech';
            final branch = c['branch'] ?? 'CSE';
            final year = c['year'] ?? '3rd';
            final room = c['room'] ?? 'Room 204';
            final time = c['time'] ?? 'Today';

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        subj.isNotEmpty ? subj[0].toUpperCase() : 'C',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subj,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "$course $branch Â· $year Â· $room Â· $time",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      _startSessionWithDefaults(
                        subject: subj,
                        course: course,
                        branch: branch,
                        year: year,
                        room: room,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      "Start".tr(context),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  Widget _buildRecentSessionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent Sessions".tr(context),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            InkWell(
              onTap: () => widget.onNavigateToTab(2), // Go to Analytics
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  "Analytics".tr(context),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentSessions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(Icons.history_rounded,
                    size: 32, color: AppColors.textTertiary),
                const SizedBox(height: 6),
                Text(
                  "No recent sessions conducted yet today.",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentSessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final s = _recentSessions[index];
              final timeStr = DateFormat('hh:mm a').format(s.startTime);

              return InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.teacherSessionAttendance,
                    arguments: s,
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              "${s.course ?? 'B.Tech'} ${s.branch ?? 'CSE'} Â· $timeStr",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textTertiary, size: 18),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    ).animate().fadeIn(delay: 250.ms, duration: 300.ms);
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Quick Actions".tr(context),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.noticeManagement,
                    arguments: widget.user);
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  "All Notices".tr(context),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildOperationCard(
                context,
                icon: Icons.campaign_rounded,
                title: "Notices",
                subtitle: "Student announcements",
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.noticeManagement,
                      arguments: widget.user);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOperationCard(
                context,
                icon: Icons.school_rounded,
                title: "Classes",
                subtitle: "Curriculum & roster",
                color: AppColors.primary,
                onTap: () => widget.onNavigateToTab(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildOperationCard(
                context,
                icon: Icons.insights_rounded,
                title: "Analytics",
                subtitle: "Attendance trends",
                color: const Color(0xFF10B981),
                onTap: () => widget.onNavigateToTab(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOperationCard(
                context,
                icon: Icons.edit_calendar_rounded,
                title: "Class Update",
                subtitle: "Cancel / reschedule",
                color: const Color(0xFFDC2626),
                onTap: () {
                  PostClassUpdateDialog.show(
                    context,
                    teacherId: widget.user?.id ?? '',
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildOperationCard(
                context,
                icon: Icons.file_upload_outlined,
                title: "AirDrop",
                subtitle: "Offline P2P files",
                color: const Color(0xFF6366F1),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.meshAirDrop);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOperationCard(
                context,
                icon: Icons.chat_bubble_outline_rounded,
                title: "Mesh Chat",
                subtitle: "Offline messaging",
                color: const Color(0xFF0EA5E9),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.meshChat);
                },
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 280.ms, duration: 300.ms);
  }

  Widget _buildOperationCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title.tr(context),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle.tr(context),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampusMeshSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131722) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.hub_rounded,
                      color: Color(0xFF6366F1),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "CampusOS Mesh",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "M1–M7",
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "Offline Academic P2P & Emergency Mesh",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  AppHaptics.lightImpact();
                  Navigator.pushNamed(context, AppRoutes.meshHub);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Open Hub",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMeshActionItem(
                  context,
                  title: "AirDrop",
                  subtitle: "P2P Files",
                  icon: Icons.file_upload_outlined,
                  color: const Color(0xFF6366F1),
                  route: AppRoutes.meshAirDrop,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMeshActionItem(
                  context,
                  title: "Mesh Chat",
                  subtitle: "Offline Chat",
                  icon: Icons.chat_bubble_outline_rounded,
                  color: const Color(0xFF0EA5E9),
                  route: AppRoutes.meshChat,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMeshActionItem(
                  context,
                  title: "Flare SOS",
                  subtitle: "Disaster Alert",
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFEF4444),
                  route: AppRoutes.meshEmergency,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMeshActionItem(
                  context,
                  title: "Radar",
                  subtitle: "Peers",
                  icon: Icons.radar_rounded,
                  color: const Color(0xFF10B981),
                  route: AppRoutes.meshRadar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeshActionItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        AppHaptics.lightImpact();
        Navigator.pushNamed(context, route);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
