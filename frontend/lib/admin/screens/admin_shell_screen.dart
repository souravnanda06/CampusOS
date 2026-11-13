import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/admin_home_content.dart';
import 'admin_operations_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_profile_screen.dart';
import '../../shared/widgets/dock/app_dock.dart';
import '../../shared/widgets/copilot/copilot_sheet.dart';
import '../../core/localization/language_provider.dart';
import '../../core/localization/app_strings.dart';

/// CampusOS Admin Shell with Apple-grade 4-Item Navigation Dock.
///
/// Exactly 4 primary destinations:
/// 1. Home (Command Center, Critical Issues, Quick Actions, Recent Activity)
/// 2. Operations (Complaints, Notices, Mess, Attendance, Security, Passport)
/// 3. Analytics (Resolution metrics, Ageing brackets, Deterministic recurring issues, Workload)
/// 4. Profile (Admin Identity, Department, Security status & Logout)
class AdminShellScreen extends StatefulWidget {
  final UserModel? user;
  final int initialIndex;

  const AdminShellScreen({
    Key? key,
    this.user,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
  }

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
          key: ValueKey('admin_shell_$lang'),
          backgroundColor: AppColors.bg,
          extendBody: true,
          body: RepaintBoundary(
            child: IndexedStack(
              key: ValueKey('admin_stack_$lang'),
              index: _currentIndex,
              children: [
                RepaintBoundary(
                  child: AdminHomeContent(
                    key: ValueKey('admin_home_$lang'),
                    user: widget.user,
                    onNavigateToTab: _onNavigateToTab,
                  ),
                ),
                RepaintBoundary(
                  child: AdminOperationsScreen(
                    key: ValueKey('admin_operations_$lang'),
                    user: widget.user,
                  ),
                ),
                RepaintBoundary(
                  child: AdminAnalyticsScreen(
                    key: ValueKey('admin_analytics_$lang'),
                    user: widget.user,
                  ),
                ),
                RepaintBoundary(
                  child: AdminProfileScreen(
                    key: ValueKey('admin_profile_$lang'),
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
                buttonKey: const Key('campus_ai_dock_admin'),
                label: 'Campus AI',
                onTap: () => CopilotSheet.show(
                  context,
                  user: widget.user,
                  role: 'admin',
                  screenContext: 'admin_tab_$_currentIndex',
                ),
              ),
              items: [
                AppDockItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: AppStrings.tr('home', lang: lang),
                ),
                AppDockItem(
                  icon: Icons.widgets_outlined,
                  activeIcon: Icons.widgets_rounded,
                  label: AppStrings.tr('operations', lang: lang),
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
