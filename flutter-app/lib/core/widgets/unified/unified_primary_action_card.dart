import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// Painter for the 4 cyan viewfinder brackets around the scanner square icon.
class _ScannerViewfinderPainter extends CustomPainter {
  final Color color;

  _ScannerViewfinderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 9.0;

    // Top-left bracket ┌
    final tlPath = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, 0)
      ..lineTo(cornerLength, 0);
    canvas.drawPath(tlPath, paint);

    // Top-right bracket ┐
    final trPath = Path()
      ..moveTo(size.width - cornerLength, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, cornerLength);
    canvas.drawPath(trPath, paint);

    // Bottom-left bracket └
    final blPath = Path()
      ..moveTo(0, size.height - cornerLength)
      ..lineTo(0, size.height)
      ..lineTo(cornerLength, size.height);
    canvas.drawPath(blPath, paint);

    // Bottom-right bracket ┘
    final brPath = Path()
      ..moveTo(size.width - cornerLength, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - cornerLength);
    canvas.drawPath(brPath, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerViewfinderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Reusable primary action card matching the reference screenshot.
/// Dark cinematic card with cyan-bracketed glowing QR icon container,
/// bold uppercase title, subtitle, right arrow button, and subtle cyber geometric background.
class UnifiedPrimaryActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const UnifiedPrimaryActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.qr_code_scanner_rounded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF00D9FF).withValues(alpha: 0.25),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D9FF).withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: const Color(0xFF00D9FF).withValues(alpha: 0.2),
            highlightColor: const Color(0xFF1557FF).withValues(alpha: 0.15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF040D22),
                    Color(0xFF071B44),
                    Color(0xFF0B2A6A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Subtle integrated branding behind the right-side arrow area
                  Positioned(
                    right: -25,
                    top: -20,
                    bottom: -20,
                    width: 140,
                    child: IgnorePointer(
                      child: Transform.rotate(
                        angle: -0.20,
                        child: Opacity(
                          opacity: 0.22,
                          child: Image.asset(
                            'assets/images/srishti_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Ambient cyan glow behind arrow button
                  Positioned(
                    right: -10,
                    top: -10,
                    bottom: -10,
                    width: 90,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF00D9FF).withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Main card content row
                  Row(
                    children: [
                      // Viewfinder corner brackets framing the QR button
                      SizedBox(
                        width: 66,
                        height: 66,
                        child: CustomPaint(
                          painter: _ScannerViewfinderPainter(
                            color: const Color(0xFF00D9FF),
                          ),
                          child: Center(
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00D9FF).withValues(alpha: 0.55),
                                    blurRadius: 14,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  icon,
                                  size: 26,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Text: Title & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Right-side circular action arrow button
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D9FF).withValues(alpha: 0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
