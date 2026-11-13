import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/screens/mess/mess_management_screen.dart';
import 'mess_today_screen.dart';
import 'mess_analytics_screen.dart';
import 'mess_profile_screen.dart';
import '../../shared/widgets/dock/app_dock.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/language_provider.dart';

/// CampusOS Mess Staff Shell with Apple-grade 4-Destination Navigation Dock.
///
/// Exactly 4 primary destinations:
/// 1. Today (Operational verification command center, active meal, batch & QR fallback)
/// 2. Menus (Mess menu management, meals, availability, and publishing)
/// 3. Analytics (Dining verification metrics, method ratios, student satisfaction)
/// 4. Profile (Staff identity, trust bundle status, offline queue, and secure logout)
class MessShellScreen extends StatefulWidget {
  final UserModel? user;
  final int initialIndex;

  const MessShellScreen({
    Key? key,
    required this.user,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<MessShellScreen> createState() => _MessShellScreenState();
}

class _MessShellScreenState extends State<MessShellScreen> {
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
          id: 'mess_staff',
          email: 'mess.staff@campusos.edu',
          name: 'Mess Staff',
          role: 'mess_staff',
        );

    return ListenableBuilder(
      listenable: LanguageProvider.instance,
      builder: (context, _) {
        final lang = LanguageProvider.instance.currentLanguage;
        return Scaffold(
          key: ValueKey('mess_shell_$lang'),
          backgroundColor: AppColors.bg,
          extendBody: true,
          body: RepaintBoundary(
            child: IndexedStack(
              key: ValueKey('mess_stack_$lang'),
              index: _currentIndex,
              children: [
                RepaintBoundary(
                  child: MessTodayScreen(
                    key: ValueKey('mess_today_$lang'),
                    user: effectiveUser,
                    onNavigateToMenus: () => _onNavigateToTab(1),
                  ),
                ),
                RepaintBoundary(
                  child: MessManagementScreen(
                    key: ValueKey('mess_management_$lang'),
                    user: effectiveUser,
                  ),
                ),
                RepaintBoundary(
                  child: MessAnalyticsScreen(
                    key: ValueKey('mess_analytics_$lang'),
                    user: effectiveUser,
                  ),
                ),
                RepaintBoundary(
                  child: MessProfileScreen(
                    key: ValueKey('mess_profile_$lang'),
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
                  icon: Icons.calendar_today_rounded,
                  activeIcon: Icons.calendar_today_rounded,
                  label: 'Today'.tr(context),
                ),
                AppDockItem(
                  icon: Icons.restaurant_menu_outlined,
                  activeIcon: Icons.restaurant_menu_rounded,
                  label: 'Menus'.tr(context),
                ),
                AppDockItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart_rounded,
                  label: 'Analytics'.tr(context),
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
