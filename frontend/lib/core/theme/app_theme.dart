import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'campus_os_theme.dart';

class AppTheme {
  // 1. Core Palette (Aliased to AppColors)
  static const Color primaryBlue = AppColors.primary;
  static const Color secondaryTeal = Color(0xFF00C9A7); // Preserved for legacy illustration
  static const Color accentPurple = Color(0xFF6C63FF); // Preserved
  static const Color darkBackground = Color(0xFF1A1A2E); // Adjusted to match design spec
  static const Color lightBackground = AppColors.bg;
  static const Color surfaceDark = Color(0xFF16213E);

  // Semantic Colors (Aliased)
  static const Color successGreen = AppColors.success;
  static const Color successColor = AppColors.success;
  static const Color errorRed = AppColors.danger;
  static const Color errorColor = AppColors.danger;
  static const Color warningOrange = AppColors.warning;

  // Legacy support
  static const Color primarySeed = AppColors.primary;

  // 2. Gradients
  static const LinearGradient mainGradient = AppColors.primaryGradient;

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [accentPurple, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient fireGradient = LinearGradient(
    colors: [warningOrange, errorRed],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static const LinearGradient darkBlueGradient = AppColors.darkCardGradient;

  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // 3. Text Styles
  static TextTheme textTheme = GoogleFonts.plusJakartaSansTextTheme();

  // 4. Light Theme (Delegated to CampusOSTheme)
  static ThemeData get lightTheme => CampusOSTheme.lightTheme;

  // 5. Dark Theme (Placeholder for future)
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
      primary: primaryBlue,
      secondary: secondaryTeal,
      error: errorRed,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );

  // 6. Utilities & Decorations
  static List<BoxShadow> softShadow({Color? color}) {
    return [
      BoxShadow(
        color: (color ?? const Color(0xFF000000)).withValues(alpha: 0.05),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ];
  }

  static List<BoxShadow> mediumShadow() {
    return [
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.1),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ];
  }

  static List<BoxShadow> coloredGlow(Color color, {double opacity = 0.3}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static BoxDecoration glassDecoration(
      {double opacity = 0.1, double radius = 24}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
    );
  }

  static BoxDecoration glassmorphic({
    Color? color,
    double borderRadius = 20,
    bool hasBorder = true,
  }) {
    return BoxDecoration(
      color: (color ?? Colors.white).withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(borderRadius),
      border:
          hasBorder ? Border.all(color: Colors.white.withValues(alpha: 0.5)) : null,
      boxShadow: softShadow(),
    );
  }

  static ShaderMask gradientText({
    required Widget child,
    required Gradient gradient,
  }) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: child,
    );
  }
}
