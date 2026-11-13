import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../router/app_routes.dart';
import '../../shared/models/attendance_model.dart';
import '../../core/models/expansion_models.dart';
import '../../core/services/expansion_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/language_provider.dart';
import '../../core/localization/app_strings.dart';
import 'dart:math' as math;
import '../screens/global_search_screen.dart';
import '../screens/notifications_center_screen.dart';
import '../screens/timetable_screen.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../shared/providers/attendance_provider.dart';
import '../../shared/models/session_model.dart';
import '../../shared/services/session_service.dart';
import '../../data/syllabus/syllabus_data.dart';
import 'attendance/attendance_card.dart';
import 'attendance/apple_attendance_expanded_view.dart';
import 'emergency/student_emergency_section.dart';
import '../../shared/widgets/motion/apple_bounceable.dart';
import '../../shared/widgets/motion/apple_spring_scroll_physics.dart';
import '../../shared/widgets/motion/apple_context_menu.dart';
import '../../shared/widgets/motion/apple_continuous_expansion.dart';
import 'timetable/apple_next_class_expanded_view.dart';

class StudentHomeContent extends StatelessWidget {
  static final GlobalKey<AppleContinuousExpansionCardState> attendanceExpansionKey =
      GlobalKey<AppleContinuousExpansionCardState>();
  static final GlobalKey<AppleContinuousExpansionCardState> nextClassExpansionKey =
      GlobalKey<AppleContinuousExpansionCardState>();
  final UserModel? user;
  final double overallAttendance;
  final List<AttendanceModel> recentAttendance;
  final Map<String, dynamic>? attendanceAnalytics;
  final bool loading;
  final void Function(int, {int? requestTab, int? requestSubTab}) onNavigateToTab;

  const StudentHomeContent({
    Key? key,
    required this.user,
    required this.overallAttendance,
    required this.recentAttendance,
    this.attendanceAnalytics,
    required this.loading,
    required this.onNavigateToTab,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Subtle ambient lavender/indigo glow in the top-right corner
        Positioned(
          top: -80,
          right: -40,
          child: IgnorePointer(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    isDark
                        ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                        : const Color(0xFF818CF8).withValues(alpha: 0.18),
                    isDark
                        ? const Color(0xFF4F46E5).withValues(alpha: 0.05)
                        : const Color(0xFFC7D2FE).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: const Color(0xFF4F46E5),
            backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
            onRefresh: () async {
              AppHaptics.mediumImpact();
              if (user?.id != null) {
                try {
                  final prov = Provider.of<AttendanceProvider>(context, listen: false);
                  await prov.fetchAttendanceData(user!.id, silent: true);
                } catch (_) {}
              }
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 165),
              physics: AppleSpringScrollPhysics.always,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header (Greeting + Name + Action Buttons + Avatar)
                  _buildStartupHeader(context)
                      .animate()
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: -0.08, curve: Curves.easeOutCubic),
                  const SizedBox(height: 18),

                  _buildCampusMeshSection(context),

                  StudentActiveSessionBanner(
                    user: user,
                    onNavigateToTab: (index) => onNavigateToTab(index),
                  ),

                  // Hero Attendance Card with Apple HIG Continuous Expansion Transition
                  Builder(
                    builder: (context) {
                      final expansionKey = attendanceExpansionKey;

                      return AppleContinuousExpansionCard(
                        key: expansionKey,
                        cardRadius: 28,
                        expandedBuilder: (ctx, dismiss) =>
                            AppleAttendanceExpandedView(
                          user: user,
                          overallAttendance: overallAttendance,
                          attendanceAnalytics: attendanceAnalytics,
                          onDismiss: dismiss,
                        ),
                        child: AppleContextMenu(
                          actions: [
                            AppleContextMenuItem(
                              title: "Attendance Analytics",
                              icon: Icons.analytics_outlined,
                              onTap: () => expansionKey.currentState?.open(),
                            ),
                            AppleContextMenuItem(
                              title: "Attendance Policy (75%)",
                              icon: Icons.policy_outlined,
                              onTap: () => _showAttendancePolicySheet(context),
                            ),
                            AppleContextMenuItem(
                              title: "Refresh Attendance",
                              icon: Icons.refresh_rounded,
                              onTap: () async {
                                AppHaptics.mediumImpact();
                                if (user?.id != null) {
                                  try {
                                    final prov = Provider.of<AttendanceProvider>(
                                        context,
                                        listen: false);
                                    await prov.fetchAttendanceData(user!.id,
                                        silent: true);
                                  } catch (_) {}
                                }
                              },
                            ),
                          ],
                          onTap: () => expansionKey.currentState?.open(),
                          child: AttendanceCard(
                            user: user,
                            overallAttendance: overallAttendance,
                            attendanceAnalytics: attendanceAnalytics,
                            onNavigateToTab: (index) => onNavigateToTab(index),
                            onCardTap: () => expansionKey.currentState?.open(),
                          ),
                        ),
                      );
                    },
                  )
                      .animate()
                      .fadeIn(delay: 80.ms, duration: 450.ms)
                      .slideY(begin: 0.08, curve: Curves.easeOutCubic),
                  const SizedBox(height: 18),

                  // Bento Grid: Streak & Next Class
                  _buildBentoGrid(context)
                      .animate()
                      .fadeIn(delay: 160.ms, duration: 450.ms)
                      .slideY(begin: 0.08, curve: Curves.easeOutCubic),
                  const SizedBox(height: 18),

                  // Campus Passport CTA Banner
                  _buildPassportCTA(context)
                      .animate()
                      .fadeIn(delay: 240.ms, duration: 450.ms)
                      .slideY(begin: 0.08, curve: Curves.easeOutCubic),
                  const SizedBox(height: 18),

                  // Career & Placements Hub Card (Door A)
                  _buildCareerHubCard(context)
                      .animate()
                      .fadeIn(delay: 280.ms, duration: 450.ms)
                      .slideY(begin: 0.08, curve: Curves.easeOutCubic),
                  const SizedBox(height: 26),

                  // Quick Actions (2 rows x 4 items)
                  _buildQuickActions(context)
                      .animate()
                      .fadeIn(delay: 320.ms, duration: 450.ms)
                      .slideY(begin: 0.08, curve: Curves.easeOutCubic),
                  const SizedBox(height: 26),

                  // Recent Activity
                  _buildRecentActivitySection(context)
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 450.ms)
                      .slideY(begin: 0.08, curve: Curves.easeOutCubic),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartupHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning,'
        : hour < 17
            ? 'Good afternoon,'
            : 'Good evening,';

    final displayName = (user?.name != null && user!.name.trim().isNotEmpty)
        ? user!.name.trim().split(' ')[0]
        : 'Sourav';

    final avatarLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: Greeting + Bold Name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.6,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Right: Search Button + Notification Bell + Avatar with Online Dot
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search Button
            AppleBounceable(
              scaleFactor: 0.90,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GlobalSearchScreen(
                      userId: user?.id ?? '',
                    ),
                  ),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1E2130) : Colors.white,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.search_rounded,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  size: 21,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Career & Placements Quick Action Button
            AppleBounceable(
              scaleFactor: 0.90,
              onTap: () {
                AppHaptics.selectionClick();
                Navigator.pushNamed(context, AppRoutes.careerHub);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1E2130) : Colors.white,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.work_outline_rounded,
                  color: Color(0xFF10B981),
                  size: 21,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Notification Bell with Badge
            FutureBuilder<int>(
              future: user?.id != null
                  ? ExpansionApiService.instance.getUnreadCount(user!.id)
                  : Future.value(0),
              builder: (context, snapshot) {
                final unread = snapshot.data ?? 0;
                return AppleBounceable(
                  scaleFactor: 0.90,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NotificationsCenterScreen(
                          userId: user?.id ?? '',
                        ),
                      ),
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF1E2130) : Colors.white,
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.10)
                                : Colors.black.withValues(alpha: 0.05),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.25 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.notifications_none_rounded,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          size: 21,
                        ),
                      ),
                      if (unread > 0)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF1E2130)
                                    : Colors.white,
                                width: 1.5,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(width: 10),

            // Avatar with Online Badge
            AppleBounceable(
              scaleFactor: 0.90,
              onTap: () => onNavigateToTab(3), // Navigate to Profile
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF4338CA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        avatarLetter,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    // Green Online Badge on bottom right of avatar
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF0C0C14) : Colors.white,
                            width: 2.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  int _calculateStreak() {
    if (attendanceAnalytics != null && attendanceAnalytics!['streak'] != null) {
      final s = (attendanceAnalytics!['streak'] as num).toInt();
      if (s > 0) return s;
    }
    if (recentAttendance.isNotEmpty) {
      int s = 0;
      for (final att in recentAttendance) {
        if (att.status.toLowerCase() == 'present') {
          s++;
        } else {
          break;
        }
      }
      if (s > 0) return s;
    }
    final attended = (attendanceAnalytics?['attendedClasses'] as num?)?.toInt() ?? 0;
    if (attended > 0) {
      return math.min(attended, 3);
    }
    return 0;
  }

  Map<String, String> _getNextClassInfo() {
    final subjects = SyllabusData.getSubjects(user?.course, user?.branch, user?.year);
    final safeSubjects = subjects.isNotEmpty
        ? subjects
        : ['Algorithms', 'DBMS', 'Operating Systems', 'Computer Org', 'Java Programming'];

    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final weekday = now.weekday;

    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      return {
        'name': safeSubjects.first,
        'timing': 'Mon · 09:00 AM',
        'room': 'Room 204',
      };
    }

    if (hour < 9) {
      return {
        'name': safeSubjects.first,
        'timing': 'Today · 09:00 AM',
        'room': 'Room 204',
      };
    } else if (hour < 10) {
      return {
        'name': safeSubjects.first,
        'timing': 'Happening Now',
        'room': 'Room 204',
      };
    } else if (hour < 11 || (hour == 11 && minute < 15)) {
      final sub = safeSubjects.length > 1 ? safeSubjects[1] : safeSubjects[0];
      return {
        'name': sub,
        'timing': 'Today · 10:15 AM',
        'room': 'Room 301',
      };
    } else if (hour < 12 || (hour == 12 && minute < 30)) {
      final sub = safeSubjects.length > 2 ? safeSubjects[2] : safeSubjects[0];
      return {
        'name': sub,
        'timing': 'Today · 11:30 AM',
        'room': 'Lab 2',
      };
    } else if (hour < 14 || (hour == 14 && minute < 30)) {
      final sub = safeSubjects.length > 3 ? safeSubjects[3] : safeSubjects[0];
      return {
        'name': sub,
        'timing': 'Today · 01:30 PM',
        'room': 'Room 205',
      };
    } else if (hour < 16) {
      final sub = safeSubjects.length > 4 ? safeSubjects[4] : safeSubjects[0];
      return {
        'name': sub,
        'timing': 'Today · 02:45 PM',
        'room': 'Lab 4',
      };
    } else {
      return {
        'name': safeSubjects.first,
        'timing': 'Tomorrow · 09:00 AM',
        'room': 'Room 204',
      };
    }
  }

  Widget _buildBentoGrid(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final streak = _calculateStreak();
    final nextClass = _getNextClassInfo();

    final nextClassTiming = nextClass['timing'] ?? '09:00 AM';
    String displayTime = "09:00";
    String displayAmPm = "AM";
    if (nextClassTiming.contains(':')) {
      final parts = nextClassTiming.split(' ');
      for (final part in parts) {
        if (part.contains(':')) displayTime = part;
        if (part.toUpperCase() == 'AM' || part.toUpperCase() == 'PM') {
          displayAmPm = part.toUpperCase();
        }
      }
    }

    final String dayName = DateFormat('EEEE').format(DateTime.now());

    return Row(
      children: [
        // --- Streak Card ---
        Expanded(
          child: AppleContextMenu(
            actions: [
              AppleContextMenuItem(
                title: "Streak Analytics",
                icon: Icons.local_fire_department_outlined,
                onTap: () {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        streak > 0
                            ? "Attendance Streak: $streak consecutive days! Keep going to maintain >75%."
                            : "No active streak. Attend consecutive classes to build your attendance streak!",
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: const Color(0xFF1E1B4B),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
              ),
              AppleContextMenuItem(
                title: "Attendance Tips",
                icon: Icons.tips_and_updates_outlined,
                onTap: () => _showStreakTipsSheet(context),
              ),
            ],
            onTap: () {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    streak > 0
                        ? "Attendance Streak: $streak consecutive days! Keep going to maintain >75%."
                        : "No active streak. Attend consecutive classes to build your attendance streak!",
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: const Color(0xFF1E1B4B),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161622) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : const Color(0xFF6366F1).withValues(alpha: 0.06),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top: Flame icon + Streak text
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2E201B)
                              : const Color(0xFFFFF3EB),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFEA580C),
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Streak",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Middle: Value (e.g. 0 days)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "$streak",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        streak == 1 ? "day" : "days",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF64748B),
                        ),
                      ),
                      if (streak > 0)
                        SizedBox(
                          width: 0,
                          height: 0,
                          child: Opacity(
                            opacity: 0.0,
                            child: Text("$streak Days"),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 7-segment dash bar with Apple Fitness progressive fill
                  Row(
                    children: List.generate(7, (index) {
                      final isActive = index < streak;
                      final trackColor = isDark
                          ? const Color(0xFF2A2322)
                          : const Color(0xFFFFEDD5);
                      const activeColor = Color(0xFFEA580C);
                      final isReduced =
                          MediaQuery.maybeDisableAnimationsOf(context) ?? false;

                      return Expanded(
                        child: Container(
                          height: 4.5,
                          margin: EdgeInsets.only(
                            right: index < 6 ? 4.0 : 0.0,
                          ),
                          decoration: BoxDecoration(
                            color: trackColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: isActive
                              ? (isReduced
                                  ? Container(
                                      decoration: BoxDecoration(
                                        color: activeColor,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    )
                                  : TweenAnimationBuilder<double>(
                                      tween: Tween<double>(begin: 0.0, end: 1.0),
                                      duration: Duration(
                                          milliseconds: 280 + (index * 60)),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, fill, _) {
                                        return FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: fill,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: activeColor,
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                          ),
                                        );
                                      },
                                    ))
                              : const SizedBox.shrink(),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 10),

                  // Subtext
                  Text(
                    streak > 0 ? "🔥 In a row" : "Attend class today",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.white60
                          : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 14),

        // --- Next class Card with Apple HIG Continuous Expansion ---
        Expanded(
          child: Builder(
            builder: (context) {
              final nextClassExpansionKey = StudentHomeContent.nextClassExpansionKey;

              return AppleContinuousExpansionCard(
                key: nextClassExpansionKey,
                cardRadius: 24,
                expandedBuilder: (ctx, dismiss) => AppleNextClassExpandedView(
                  nextClass: nextClass,
                  onDismiss: dismiss,
                  onOpenTimetable: () {
                    dismiss();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TimetableScreen(),
                      ),
                    );
                  },
                ),
                child: AppleContextMenu(
                  actions: [
                    AppleContextMenuItem(
                      title: "Class Details",
                      icon: Icons.fullscreen_rounded,
                      onTap: () => nextClassExpansionKey.currentState?.open(),
                    ),
                    AppleContextMenuItem(
                      title: "Open Timetable",
                      icon: Icons.calendar_month_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TimetableScreen(),
                          ),
                        );
                      },
                    ),
                    AppleContextMenuItem(
                      title: "Room Guidance",
                      icon: Icons.navigation_outlined,
                      onTap: () {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Directions: ${nextClass['room'] ?? 'Room 204'} · Academic Block B",
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: const Color(0xFF1E1B4B),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                  ],
                  onTap: () => nextClassExpansionKey.currentState?.open(),
                  child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161622) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : const Color(0xFF6366F1).withValues(alpha: 0.06),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top: Clock icon + Next class + Chevron
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1B2438)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.access_time_rounded,
                          color: Color(0xFF2563EB),
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Next Class",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(
                        width: 0,
                        height: 0,
                        child: Opacity(
                          opacity: 0.0,
                          child: Text("TIMETABLE"),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF94A3B8),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Middle: Time (e.g. 09:00 AM)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        displayTime,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        displayAmPm,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Subject Name
                  Text(
                    nextClass['name'] ?? "Algorithms",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 3),

                  // Day
                  Text(
                    dayName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.white60
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  ),
],
);
  }

  Widget _buildCareerHubCard(BuildContext context) {
    return AppleBounceable(
      scaleFactor: 0.98,
      onTap: () {
        AppHaptics.selectionClick();
        Navigator.pushNamed(context, AppRoutes.careerHub);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF334155),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.40),
                  width: 1.0,
                ),
              ),
              child: const Icon(
                Icons.work_outline_rounded,
                color: Color(0xFF34D399),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "Career & Placements",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "NEW",
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF34D399),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "Campus drives, tech jobs & AI resume review",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassportCTA(BuildContext context) {
    final isReduced =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    Widget cta = AppleBounceable(
      scaleFactor: 0.98,
      onTap: () => onNavigateToTab(1), // Passport tab
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF4338CA),
              Color(0xFF4F46E5),
              Color(0xFF6366F1),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.30),
                  width: 1.0,
                ),
              ),
              child: const Icon(
                Icons.badge_outlined,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Campus Passport",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "View your digital credential",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );

    if (!isReduced) {
      cta = cta
          .animate()
          .shimmer(
            delay: 450.ms,
            duration: 1100.ms,
            color: Colors.white.withValues(alpha: 0.18),
            angle: 45,
          );
    }

    return cta;
  }

  Widget _buildQuickActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Actions",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161622) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : const Color(0xFF6366F1).withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Row 1: Leave, Gate Pass, Complaint, Notices
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickActionItem(
                    context: context,
                    index: 0,
                    title: "Leave",
                    icon: Icons.calendar_month_rounded,
                    isDark: isDark,
                    onTap: () => onNavigateToTab(2, requestTab: 0, requestSubTab: 0),
                  ),
                  _buildQuickActionItem(
                    context: context,
                    index: 1,
                    title: "Gate Pass",
                    icon: Icons.door_front_door_outlined,
                    isDark: isDark,
                    onTap: () => onNavigateToTab(2, requestTab: 0, requestSubTab: 1),
                  ),
                  _buildQuickActionItem(
                    context: context,
                    index: 2,
                    title: "Complaint",
                    icon: Icons.warning_amber_rounded,
                    isDark: isDark,
                    onTap: () => onNavigateToTab(2, requestTab: 4),
                  ),
                  _buildQuickActionItem(
                    context: context,
                    index: 3,
                    title: "Notices",
                    icon: Icons.campaign_rounded,
                    isDark: isDark,
                    onTap: () => onNavigateToTab(2, requestTab: 5),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Row 2: Timetable, Mess, Mesh Chat, AirDrop
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickActionItem(
                    context: context,
                    index: 4,
                    title: "Timetable",
                    icon: Icons.calendar_today_rounded,
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TimetableScreen(),
                        ),
                      );
                    },
                  ),
                  _buildQuickActionItem(
                    context: context,
                    index: 5,
                    title: "Mess",
                    icon: Icons.restaurant_rounded,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.studentMess);
                    },
                  ),
                  _buildQuickActionItem(
                    context: context,
                    index: 6,
                    title: "Mesh Chat",
                    icon: Icons.chat_bubble_outline_rounded,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.meshChat);
                    },
                  ),
                  _buildQuickActionItem(
                    context: context,
                    index: 7,
                    title: "AirDrop",
                    icon: Icons.download_rounded,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.meshAirDrop);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required BuildContext context,
    required int index,
    required String title,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final isReduced =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // Curated 3D Apple-style volumetric gradients per action
    final List<List<Color>> action3dGradients = [
      [const Color(0xFF6366F1), const Color(0xFF4F46E5), const Color(0xFF3730A3)], // 0: Leave (Indigo)
      [const Color(0xFF38BDF8), const Color(0xFF0284C7), const Color(0xFF075985)], // 1: Gate Pass (Sky/Blue)
      [const Color(0xFFFBBF24), const Color(0xFFF59E0B), const Color(0xFFD97706)], // 2: Complaint (Amber)
      [const Color(0xFFA855F7), const Color(0xFF9333EA), const Color(0xFF7E22CE)], // 3: Notices (Purple)
      [const Color(0xFF2DD4BF), const Color(0xFF0D9488), const Color(0xFF115E59)], // 4: Timetable (Teal)
      [const Color(0xFFFB7185), const Color(0xFFE11D48), const Color(0xFF9F1239)], // 5: Mess (Rose/Coral)
      [const Color(0xFF34D399), const Color(0xFF059669), const Color(0xFF047857)], // 6: Mesh Chat (Emerald)
      [const Color(0xFF60A5FA), const Color(0xFF2563EB), const Color(0xFF1D4ED8)], // 7: AirDrop (Electric Blue)
    ];

    final List<Color> actionShadowGlows = [
      const Color(0xFF6366F1),
      const Color(0xFF0284C7),
      const Color(0xFFF59E0B),
      const Color(0xFF9333EA),
      const Color(0xFF0D9488),
      const Color(0xFFE11D48),
      const Color(0xFF059669),
      const Color(0xFF2563EB),
    ];

    final gradient = index < action3dGradients.length
        ? action3dGradients[index]
        : [const Color(0xFF6366F1), const Color(0xFF4F46E5), const Color(0xFF3730A3)];
    final glow = index < actionShadowGlows.length
        ? actionShadowGlows[index]
        : const Color(0xFF4F46E5);

    final item = AppleBounceable(
      scaleFactor: 0.90,
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 3D Volumetric Pod
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                boxShadow: [
                  // 1. Volumetric ambient colored 3D elevation glow
                  BoxShadow(
                    color: glow.withValues(alpha: isDark ? 0.38 : 0.26),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                  // 2. Physical contact shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 3D Specular Curved Glass Sheen
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 28,
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: isDark ? 0.32 : 0.42),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Tactile Rim Bevel Border
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white
                              .withValues(alpha: isDark ? 0.22 : 0.38),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),

                  // Floating Micro-Depth Disc
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),

                  // 3D Embossed Floating Glyph with drop shadow
                  Icon(
                    icon,
                    size: 26,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        offset: const Offset(0, 1.8),
                        blurRadius: 3.5,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                letterSpacing: -0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    if (isReduced) return item;

    return item
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 180 + (index * 32)),
          duration: 320.ms,
        )
        .scale(
          begin: const Offset(0.88, 0.88),
          end: const Offset(1.0, 1.0),
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildCampusMeshSection(BuildContext context) {
    return StudentEmergencySection(user: user);
  }

  Widget _buildRecentActivitySection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Recent Activity",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            AppleBounceable(
              scaleFactor: 0.94,
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.history);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  "See all",
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF4F46E5),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (loading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: CircularProgressIndicator(color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
            ),
          )
        else if (recentAttendance.isEmpty)
          _buildEmptyActivityState(context, isDark)
        else
          SizedBox(
            height: 84,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const AppleSpringScrollPhysics(),
              itemCount: recentAttendance.length,
              clipBehavior: Clip.none,
              itemBuilder: (context, index) {
                final record = recentAttendance[index];
                return _buildActivityCard(record, index, isDark);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyActivityState(BuildContext context, bool isDark) {
    final isReduced =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    Widget chartIcon = Icon(
      Icons.show_chart_rounded,
      size: 24,
      color: isDark ? Colors.white60 : const Color(0xFF64748B),
    );

    if (!isReduced) {
      chartIcon = chartIcon
          .animate()
          .fadeIn(duration: 400.ms)
          .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161622) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFF6366F1).withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFF222436)
                  : const Color(0xFFF1F5F9),
            ),
            child: chartIcon,
          ),
          const SizedBox(height: 14),
          Text(
            "No activity yet",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? Colors.white
                  : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Start your first class to see updates here.",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: isDark
                  ? Colors.white60
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(AttendanceModel record, int index, bool isDark) {
    return AppleBounceable(
      scaleFactor: 0.97,
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161622) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : const Color(0xFF6366F1).withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF222438)
                    : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.class_rounded,
                color: Color(0xFF4F46E5),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    record.sessionName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('MMM dd, hh:mm a').format(record.checkInTime),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttendancePolicySheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161622) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.policy_outlined,
                        color: Color(0xFF4F46E5), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Attendance Regulations",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                "Institutional rules require students to maintain a minimum of 75% attendance across all registered courses to appear in semester examinations.\n\n• Above 85%: Excellent standing.\n• 75% - 84%: Eligible for semester exams.\n• Below 75%: Low attendance warning. Medical or OD exemptions must be verified by Dean Academics.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Got it",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStreakTipsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161622) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_fire_department_rounded,
                        color: Color(0xFFEA580C), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Streak Guidelines",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                "Streaks represent your consecutive days of active classroom presence:\n\n1. Attend all scheduled lectures and labs for the day.\n2. Submit medical leaves before 10 AM to prevent streak forfeiture.\n3. Achieving a 14-day streak unlocks bonus campus privileges.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Understood",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Production-grade dismissible and swipable notification-style Academic Updates section
class TodaysAcademicUpdatesSection extends StatefulWidget {
  final UserModel? user;
  final ExpansionApiService? apiService;
  final List<ClassUpdateModel>? initialUpdates;

  const TodaysAcademicUpdatesSection({
    Key? key,
    required this.user,
    this.apiService,
    this.initialUpdates,
  }) : super(key: key);

  @override
  State<TodaysAcademicUpdatesSection> createState() => _TodaysAcademicUpdatesSectionState();
}

class _TodaysAcademicUpdatesSectionState extends State<TodaysAcademicUpdatesSection> {
  final Set<String> _dismissedIds = {};
  List<ClassUpdateModel>? _allUpdates;
  bool _isLoading = true;

  String get _storageKey => 'dismissed_academic_updates_${widget.user?.id ?? 'default'}';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.user?.id == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_storageKey) ?? [];
      _dismissedIds.addAll(saved);
    } catch (_) {}

    if (widget.initialUpdates != null) {
      if (mounted) {
        setState(() {
          _allUpdates = widget.initialUpdates;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final service = widget.apiService ?? ExpansionApiService.instance;
      final updates = await service.getMyClassUpdates(widget.user!.id);
      if (mounted) {
        setState(() {
          _allUpdates = updates;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _allUpdates = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _dismissUpdate(ClassUpdateModel update) async {
    AppHaptics.mediumImpact();
    setState(() {
      _dismissedIds.add(update.id);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, _dismissedIds.toList());
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${update.courseCode} update dismissed",
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          action: SnackBarAction(
            label: "UNDO",
            textColor: const Color(0xFF67E8F9),
            onPressed: () => _restoreUpdate(update.id),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _restoreUpdate(String updateId) async {
    setState(() {
      _dismissedIds.remove(updateId);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, _dismissedIds.toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user?.id == null) return const SizedBox.shrink();
    if (_isLoading) return const SizedBox.shrink();

    final visibleUpdates = (_allUpdates ?? [])
        .where((u) => !_dismissedIds.contains(u.id))
        .toList();

    return ListenableBuilder(
      listenable: LanguageProvider.instance,
      builder: (context, _) {
        final lang = LanguageProvider.instance.currentLanguage;

        if (visibleUpdates.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: Color(0xFF16A34A), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang == 'hi'
                        ? "आज सभी कक्षाएं और प्रयोगशालाएं समय पर हैं।"
                        : (lang == 'or'
                            ? "ଆଜି ସମସ୍ତ କ୍ଲାସ୍ ଓ ଲ୍ୟାବ୍ ନିର୍ଦ୍ଧାରିତ ସମୟରେ ଅଛି।"
                            : "All lectures and labs are on schedule today."),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ),
                if (_dismissedIds.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _dismissedIds.clear();
                      });
                      SharedPreferences.getInstance().then((p) => p.remove(_storageKey));
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        lang == 'hi' ? "पुनः देखें" : (lang == 'or' ? "ଦେଖନ୍ତୁ" : "Review"),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF16A34A),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_rounded,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Text(
                  AppStrings.tr('todays_academic_updates', lang: lang),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${visibleUpdates.length} ${visibleUpdates.length > 1 ? 'notices' : 'notice'}",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...visibleUpdates.map((update) => _buildDismissibleUpdateCard(update, lang)),
          ],
        );
      },
    );
  }

  Widget _buildDismissibleUpdateCard(ClassUpdateModel update, String lang) {
    Color bannerColor;
    Color badgeColor;
    IconData icon;
    String typeLabel = update.updateType;

    switch (update.updateType.toUpperCase()) {
      case 'CANCELLED':
        bannerColor = const Color(0xFFFEF2F2);
        badgeColor = AppColors.error;
        icon = Icons.cancel_outlined;
        typeLabel = lang == 'hi' ? "रद्द" : (lang == 'or' ? "ବାତିଲ୍" : "CANCELLED");
        break;
      case 'ROOM_CHANGED':
        bannerColor = const Color(0xFFFFFBEB);
        badgeColor = const Color(0xFFD97706);
        icon = Icons.meeting_room_outlined;
        typeLabel = lang == 'hi' ? "कमरा बदला" : (lang == 'or' ? "କୋଠରୀ ବଦଳିଛି" : "ROOM CHANGE");
        break;
      case 'RESCHEDULED':
        bannerColor = const Color(0xFFEFF6FF);
        badgeColor = const Color(0xFF2563EB);
        icon = Icons.schedule_rounded;
        typeLabel = lang == 'hi' ? "समय बदला" : (lang == 'or' ? "ସମୟ ବଦଳିଛି" : "RESCHEDULED");
        break;
      default:
        bannerColor = const Color(0xFFF5F3FF);
        badgeColor = AppColors.primary;
        icon = Icons.info_outline_rounded;
        typeLabel = lang == 'hi' ? "सूचना" : (lang == 'or' ? "ବିଜ୍ଞପ୍ତି" : "NOTICE");
    }

    return Dismissible(
      key: ValueKey('academic_update_${update.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: (direction) => _dismissUpdate(update),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              "Dismiss",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              "Dismiss",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.close_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bannerColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: badgeColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${update.courseCode} - ${update.courseName}",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          typeLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _dismissUpdate(update),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    update.message,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (update.newRoom != null || update.newTime != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (update.newRoom != null)
                          Text(
                            "New Room: ${update.newRoom}",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: badgeColor,
                            ),
                          ),
                        if (update.newRoom != null && update.newTime != null)
                          const Text(" • "),
                        if (update.newTime != null)
                          Text(
                            "New Time: ${update.newTime}",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: badgeColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.swipe_rounded, size: 11, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        "Swipe to dismiss",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentActiveSessionBanner extends StatefulWidget {
  final UserModel? user;
  final void Function(int) onNavigateToTab;

  const StudentActiveSessionBanner({
    Key? key,
    required this.user,
    required this.onNavigateToTab,
  }) : super(key: key);

  @override
  State<StudentActiveSessionBanner> createState() => _StudentActiveSessionBannerState();
}

class _StudentActiveSessionBannerState extends State<StudentActiveSessionBanner> {
  final SessionService _sessionService = SessionService();
  SessionModel? _activeSession;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkActiveSessions();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _checkActiveSessions());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkActiveSessions() async {
    if (!mounted) return;
    try {
      final sessions = await _sessionService.getActiveSessions(
        course: widget.user?.course,
        branch: widget.user?.branch,
        year: widget.user?.year,
      );
      if (mounted) {
        final now = DateTime.now();
        final valid = sessions.where((s) => s.isActive && s.endTime.isAfter(now)).toList();
        setState(() {
          _activeSession = valid.isNotEmpty ? valid.first : null;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final session = _activeSession;
    if (session == null) return const SizedBox.shrink();

    final now = DateTime.now();
    if (!session.isActive || session.endTime.isBefore(now)) {
      return const SizedBox.shrink();
    }

    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final isAttended = attendanceProvider.isSessionAttended(session.id);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "LIVE CLASS IN PROGRESS",
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF22C55E),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            session.name,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "${session.branch} · Year ${session.year} · ${session.location.isNotEmpty ? session.location : 'Campus'}",
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          if (isAttended)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF22C55E)),
                  const SizedBox(width: 8),
                  Text(
                    "Attendance Verified",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  AppHaptics.mediumImpact();
                  widget.onNavigateToTab(1); // Open Passport tab
                },
                icon: const Icon(Icons.badge_rounded, size: 18, color: Colors.white),
                label: Text(
                  "Open Passport to Check In",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
