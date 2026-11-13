import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

import '../../../auth/models/user_model.dart';
import '../../../../shared/widgets/motion/apple_bounceable.dart';

class AttendanceCard extends StatelessWidget {
  final UserModel? user;
  final double overallAttendance;
  final Map<String, dynamic>? attendanceAnalytics;
  final void Function(int) onNavigateToTab;
  final VoidCallback? onCardTap;

  const AttendanceCard({
    Key? key,
    required this.user,
    required this.overallAttendance,
    this.attendanceAnalytics,
    required this.onNavigateToTab,
    this.onCardTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double percentage = overallAttendance.clamp(0.0, 100.0);
    final int displayPercent = percentage.toInt();

    final bool isLow = percentage < 75;
    final bool isExcellent = percentage >= 85;

    final String statusLabel = isLow
        ? "Low"
        : (isExcellent ? "Excellent" : "Good");

    final Color statusColor = isLow
        ? const Color(0xFFEA580C)
        : const Color(0xFF16A34A);

    final Color statusBg = isLow
        ? const Color(0xFFFFF3EB)
        : const Color(0xFFEDFDF2);

    final Color statusDotColor = isLow
        ? const Color(0xFFF97316)
        : const Color(0xFF22C55E);

    final String subtitle = isLow
        ? "Low attendance record.\nJoin today's classes to climb back."
        : (isExcellent
            ? "Excellent attendance record.\nKeep up the great work this term."
            : "Good attendance record.\nAttend classes to maintain your streak.");

    return AppleBounceable(
      scaleFactor: 0.98,
      onTap: onCardTap ?? () => onNavigateToTab(1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: isDark ? const Color(0xFF161622) : Colors.white,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : const Color(0xFF6366F1).withValues(alpha: 0.08),
              blurRadius: 32,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Apple-grade ambient atmospheric aura behind the radial gauge (zero muddy grey)
              Positioned(
                top: 10,
                right: -15,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(0.15, -0.1),
                      radius: 0.85,
                      colors: [
                        (isLow ? const Color(0xFFFB923C) : const Color(0xFF34D399))
                            .withValues(alpha: isDark ? 0.22 : 0.16),
                        (isLow ? const Color(0xFFF97316) : const Color(0xFF10B981))
                            .withValues(alpha: isDark ? 0.10 : 0.06),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.50, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -30,
                right: 50,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isLow ? const Color(0xFFFDBA74) : const Color(0xFF6EE7B7))
                            .withValues(alpha: isDark ? 0.12 : 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Card Body Content (Header + Percentage + Gauge) ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header: Squircle Icon + "Attendance" + Status Pill
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF2A1C16)
                                        : const Color(0xFFFFF3EB),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today_rounded,
                                    color: Color(0xFFEA580C),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "Attendance",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),

                            // Status Pill Badge (e.g. • Low)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? statusColor.withValues(alpha: 0.18)
                                    : statusBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.25),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: statusDotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    statusLabel,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: statusColor,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Center Section: Big Display Percentage & Gauge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TweenAnimationBuilder<int>(
                                    tween: IntTween(begin: 0, end: displayPercent),
                                    duration: const Duration(milliseconds: 1400),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, val, child) {
                                      return RichText(
                                        text: TextSpan(
                                          text: "$val",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 50,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                            letterSpacing: -1.2,
                                            height: 1.0,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: "%",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? Colors.white70
                                                    : const Color(0xFF475569),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    subtitle,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white60
                                          : const Color(0xFF64748B),
                                      height: 1.38,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Radial Gauge
                            SizedBox(
                              width: 124,
                              height: 124,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                        begin: 0.0, end: percentage / 100.0),
                                    duration: const Duration(milliseconds: 1400),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, progressVal, child) {
                                      return CustomPaint(
                                        size: const Size(124, 124),
                                        painter: _AppleAttendanceRingPainter(
                                          progress: progressVal,
                                          trackColor: isDark
                                              ? Colors.white.withValues(alpha: 0.08)
                                              : const Color(0xFFFFE4D6),
                                          progressColor: isLow
                                              ? const Color(0xFFF97316)
                                              : const Color(0xFF22C55E),
                                          strokeWidth: 13.0,
                                        ),
                                      );
                                    },
                                  ),

                                  // Inner elevated pure white circular container with calendar icon
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark
                                          ? const Color(0xFF1E2130)
                                          : Colors.white,
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.10)
                                            : Colors.white,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isLow
                                                  ? const Color(0xFFEA580C)
                                                  : const Color(0xFF16A34A))
                                              .withValues(alpha: isDark ? 0.20 : 0.08),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                              alpha: isDark ? 0.35 : 0.05),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.calendar_today_outlined,
                                      color: isLow
                                          ? const Color(0xFFEA580C)
                                          : const Color(0xFF16A34A),
                                      size: 23,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // --- Bottom Full-Bleed Status Strip (as seen in latest screenshot) ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2034)
                          : const Color(0xFFF0F2FE),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(28),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF4F46E5),
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "All lectures and labs are on schedule today.",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF1E293B),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppleAttendanceRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _AppleAttendanceRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final sweepAngle = (2 * math.pi * progress).clamp(0.0, 2 * math.pi);
    const startAngle = -math.pi / 2;

    if (progress > 0.005) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );

      // Indicator knob at the end tip of arc
      final endAngle = startAngle + sweepAngle;
      final knobCenter = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );

      // Soft ambient glow around knob
      final glowPaint = Paint()
        ..color = progressColor.withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(knobCenter, strokeWidth / 2 + 2, glowPaint);

      // Outer crisp knob ring
      final knobPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(knobCenter, strokeWidth / 2, knobPaint);

      // White inner focal point
      final knobCorePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(knobCenter, 3.2, knobCorePaint);
    } else {
      // 0% indicator knob at 12 o'clock position (as seen in screenshot)
      final knobCenter = Offset(center.dx, center.dy - radius);

      final glowPaint = Paint()
        ..color = progressColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(knobCenter, strokeWidth / 2 + 2, glowPaint);

      final knobPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(knobCenter, strokeWidth / 2, knobPaint);

      final knobCorePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(knobCenter, 3.2, knobCorePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AppleAttendanceRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
