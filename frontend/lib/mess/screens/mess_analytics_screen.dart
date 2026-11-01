import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';
import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../student/models/mess_model.dart';
import '../../student/services/mess_service.dart';
import '../../core/localization/app_localizations.dart';

/// CampusOS Mess Analytics Screen.
///
/// Surfaces real dining operational metrics (total entries, batch vs QR fallback distribution,
/// meal breakdowns) and student satisfaction trends using authenticated backend APIs.
class MessAnalyticsScreen extends StatefulWidget {
  final UserModel? user;
  final MessService? messService;

  const MessAnalyticsScreen({
    Key? key,
    this.user,
    this.messService,
  }) : super(key: key);

  @override
  State<MessAnalyticsScreen> createState() => _MessAnalyticsScreenState();
}

class _MessAnalyticsScreenState extends State<MessAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final MessService _messService;

  bool _isLoading = true;
  String? _errorMessage;

  MessOperationalAnalytics? _operations;
  FeedbackSummary? _feedbackSummary;
  List<FeedbackTrend> _trends = [];

  MessOperationalAnalytics? get operations => _operations;
  FeedbackSummary? get feedbackSummary => _feedbackSummary;
  List<FeedbackTrend> get trends => _trends;
  String? get errorMessage => _errorMessage;

  @override
  void initState() {
    super.initState();
    _messService = widget.messService ?? MessService();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final requesterId = widget.user?.uid ?? '';
      final opsFuture = _messService.getMessOperationalAnalytics(
        requesterId: requesterId,
      );
      final summaryFuture = _messService.getFeedbackSummary(
        requesterId: requesterId,
      );
      final trendsFuture = _messService.getFeedbackTrends(
        requesterId: requesterId,
      );

      final results = await Future.wait([
        opsFuture.catchError((_) => MessOperationalAnalytics(mealBreakdown: {})),
        summaryFuture.then<dynamic>((v) => v).catchError((_) => null),
        trendsFuture.catchError((_) => <FeedbackTrend>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _operations = results[0] as MessOperationalAnalytics?;
        _feedbackSummary = results[1] as FeedbackSummary?;
        _trends = results[2] as List<FeedbackTrend>;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text(
          'Mess Analytics'.tr(context),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            tooltip: 'Refresh Analytics',
            onPressed: () {
              AppHaptics.lightImpact();
              _loadAnalytics();
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
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Operational Cards
                    _buildOperationalSummaryGrid(),

                    const SizedBox(height: 20),

                    // Verification Method Ratio: Batch vs QR Fallback
                    _buildVerificationDistributionCard(),

                    const SizedBox(height: 20),

                    // Meal Type Breakdown
                    _buildMealBreakdownCard(),

                    const SizedBox(height: 24),

                    // Student Satisfaction & Feedback Summary
                    _buildStudentFeedbackSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOperationalSummaryGrid() {
    final ops = _operations;
    final total = ops?.totalEntries ?? 0;
    final today = ops?.todayEntries ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Total Verified Entries'.tr(context),
            value: '$total',
            subtitle: 'Historical verified'.tr(context),
            icon: Icons.done_all_rounded,
            color: AppColors.emerald,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            title: "Today's Check-ins".tr(context),
            value: '$today',
            subtitle: 'All meals today'.tr(context),
            icon: Icons.today_rounded,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationDistributionCard() {
    final ops = _operations;
    final batch = ops?.batchEntries ?? 0;
    final qr = ops?.qrEntries ?? 0;
    final total = batch + qr;

    final batchRatio = total > 0 ? (batch / total) : 0.5;
    final qrRatio = total > 0 ? (qr / total) : 0.5;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Verification Method Ratio',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Primary vs Fallback',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Distribution Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  Expanded(
                    flex: (batchRatio * 100).toInt(),
                    child: Container(color: AppColors.primary),
                  ),
                  Expanded(
                    flex: (qrRatio * 100).toInt(),
                    child: Container(color: const Color(0xFFF59E0B)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Batch Verified: $batch (${(batchRatio * 100).toStringAsFixed(1)}%)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'QR Fallback: $qr (${(qrRatio * 100).toStringAsFixed(1)}%)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealBreakdownCard() {
    final ops = _operations;
    final mb = ops?.mealBreakdown ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meal-Wise Entry Totals',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _buildMealRow('Breakfast', mb['BREAKFAST'] ?? 0, Icons.free_breakfast_outlined),
          const Divider(height: 20, thickness: 0.5),
          _buildMealRow('Lunch', mb['LUNCH'] ?? 0, Icons.lunch_dining_outlined),
          const Divider(height: 20, thickness: 0.5),
          _buildMealRow('Snacks', mb['SNACKS'] ?? 0, Icons.fastfood_outlined),
          const Divider(height: 20, thickness: 0.5),
          _buildMealRow('Dinner', mb['DINNER'] ?? 0, Icons.dinner_dining_outlined),
        ],
      ),
    );
  }

  Widget _buildMealRow(String label, int count, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          '$count entries',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentFeedbackSection() {
    final summary = _feedbackSummary;
    final ratingCount = summary?.totalRatings ?? 0;
    final avgRating = summary?.averageRating ?? 0.0;
    final positiveCount = summary != null
        ? ((summary.ratingDistribution[4] ?? 0) +
            (summary.ratingDistribution[5] ?? 0))
        : 0;
    final criticalCount = summary != null
        ? ((summary.ratingDistribution[1] ?? 0) +
            (summary.ratingDistribution[2] ?? 0))
        : 0;
    final positivePct = ratingCount > 0
        ? (positiveCount / ratingCount * 100).toStringAsFixed(0)
        : '0';
    final criticalPct = ratingCount > 0
        ? (criticalCount / ratingCount * 100).toStringAsFixed(0)
        : '0';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Student Meal Feedback',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (ratingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (ratingCount == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No student feedback ratings submitted yet.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else ...[
            Text(
              'Based on $ratingCount student ratings across dining sessions.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildSentimentStat(
                    'Positive Ratings',
                    '$positivePct%',
                    AppColors.emerald,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSentimentStat(
                    'Critical Ratings',
                    '$criticalPct%',
                    AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSentimentStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
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
}
