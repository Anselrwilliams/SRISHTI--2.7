/// Represents a volunteer check-in or scan activity record.
class ActivityItem {
  final String id;
  final String participantName;
  final String participantCode;
  final String? eventName;
  final String actionType; // 'Arrival Check-in', 'Event Attendance', 'QR Scan'
  final String source; // 'QR Scan' or 'Manual Search'
  final DateTime timestamp;
  final bool isSuccess;

  const ActivityItem({
    required this.id,
    required this.participantName,
    required this.participantCode,
    this.eventName,
    required this.actionType,
    required this.source,
    required this.timestamp,
    this.isSuccess = true,
  });
}
