import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Renders the official SRISHTI 2.7 logo with Apple-inspired container treatment.
class SrishtiLogo extends StatelessWidget {
  final double size;
  final bool showBadge;
  final bool compact;

  const SrishtiLogo({
    super.key,
    this.size = 56,
    this.showBadge = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.asset(
        'assets/images/srishti_logo.jpg',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback if image asset fails to load
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(size * 0.28),
              border: Border.all(color: AppColors.borderDarkSubtle),
            ),
            child: Center(
              child: ShaderMask(
                shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                child: Icon(
                  Icons.auto_awesome,
                  size: size * 0.5,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );

    if (compact) {
      return imageWidget;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF1E293B),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: imageWidget,
    );
  }
}
