import 'package:flutter/material.dart';

/// Painter for the subtle blue/cyan fluid artwork on the right side of the event card.
class _EventCardArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Top-right fluid curve
    final topPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          const Color(0xFF00D9FF).withValues(alpha: 0.35),
          const Color(0xFF1557FF).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(size.width * 0.45, 0, size.width * 0.55, size.height * 0.85))
      ..style = PaintingStyle.fill;

    final topPath = Path();
    topPath.moveTo(size.width * 0.58, 0);
    topPath.cubicTo(
      size.width * 0.68,
      size.height * 0.40,
      size.width * 0.82,
      size.height * 0.65,
      size.width,
      size.height * 0.35,
    );
    topPath.lineTo(size.width, 0);
    topPath.close();
    canvas.drawPath(topPath, topPaint);

    // 2. Bottom-right angled accent
    final bottomPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          const Color(0xFF00D9FF).withValues(alpha: 0.28),
          const Color(0xFF1557FF).withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(size.width * 0.7, size.height * 0.5, size.width * 0.3, size.height * 0.5))
      ..style = PaintingStyle.fill;

    final bottomPath = Path();
    bottomPath.moveTo(size.width * 0.85, size.height);
    bottomPath.cubicTo(
      size.width * 0.80,
      size.height * 0.70,
      size.width * 0.90,
      size.height * 0.60,
      size.width,
      size.height * 0.55,
    );
    bottomPath.lineTo(size.width, size.height);
    bottomPath.close();
    canvas.drawPath(bottomPath, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Reusable primary content card matching the reference screenshot.
/// Large rounded white event card with category badge, event code badge,
/// bold event name, venue, date, time, and subtle blue fluid artwork.
class UnifiedEventCard extends StatelessWidget {
  final String category;
  final String eventCode;
  final String title;
  final String venue;
  final String date;
  final String time;
  final VoidCallback? onTap;

  const UnifiedEventCard({
    super.key,
    required this.category,
    required this.eventCode,
    required this.title,
    required this.venue,
    required this.date,
    required this.time,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative blue/cyan fluid artwork on the right
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _EventCardArtworkPainter(),
                ),
              ),
            ),

            // Card content
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Category and Code badges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              category.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0284C7),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              eventCode,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Event Title
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Details Row: Venue, Date, Time
                      Row(
                        children: [
                          // Venue
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              venue,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Date
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 15,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            date,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Time
                          const Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              time,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF475569),
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
          ],
        ),
      ),
    );
  }
}
