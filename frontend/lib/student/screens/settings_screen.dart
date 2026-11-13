import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/haptics/app_haptics.dart';
import '../../core/haptics/haptics_provider.dart';
import '../../core/performance/performance.dart';
import '../../core/localization/language_provider.dart';
import '../../core/localization/language_selector_sheet.dart';
import '../../core/localization/app_localizations.dart';
import '../../auth/services/auth_service.dart';
import '../../router/app_routes.dart';
import '../../shared/widgets/motion/apple_bounceable.dart';
import '../../shared/widgets/motion/apple_spring_scroll_physics.dart';
import '../../shared/widgets/motion/apple_spring_curve.dart';

/// Dedicated Settings screen — "How should CampusOS behave?"
///
/// Groups all behavioral preferences: appearance (theme), interaction (haptics, motion),
/// performance (refresh rates), language, and account actions.
class SettingsScreen extends StatefulWidget {
  final UserModel? user;
  final Function(int)? onNavigateToTab;

  const SettingsScreen({
    Key? key,
    this.user,
    this.onNavigateToTab,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeProvider.instance,
        PerformanceEngine.instance,
      ]),
      builder: (context, _) {
        final motion = PerformanceEngine.instance.profile.animationProfile;
        final isReduced = motion.reducedMotion;

        final bg = AppColors.bgOf(context);
        final surface = AppColors.surfaceOf(context);
        final textPrimary = AppColors.textPrimaryOf(context);
        final textSecondary = AppColors.textSecondaryOf(context);
        final border = AppColors.borderOf(context);

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: surface,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            surfaceTintColor: Colors.transparent,
            leading: AppleBounceable(
              onTap: () {
                AppHaptics.lightImpact();
                Navigator.pop(context);
              },
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                    border: Border.all(color: border, width: 0.6),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: textPrimary),
                ),
              ),
            ),
            title: Text(
              'Settings'.tr(context),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: true,
          ),
          body: ListView(
            physics: AppleSpringScrollPhysics.always,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              // ── Appearance ──────────────────────────────────
              _buildSectionHeader('Appearance'.tr(context),
                      Icons.palette_outlined, textSecondary)
                  ._animateAdaptive(isReduced,
                      delay: Duration.zero, duration: motion.standard),
              const SizedBox(height: 8),
              _buildAppearanceCard(surface, textPrimary, textSecondary, border)
                  ._animateAdaptive(isReduced,
                      delay: Duration.zero,
                      duration: motion.standard,
                      slide: true),

              const SizedBox(height: 24),

              // ── Interaction ─────────────────────────────────
              _buildSectionHeader('Interaction'.tr(context),
                      Icons.touch_app_outlined, textSecondary)
                  ._animateAdaptive(isReduced,
                      delay: 50.ms, duration: motion.standard),
              const SizedBox(height: 8),
              _buildInteractionCard(
                      surface, textPrimary, textSecondary, border)
                  ._animateAdaptive(isReduced,
                      delay: 50.ms,
                      duration: motion.standard,
                      slide: true),

              const SizedBox(height: 24),

              // ── Performance ─────────────────────────────────
              _buildSectionHeader('Performance'.tr(context),
                      Icons.bolt_rounded, textSecondary)
                  ._animateAdaptive(isReduced,
                      delay: 100.ms, duration: motion.standard),
              const SizedBox(height: 8),
              _buildPerformanceCard(surface, border)._animateAdaptive(
                  isReduced,
                  delay: 100.ms,
                  duration: motion.standard,
                  slide: true),

              const SizedBox(height: 24),

              // ── Language ────────────────────────────────────
              _buildSectionHeader('Language'.tr(context),
                      Icons.language_rounded, textSecondary)
                  ._animateAdaptive(isReduced,
                      delay: 150.ms, duration: motion.standard),
              const SizedBox(height: 8),
              _buildLanguageCard(surface, textPrimary, textSecondary, border)
                  ._animateAdaptive(isReduced,
                      delay: 150.ms,
                      duration: motion.standard,
                      slide: true),

              const SizedBox(height: 24),

              // ── About ───────────────────────────────────────
              _buildSectionHeader('About'.tr(context),
                      Icons.info_outline_rounded, textSecondary)
                  ._animateAdaptive(isReduced,
                      delay: 200.ms, duration: motion.standard),
              const SizedBox(height: 8),
              _buildAboutCard(surface, textPrimary, textSecondary, border)
                  ._animateAdaptive(isReduced,
                      delay: 200.ms,
                      duration: motion.standard,
                      slide: true),

              const SizedBox(height: 28),

              // ── Logout ──────────────────────────────────────
              _buildLogoutButton()._animateAdaptive(isReduced,
                  delay: 250.ms, duration: motion.standard),
            ],
          ),
        );
      },
    );
  }

  // ─── Section Header ─────────────────────────────────────────────
  Widget _buildSectionHeader(
      String title, IconData icon, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: textSecondary),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Appearance Card ────────────────────────────────────────────
  Widget _buildAppearanceCard(Color surface, Color textPrimary,
      Color textSecondary, Color border) {
    final current = ThemeProvider.instance.themeMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildCard(
      surface: surface,
      border: border,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme'.tr(context),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Choose how CampusOS looks on your device'.tr(context),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildThemeChip(
                    label: 'Light'.tr(context),
                    icon: Icons.light_mode_rounded,
                    isSelected: current == ThemeMode.light,
                    isDark: isDark,
                    onTap: () {
                      AppHaptics.selectionClick();
                      ThemeProvider.instance.setThemeMode(ThemeMode.light);
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildThemeChip(
                    label: 'Dark'.tr(context),
                    icon: Icons.dark_mode_rounded,
                    isSelected: current == ThemeMode.dark,
                    isDark: isDark,
                    onTap: () {
                      AppHaptics.selectionClick();
                      ThemeProvider.instance.setThemeMode(ThemeMode.dark);
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildThemeChip(
                    label: 'System'.tr(context),
                    icon: Icons.settings_brightness_rounded,
                    isSelected: current == ThemeMode.system,
                    isDark: isDark,
                    onTap: () {
                      AppHaptics.selectionClick();
                      ThemeProvider.instance.setThemeMode(ThemeMode.system);
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

  Widget _buildThemeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final chipBg = isSelected
        ? AppColors.primary.withValues(alpha: 0.15)
        : (isDark ? const Color(0xFF131A2A) : AppColors.bgOf(context));

    final chipBorder = isSelected
        ? AppColors.primary
        : (isDark
            ? const Color(0xFF28283C)
            : AppColors.borderOf(context));

    return Expanded(
      child: AppleBounceable(
        onTap: onTap,
        scaleFactor: 0.95,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: AppleSpringCurve.standard,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: chipBorder,
              width: isSelected ? 1.5 : 0.6,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 21,
                color: isSelected
                    ? AppColors.primary
                    : (isDark
                        ? const Color(0xFF8E8E9E)
                        : AppColors.textSecondaryOf(context)),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                          ? const Color(0xFF8E8E9E)
                          : AppColors.textSecondaryOf(context)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Interaction Card ───────────────────────────────────────────
  Widget _buildInteractionCard(Color surface, Color textPrimary,
      Color textSecondary, Color border) {
    final hapticsEnabled = HapticsProvider.instance.isEnabled;
    final reducedMotion =
        PerformanceEngine.instance.profile.animationProfile.reducedMotion;

    return _buildCard(
      surface: surface,
      border: border,
      children: [
        // Haptics toggle
        _buildToggleTile(
          icon: Icons.vibration_rounded,
          title: 'Haptic Feedback'.tr(context),
          subtitle: hapticsEnabled
              ? 'Tactile responses are enabled'.tr(context)
              : 'Haptic feedback is disabled'.tr(context),
          value: hapticsEnabled,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onChanged: (val) {
            HapticsProvider.instance.setEnabled(val);
            if (val) AppHaptics.lightImpact();
          },
        ),
        _buildDivider(border),
        // Reduced Motion toggle
        _buildToggleTile(
          icon: Icons.motion_photos_off_rounded,
          title: 'Reduce Motion'.tr(context),
          subtitle: reducedMotion
              ? 'Animations are minimized'.tr(context)
              : 'Full animations enabled'.tr(context),
          value: reducedMotion,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onChanged: (val) {
            AppHaptics.selectionClick();
            PerformanceEngine.instance.setReducedMotion(val);
          },
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color textPrimary,
    required Color textSecondary,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // ─── Performance Card ───────────────────────────────────────────
  Widget _buildPerformanceCard(Color surface, Color border) {
    return _buildCard(
      surface: surface,
      border: border,
      children: [
        const OptimizeCampusTile(),
      ],
    );
  }

  // ─── Language Card ──────────────────────────────────────────────
  Widget _buildLanguageCard(Color surface, Color textPrimary,
      Color textSecondary, Color border) {
    return ListenableBuilder(
      listenable: LanguageProvider.instance,
      builder: (context, _) {
        final currentName =
            LanguageProvider.instance.currentLanguageName;
        return _buildCard(
          surface: surface,
          border: border,
          children: [
            AppleBounceable(
              onTap: () {
                AppHaptics.lightImpact();
                LanguageSelectorSheet.show(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 15),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.language_rounded,
                          color: AppColors.info, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Regional Language'.tr(context),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: textSecondary, size: 20),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── About Card ─────────────────────────────────────────────────
  Widget _buildAboutCard(Color surface, Color textPrimary,
      Color textSecondary, Color border) {
    return _buildCard(
      surface: surface,
      border: border,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CampusOS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Version 7.5 • Built for campus life',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Destructive Logout Button ──────────────────────────────────
  Widget _buildLogoutButton() {
    return AppleBounceable(
      scaleFactor: 0.98,
      onTap: () async {
        AppHaptics.mediumImpact();
        final nav = Navigator.of(context);
        await AuthService.signOut();
        if (mounted) {
          nav.pushNamedAndRemoveUntil(
            AppRoutes.login,
            (route) => false,
          );
        }
      },
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.danger.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded,
                color: AppColors.danger, size: 18),
            const SizedBox(width: 8),
            Text(
              'Logout'.tr(context),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Shared Inset Grouped Card Wrapper ──────────────────────────
  Widget _buildCard({
    required Color surface,
    required Color border,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildDivider(Color border) {
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 18,
      color: border.withValues(alpha: 0.6),
    );
  }
}

extension _AdaptiveMotionExtension on Widget {
  Widget _animateAdaptive(
    bool isReduced, {
    Duration? delay,
    Duration? duration,
    bool slide = false,
  }) {
    if (isReduced) return this;
    var w = animate().fadeIn(
      delay: delay ?? Duration.zero,
      duration: duration ?? 200.ms,
    );
    if (slide) {
      w = w.slideY(
        begin: 0.04,
        curve: Curves.easeOutCubic,
        duration: duration ?? 200.ms,
      );
    }
    return w;
  }
}
