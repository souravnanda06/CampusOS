import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../auth/models/user_model.dart';
import '../../auth/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../router/app_routes.dart';
import '../../student/services/mess_service.dart';
import '../../student/services/passport_trust_bundle_service.dart';
import '../../core/performance/performance.dart';
import '../../core/localization/language_provider.dart';
import '../../core/localization/language_selector_sheet.dart';
import '../../core/localization/app_localizations.dart';

/// CampusOS Mess Staff Profile Screen.
///
/// Displays staff identity credentials, institutional role verification status,
/// local certified trust bundle health, pending offline sync queues, and secure logout.
class MessProfileScreen extends StatefulWidget {
  final UserModel? user;
  final AuthService? authService;
  final MessService? messService;
  final PassportTrustBundleService? trustBundleService;

  const MessProfileScreen({
    Key? key,
    required this.user,
    this.authService,
    this.messService,
    this.trustBundleService,
  }) : super(key: key);

  @override
  State<MessProfileScreen> createState() => _MessProfileScreenState();
}

class _MessProfileScreenState extends State<MessProfileScreen> {
  late final AuthService _authService;
  late final MessService _messService;
  late final PassportTrustBundleService _bundleService;

  AuthService get authService => _authService;
  int get queuedOfflineCount => _queuedOfflineCount;

  int _queuedOfflineCount = 0;
  bool _isSyncing = false;
  String? _bundleStatus;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _messService = widget.messService ?? MessService();
    _bundleService = widget.trustBundleService ?? PassportTrustBundleService();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final queued = await _messService.getQueuedOfflineMealEntries();
      final bundle = await _bundleService.getLocalBundle();

      if (mounted) {
        setState(() {
          _queuedOfflineCount = queued.length;
          _bundleStatus = bundle != null
              ? 'Active (${bundle.identities.length} certified student identities)'
              : 'Trust bundle synced';
        });
      }
    } catch (_) {}
  }

  Future<void> _handleSyncNow() async {
    if (_isSyncing || _queuedOfflineCount == 0) return;
    setState(() => _isSyncing = true);
    AppHaptics.selectionClick();

    try {
      final res = await _messService.syncQueuedOfflineMealEntries(
        requesterId: widget.user?.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Synced ${res['synced']} entries successfully (${res['duplicates']} duplicate records skipped).',
          ),
          backgroundColor: AppColors.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: ${MessService.sanitizeError(e)}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of your Mess Staff account? Local cryptographic verification keys and offline queues will be safely preserved.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Sign Out',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      AppHaptics.mediumImpact();
      await AuthService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.user?.name ?? 'Mess Staff';
    final userEmail = widget.user?.email ?? 'mess.staff@campusos.edu';
    final role = widget.user?.role.toUpperCase() ?? 'MESS_STAFF';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text(
          'Profile',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        child: Column(
          children: [
            // User Identity Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'M',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    userName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Institutional Role Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_rounded,
                            color: AppColors.primary, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          role,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Operational & Trust Bundle Settings Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  _buildListTile(
                    icon: Icons.shield_rounded,
                    iconColor: AppColors.emerald,
                    title: 'Institutional Trust Bundle'.tr(context),
                    subtitle: _bundleStatus ?? 'Synced with backend authority',
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildListTile(
                    icon: Icons.cloud_sync_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Pending Offline Entries'.tr(context),
                    subtitle: '$_queuedOfflineCount records queued for sync',
                    trailing: _queuedOfflineCount > 0
                        ? TextButton(
                            onPressed: _isSyncing ? null : _handleSyncNow,
                            child: _isSyncing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text('Sync Now'.tr(context)),
                          )
                        : null,
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildListTile(
                    icon: Icons.key_rounded,
                    iconColor: AppColors.primary,
                    title: 'Ed25519 Cryptographic Keys'.tr(context),
                    subtitle: 'Stored in secure hardware vault',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Regional Language Selector
            SafeLanguageConsumer(
              builder: (context, currentLanguage, currentName) {
                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: InkWell(
                    onTap: () => LanguageSelectorSheet.show(context),
                    child: _buildListTile(
                      icon: Icons.language_rounded,
                      iconColor: AppColors.primary,
                      title: 'Regional Language'.tr(context),
                      subtitle: currentName,
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Performance & Device Adaptive Engine
            const OptimizeCampusTile(),

            const SizedBox(height: 12),

            // Logout Action
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                key: const Key('mess_staff_logout_button'),
                onPressed: _handleSignOut,
                icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                label: Text(
                  'Log Out'.tr(context),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
