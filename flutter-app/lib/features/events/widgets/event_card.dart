import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../models/event_model.dart';

/// Clean Apple-style card displaying event details and attendance metrics.
class EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  Color _getCategoryColor(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('code') || cat.contains('robot') || cat.contains('web') || cat.contains('workshop') || cat.contains('tech')) {
      return AppColors.cyan;
    } else if (cat.contains('cultur') || cat.contains('art') || cat.contains('music') || cat.contains('dance')) {
      return const Color(0xFF8B5CF6);
    } else if (cat.contains('fun') || cat.contains('game') || cat.contains('gaming')) {
      return const Color(0xFFF59E0B);
    }
    return AppColors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor(event.category);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: categoryColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.category.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: categoryColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (event.eventCode.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              event.eventCode,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    AppStatusBadge(
                      label: event.status,
                      status: event.status == 'Live'
                          ? BadgeStatus.live
                          : event.status == 'Completed'
                              ? BadgeStatus.completed
                              : BadgeStatus.pending,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  event.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${event.date ?? "Day 1"} • ${TimeFormatter.formatTimeOrRange(event.time).isNotEmpty ? TimeFormatter.formatTimeOrRange(event.time) : (event.time ?? "10:00 AM")}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.venue ?? 'Main Campus',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'REGISTRATIONS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${event.registrationCount}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 22,
                        width: 1,
                        color: AppColors.borderLight,
                      ),
                      Column(
                        children: [
                          const Text(
                            'PRESENT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${event.attendanceCount}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
