/// Model representing a SRISHTI competition or workshop event.
class EventModel {
  final String id;
  final String eventCode;
  final String name;
  final String category;
  final String? venue;
  final String? date;
  final String? time;
  final int registrationCount;
  final int attendanceCount;
  final String status;

  const EventModel({
    required this.id,
    required this.eventCode,
    required this.name,
    required this.category,
    this.venue,
    this.date,
    this.time,
    this.registrationCount = 0,
    this.attendanceCount = 0,
    this.status = 'Upcoming',
  });

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id']?.toString() ?? '',
      eventCode: map['event_code']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Event',
      category: map['category']?.toString() ?? 'General',
      venue: map['venue']?.toString() ?? 'Main Campus',
      date: map['event_date']?.toString() ?? 'Day 1',
      time: map['start_time']?.toString() ?? '10:00 AM',
      registrationCount: int.tryParse(map['registrations_count']?.toString() ?? '0') ?? 0,
      attendanceCount: int.tryParse(map['attendance_count']?.toString() ?? '0') ?? 0,
      status: map['status']?.toString() ?? 'Upcoming',
    );
  }
}
