import 'package:flutter/material.dart';

/// SRISHTI 2.7 Visual Identity and Color Tokens.
///
/// Anchored on Apple-inspired minimalism with a white canvas,
/// refined dark surfaces, and a signature cyan-to-electric-blue gradient.
class AppColors {
  AppColors._();

  // Core Brand Palette
  static const Color deepBlack = Color(0xFF050505);
  static const Color nearBlack = Color(0xFF080B10);
  static const Color white = Color(0xFFFFFFFF);
  static const Color softWhite = Color(0xFFF5F7FA);
  static const Color cyan = Color(0xFF00D9FF);
  static const Color blue = Color(0xFF1557FF);
  static const Color deepBlue = Color(0xFF1237D6);

  // Aliases for compatibility
  static const Color electricBlue = blue;
  static const Color darkBlue = deepBlue;

  // Primary Canvas & Surfaces
  static const Color background = softWhite;
  static const Color backgroundSecondary = Color(0xFFEFF2F6);
  static const Color surface = white;
  static const Color surfaceDark = nearBlack;
  static const Color surfaceDarkElevated = Color(0xFF0F1522);
  static const Color surfaceDarkCard = Color(0xFF141C2B);

  // Signature Brand Gradient: Cyan → Electric Blue (#00D9FF → #1557FF)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [cyan, blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient horizontalBrandGradient = LinearGradient(
    colors: [cyan, blue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Dark Hero Card Background with subtle atmospheric glow
  static const LinearGradient darkHeroGradient = LinearGradient(
    colors: [
      Color(0xFF080B10),
      Color(0xFF0B111A),
      Color(0xFF0E1624),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF080B10), Color(0xFF111827)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Subtle Ambient Glow Gradient for Hero Actions
  static const LinearGradient subtleGlowGradient = LinearGradient(
    colors: [Color(0x3300D9FF), Color(0x331557FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Typography Colors
  static const Color textPrimary = Color(0xFF080B10);
  static const Color textSecondary = Color(0xFF5A687C);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDarkPrimary = Color(0xFFF8FAFC);
  static const Color textDarkSecondary = Color(0xFF94A3B8);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFEDF2F7);
  static const Color borderDark = Color(0xFF1A2333);
  static const Color borderDarkSubtle = Color(0xFF28354A);

  // Semantic Status Colors
  static const Color green = Color(0xFF10B981);
  static const Color success = green;
  static const Color successBg = Color(0xFFECFDF5);
  static const Color successBorder = Color(0xFFA7F3D0);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color warningBorder = Color(0xFFFDE68A);

  static const Color error = Color(0xFFEF4444);
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color errorBorder = Color(0xFFFECACA);

  static const Color info = Color(0xFF0284C7);
  static const Color infoBg = Color(0xFFF0F9FF);
  static const Color infoBorder = Color(0xFFBAE6FD);

  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleBg = Color(0xFFF5F3FF);
  static const Color purpleBorder = Color(0xFFDDD6FE);

  // Premium Soft Shadows
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF080B10).withAlpha(12),
          blurRadius: 18,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get floatingBarShadow => [
        BoxShadow(
          color: const Color(0xFF080B10).withAlpha(18),
          blurRadius: 28,
          offset: const Offset(0, 8),
          spreadRadius: -2,
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF080B10).withAlpha(14),
          blurRadius: 16,
          offset: const Offset(0, 3),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get glowShadow => [
        BoxShadow(
          color: blue.withAlpha(70),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: -2,
        ),
        BoxShadow(
          color: cyan.withAlpha(40),
          blurRadius: 12,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ];
}
