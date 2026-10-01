import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Cyber-minimalist scanning viewfinder with animated cyan-to-electric-blue laser beam.
class ScanOverlay extends StatefulWidget {
  final double scanAreaSize;

  const ScanOverlay({
    super.key,
    this.scanAreaSize = 260,
  });

  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beamController;
  late final Animation<double> _beamAnimation;

  @override
  void initState() {
    super.initState();
    _beamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _beamAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _beamController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _beamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.scanAreaSize;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Framing Box with Corner Accents
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              // Subtle Border
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.cyan.withAlpha(50),
                    width: 1.5,
                  ),
                ),
              ),

              // Corner Brackets
              Positioned(top: 0, left: 0, child: _buildCorner(isTop: true, isLeft: true)),
              Positioned(top: 0, right: 0, child: _buildCorner(isTop: true, isLeft: false)),
              Positioned(bottom: 0, left: 0, child: _buildCorner(isTop: false, isLeft: true)),
              Positioned(bottom: 0, right: 0, child: _buildCorner(isTop: false, isLeft: false)),

              // Animated Laser Beam
              AnimatedBuilder(
                animation: _beamAnimation,
                builder: (context, child) {
                  return Positioned(
                    top: _beamAnimation.value * (size - 24) + 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.cyan,
                            Colors.white,
                            AppColors.cyan,
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cyan.withAlpha(200),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCorner({required bool isTop, required bool isLeft}) {
    const length = 26.0;
    const thickness = 3.5;
    const radius = 24.0;

    return Container(
      width: length,
      height: length,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: AppColors.cyan, width: thickness)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: AppColors.cyan, width: thickness)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: AppColors.cyan, width: thickness)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: AppColors.cyan, width: thickness)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: isTop && isLeft ? const Radius.circular(radius) : Radius.zero,
          topRight: isTop && !isLeft ? const Radius.circular(radius) : Radius.zero,
          bottomLeft: !isTop && isLeft ? const Radius.circular(radius) : Radius.zero,
          bottomRight: !isTop && !isLeft ? const Radius.circular(radius) : Radius.zero,
        ),
      ),
    );
  }
}
