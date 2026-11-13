import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import 'warden_home_screen.dart';
import 'warden_leave_requests_screen.dart';
import 'warden_activity_screen.dart';
import 'warden_profile_screen.dart';
import '../../shared/widgets/dock/app_dock.dart';
import '../../core/localization/language_provider.dart';
import '../../core/localization/app_localizations.dart';

/// CampusOS Warden Shell with Apple-grade 4-Destination Navigation Dock.
///
/// Exactly 4 primary destinations:
/// 1. Home (Warden Command Center, Live metrics, Pending preview)
/// 2. Requests (Pending, Approved, Rejected tabs, Search, Quick action)
/// 3. Activity (Leave and Gate Pass transit audit log)
/// 4. Profile (Warden institutional identity, authority info, Sign out)
class WardenShellScreen extends StatefulWidget {
  final UserModel? user;
  final int initialIndex;

  const WardenShellScreen({
    Key? key,
    required this.user,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<WardenShellScreen> createState() => _WardenShellScreenState();
}

class _WardenShellScreenState extends State<WardenShellScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onNavigateToTab(int index) {
    if (index >= 0 && index < 4 && index != _currentIndex) {
      AppHaptics.selectionClick();
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUser = widget.user ??
        UserModel(
          id: 'warden_officer',
          email: 'warden@campusos.edu',
          name: 'Chief Warden',
          role: 'warden',
        );

    return ListenableBuilder(
      listenable: LanguageProvider.instance,
      builder: (context, _) {
        final lang = LanguageProvider.instance.currentLanguage;
        return Scaffold(
          key: ValueKey('warden_shell_$lang'),
          backgroundColor: AppColors.bg,
          extendBody: true,
          body: RepaintBoundary(
            child: IndexedStack(
              key: ValueKey('warden_stack_$lang'),
              index: _currentIndex,
              children: [
                RepaintBoundary(
                  child: WardenHomeScreen(
                    key: ValueKey('warden_home_$lang'),
                    user: effectiveUser,
                    onNavigateToRequests: () => _onNavigateToTab(1),
                    onNavigateToActivity: () => _onNavigateToTab(2),
                  ),
                ),
                RepaintBoundary(
                  child: WardenLeaveRequestsScreen(
                    key: ValueKey('warden_requests_$lang'),
                    user: effectiveUser,
                  ),
                ),
                RepaintBoundary(
                  child: WardenActivityScreen(
                    key: ValueKey('warden_activity_$lang'),
                    user: effectiveUser,
                  ),
                ),
                RepaintBoundary(
                  child: WardenProfileScreen(
                    key: ValueKey('warden_profile_$lang'),
                    user: effectiveUser,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: RepaintBoundary(
            child: AppDock(
              currentIndex: _currentIndex,
              onTap: (index) => _onNavigateToTab(index),
              items: [
                AppDockItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  label: 'Home'.tr(context),
                ),
                AppDockItem(
                  icon: Icons.assignment_outlined,
                  activeIcon: Icons.assignment_rounded,
                  label: 'Requests'.tr(context),
                ),
                AppDockItem(
                  icon: Icons.history_rounded,
                  activeIcon: Icons.history_toggle_off_rounded,
                  label: 'Activity'.tr(context),
                ),
                AppDockItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile'.tr(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
