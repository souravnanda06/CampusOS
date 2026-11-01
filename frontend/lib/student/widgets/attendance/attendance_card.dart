import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:flutter_animate/flutter_animate.dart';

import '../../../auth/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shimmering_text.dart';

class AttendanceCard extends StatelessWidget {
  final UserModel? user;
  final double overallAttendance;
  final Map<String, dynamic>? attendanceAnalytics;
  final void Function(int) onNavigateToTab;

  const AttendanceCard({
    Key? key,
    required this.user,
    required this.overallAttendance,
    this.attendanceAnalytics,
    required this.onNavigateToTab,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double percentage = overallAttendance;
    final int displayPercent = percentage.toInt();

    String status = "Low";
    if (percentage > 90) {
      status = "Excellent";
    } else if (percentage > 75) {
      status = "Good";
    } else if (percentage > 60) {
      status = "Average";
    }

    final int attended = (attendanceAnalytics?['attendedClasses'] as num?)?.toInt() ?? 0;
    final int total = (attendanceAnalytics?['totalClasses'] as num?)?.toInt() ?? 0;
    final int absent = (total - attended).clamp(0, total);

    return InkWell(
      onTap: () => onNavigateToTab(1), // Navigates to Passport tab
      borderRadius: BorderRadius.circular(32),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: AppColors.darkCardGradient,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.25),
              blurRadius: 50,
              spreadRadius: 4,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded,
                              color: AppColors.warning, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            "Overall Status",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ShimmeringText(
                        text: status,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "You're maintaining a\n$status attendance record.",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                              blurRadius: 50,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1.2, 1.2),
                          duration: 3000.ms),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: percentage / 100),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return SizedBox(
                            width: 130,
                            height: 130,
                            child: CustomPaint(
                              painter: _RingPainter(value),
                            ),
                          );
                        },
                      ),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: displayPercent),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Text(
                            "$value%",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).scale(),
              ],
            ),
            if (total > 0) ...[
              const SizedBox(height: 24),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem("Total", total.toString(), AppColors.textTertiary),
                  Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.1)),
                  _buildStatItem("Present", attended.toString(), AppColors.success),
                  Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.1)),
                  _buildStatItem("Absent", absent.toString(), AppColors.danger),
                ],
              ),
            ]
          ],
        ),
      ),
    ).animate().slideY(begin: 0.2, duration: 600.ms, curve: Curves.easeOutQuart).fadeIn();
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percentage;

  _RingPainter(this.percentage);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background track
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    // Gradient track
    final gradientPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    // Draw full background circle
    canvas.drawCircle(center, radius, bgPaint);

    // Draw progress arc
    final sweepAngle = 2 * math.pi * percentage;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      gradientPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.percentage != percentage;
  }
}
