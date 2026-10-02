import 'package:flutter/material.dart';

/// Atmospheric background wrapper providing the subtle soft white canvas
/// with the exact luminous cyan/blue atmospheric pill shapes and soft washes
/// seen in the reference screenshot.
class UnifiedBackground extends StatelessWidget {
  final Widget child;

  const UnifiedBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Stack(
        children: [
          // 1. Broad soft ambient cyan/blue radial wash in top-right
          Positioned(
            top: -60,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00D9FF).withValues(alpha: 0.16),
                      const Color(0xFF1557FF).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Primary angled atmospheric capsule descending from top-right
          Positioned(
            top: -20,
            right: 15,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -0.64, // ~ -37 degrees
                child: Container(
                  width: 110,
                  height: 340,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(55),
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        const Color(0xFF00D9FF).withValues(alpha: 0.22),
                        const Color(0xFF1557FF).withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Secondary subtle angled accent on right side
          Positioned(
            top: 250,
            right: -25,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -0.64,
                child: Container(
                  width: 80,
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        const Color(0xFF00D9FF).withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          child,
        ],
      ),
    );
  }
}
