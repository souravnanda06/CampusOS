// =========================================================
// LEGACY / DEACTIVATED: OnboardingScreen
// This screen was retired in Step 12. Unauthenticated 
// users are now directed to LoginScreen directly.
// =========================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/widgets/campus_os_logo.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final GlobalKey _buttonKey = GlobalKey(); // Capture button position
  int _currentPage = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutQuart,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() {
    // Show spinner briefly for immediate feedback
    setState(() => _isLoading = true);

    // Almost instant transition (50ms to allow button tap visual to cycle)
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;

      // 1. Get Button Center
      final RenderBox? renderBox =
          _buttonKey.currentContext?.findRenderObject() as RenderBox?;
      Offset center = Offset.zero;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        center = position + Offset(size.width / 2, size.height / 2);
      } else {
        // Fallback to center of screen if renderbox fails
        final size = MediaQuery.of(context).size;
        center = Offset(size.width / 2, size.height / 2);
      }

      // 2. Push with Circular Reveal
      Navigator.pushReplacement(
        context,
        _createCircularRevealRoute(const LoginScreen(), center),
      );
    });
  }

  Route _createCircularRevealRoute(Widget page, Offset center) {
    return PageRouteBuilder(
      transitionDuration:
          const Duration(milliseconds: 1200), // Slower, premium feel
      reverseTransitionDuration: const Duration(milliseconds: 1200),
      opaque: false,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.fastOutSlowIn,
        );
        return ClipPath(
          clipper: CircleRevealClipper(
              center: center, fraction: curvedAnimation.value),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1B3F), // Midnight Navy
      body: Stack(
        children: [
          // Dynamic Background
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(seconds: 1),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _getGradientColors(_currentPage),
                ),
              ),
            ),
          ),

          // Ambient Particles (Simulated)
          ...List.generate(5, (index) => _buildAmbientParticle(index)),

          // Page Content
          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildPage1Brand(),
              _buildPage2BLE(),
              _buildPage3Analytics(),
              _buildPage4Sync(),
              _buildPage5GetStarted(),
            ],
          ),

          // Bottom Navigation (Indicators + Skip)
          if (_currentPage < 4)
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => _pageController.jumpToPage(4),
                    child: Text(
                      "Skip",
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Row(
                    children:
                        List.generate(5, (index) => _buildIndicator(index)),
                  ),
                  IconButton(
                    onPressed: _nextPage,
                    icon: const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Color> _getGradientColors(int page) {
    switch (page) {
      case 0:
        return [
          const Color(0xFF0B1B3F),
          const Color(0xFF1E3A8A)
        ]; // Navy -> Royal
      case 1:
        return [
          const Color(0xFF1E3A8A),
          const Color(0xFF2563EB)
        ]; // Royal -> Blue
      case 2:
        return [
          const Color(0xFF312E81),
          const Color(0xFF4F46E5)
        ]; // Indigo -> Violet
      case 3:
        return [
          const Color(0xFF0F172A),
          const Color(0xFF334155)
        ]; // Slate -> Grey
      case 4:
        return [
          const Color(0xFF1E1B4B),
          const Color(0xFF312E81)
        ]; // Deep Indigo
      default:
        return [const Color(0xFF0B1B3F), const Color(0xFF1E3A8A)];
    }
  }

  Widget _buildIndicator(int index) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 6,
      width: isActive ? 24 : 6,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(3),
        boxShadow: isActive
            ? [
                BoxShadow(
                    color: Colors.white.withValues(alpha: 0.5), blurRadius: 8)
              ]
            : null,
      ),
    );
  }

  Widget _buildAmbientParticle(int index) {
    final random = Random(index);
    return Positioned(
      top: random.nextDouble() * 600,
      left: random.nextDouble() * 300,
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(0.5, 0.5),
            end: const Offset(1.5, 1.5),
            duration: Duration(seconds: 2 + index),
          )
          .moveY(
            begin: 0,
            end: -50,
            duration: Duration(seconds: 5 + index),
          ),
    );
  }

  // --- PAGE 1: BRAND ---
  Widget _buildPage1Brand() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          const SizedBox(
            width: 130,
            height: 130,
            child: CampusOSLogo(
              variant: CampusOSLogoVariant.mark,
            ),
          ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 40),
          Text(
            "Welcome to CampusOS",
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 16),
          Text(
            "Smarter. Faster. Seamless Attendance.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2, end: 0),
          const Spacer(),
        ],
      ),
    );
  }

  // --- PAGE 2: BLE ---
  Widget _buildPage2BLE() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          SizedBox(
            width: 200,
            height: 200,
            child: CustomPaint(
              painter: BleRadarPainter(),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            "Smart Attendance",
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ).animate().fadeIn().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 16),
          Text(
            "Mark your presence instantly using BLE.\nSecure. Automatic. Frictionless.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
          const Spacer(),
        ],
      ),
    );
  }

  // --- PAGE 3: ANALYTICS ---
  Widget _buildPage3Analytics() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          SizedBox(
            width: 220,
            height: 180,
            child: CustomPaint(
              painter: AnalyticsGraphPainter(),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            "Track Progress",
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ).animate().fadeIn().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 16),
          Text(
            "Your attendance analytics beautifully visualized.\nSmarter decisions. Better outcomes.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
          const Spacer(),
        ],
      ),
    );
  }

  // --- PAGE 4: SYNC ---
  Widget _buildPage4Sync() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          SizedBox(
            width: 240,
            height: 160,
            child: CustomPaint(
              painter: SyncDataPainter(),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            "Stay Connected",
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ).animate().fadeIn().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 16),
          Text(
            "Real-time updates between students and teachers.\nAlways in sync. Always informed.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
          const Spacer(),
        ],
      ),
    );
  }

  // --- PAGE 5: GET STARTED ---
  Widget _buildPage5GetStarted() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Small Logo
          const CampusOSLogo(
            variant: CampusOSLogoVariant.mark,
            width: 80,
            height: 80,
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 32),
          Text(
            "Ready to begin?",
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 48),

          // Premium CTA Button
          GestureDetector(
            onTap: _isLoading ? null : _finishOnboarding,
            child: Container(
              key: _buttonKey, // Capture position
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Get Started",
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white),
                      ],
                    ),
            ),
          )
              .animate()
              .fadeIn(delay: 500.ms)
              .slideY(begin: 0.2, end: 0)
              .animate(
                  target: _isLoading ? 0 : 1,
                  onPlay: (c) => c.repeat(reverse: true))
              .shimmer(duration: 2000.ms, delay: 1000.ms),

          const Spacer(),
        ],
      ),
    );
  }
}

// --- CUSTOM ANIMATION CLIPPERS ---

class CircleRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double fraction;

  CircleRevealClipper({required this.center, required this.fraction});

  @override
  Path getClip(Size size) {
    // Calculate radius to cover the entire screen from the center point
    final double maxW = max(center.dx, size.width - center.dx);
    final double maxH = max(center.dy, size.height - center.dy);
    final double maxRadius = sqrt(maxW * maxW + maxH * maxH) + 20;

    final double radius = maxRadius * fraction;

    final path = Path();
    path.addOval(Rect.fromCircle(center: center, radius: radius));
    return path;
  }

  @override
  bool shouldReclip(covariant CircleRevealClipper oldClipper) {
    return oldClipper.fraction != fraction;
  }
}

// --- CUSTOM PAINTERS ---

class BleRadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Concentric circles
    for (int i = 1; i <= 3; i++) {
      paint.color = Colors.white.withValues(alpha: 0.1 * i);
      canvas.drawCircle(center, i * 30.0, paint);
    }

    // Center icon
    final iconPaint = Paint()..color = Colors.blue;
    canvas.drawCircle(center, 10, iconPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AnalyticsGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width * 0.3, size.height * 0.7,
        size.width * 0.5, size.height * 0.4);
    path.quadraticBezierTo(
        size.width * 0.7, size.height * 0.6, size.width, size.height * 0.1);

    canvas.drawPath(path, paint);

    // Dots
    final dotPaint = Paint()..color = Colors.blueAccent;
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.4), 6, dotPaint);
    canvas.drawCircle(Offset(size.width, size.height * 0.1), 6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SyncDataPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Left Circle (Teacher)
    canvas.drawCircle(Offset(40, size.height / 2), 30, paint);

    // Right Circle (Student)
    canvas.drawCircle(Offset(size.width - 40, size.height / 2), 30, paint);

    // Connecting Lines
    final linePaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(80, size.height / 2);
    path.lineTo(size.width - 80, size.height / 2);

    // Dashed effect (simulated)
    double dashWidth = 10;
    double dashSpace = 5;
    double distance = 0;
    while (distance < size.width - 160) {
      canvas.drawLine(Offset(80 + distance, size.height / 2),
          Offset(80 + distance + dashWidth, size.height / 2), linePaint);
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
