import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const Color primary = Color(0xFF5B5BD6);
  static const Color primaryDark = Color(0xFF4747B1);
  static const Color primaryLight = Color(0xFFEDEDFC);

  // Background - Light
  static const Color bg = Color(0xFFF2F2F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF9F9FB);

  // Background - Dark (Deep Institutional OLED/Apple Dark)
  static const Color bgDark = Color(0xFF0C0C14);
  static const Color surfaceDark = Color(0xFF161622);
  static const Color surfaceAltDark = Color(0xFF1E1E2E);
  static const Color surfaceCardDark = Color(0xFF181826);

  // Text - Light
  static const Color textPrimary = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFFC7C7CC);

  // Text - Dark
  static const Color textPrimaryDark = Color(0xFFF2F2F7);
  static const Color textSecondaryDark = Color(0xFF9E9EA8);
  static const Color textTertiaryDark = Color(0xFF636370);

  // Semantic
  static const Color success = Color(0xFF34C759);
  static const Color emerald = Color(0xFF10B981);
  static const Color warning = Color(0xFFFF9500);
  static const Color danger = Color(0xFFFF3B30);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF007AFF);

  // Borders - Light
  static const Color border = Color(0xFFE5E5EA);
  static const Color divider = Color(0xFFC6C6C8);

  // Borders - Dark
  static const Color borderDark = Color(0xFF262638);
  static const Color dividerDark = Color(0xFF222232);

  // Contextual Dynamic Theme Colors
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bgOf(BuildContext context) =>
      isDark(context) ? bgDark : bg;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? surfaceDark : surface;

  static Color surfaceAltOf(BuildContext context) =>
      isDark(context) ? surfaceAltDark : surfaceAlt;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? textPrimaryDark : textPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? textSecondaryDark : textSecondary;

  static Color textTertiaryOf(BuildContext context) =>
      isDark(context) ? textTertiaryDark : textTertiary;

  static Color borderOf(BuildContext context) =>
      isDark(context) ? borderDark : border;

  static Color dividerOf(BuildContext context) =>
      isDark(context) ? dividerDark : divider;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
