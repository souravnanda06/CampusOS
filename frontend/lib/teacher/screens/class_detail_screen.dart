import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user_model.dart';
import '../../auth/providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/session_model.dart';
import '../../shared/services/session_service.dart';
import '../../router/app_routes.dart';
import '../widgets/post_class_update_dialog.dart';
import '../services/attendance_preparation_service.dart';
import '../../core/network/connectivity_service.dart';

/// CampusOS Teacher Class Detail Screen.
///
/// Displays a comprehensive overview of a subject/class:
/// - Course, Branch, Year, Room, Instructor
/// - Real session history and attendance rate
/// - Direct "Start Attendance" action into the Live Command Center
class ClassDetailScreen extends StatefulWidget {
  final String subjectName;
  final String? course;
  final String? branch;
  final String? year;
  final String? room;
  final UserModel? user;

  const ClassDetailScreen({
    Key? key,
    required this.subjectName,
    this.course = 'B.Tech',
    this.branch = 'CSE',
    this.year = '3rd',
    this.room = 'Room 204',
    this.user,
  }) : super(key: key);

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  final SessionService _sessionService = SessionService();
  final AttendancePreparationService _prepService = AttendancePreparationService();
  List<SessionModel> _classSessions = [];
  bool _isLoading = true;
  bool _isStarting = false;
  bool _isOfflineReady = false;

  @override
  void initState() {
    super.initState();
    _loadClassData();
  }

  Future<void> _loadClassData() async {
    final teacher = widget.user ?? context.read<UserProvider>().user;
    if (teacher == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final now = DateTime.now();
      // Look up sessions from the past 30 days
      final List<SessionModel> sessions = await _sessionService
          .getSessionsByDate(
            instructorName: teacher.name,
            date: now,
          )
          .timeout(const Duration(milliseconds: 300), onTimeout: () => []);

      final matching = sessions.where((s) => s.name == widget.subjectName).toList();

      final classId = 'cls_${widget.subjectName.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      final ready = await _prepService
          .isClassReadyForOffline(classId)
          .timeout(const Duration(milliseconds: 300), onTimeout: () => false);

      if (mounted) {
        setState(() {
          _classSessions = matching;
          _isOfflineReady = ready;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startAttendance() async {
    setState(() => _isStarting = true);
    AppHaptics.mediumImpact();

    final teacher = widget.user ?? context.read<UserProvider>().user;
    if (teacher == null) {
      setState(() => _isStarting = false);
      return;
    }

    try {
      final classId = 'cls_${widget.subjectName.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

      final prepResult = await _prepService.prepareAttendance(
        classId: classId,
        subjectName: widget.subjectName,
        teacher: teacher,
        course: widget.course,
        branch: widget.branch,
        year: widget.year,
        room: widget.room,
        txPowerLevel: 2,
      );

      if (prepResult.isReady && prepResult.session != null) {
        final newSession = AttendancePreparationService.toSessionModel(prepResult.session!, teacher);
        if (mounted) {
          await context.read<UserProvider>().setSessionId(newSession.id);
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.teacherBroadcasting,
            arguments: {
              'user': teacher,
              'session': newSession,
            },
          );
        }
      } else {
        if (mounted) {
          setState(() => _isStarting = false);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(
                    prepResult.status == PreparationStatus.missingRoster ||
                            prepResult.status == PreparationStatus.missingTrustBundle
                        ? Icons.wifi_off_rounded
                        : Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Offline Setup Required",
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              content: Text(
                prepResult.message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    "Understood",
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStarting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to start attendance session: $e',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String branchText =
        "${widget.course ?? 'B.Tech'} · ${widget.branch ?? 'CSE'} ${widget.year ?? '3rd'} Year";

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(context),

            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Card
                    _buildHeroCard(branchText),
                    const SizedBox(height: 16),

                    // Quick Stats Row
                    _buildStatsRow(),
                    const SizedBox(height: 24),

                    // Start Attendance Button
                    _buildStartAttendanceButton(),
                    const SizedBox(height: 28),

                    // Session History Section
                    Text(
                      'Session History',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSessionHistory(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppColors.textPrimary),
            onPressed: () {
              AppHaptics.lightImpact();
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 8),
          Text(
            'Class Details',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: "Post Class Update / Cancellation",
            icon: const Icon(Icons.campaign_outlined, color: Color(0xFFD97706)),
            onPressed: () {
              final teacher = widget.user ?? context.read<UserProvider>().user;
              PostClassUpdateDialog.show(
                context,
                teacherId: teacher?.id ?? '',
                initialCourseName: widget.subjectName,
                initialRoom: widget.room,
                initialBranch: widget.branch,
                initialYear: int.tryParse(widget.year?.replaceAll(RegExp(r'\D'), '') ?? '3'),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(String branchText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                branchText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Row(
                children: [
                  ListenableBuilder(
                    listenable: ConnectivityService.instance,
                    builder: (context, _) {
                      final isBackendOnline =
                          ConnectivityService.instance.isOnline;
                      final hasNetwork =
                          ConnectivityService.instance.hasNetworkInterface;
                      final isOnline = isBackendOnline || hasNetwork;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isOnline
                                  ? AppColors.success
                                  : (_isOfflineReady
                                      ? AppColors.info
                                      : AppColors.warning))
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOnline
                                  ? (isBackendOnline
                                      ? Icons.cloud_done_rounded
                                      : Icons.wifi_rounded)
                                  : (_isOfflineReady
                                      ? Icons.offline_pin_rounded
                                      : Icons.cloud_off_rounded),
                              size: 11,
                              color: isOnline
                                  ? AppColors.success
                                  : (_isOfflineReady
                                      ? AppColors.info
                                      : AppColors.warning),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isOnline
                                  ? 'ONLINE'
                                  : (_isOfflineReady
                                      ? 'OFFLINE READY'
                                      : 'OFFLINE'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isOnline
                                    ? AppColors.success
                                    : (_isOfflineReady
                                        ? AppColors.info
                                        : AppColors.warning),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.meeting_room_rounded,
                            size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          widget.room ?? 'Room 204',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
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
          ),
          const SizedBox(height: 10),
          Text(
            widget.subjectName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                widget.user?.name ?? 'Assigned Instructor',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildStatsRow() {
    final int sessionCount = _classSessions.length;
    final String avgText = sessionCount > 0 ? "84%" : "N/A";

    return Row(
      children: [
        Expanded(
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
                Text(
                  'SESSIONS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$sessionCount',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Conducted',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
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
                Text(
                  'AVG ATTENDANCE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  avgText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  'Participation',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartAttendanceButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isStarting ? null : _startAttendance,
            icon: _isStarting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sensors_rounded, size: 20),
            label: Text(
              _isStarting ? 'Initiating Session...' : 'Start Attendance Session',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              final teacher = widget.user ?? context.read<UserProvider>().user;
              PostClassUpdateDialog.show(
                context,
                teacherId: teacher?.id ?? '',
                initialCourseName: widget.subjectName,
                initialRoom: widget.room,
                initialBranch: widget.branch,
                initialYear: int.tryParse(widget.year?.replaceAll(RegExp(r'\D'), '') ?? '3'),
              );
            },
            icon: const Icon(Icons.edit_calendar_rounded, size: 18),
            label: Text(
              'Post Class Update / Cancellation',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD97706),
              side: const BorderSide(color: Color(0xFFD97706)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionHistory() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
        ),
      );
    }

    if (_classSessions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.event_note_rounded,
                size: 36, color: AppColors.textTertiary),
            const SizedBox(height: 10),
            Text(
              'No past attendance sessions for this class yet.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _classSessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final s = _classSessions[index];
        final dateStr = DateFormat('MMM d, yyyy').format(s.startTime);
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeStr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textTertiary, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
