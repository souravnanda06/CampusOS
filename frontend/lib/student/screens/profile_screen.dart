import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../auth/services/auth_service.dart';
import '../../router/app_routes.dart';
import '../../core/performance/performance.dart';
import '../../core/models/expansion_models.dart';
import '../../core/services/expansion_api_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/haptics/app_haptics.dart';
import '../../shared/widgets/motion/apple_bounceable.dart';
import 'settings_screen.dart';
import 'smart_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel? user;
  final Function(int)? onNavigateToTab;

  const ProfileScreen({
    Key? key,
    this.user,
    this.onNavigateToTab,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = widget.user;

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
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium collapsing identity header
              _buildSliverHeader(user, motion, isReduced),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildIdentityCardSection(user, surface, textPrimary, textSecondary, border)
                        ._animateAdaptive(isReduced, duration: motion.standard, slide: true),
                    const SizedBox(height: 24),
                    _buildAcademicSection(user, surface, textPrimary, textSecondary, border)
                        ._animateAdaptive(isReduced, delay: 60.ms, duration: motion.standard, slide: true),
                    const SizedBox(height: 24),
                    _buildHostelSection(user, surface, textPrimary, textSecondary, border)
                        ._animateAdaptive(isReduced, delay: 120.ms, duration: motion.standard, slide: true),
                    const SizedBox(height: 24),
                    _buildDeviceSection(user, surface, textPrimary, textSecondary, border)
                        ._animateAdaptive(isReduced, delay: 180.ms, duration: motion.standard, slide: true),
                    const SizedBox(height: 24),
                    _buildCareerSection(user, surface, textPrimary, textSecondary, border)
                        ._animateAdaptive(isReduced, delay: 210.ms, duration: motion.standard, slide: true),
                    const SizedBox(height: 32),
                    _buildQuickActions(motion, isReduced, surface, textPrimary, textSecondary, border)
                        ._animateAdaptive(isReduced, delay: 240.ms, duration: motion.standard, slide: true),
                    const SizedBox(height: 32),
                    _buildLogoutButton(context)
                        ._animateAdaptive(isReduced, delay: 300.ms, duration: motion.standard),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Sliver Header ──────────────────────────────────────────────
  Widget _buildSliverHeader(UserModel? user, MotionConfig motion, bool isReduced) {
    final name = user?.name ?? 'Student';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';
    final branch = user?.branch ?? '';
    final year = user?.year ?? '';
    final subtitle = [branch, year].where((s) => s.isNotEmpty).join(' • ');

    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A2E),
      elevation: 0,
      stretch: true,
      automaticallyImplyLeading: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 22),
            onPressed: () {
              AppHaptics.lightImpact();
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => SettingsScreen(
                    user: widget.user,
                    onNavigateToTab: widget.onNavigateToTab,
                  ),
                  transitionsBuilder: (_, anim, __, child) {
                    if (isReduced) return child;
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: anim, curve: motion.enterCurve)),
                      child: child,
                    );
                  },
                  transitionDuration: isReduced ? Duration.zero : motion.deliberate,
                ),
              );
            },
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.only(bottom: 16),
        title: Text(
          name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.darkCardGradient,
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.4),
                        AppColors.primaryDark.withValues(alpha: 0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Identity Card ──────────────────────────────────────────────
  Widget _buildIdentityCardSection(
    UserModel? user,
    Color surface,
    Color textPrimary,
    Color textSecondary,
    Color border,
  ) {
    final regNum = user?.registrationNumber;
    final email = user?.email ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (regNum == null && email.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Student ID'.tr(context),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          if (regNum != null && regNum.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF12121E) : AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registration Number'.tr(context),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          regNum,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      AppHaptics.lightImpact();
                      Clipboard.setData(ClipboardData(text: regNum));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Registration number copied'.tr(context)),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: border),
                      ),
                      child: Icon(Icons.copy_rounded, size: 16, color: textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (email.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.email_outlined, size: 16, color: textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    email,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Academic Section ───────────────────────────────────────────
  Widget _buildAcademicSection(
    UserModel? user,
    Color surface,
    Color textPrimary,
    Color textSecondary,
    Color border,
  ) {
    final branch = user?.branch;
    final year = user?.year;
    final course = user?.course;

    if (branch == null && year == null) return const SizedBox.shrink();

    return _buildSection(
      title: 'Academic Credentials'.tr(context),
      icon: Icons.school_outlined,
      surface: surface,
      border: border,
      textSecondary: textSecondary,
      children: [
        if (branch != null)
          _buildInfoRow(Icons.domain_outlined, 'Branch'.tr(context), branch, textPrimary, textSecondary, border),
        if (year != null)
          _buildInfoRow(Icons.calendar_today_outlined, 'Semester'.tr(context), year, textPrimary, textSecondary, border),
        if (course != null)
          _buildInfoRow(Icons.menu_book_outlined, 'Course'.tr(context), course, textPrimary, textSecondary, border, isLast: true),
        if (course == null && year != null)
          _buildInfoRow(Icons.calendar_today_outlined, 'Semester'.tr(context), year, textPrimary, textSecondary, border, isLast: true),
      ],
    );
  }

  // ─── Hostel Section ─────────────────────────────────────────────
  Widget _buildHostelSection(
    UserModel? user,
    Color surface,
    Color textPrimary,
    Color textSecondary,
    Color border,
  ) {
    if (user?.id == null) return const SizedBox.shrink();

    return FutureBuilder<HostelAllocationModel?>(
      future: ExpansionApiService.instance.getMyRoom(user!.id),
      builder: (context, snapshot) {
        final room = snapshot.data;
        if (room == null) return const SizedBox.shrink();

        return _buildSection(
          title: 'Hostel & Room'.tr(context),
          icon: Icons.apartment_rounded,
          surface: surface,
          border: border,
          textSecondary: textSecondary,
          children: [
            _buildInfoRow(Icons.apartment_rounded, 'Hostel'.tr(context), room.hostelName, textPrimary, textSecondary, border),
            _buildInfoRow(Icons.door_front_door_outlined, 'Room Number'.tr(context), '${room.block} • Room ${room.roomNumber}', textPrimary, textSecondary, border),
            _buildInfoRow(Icons.single_bed_outlined, 'Bed Allocation'.tr(context), '${room.bedLabel} (${room.roomType})', textPrimary, textSecondary, border),
            if (room.roommates.isNotEmpty)
              _buildInfoRow(
                Icons.people_alt_outlined,
                'Roommates'.tr(context),
                room.roommates
                    .map((r) => (r['name'] ?? r['studentName'] ?? '').toString())
                    .where((n) => n.isNotEmpty)
                    .join(', '),
                textPrimary,
                textSecondary,
                border,
                isLast: true,
              )
            else
              _buildInfoRow(
                Icons.inventory_2_outlined,
                'Room Assets'.tr(context),
                'All inventory registered & verified'.tr(context),
                textPrimary,
                textSecondary,
                border,
                isLast: true,
              ),
          ],
        );
      },
    );
  }

  // ─── Device Section ─────────────────────────────────────────────
  Widget _buildDeviceSection(
    UserModel? user,
    Color surface,
    Color textPrimary,
    Color textSecondary,
    Color border,
  ) {
    final deviceId = user?.deviceId;
    final isBound = deviceId != null && deviceId.isNotEmpty;

    String displayId = '';
    if (isBound) {
      displayId = deviceId.length > 4
          ? 'ID ••••${deviceId.substring(deviceId.length - 4)}'
          : 'ID $deviceId';
    }

    return _buildSection(
      title: 'Device & Security'.tr(context),
      icon: Icons.phonelink_lock_rounded,
      surface: surface,
      border: border,
      textSecondary: textSecondary,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isBound ? AppColors.success : textSecondary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isBound ? Icons.phonelink_lock_rounded : Icons.phonelink_erase_rounded,
                  color: isBound ? AppColors.success : textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBound ? 'Device Bound'.tr(context) : 'Device Not Bound'.tr(context),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    if (isBound) ...[
                      const SizedBox(height: 3),
                      Text(
                        displayId,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isBound)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Verified'.tr(context),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
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

  // ─── Career & Placement Profile ───────────────────────────────
  Widget _buildCareerSection(
    UserModel? user,
    Color surface,
    Color textPrimary,
    Color textSecondary,
    Color border,
  ) {
    return _buildSection(
      title: 'Career & Professional Profile'.tr(context),
      icon: Icons.business_center_outlined,
      surface: surface,
      border: border,
      textSecondary: textSecondary,
      children: [
        // 1. Smart Profile Studio (Skills, Projects, Certifications)
        AppleBounceable(
          onTap: () {
            AppHaptics.selectionClick();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SmartProfileScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Profile Studio',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage skills, projects, certifications & academic records',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '94% Ready',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        // Apple-style Hairline Divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Divider(height: 1, color: border.withValues(alpha: 0.5)),
        ),

        // 2. Career Hub & Placement Drives
        AppleBounceable(
          onTap: () {
            AppHaptics.selectionClick();
            Navigator.of(context).pushNamed(AppRoutes.careerHub);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Color(0xFF6366F1),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Career Hub & Placement Drives',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'On-campus drives, off-campus jobs & ATS resume score',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Quick Actions (Settings & Requests) ────────────────────────
  Widget _buildQuickActions(
    MotionConfig motion,
    bool isReduced,
    Color surface,
    Color textPrimary,
    Color textSecondary,
    Color border,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Settings entry
        _buildActionTile(
          icon: Icons.settings_rounded,
          iconColor: AppColors.primary,
          title: 'Settings'.tr(context),
          subtitle: 'Appearance, haptics, performance & more'.tr(context),
          surface: surface,
          border: border,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onTap: () {
            AppHaptics.lightImpact();
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => SettingsScreen(
                  user: widget.user,
                  onNavigateToTab: widget.onNavigateToTab,
                ),
                transitionsBuilder: (_, anim, __, child) {
                  if (isReduced) return child;
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: anim, curve: motion.enterCurve)),
                    child: child,
                  );
                },
                transitionDuration: isReduced ? Duration.zero : motion.deliberate,
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        // My Requests shortcut
        _buildActionTile(
          icon: Icons.inbox_rounded,
          iconColor: AppColors.info,
          title: 'My Requests'.tr(context),
          subtitle: 'Leave, documents, hostel & passes'.tr(context),
          surface: surface,
          border: border,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onTap: () {
            AppHaptics.lightImpact();
            if (widget.onNavigateToTab != null) {
              widget.onNavigateToTab!(2);
            }
          },
        ),
      ],
    );
  }

  // ─── Shared Section Builder ─────────────────────────────────────
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color surface,
    required Color border,
    required Color textSecondary,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: textSecondary),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  // ─── Info Row ───────────────────────────────────────────────────
  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color textPrimary,
    Color textSecondary,
    Color border, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 54, endIndent: 20, color: border.withValues(alpha: 0.6)),
      ],
    );
  }

  // ─── Action Tile ────────────────────────────────────────────────
  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required Color surface,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
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
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Logout ─────────────────────────────────────────────────────
  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () async {
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
        icon: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 18),
        label: Text(
          'Logout'.tr(context),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.danger,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4), width: 1.5),
          backgroundColor: AppColors.danger.withValues(alpha: 0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

extension _ProfileMotionExtension on Widget {
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
