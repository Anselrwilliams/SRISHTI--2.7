import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../checkin/models/attendance_mode.dart';
import '../../participants/screens/participant_search_screen.dart';
import '../../scanner/screens/scan_screen.dart';
import '../models/event_model.dart';

/// Bottom sheet displaying full details for an event and attendance actions.
class EventDetailSheet extends StatelessWidget {
  final EventModel event;
  final VoidCallback? onAttendanceMarked;

  const EventDetailSheet({
    super.key,
    required this.event,
    this.onAttendanceMarked,
  });

  static Future<void> show(
    BuildContext context, {
    required EventModel event,
    VoidCallback? onAttendanceMarked,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventDetailSheet(
        event: event,
        onAttendanceMarked: onAttendanceMarked,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header Category & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  event.category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.electricBlue,
                    letterSpacing: 0.5,
                  ),
                ),
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
          const SizedBox(height: 14),

          Text(
            event.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 16),

          // Info Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                _buildInfoRow('Event Code', event.eventCode),
                const Divider(height: 16),
                _buildInfoRow('Venue', event.venue ?? 'Main Campus'),
                const Divider(height: 16),
                _buildInfoRow('Date', event.date ?? 'Day 1'),
                const Divider(height: 16),
                _buildInfoRow(
                  'Scheduled Time',
                  TimeFormatter.formatTimeOrRange(event.time).isNotEmpty
                      ? TimeFormatter.formatTimeOrRange(event.time)
                      : (event.time ?? '10:00 AM'),
                ),
                const Divider(height: 16),
                _buildInfoRow('Registered Count', '${event.registrationCount} Participants'),
                const Divider(height: 16),
                _buildInfoRow('Present at Event', '${event.attendanceCount} Checked In'),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Primary Action: Scan Event Attendance
          GradientButton(
            onPressed: () {
              final effectiveEventId = event.id.isNotEmpty ? event.id : event.eventCode;
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ScanScreen(
                    mode: AttendanceMode.event,
                    eventId: effectiveEventId,
                    eventName: event.name,
                    onScanComplete: onAttendanceMarked,
                  ),
                ),
              );
            },
            label: 'Scan Event Attendance',
            icon: Icons.qr_code_scanner_rounded,
            height: 52,
          ),
          const SizedBox(height: 10),

          // Secondary Action: Manual Search for Event
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              final effectiveEventId = event.id.isNotEmpty ? event.id : event.eventCode;
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ParticipantSearchScreen(
                    mode: AttendanceMode.event,
                    eventId: effectiveEventId,
                    eventName: event.name,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.person_search_rounded, size: 18),
            label: const Text('Search Attendees Manually'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
