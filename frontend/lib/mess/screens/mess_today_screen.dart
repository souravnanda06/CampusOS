import 'dart:async';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../student/models/mess_model.dart';
import '../../student/services/mess_service.dart';
import 'mess_batch_verification_screen.dart';
import 'mess_qr_scanner_screen.dart';
import '../../core/localization/app_localizations.dart';
import '../../router/app_routes.dart';

/// CampusOS Mess Staff Today Screen.
///
/// Primary operational command center for dining hall verification.
/// Displays current meal, timings, published menu status, verified dining counts,
/// offline queue indicators, and primary actions for Batch Verification and QR Fallback.
class MessTodayScreen extends StatefulWidget {
  final UserModel? user;
  final MessService? messService;
  final VoidCallback? onNavigateToMenus;

  const MessTodayScreen({
    Key? key,
    required this.user,
    this.messService,
    this.onNavigateToMenus,
  }) : super(key: key);

  @override
  State<MessTodayScreen> createState() => _MessTodayScreenState();
}

class _MessTodayScreenState extends State<MessTodayScreen> {
  late final MessService _messService;

  TodayMealStats? _stats;
  MessMenu? _todayMenu;
  bool _isLoading = true;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  int _pendingOfflineCount = 0;
  bool _isSyncingOffline = false;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _messService = widget.messService ?? MessService();
    _loadData();
    // Auto-refresh stats periodically every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadStatsSilently();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final requesterId = widget.user?.uid;
      final statsFuture = _messService.getTodayMealStats(requesterId: requesterId);
      final menuFuture = _messService.getTodayMenu(requesterId: requesterId);
      final offlineFuture = _messService.getQueuedOfflineMealEntries();

      final results = await Future.wait([
        statsFuture.then<dynamic>((v) => v).catchError((_) => null),
        menuFuture.then<dynamic>((v) => v).catchError((_) => null),
        offlineFuture.catchError((_) => <MealEntryRecord>[]),
      ]);

      if (!mounted) return;

      setState(() {
        _stats = results[0] as TodayMealStats?;
        _todayMenu = results[1] as MessMenu?;
        _pendingOfflineCount = (results[2] as List<MealEntryRecord>).length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = MessService.sanitizeError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStatsSilently() async {
    try {
      final requesterId = widget.user?.uid;
      final stats = await _messService.getTodayMealStats(requesterId: requesterId);
      final offline = await _messService.getQueuedOfflineMealEntries();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _pendingOfflineCount = offline.length;
      });
    } catch (_) {}
  }

  Future<void> _handleSyncOfflineEntries() async {
    if (_isSyncingOffline || _pendingOfflineCount == 0) return;
    setState(() => _isSyncingOffline = true);
    AppHaptics.mediumImpact();

    try {
      final res = await _messService.syncQueuedOfflineMealEntries(
        requesterId: widget.user?.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Synced ${res['synced']} offline entries (${res['duplicates']} duplicates).',
          ),
          backgroundColor: AppColors.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadStatsSilently();
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
      if (mounted) setState(() => _isSyncingOffline = false);
    }
  }

  void _startBatchVerification() {
    AppHaptics.mediumImpact();
    final mealType = _stats?.activeMeal ?? 'LUNCH';
    final date = _stats?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessBatchVerificationScreen(
          user: widget.user,
          mealType: mealType,
          date: date,
          messService: _messService,
        ),
      ),
    ).then((_) => _loadStatsSilently());
  }

  void _startQrFallbackVerification() {
    AppHaptics.selectionClick();
    final mealType = _stats?.activeMeal ?? 'LUNCH';
    final date = _stats?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessQrScannerScreen(
          user: widget.user,
          mealType: mealType,
          date: date,
          messService: _messService,
        ),
      ),
    ).then((_) => _loadStatsSilently());
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateDisplay = DateFormat('EEEE, MMMM d').format(now);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mess Operations'.tr(context),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              dateDisplay,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_input_antenna_rounded, color: Color(0xFF6366F1)),
            tooltip: 'Campus Mesh Hub',
            onPressed: () {
              AppHaptics.lightImpact();
              Navigator.pushNamed(context, AppRoutes.meshHub);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            tooltip: 'Refresh',
            onPressed: () {
              AppHaptics.lightImpact();
              _loadData();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Offline Queue Sync Banner
                    if (_pendingOfflineCount > 0) ...[
                      _buildOfflineBanner(),
                      const SizedBox(height: 16),
                    ],

                    if (_errorMessage != null) ...[
                      _buildErrorBanner(),
                      const SizedBox(height: 16),
                    ],

                    // Primary Meal Operational Hero
                    _buildActiveMealHero(),

                    const SizedBox(height: 16),

                    // Metrics Breakdown Row
                    _buildMetricsGrid(),

                    const SizedBox(height: 20),

                    // Meal Timing & Menu Status Card
                    _buildMenuStatusCard(),

                    const SizedBox(height: 24),

                    // Live Verification Activity
                    _buildRecentActivityHeader(),
                    const SizedBox(height: 12),
                    _buildRecentActivityList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7), // Warm amber background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFD97706), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Entries Pending'.tr(context),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                ),
                Text(
                  '$_pendingOfflineCount verified locally while offline.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _isSyncingOffline ? null : _handleSyncOfflineEntries,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isSyncingOffline
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    'Sync Now'.tr(context),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMealHero() {
    final activeMeal = _stats?.activeMeal ?? 'LUNCH';
    final mealTiming = _stats?.mealTiming ?? '12:00 PM – 3:00 PM';
    final counts = _stats?.counts[activeMeal];
    final totalVerifiedForMeal = counts?.total ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF38BDF8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Active Meal'.tr(context).toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF38BDF8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                mealTiming,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            activeMeal.tr(context).toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$totalVerifiedForMeal students verified for this meal today',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 22),
          // Primary Action: START BATCH VERIFICATION
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              key: const Key('start_batch_verification_button'),
              onPressed: _startBatchVerification,
              icon: const Icon(Icons.sensors_rounded, size: 20),
              label: Text(
                'Batch Verification'.tr(context).toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Fallback Action: QR SCANNING
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              key: const Key('switch_to_qr_scanning_button'),
              onPressed: _startQrFallbackVerification,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Colors.white),
              label: Text(
                'Scan QR Code'.tr(context),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.25), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final activeMeal = _stats?.activeMeal ?? 'LUNCH';
    final counts = _stats?.counts[activeMeal];
    final totalVerified = _stats?.totalVerifiedToday ?? 0;
    final batchCount = counts?.batch ?? 0;
    final qrCount = counts?.qr ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            label: 'Total Today',
            value: '$totalVerified',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.emerald,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            label: 'Batch Verified',
            value: '$batchCount',
            icon: Icons.sensors_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            label: 'QR Fallbacks',
            value: '$qrCount',
            icon: Icons.qr_code_rounded,
            color: const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.tr(context),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuStatusCard() {
    final status = _todayMenu?.status ?? _stats?.menuStatus ?? 'NONE';
    final isPublished = status.toUpperCase() == 'PUBLISHED';
    final isDraft = status.toUpperCase() == 'DRAFT';

    Color pillBg;
    Color pillText;
    String statusLabel;

    if (isPublished) {
      pillBg = const Color(0xFFD1FAE5);
      pillText = const Color(0xFF065F46);
      statusLabel = 'Published';
    } else if (isDraft) {
      pillBg = const Color(0xFFFEF3C7);
      pillText = const Color(0xFF92400E);
      statusLabel = 'Draft';
    } else {
      pillBg = const Color(0xFFF3F4F6);
      pillText = const Color(0xFF4B5563);
      statusLabel = 'No Menu';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPublished
                  ? Icons.restaurant_menu_rounded
                  : Icons.warning_amber_rounded,
              color: pillText,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Today's Menu",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: pillText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isPublished
                      ? 'Students can view items and submit ratings'
                      : 'No menu published for today.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              if (widget.onNavigateToMenus != null) {
                widget.onNavigateToMenus!();
              }
            },
            child: Text(
              isPublished ? 'View' : 'Manage',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Live Verification Activity',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        Text(
          'Live',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityList() {
    final recent = _stats?.recentEntries ?? [];
    if (recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Icon(Icons.how_to_reg_outlined, color: Colors.grey.shade400, size: 36),
            const SizedBox(height: 10),
            Text(
              'No meal entries recorded yet today',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Entries verified via batch or QR fallback will appear here live.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recent.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = recent[index];
        final isQr = entry.verificationMode == 'QR_FALLBACK';
        final timeStr = entry.createdAt != null
            ? DateFormat('h:mm a').format(entry.createdAt!)
            : 'Just now';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isQr
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isQr ? Icons.qr_code_rounded : Icons.sensors_rounded,
                  color: isQr ? const Color(0xFFD97706) : AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.studentName.isNotEmpty ? entry.studentName : 'Student',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.mealType} · ${isQr ? 'QR Fallback' : 'Batch Sync'}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.emerald, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Recorded',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
