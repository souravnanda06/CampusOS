import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/models/user_model.dart';
import '../../../../shared/widgets/motion/apple_spring_scroll_physics.dart';
import '../../../../shared/widgets/motion/apple_bounceable.dart';
import '../../../../core/haptics/app_haptics.dart';

/// Full-screen expanded attendance intelligence view displayed
/// during continuous card expansion.
class AppleAttendanceExpandedView extends StatefulWidget {
  final UserModel? user;
  final double overallAttendance;
  final Map<String, dynamic>? attendanceAnalytics;
  final VoidCallback onDismiss;

  const AppleAttendanceExpandedView({
    Key? key,
    required this.user,
    required this.overallAttendance,
    this.attendanceAnalytics,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<AppleAttendanceExpandedView> createState() =>
      _AppleAttendanceExpandedViewState();
}

class _AppleAttendanceExpandedViewState
    extends State<AppleAttendanceExpandedView> {
  int _bunkSimulatedClasses = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percentage = widget.overallAttendance.clamp(0.0, 100.0);
    final isLow = percentage < 75.0;

    final attended =
        (widget.attendanceAnalytics?['attendedClasses'] as num?)?.toInt() ?? 26;
    final total =
        (widget.attendanceAnalytics?['totalClasses'] as num?)?.toInt() ?? 32;

    // Attendance buffer calculation relative to 75% threshold
    final safeBunkBuffer = (attended - (0.75 * total)).floor();
    final classesNeededFor75 = ((0.75 * total - attended) / 0.25).ceil();

    // Simulation calculation:
    final simulatedTotal = total + _bunkSimulatedClasses;
    final simulatedPercent =
        ((attended / math.max(1, simulatedTotal)) * 100).clamp(0.0, 100.0);
    final simulatedIsLow = simulatedPercent < 75.0;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Apple Grab Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: AppleSpringScrollPhysics.always,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 44),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isLow
                                        ? const Color(0xFFEA580C)
                                        : const Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "ACADEMIC INTELLIGENCE",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: isLow
                                        ? const Color(0xFFEA580C)
                                        : const Color(0xFF6366F1),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Attendance Overview",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isLow
                                ? const Color(0xFFEA580C).withValues(alpha: 0.12)
                                : const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isLow
                                  ? const Color(0xFFEA580C).withValues(alpha: 0.28)
                                  : const Color(0xFF10B981).withValues(alpha: 0.28),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isLow
                                      ? const Color(0xFFEA580C)
                                      : const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isLow ? "Below 75%" : "Compliant (75%+)",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isLow
                                      ? const Color(0xFFEA580C)
                                      : const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Primary Gauge Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161E2E) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.35 : 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Apple Activity Ring Gauge
                              SizedBox(
                                width: 104,
                                height: 104,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Background Track
                                    SizedBox(
                                      width: 104,
                                      height: 104,
                                      child: CircularProgressIndicator(
                                        value: 1.0,
                                        strokeWidth: 10.0,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          isDark
                                              ? Colors.white12
                                              : (isLow
                                                  ? const Color(0xFFFFE4D6)
                                                  : const Color(0xFFDCFCE7)),
                                        ),
                                      ),
                                    ),
                                    // Foreground Indicator
                                    SizedBox(
                                      width: 104,
                                      height: 104,
                                      child: CircularProgressIndicator(
                                        value: percentage / 100.0,
                                        strokeWidth: 10.0,
                                        strokeCap: StrokeCap.round,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          isLow
                                              ? const Color(0xFFEA580C)
                                              : const Color(0xFF10B981),
                                        ),
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "${percentage.toInt()}%",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 25,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          "OVERALL",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),

                              // Ratio & Guidance
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Attendance Ratio",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "$attended / $total Conducted",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isLow
                                          ? "Attendance is below the mandatory 75% university policy threshold."
                                          : "You are safely eligible for all upcoming exams and lab evaluations.",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isLow
                                            ? const Color(0xFFEA580C)
                                            : const Color(0xFF10B981),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // 3 Micro KPI Stat Pills
                          Row(
                            children: [
                              Expanded(
                                child: _buildKpiPill(
                                  label: "Attended",
                                  value: "$attended",
                                  accentColor: const Color(0xFF10B981),
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildKpiPill(
                                  label: "Missed",
                                  value: "${math.max(0, total - attended)}",
                                  accentColor: const Color(0xFFEA580C),
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildKpiPill(
                                  label: isLow ? "Deficit" : "Safe Buffer",
                                  value: isLow
                                      ? "-$classesNeededFor75"
                                      : "+${math.max(0, safeBunkBuffer)}",
                                  accentColor: isLow
                                      ? const Color(0xFFEA580C)
                                      : const Color(0xFF6366F1),
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Interactive "What-If" Predictive Bunk Calculator
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF1E1B4B),
                                  const Color(0xFF161E2E)
                                ]
                              : [
                                  const Color(0xFFEEF2FF),
                                  const Color(0xFFF8FAFC)
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF818CF8).withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF6366F1).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.calculate_rounded,
                                  size: 17,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Text(
                                "Predictive Margin Calculator",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E1B4B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Simulate skipping upcoming lectures to preview exact percentage impact before bunking.",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF475569),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Dynamic simulation feedback banner
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _bunkSimulatedClasses == 0
                                          ? "Current Standing"
                                          : "Simulate skipping $_bunkSimulatedClasses ${_bunkSimulatedClasses == 1 ? 'class' : 'classes'}",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF4F46E5),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      simulatedIsLow
                                          ? "Attendance drops below safe 75%"
                                          : "Maintains required examination buffer",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: simulatedIsLow
                                        ? const Color(0xFFEA580C)
                                        : const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Projected: ${simulatedPercent.toStringAsFixed(1)}%",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Slider
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF6366F1),
                              inactiveTrackColor: isDark
                                  ? Colors.white12
                                  : const Color(0xFFCBD5E1),
                              thumbColor: const Color(0xFF4F46E5),
                              trackHeight: 5,
                            ),
                            child: Slider(
                              value: _bunkSimulatedClasses.toDouble(),
                              min: 0,
                              max: 8,
                              divisions: 8,
                              onChanged: (val) {
                                AppHaptics.selectionClick();
                                setState(() {
                                  _bunkSimulatedClasses = val.toInt();
                                });
                              },
                            ),
                          ),

                          // Quick Preset Chips
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [0, 1, 2, 3, 4].map((count) {
                              final isSelected = _bunkSimulatedClasses == count;
                              return AppleBounceable(
                                scaleFactor: 0.92,
                                onTap: () {
                                  AppHaptics.selectionClick();
                                  setState(() {
                                    _bunkSimulatedClasses = count;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF4F46E5)
                                        : (isDark
                                            ? Colors.white10
                                            : Colors.white),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF4F46E5)
                                          : (isDark
                                              ? Colors.white12
                                              : Colors.black.withValues(
                                                  alpha: 0.08)),
                                    ),
                                  ),
                                  child: Text(
                                    count == 0 ? "Reset" : "+$count Bunk",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white70
                                              : const Color(0xFF475569)),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Subject Breakdown Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Subject Breakdown",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          "4 Enrolled Courses",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildSubjectTile(
                      name: "Design & Analysis of Algorithms",
                      code: "CS-301",
                      percentage: 85.7,
                      attended: 18,
                      total: 21,
                      isDark: isDark,
                    ),
                    _buildSubjectTile(
                      name: "Database Management Systems",
                      code: "CS-302",
                      percentage: 78.9,
                      attended: 15,
                      total: 19,
                      isDark: isDark,
                    ),
                    _buildSubjectTile(
                      name: "Operating Systems & Kernels",
                      code: "CS-303",
                      percentage: 69.2,
                      attended: 9,
                      total: 13,
                      isDark: isDark,
                    ),
                    _buildSubjectTile(
                      name: "Computer Organization & Arch",
                      code: "CS-304",
                      percentage: 90.9,
                      attended: 20,
                      total: 22,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 20),

                    // University Policy Sheet
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161E2E) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.shield_outlined,
                                  size: 16,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "University Regulations § 4.2",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "• Minimum 75% attendance is required to be eligible for end-semester examinations.\n"
                            "• A condonation of up to 10% may be granted by the Academic Council for certified medical leave.\n"
                            "• Unexcused shortage below 65% will result in a course repeat designation.",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF64748B),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiPill({
    required String label,
    required String value,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.22),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectTile({
    required String name,
    required String code,
    required double percentage,
    required int attended,
    required int total,
    required bool isDark,
  }) {
    final isLow = percentage < 75.0;
    final buffer = (attended - (0.75 * total)).floor();
    final needed = ((0.75 * total - attended) / 0.25).ceil();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161E2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1)
                            .withValues(alpha: isDark ? 0.20 : 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        code,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${percentage.toStringAsFixed(1)}%",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isLow
                          ? const Color(0xFFEA580C)
                          : const Color(0xFF10B981),
                    ),
                  ),
                  Text(
                    isLow ? "Needs Attendance" : "On Track",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isLow
                          ? const Color(0xFFEA580C)
                          : const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentage / 100.0,
              minHeight: 6.5,
              backgroundColor:
                  isDark ? Colors.white12 : const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                isLow ? const Color(0xFFEA580C) : const Color(0xFF10B981),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$attended of $total attended",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              Text(
                isLow
                    ? "Must attend next $needed classes"
                    : "Can miss ${math.max(0, buffer)} more safely",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isLow
                      ? const Color(0xFFEA580C)
                      : const Color(0xFF6366F1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
