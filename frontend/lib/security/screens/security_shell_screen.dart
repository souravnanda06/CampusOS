import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import 'security_home_screen.dart';
import 'security_passes_screen.dart';
import 'security_activity_screen.dart';
import 'security_profile_screen.dart';
import '../../shared/widgets/dock/app_dock.dart';
import '../../core/localization/language_provider.dart';
import '../../core/localization/app_localizations.dart';

/// CampusOS Gate Security Shell with Apple-grade 4-Destination Navigation Dock.
///
/// Exactly 4 primary destinations:
/// 1. Home (Operational gate command center, live metrics, Verify Pass CTA)
/// 2. Passes (Operational pass list: Active, Outside, Returned, Expired)
/// 3. Activity (Gate transit audit timeline, filterable by operation & result)
/// 4. Profile (Security guard identity, gate assignment, offline sync badge, logout)
class SecurityShellScreen extends StatefulWidget {
  final UserModel? user;
  final int initialIndex;

  const SecurityShellScreen({
    Key? key,
    required this.user,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<SecurityShellScreen> createState() => _SecurityShellScreenState();
}

class _SecurityShellScreenState extends State<SecurityShellScreen> {
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
          id: 'security_guard',
          email: 'security@campusos.edu',
          name: 'Gate Security Officer',
          role: 'security',
        );

    return ListenableBuilder(
      listenable: LanguageProvider.instance,
      builder: (context, _) {
        final lang = LanguageProvider.instance.currentLanguage;
        return Scaffold(
          key: ValueKey('security_shell_$lang'),
          backgroundColor: AppColors.bg,
          extendBody: true,
          body: RepaintBoundary(
            child: IndexedStack(
              key: ValueKey('security_stack_$lang'),
              index: _currentIndex,
              children: [
                RepaintBoundary(
                  child: SecurityHomeScreen(
                    key: ValueKey('security_home_$lang'),
                    user: effectiveUser,
                    onNavigateToPasses: () => _onNavigateToTab(1),
                    onNavigateToActivity: () => _onNavigateToTab(2),
                  ),
                ),
                RepaintBoundary(
                  child: SecurityPassesScreen(
                    key: ValueKey('security_passes_$lang'),
                    user: effectiveUser,
                  ),
                ),
                RepaintBoundary(
                  child: SecurityActivityScreen(
                    key: ValueKey('security_activity_$lang'),
                    user: effectiveUser,
                  ),
                ),
                RepaintBoundary(
                  child: SecurityProfileScreen(
                    key: ValueKey('security_profile_$lang'),
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
                  icon: Icons.shield_outlined,
                  activeIcon: Icons.shield_rounded,
                  label: 'Home'.tr(context),
                ),
                AppDockItem(
                  icon: Icons.badge_outlined,
                  activeIcon: Icons.badge_rounded,
                  label: 'Passes'.tr(context),
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
