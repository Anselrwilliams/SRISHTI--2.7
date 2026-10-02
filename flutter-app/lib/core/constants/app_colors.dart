import 'package:flutter/material.dart';

/// SRISHTI 2.7 Visual Identity and Color Tokens.
///
/// Anchored on Apple-inspired minimalism with a white canvas,
/// refined dark surfaces, and a signature cyan-to-electric-blue gradient.
class AppColors {
  AppColors._();

  // Primary Canvas & Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundSecondary = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF090D16);
  static const Color surfaceDarkElevated = Color(0xFF131B2E);
  static const Color surfaceDarkCard = Color(0xFF1E293B);

  // Signature Accent Gradient: Cyan → Electric Blue
  static const Color cyan = Color(0xFF00E5FF);
  static const Color electricBlue = Color(0xFF0066FF);
  static const Color darkBlue = Color(0xFF0A192F);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [cyan, electricBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Subtle Ambient Glow Gradient for Hero Actions
  static const LinearGradient subtleGlowGradient = LinearGradient(
    colors: [Color(0x3300E5FF), Color(0x330066FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Typography Colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDarkPrimary = Color(0xFFF8FAFC);
  static const Color textDarkSecondary = Color(0xFF94A3B8);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderDark = Color(0xFF1E293B);
  static const Color borderDarkSubtle = Color(0xFF334155);

  // Status & Feedback Colors
  static const Color success = Color(0xFF10B981);
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

  // Apple-style soft shadows
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withAlpha(10),
          blurRadius: 18,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withAlpha(12),
          blurRadius: 14,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get glowShadow => [
        BoxShadow(
          color: cyan.withAlpha(50),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: -2,
        ),
      ];
}
