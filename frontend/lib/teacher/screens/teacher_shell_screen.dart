import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/session_model.dart';
import '../widgets/teacher_home_content.dart';
import 'teacher_classes_screen.dart';
import 'teacher_analytics_screen.dart';
import 'teacher_profile_screen.dart';
import '../../shared/widgets/dock/app_dock.dart';
import '../../shared/widgets/copilot/copilot_sheet.dart';
import '../../core/localization/language_provider.dart';
import '../../core/localization/app_strings.dart';

/// CampusOS Teacher Shell with Apple-grade 4-Item Navigation Dock.
///
/// Exactly 4 primary destinations:
/// 1. Home (One-tap attendance launchpad, quick-start hero, recent sessions)
/// 2. Classes (Assigned subjects, class detail, schedule presets)
/// 3. Analytics (Roster attendance trends, student stats, device reset, export)
/// 4. Profile (Teacher identity, department, credentials, security & logout)
///
/// NOTE: The Live Attendance Command Center is an intentional full-screen workflow
/// launched from Home or Classes, NOT a navigation dock tab.
class TeacherShellScreen extends StatefulWidget {
  final UserModel? user;
  final List<SessionModel> activeSessions;
  final VoidCallback onRefreshSessions;

  const TeacherShellScreen({
    Key? key,
    required this.user,
    required this.activeSessions,
    required this.onRefreshSessions,
  }) : super(key: key);

  @override
  State<TeacherShellScreen> createState() => _TeacherShellScreenState();
}

class _TeacherShellScreenState extends State<TeacherShellScreen> {
  int _currentIndex = 0;

  void _onNavigateToTab(int index) {
    if (index >= 0 && index < 4 && _currentIndex != index) {
      AppHaptics.selectionClick();
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageProvider.instance,
      builder: (context, _) {
        final lang = LanguageProvider.instance.currentLanguage;
        return Scaffold(
          key: ValueKey('teacher_shell_$lang'),
          backgroundColor: AppColors.bg,
          extendBody: true,
          body: RepaintBoundary(
            child: IndexedStack(
              key: ValueKey('teacher_stack_$lang'),
              index: _currentIndex,
              children: [
                RepaintBoundary(
                  child: TeacherHomeContent(
                    key: ValueKey('teacher_home_$lang'),
                    user: widget.user,
                    activeSessions: widget.activeSessions,
                    onRefreshSessions: widget.onRefreshSessions,
                    onNavigateToTab: _onNavigateToTab,
                  ),
                ),
                RepaintBoundary(
                  child: TeacherClassesScreen(
                    key: ValueKey('teacher_classes_$lang'),
                    user: widget.user,
                  ),
                ),
                RepaintBoundary(
                  child: TeacherAnalyticsScreen(
                    key: ValueKey('teacher_analytics_$lang'),
                  ),
                ),
                RepaintBoundary(
                  child: TeacherProfileScreen(
                    key: ValueKey('teacher_profile_$lang'),
                    user: widget.user,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: RepaintBoundary(
            child: AppDock(
              currentIndex: _currentIndex,
              onTap: (index) => _onNavigateToTab(index),
              centerAction: AppDockCenterAction(
                buttonKey: const Key('campus_ai_dock_teacher'),
                label: 'Campus AI',
                onTap: () => CopilotSheet.show(
                  context,
                  user: widget.user,
                  role: 'teacher',
                  screenContext: 'teacher_tab_$_currentIndex',
                ),
              ),
              items: [
                AppDockItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: AppStrings.tr('home', lang: lang),
                ),
                AppDockItem(
                  icon: Icons.calendar_today_outlined,
                  activeIcon: Icons.calendar_today_rounded,
                  label: AppStrings.tr('classes', lang: lang),
                ),
                AppDockItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart_rounded,
                  label: AppStrings.tr('analytics', lang: lang),
                ),
                AppDockItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: AppStrings.tr('profile', lang: lang),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
