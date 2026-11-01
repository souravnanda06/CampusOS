import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../auth/services/auth_service.dart';
import '../router/app_routes.dart';
import '../shared/widgets/branded_loader.dart';
import '../shared/widgets/campus_os_logo.dart';
import '../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final authService = AuthService();
    
    // Check auth concurrently with a balanced duration (1800ms) to allow the
    // official CampusOS logo, wordmark, tagline, and loader animations to play smoothly.
    final authFuture = authService.tryAutoLogin();
    final delayFuture = Future.delayed(const Duration(milliseconds: 1800));
    
    final results = await Future.wait([authFuture, delayFuture]);
    final isLoggedIn = results[0] as bool;

    if (!mounted) return;

    if (isLoggedIn) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // 1. Logo
              const CampusOSLogo(
                variant: CampusOSLogoVariant.mark,
                width: 96,
                height: 96,
              )
                  .animate()
                  .scale(
                    duration: 500.ms,
                    curve: Curves.easeOutBack,
                    begin: const Offset(0.8, 0.8),
                  )
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              // 2. Wordmark
              const CampusOSLogo(
                variant: CampusOSLogoVariant.accent,
                height: 38,
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 400.ms)
                  .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),

              const SizedBox(height: 12),

              // 3. Tagline
              Text(
                'Your campus. One place.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              )
                  .animate()
                  .fadeIn(delay: 700.ms, duration: 400.ms),

              const Spacer(),

              // 4. Subtle Loader
              const Padding(
                padding: EdgeInsets.only(bottom: 48),
                child: BrandedLoader(
                  color: AppColors.primary,
                  size: 32,
                ),
              )
                  .animate()
                  .fadeIn(delay: 1000.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
