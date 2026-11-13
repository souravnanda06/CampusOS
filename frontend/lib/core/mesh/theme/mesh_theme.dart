import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// CampusOS Mesh Design Tokens and Theme Definition.
///
/// Implements an Apple-grade Telegram-style visual language:
/// - Inter typography with JetBrains Mono role tags
/// - Indigo-to-Violet accent gradient
/// - Multi-stop vertical background gradient
/// - Frosted glass surfaces with BackdropFilter blur & hairline borders
/// - Layered soft shadows and high-contrast accessible color palette
class AppColors {
  AppColors._();

  // Accent Gradient & Colors
  static const Color accentIndigo = Color(0xFF5B5BD6);
  static const Color accentViolet = Color(0xFF7A56F0);
  static const Color accentDark = Color(0xFF4545B8);

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentIndigo, accentViolet],
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5850E2), Color(0xFF8359F6)],
  );

  // Background Gradient
  static const Color bgStop1 = Color(0xFFECEEFF);
  static const Color bgStop2 = Color(0xFFF4F0FF);
  static const Color bgStop3 = Color(0xFFEEF3FB);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgStop1, bgStop2, bgStop3],
  );

  // Typography Colors
  static const Color textPrimary = Color(0xFF14142B);
  static const Color textSecondary = Color(0xFF5A5D75);
  static const Color textMeta = Color(0xFF6B6F80);

  // Status & Semantic Colors
  static const Color successGreen = Color(0xFF22A06B);
  static const Color successGreenLight = Color(0xFFE8F7F0);

  // Warning Amber (Content Moderation / Safety Flag)
  static const Color warningAmberBg = Color(0xFFFFF3DC);
  static const Color warningAmberText = Color(0xFF7A4A00);
  static const Color warningAmberRing = Color(0xFFF2C77B);

  // Frosted Glass & Surface Fills
  static const Color frostedGlassWhite = Color(0xD6FFFFFF); // ~84% opacity
  static const Color frostedCardWhite = Color(0xE0FFFFFF); // ~88% opacity
  static const Color frostedHeaderWhite = Color(0xD1FFFFFF); // ~82% opacity
  static const Color hairlineBorder = Color(0x18000000);
  static const Color glassBorder = Color(0x33FFFFFF);

  // Interaction Tints
  static const Color inkWellIndigo12 = Color(0x1F5B5BD6); // 12%
  static const Color inkWellIndigo6 = Color(0x0F5B5BD6); // 6%

  // Outgoing / Incoming Chat Surfaces
  static const Color incomingBubbleBg = Colors.white;
  static const Color outgoingCheckmarks = Color(0xFFE6E6FF);
  static const Color composerGrey = Color(0xFF9A9CC4);
}

class AppRadii {
  AppRadii._();

  static const double card = 26.0;
  static const double cardInner = 24.0;
  static const double bubble = 20.0;
  static const double bubbleTail = 6.0;
  static const double bubbleJoined = 6.0;
  static const double composer = 28.0;
  static const double pill = 999.0;
  static const double appIcon = 14.0;
  static const double avatarLarge = 52.0;
  static const double avatarMedium = 42.0;
  static const double avatarSmall = 30.0;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius composerRadius = BorderRadius.all(Radius.circular(composer));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius appIconRadius = BorderRadius.all(Radius.circular(appIcon));
}

class AppShadows {
  AppShadows._();

  // Layered soft shadow for floating cards
  static const List<BoxShadow> softCard = [
    BoxShadow(
      color: Color(0x0A14142B),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x055B5BD6),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];

  // Inset top highlight for gradient surfaces
  static const BoxShadow insetTopHighlight = BoxShadow(
    color: Color(0x47FFFFFF),
    offset: Offset(0, 1),
    blurRadius: 1,
  );

  // Mesh status card colored glow
  static const List<BoxShadow> meshStatusCard = [
    BoxShadow(
      color: Color(0x3D5B5BD6),
      blurRadius: 26,
      offset: Offset(0, 10),
      spreadRadius: -4,
    ),
  ];

  // Outgoing bubble colored shadow
  static const List<BoxShadow> outgoingBubble = [
    BoxShadow(
      color: Color(0x305B5BD6),
      blurRadius: 14,
      offset: Offset(0, 5),
      spreadRadius: -2,
    ),
  ];

  // Incoming bubble subtle shadow
  static const List<BoxShadow> incomingBubble = [
    BoxShadow(
      color: Color(0x0C14142B),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];

  // Floating Composer shadow
  static const List<BoxShadow> composerShadow = [
    BoxShadow(
      color: Color(0x1414142B),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -2,
    ),
  ];

  // App Icon shadow
  static const List<BoxShadow> appIconShadow = [
    BoxShadow(
      color: Color(0x405B5BD6),
      blurRadius: 14,
      offset: Offset(0, 5),
    ),
  ];
}

class AppTextStyles {
  AppTextStyles._();

  // Screen 1: Header Overline
  static TextStyle headerOverline = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.accentIndigo,
    letterSpacing: 0.3,
  );

  // Screen 1: Header Title (36px, weight 700, tight letter-spacing)
  static TextStyle headerTitle = GoogleFonts.inter(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    color: AppColors.textPrimary,
  );

  // Status Card Title & Subtitle
  static TextStyle statusTitle = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: -0.2,
  );

  static TextStyle statusSubtitle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Colors.white.withValues(alpha: 0.9),
  );

  // Section Label (12px, weight 600, letter-spaced)
  static TextStyle sectionLabel = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: AppColors.textSecondary,
  );

  // Channel Row
  static TextStyle channelName = GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  static TextStyle channelPreview = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle channelTime = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textMeta,
  );

  // Screen 2: Chat Header
  static TextStyle chatHeaderTitle = GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  static TextStyle chatHeaderStatus = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // Role Tag (JetBrains Mono 500)
  static TextStyle roleTag = GoogleFonts.jetBrainsMono(
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    color: AppColors.successGreen,
  );

  // Sender Name in Group
  static TextStyle senderName = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.accentIndigo,
  );

  // Date Chip ("Today")
  static TextStyle dateChip = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  // Messages
  static TextStyle incomingMessageText = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  static TextStyle outgoingMessageText = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: Colors.white,
    height: 1.35,
  );

  static TextStyle metaIncoming = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textMeta,
  );

  static TextStyle metaOutgoing = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: Colors.white.withValues(alpha: 0.85),
  );

  // Flagged Message Card
  static TextStyle flaggedTitle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.warningAmberText,
  );

  static TextStyle flaggedSubtitle = GoogleFonts.inter(
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    color: AppColors.warningAmberText.withValues(alpha: 0.85),
  );

  // Composer
  static TextStyle composerHint = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textMeta,
  );

  static TextStyle composerInput = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
}

/// Helper that returns ThemeData enriched with Mesh tokens
ThemeData createMeshTheme(ThemeData baseTheme) {
  return baseTheme.copyWith(
    scaffoldBackgroundColor: AppColors.bgStop1,
    colorScheme: baseTheme.colorScheme.copyWith(
      primary: AppColors.accentIndigo,
      secondary: AppColors.accentViolet,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
    textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme),
  );
}
