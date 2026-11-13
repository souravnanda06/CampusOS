import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';
import '../../shared/providers/attendance_provider.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../shared/models/attendance_model.dart';
import '../widgets/student_home_content.dart';
import 'passport_screen.dart';
import 'requests_screen.dart';
import 'profile_screen.dart';
import '../../core/localization/language_provider.dart';
import '../../core/localization/app_strings.dart';
import '../../shared/widgets/dock/app_dock.dart';
import '../../shared/widgets/copilot/copilot_sheet.dart';
import '../../core/mesh/campus_mesh_manager.dart';


class StudentShellScreen extends StatefulWidget {
  final UserModel? user;
  final double overallAttendance;
  final List<AttendanceModel> recentAttendance;
  final Map<String, dynamic>? attendanceAnalytics;
  final bool loading;

  const StudentShellScreen({
    Key? key,
    required this.user,
    required this.overallAttendance,
    required this.recentAttendance,
    this.attendanceAnalytics,
    required this.loading,
  }) : super(key: key);

  @override
  State<StudentShellScreen> createState() => _StudentShellScreenState();
}

class _StudentShellScreenState extends State<StudentShellScreen> {
  int _currentIndex = 0;
  final ValueNotifier<bool> _passportFullScreen = ValueNotifier<bool>(false);
  final GlobalKey<RequestsScreenState> _requestsKey = GlobalKey<RequestsScreenState>();

  @override
  void initState() {
    super.initState();
    CampusMeshManager.instance.initialize(user: widget.user);
  }

  @override
  void dispose() {
    _passportFullScreen.dispose();
    super.dispose();
  }


  void _onNavigateToTab(int index, {int? requestTab, int? requestSubTab}) {
    AppHaptics.selectionClick();
    setState(() {
      _currentIndex = index;
    });
    if (index == 0) {
      try {
        context
            .read<AttendanceProvider>()
            .refreshAttendance(studentId: widget.user?.id);
      } catch (_) {}
    }
    if (index == 2 && requestTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestsKey.currentState?.setTab(requestTab, subTab: requestSubTab ?? 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LanguageProvider.instance,
        ThemeProvider.instance,
      ]),
      builder: (context, _) {
        final lang = LanguageProvider.instance.currentLanguage;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return ValueListenableBuilder<bool>(
          valueListenable: _passportFullScreen,
          builder: (context, isPassportFullScreen, child) {
            return Scaffold(
              key: ValueKey('student_shell_$lang'),
              backgroundColor: isPassportFullScreen ? Colors.black : (isDark ? AppColors.bgDark : AppColors.bg),
              extendBody: true,
              body: RepaintBoundary(
                child: IndexedStack(
                  key: ValueKey('student_stack_$lang'),
                  index: _currentIndex,
                  children: [
                    RepaintBoundary(
                      child: Builder(
                        builder: (context) {
                          AttendanceProvider? attendance;
                          try {
                            attendance = Provider.of<AttendanceProvider>(context);
                          } catch (_) {
                            attendance = null;
                          }
                          final useLive = attendance != null && attendance.hasData;
                          return StudentHomeContent(
                            key: ValueKey('student_home_$lang'),
                            user: widget.user,
                            overallAttendance: useLive
                                ? attendance.overallAttendance
                                : widget.overallAttendance,
                            recentAttendance: useLive
                                ? attendance.recentAttendance
                                : widget.recentAttendance,
                            attendanceAnalytics: useLive
                                ? (attendance.attendanceAnalytics ??
                                    widget.attendanceAnalytics)
                                : widget.attendanceAnalytics,
                            loading: widget.loading,
                            onNavigateToTab: _onNavigateToTab,
                          );
                        },
                      ),
                    ),
                    RepaintBoundary(
                      child: PassportScreen(
                        key: ValueKey('passport_$lang'),
                        user: widget.user,
                        isFullScreenActive: _passportFullScreen,
                        isActiveTab: _currentIndex == 1,
                      ),
                    ),
                    RepaintBoundary(
                      child: RequestsScreen(
                        key: _requestsKey,
                      ),
                    ),
                    RepaintBoundary(
                      child: ProfileScreen(
                        key: ValueKey('profile_$lang'),
                        user: widget.user,
                        onNavigateToTab: _onNavigateToTab,
                      ),
                    ),
                  ],
                ),
              ),
          bottomNavigationBar: AnimatedSlide(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            offset: isPassportFullScreen ? const Offset(0, 1.2) : Offset.zero,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              opacity: isPassportFullScreen ? 0.0 : 1.0,
              child: IgnorePointer(
                ignoring: isPassportFullScreen,
                child: RepaintBoundary(
                  child: AppDock(
                    currentIndex: _currentIndex,
                    onTap: (index) => _onNavigateToTab(index),
                    centerAction: AppDockCenterAction(
                      buttonKey: const Key('campus_ai_dock_student'),
                      label: 'Campus AI',
                      onTap: () => CopilotSheet.show(
                        context,
                        user: widget.user,
                        role: 'student',
                        screenContext: 'student_tab_$_currentIndex',
                      ),
                    ),
                    items: [
                      AppDockItem(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                        label: AppStrings.tr('home', lang: lang),
                      ),
                      AppDockItem(
                        icon: Icons.account_balance_wallet_outlined,
                        activeIcon: Icons.account_balance_wallet_rounded,
                        label: AppStrings.tr('wallet', lang: lang),
                      ),
                      AppDockItem(
                        icon: Icons.inbox_outlined,
                        activeIcon: Icons.inbox_rounded,
                        label: AppStrings.tr('requests', lang: lang),
                      ),
                      AppDockItem(
                        icon: Icons.person_outline_rounded,
                        activeIcon: Icons.person_rounded,
                        label: AppStrings.tr('profile', lang: lang),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  },
);
  }
}
