import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

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
import '../../core/localization/app_localizations.dart';
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

class StudentHomeContent extends StatelessWidget {
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
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStartupHeader(context),
            const SizedBox(height: 16),
            _buildCampusMeshSection(context),
            StudentActiveSessionBanner(
              user: user,
              onNavigateToTab: (index) => onNavigateToTab(index),
            ),
            const SizedBox(height: 24),
            AttendanceCard(
              user: user,
              overallAttendance: overallAttendance,
              attendanceAnalytics: attendanceAnalytics,
              onNavigateToTab: (index) => onNavigateToTab(index),
            ),
            const SizedBox(height: 24),
            TodaysAcademicUpdatesSection(user: user),
            const SizedBox(height: 24),
            _buildBentoGrid(context),
            const SizedBox(height: 24),
            _buildPassportCTA(context),
            const SizedBox(height: 24),
            _buildQuickActions(context),
            const SizedBox(height: 24),
            _buildRecentActivitySection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStartupHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListenableBuilder(
                listenable: LanguageProvider.instance,
                builder: (context, _) {
                  final lang = LanguageProvider.instance.currentLanguage;
                  final hour = DateTime.now().hour;
                  final greeting = hour < 12
                      ? (lang == 'hi' ? 'सुप्रभात,' : (lang == 'or' ? 'ଶୁଭ ସକାଳ,' : (lang == 'bn' ? 'সুপ্রভাত,' : 'Good Morning,')))
                      : hour < 17
                          ? (lang == 'hi' ? 'शुभ दोपहर,' : (lang == 'or' ? 'ଶୁଭ ଅପରାହ୍ନ,' : (lang == 'bn' ? 'শুভ অপরাহ্ন,' : 'Good Afternoon,')))
                          : (lang == 'hi' ? 'शुभ संध्या,' : (lang == 'or' ? 'ଶୁଭ ସନ୍ଧ୍ୟା,' : (lang == 'bn' ? 'শুভ সন্ধ্যা,' : 'Good Evening,')));
                  return Text(
                    greeting,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(
                user?.name.split(' ')[0] ?? 'Student',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Online",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: "Search Campus",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GlobalSearchScreen(
                      userId: user?.id ?? '',
                    ),
                  ),
                );
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.search_rounded,
                    color: AppColors.textPrimary, size: 20),
              ),
            ),
            FutureBuilder<int>(
              future: user?.id != null
                  ? ExpansionApiService.instance.getUnreadCount(user!.id)
                  : Future.value(0),
              builder: (context, snapshot) {
                final unread = snapshot.data ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: "Notifications",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NotificationsCenterScreen(
                              userId: user?.id ?? '',
                            ),
                          ),
                        );
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.notifications_outlined,
                            color: AppColors.textPrimary, size: 20),
                      ),
                    ),
                    if (unread > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            IconButton(
              tooltip: "Campus Mesh Network",
              onPressed: () {
                AppHaptics.lightImpact();
                Navigator.pushNamed(context, AppRoutes.meshHub);
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.hub_rounded,
                    color: Color(0xFF6366F1), size: 20),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => onNavigateToTab(3), // Navigate to Profile (tab 3)
              borderRadius: BorderRadius.circular(32),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight,
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1)),
                ),
                alignment: Alignment.center,
                child: Text(
                  user?.name.isNotEmpty == true
                      ? user!.name[0].toUpperCase()
                      : 'S',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
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
    final weekday = now.weekday; // 1 = Monday ... 7 = Sunday

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
    final streak = _calculateStreak();
    final streakText = streak > 0 ? "$streak ${streak == 1 ? 'Day'.tr(context) : 'Days'.tr(context)}" : "0 ${'Days'.tr(context)}";
    final inARowTranslated = "In a row".tr(context);
    final streakSubtitle = streak > 0
        ? (LanguageProvider.instance.currentLanguage == 'en' ? "🔥 In a row" : "🔥 $inARowTranslated")
        : "Attend class today".tr(context);

    final nextClass = _getNextClassInfo();

    return Row(
      children: [
        Expanded(
          child: _buildBentoCard(
            title: "Streak".tr(context),
            value: streakText,
            subtitle: streakSubtitle,
            icon: streak > 0 ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
            iconColor: AppColors.warning,
            onTap: () {
              AppHaptics.lightImpact();
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          streak > 0
                              ? "Attendance Streak: $streak consecutive days! Keep going to maintain >75%."
                              : "No active streak. Attend consecutive classes to build your attendance streak!",
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF1E1B4B),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildBentoCard(
            title: "Next Class".tr(context),
            value: nextClass['name'] ?? "No class".tr(context),
            subtitle: nextClass['timing'] ?? "Tap to view timetable".tr(context),
            icon: Icons.schedule_rounded,
            iconColor: AppColors.info,
            badge: "TIMETABLE",
            onTap: () {
              AppHaptics.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TimetableScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBentoCard({
    required String title,
    required String value,
    String? subtitle,
    String? badge,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.10),
              blurRadius: 24,
              spreadRadius: 0,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          badge,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: iconColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_forward_ios_rounded, size: 8, color: iconColor),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E1B4B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPassportCTA(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.lightImpact();
        onNavigateToTab(1); // Passport tab
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.badge_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Campus Passport".tr(context),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "View your digital credential".tr(context),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Actions".tr(context),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionTile(
                title: "Leave".tr(context),
                subtitle: "Request leave".tr(context),
                icon: Icons.event_busy_rounded,
                onTap: () => onNavigateToTab(2, requestTab: 0, requestSubTab: 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionTile(
                title: "Gate Pass".tr(context),
                subtitle: "Campus exit pass".tr(context),
                icon: Icons.door_sliding_rounded,
                onTap: () => onNavigateToTab(2, requestTab: 0, requestSubTab: 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionTile(
                title: "Complaint".tr(context),
                subtitle: "Report an issue".tr(context),
                icon: Icons.report_problem_rounded,
                onTap: () => onNavigateToTab(2, requestTab: 4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionTile(
                title: "Notices".tr(context),
                subtitle: "Campus updates".tr(context),
                icon: Icons.campaign_rounded,
                onTap: () => onNavigateToTab(2, requestTab: 5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionTile(
                title: "Timetable".tr(context),
                subtitle: "Class schedule".tr(context),
                icon: Icons.calendar_month_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TimetableScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionTile(
                title: "Mess".tr(context),
                subtitle: "Daily meals".tr(context),
                icon: Icons.restaurant_menu_rounded,
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.studentMess);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionTile(
                title: "Mesh Chat",
                subtitle: "Offline P2P",
                icon: Icons.chat_bubble_outline_rounded,
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.meshChat);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionTile(
                title: "AirDrop",
                subtitle: "P2P Files",
                icon: Icons.file_download_outlined,
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.meshAirDrop);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCampusMeshSection(BuildContext context) {
    return const SizedBox.shrink();
  }

  // ignore: unused_element
  Widget _buildCampusMeshSectionOld(BuildContext context) {
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
                        "Decentralized BLE 5 · Zero Cellular Needed",
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
                child: _buildMeshActionButton(
                  context: context,
                  isDark: isDark,
                  label: "P2P Chat",
                  sublabel: "M3 Offline",
                  icon: Icons.chat_bubble_outline_rounded,
                  color: const Color(0xFF3B82F6),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.meshChat),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMeshActionButton(
                  context: context,
                  isDark: isDark,
                  label: "AirDrop",
                  sublabel: "M5 File Share",
                  icon: Icons.file_download_outlined,
                  color: const Color(0xFF10B981),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.meshAirDrop),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMeshActionButton(
                  context: context,
                  isDark: isDark,
                  label: "Flare",
                  sublabel: "M4 Emergency",
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFEF4444),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.meshEmergency),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMeshActionButton(
                  context: context,
                  isDark: isDark,
                  label: "Radar",
                  sublabel: "M7 Visual",
                  icon: Icons.radar_rounded,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.meshRadar),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              AppHaptics.lightImpact();
              Navigator.pushNamed(context, AppRoutes.meshSimulator);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B1F2E) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF283045) : const Color(0xFFCBD5E1),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline_rounded, size: 16, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Launch M7 Stage Simulator & 60s Demo",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF3730A3),
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF6366F1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeshActionButton({
    required BuildContext context,
    required bool isDark,
    required String label,
    required String sublabel,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        AppHaptics.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A202E) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            Text(
              sublabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        AppHaptics.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.10),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E1B4B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent Activity",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.history);
              },
              child: Text(
                "See All",
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (loading)
          const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
        else if (recentAttendance.isEmpty)
          _buildEmptyActivityState()
        else
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: recentAttendance.length,
              clipBehavior: Clip.none,
              itemBuilder: (context, index) {
                final record = recentAttendance[index];
                return _buildActivityCard(record, index);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyActivityState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.history_edu_rounded,
              size: 40, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            "No activity yet",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Start your first class to see updates here.",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(AttendanceModel record, int index) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.class_rounded,
              color: AppColors.primary,
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
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, hh:mm a').format(record.checkInTime),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
