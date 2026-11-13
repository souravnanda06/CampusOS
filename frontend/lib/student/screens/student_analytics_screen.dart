import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../auth/providers/user_provider.dart';
import '../../shared/services/attendance_service.dart';
import '../../shared/widgets/motion/apple_spring_scroll_physics.dart';

class StudentAnalyticsScreen extends StatefulWidget {
  const StudentAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<StudentAnalyticsScreen> createState() => _StudentAnalyticsScreenState();
}

class _StudentAnalyticsScreenState extends State<StudentAnalyticsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<Map<String, dynamic>> _fetchRealStats() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final uid = userProvider.user?.id;
    if (uid == null) return {};

    try {
      final data =
          await AttendanceService().getStudentComprehensiveAnalytics(uid);
      return data ?? {};
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }
    return {};
  }

  Color _getColorForSubject(String subject) {
    final s = subject.toLowerCase();
    if (s.contains("math")) return const Color(0xFF00B5FF);
    if (s.contains("phys")) return const Color(0xFFFF6B6B);
    if (s.contains("chem")) return const Color(0xFF06FFA5);
    if (s.contains("data") || s.contains("computer")) return const Color(0xFF9D4EDD);
    return const Color(0xFFFF9F43); // Default Orange
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchRealStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            );
          }

          final data = snapshot.data ?? {};
          final double overall = (data['overallPercentage'] ?? 0).toDouble();
          final String consistency = data['consistency'] ?? "N/A";
          final List subjects = data['subjects'] as List? ?? [];
          
          // Parse dynamic lists safely
          final List<double> weeklyActivity = (data['weeklyActivity'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ?? [];
          final List<double> trendPoints = (data['trendPoints'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ?? [];

          // Determine risk label
          String riskLevel = "Low";
          if (overall < 65) {
            riskLevel = "High";
          } else if (overall < 75) {
            riskLevel = "Medium";
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              physics: AppleSpringScrollPhysics.always,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildHeader(),

                  const SizedBox(height: 32),

                  // 1. Real Insight Grid
                  _buildInsightGrid(
                    attendance: "${overall.toStringAsFixed(1)}%",
                    consistency: consistency,
                    riskLevel: riskLevel,
                  ),

                  const SizedBox(height: 32),

                  // 2. Real Heatmap
                  _buildSectionTitle("Weekly Activity", subtitle: "Last 7 Days"),
                  const SizedBox(height: 16),
                  _buildRealHeatMap(weeklyActivity),

                  const SizedBox(height: 32),

                  // 3. Real Trend Graph
                  _buildSectionTitle("Attendance Trend", subtitle: "Last 10 Sessions"),
                  const SizedBox(height: 16),
                  _buildRealTrendGraph(trendPoints),

                  const SizedBox(height: 32),

                  // 4. Real Subject List
                  _buildSectionTitle("Subject Performance"),
                  const SizedBox(height: 16),
                  
                  if (subjects.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        "No classes attended yet.",
                        style: GoogleFonts.outfit(color: Colors.grey),
                      ),
                    )
                  else
                    Column(
                      children: subjects.map<Widget>((s) {
                        return _buildSubjectCard(
                          s['subject'] ?? "Unknown",
                          ((s['percentage'] ?? 0) as num).toDouble() / 100,
                          _getColorForSubject(s['subject'] ?? ""),
                          s['trend'] ?? "Stable",
                          0, 
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 32),

                  _buildAISummaryFooter(overall),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Analytics",
            style: GoogleFonts.outfit(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ).animate().fadeIn().slideX(begin: -0.1, end: 0),
          const SizedBox(height: 4),
          Text(
            "Real-time attendance intelligence",
            style: GoogleFonts.outfit(
              fontSize: 15,
              color: const Color(0xFF8A93A2),
              fontWeight: FontWeight.w500,
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }

  Widget _buildInsightGrid({
    required String attendance,
    required String consistency,
    required String riskLevel
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInsightCard(
                title: "Attendance",
                value: attendance,
                subtext: "Current Avg",
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF00B5FF),
                isHero: true,
                delay: 100,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInsightCard(
                title: "Consistency",
                value: consistency,
                subtext: "Based on logs",
                icon: Icons.analytics_rounded,
                color: const Color(0xFF9D4EDD),
                delay: 200,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildRiskCard(riskLevel, delay: 300),
      ],
    );
  }

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildInsightCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    bool isHero = false,
    required int delay,
  }) {
    return Container(
      height: isHero ? 180 : 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.5,
          colors: [
            color.withValues(alpha: 0.05),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Icon(Icons.arrow_outward_rounded,
                  color: Colors.grey.shade300, size: 16),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: isHero ? 32 : 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            subtext,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).scale(curve: Curves.easeOutBack);
  }

  Widget _buildRiskCard(String level, {required int delay}) {
    Color color = level == "High" ? AppTheme.errorRed : AppTheme.successGreen;
    if (level == "Medium") color = Colors.orange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Risk Level", 
                style: GoogleFonts.outfit(
                  color: Colors.grey[600], 
                  fontSize: 14
                )
              ),
              Text(
                level, 
                style: GoogleFonts.outfit(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold, 
                  color: color
                )
              ),
              Text(
                "Safe zone > 75%",
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.2),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.2, 1.2),
                    duration: 1500.ms,
                  ),
              Icon(Icons.shield_outlined, color: color, size: 28),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).scale(curve: Curves.easeOutBack);
  }

  Widget _buildRealHeatMap(List<double> data) {
    if (data.isEmpty) return const Text("No recent activity data");
    
    final labels = ["-6d", "-5d", "-4d", "-3d", "-2d", "Yst", "Today"];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(data.length, (index) {
          // Normalize intensity for visual (0.0 to 1.0)
          double intensity = data[index].clamp(0.0, 1.0);
          
          return Column(
            children: [
              Tooltip(
                message: "${(intensity * 100).toInt()}% Activity",
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(
                      alpha: intensity == 0 ? 0.1 : (0.2 + intensity * 0.8).clamp(0.0, 1.0)
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                labels[index],
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }),
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildRealTrendGraph(List<double> points) {
    if (points.isEmpty) return const SizedBox();

    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow(),
      ),
      child: CustomPaint(
        painter: _DynamicTrendPainter(points: points),
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSubjectCard(
      String subject, double percentage, Color color, String trend, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.book_rounded, color: color, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        "Trend: $trend",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                "${(percentage * 100).toInt()}%",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Bar
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.6), color],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (700 + index * 100).ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildAISummaryFooter(double overall) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppTheme.primaryBlue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AI Insight",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "You are currently at ${overall.toStringAsFixed(1)}%. ${overall > 75 ? 'Great job maintaining consistency!' : 'Try attending more classes to improve.'}",
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 1200.ms).slideY(begin: 0.2, end: 0);
  }
}

class _DynamicTrendPainter extends CustomPainter {
  final List<double> points; 
  _DynamicTrendPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = AppTheme.primaryBlue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final width = size.width;
    final height = size.height;
    
    final stepX = width / (points.length - 1);

    // Map 1.0 (Present) to top, 0.0 (Absent) to bottom
    double getY(double val) => height - (val * height * 0.7) - (height * 0.15);

    path.moveTo(0, getY(points[0]));

    for (int i = 1; i < points.length; i++) {
      final x = i * stepX;
      final y = getY(points[i]);
      
      // Monotone cubic interpolation for smooth curve
      final prevX = (i - 1) * stepX;
      final prevY = getY(points[i - 1]);
      
      final midX = (prevX + x) / 2;
      
      path.cubicTo(midX, prevY, midX, y, x, y);
    }

    // Shadow Gradient
    final shadowPath = Path.from(path)
      ..lineTo(width, height)
      ..lineTo(0, height)
      ..close();

    final shadowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.primaryBlue.withValues(alpha: 0.2),
          AppTheme.primaryBlue.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(shadowPath, shadowPaint);
    canvas.drawPath(path, paint);

    // Draw Dots
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = getY(points[i]);
      
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(x, y), 
        5, 
        Paint()..color = AppTheme.primaryBlue..style = PaintingStyle.stroke..strokeWidth = 2
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DynamicTrendPainter oldDelegate) {
    if (identical(points, oldDelegate.points)) return false;
    if (points.length != oldDelegate.points.length) return true;
    for (int i = 0; i < points.length; i++) {
      if (points[i] != oldDelegate.points[i]) return true;
    }
    return false;
  }
}