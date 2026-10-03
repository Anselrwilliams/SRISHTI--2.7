import '../../../core/utils/time_formatter.dart';

/// Model representing a SRISHTI competition or workshop event.
class EventModel {
  final String id;
  final String eventCode;
  final String name;
  final String category;
  final String? venue;
  final String? date;
  final String? time;
  final String? startTime;
  final String? endTime;
  final int? capacity;
  final int registrationCount;
  final int attendanceCount;
  final String status;
  final String registrationType;
  final int? maxTeamSize;
  final double? registrationFee;

  const EventModel({
    required this.id,
    required this.eventCode,
    required this.name,
    required this.category,
    this.venue,
    this.date,
    this.time,
    this.startTime,
    this.endTime,
    this.capacity,
    this.registrationCount = 0,
    this.attendanceCount = 0,
    this.status = 'Upcoming',
    this.registrationType = 'individual',
    this.maxTeamSize,
    this.registrationFee,
  });

  bool get isTeamEvent => registrationType.trim().toLowerCase() == 'team';
  bool get isIndividualEvent => !isTeamEvent;
  int get effectiveMaxTeamSize => maxTeamSize ?? (isTeamEvent ? 4 : 1);

  factory EventModel.fromMap(Map<String, dynamic> map) {
    final rawStart = map['start_time']?.toString();
    final rawEnd = map['end_time']?.toString();
    final formattedStart = (rawStart != null && rawStart.trim().isNotEmpty)
        ? TimeFormatter.formatTime(rawStart)
        : null;
    final formattedEnd = (rawEnd != null && rawEnd.trim().isNotEmpty)
        ? TimeFormatter.formatTime(rawEnd)
        : null;

    final combinedTime = TimeFormatter.formatTimeRange(
      rawStart,
      rawEnd,
      fallback: map['time']?.toString() ?? '10:00 AM',
    );

    final rawRegType = map['registration_type']?.toString().toLowerCase() ??
        map['reg_type']?.toString().toLowerCase() ??
        'individual';

    final parsedMaxTeam = int.tryParse(map['max_team_size']?.toString() ?? '') ??
        int.tryParse(map['team_size']?.toString() ?? '');

    final parsedFee = double.tryParse(map['registration_fee']?.toString() ?? '') ??
        double.tryParse(map['fee']?.toString() ?? '') ??
        double.tryParse(map['amount']?.toString() ?? '');

    return EventModel(
      id: map['id']?.toString() ?? '',
      eventCode: map['event_code']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Event',
      category: map['category']?.toString() ?? 'General',
      venue: map['venue']?.toString() ?? 'Main Campus',
      date: map['date']?.toString() ?? map['event_date']?.toString() ?? 'Day 1',
      time: combinedTime,
      startTime: formattedStart,
      endTime: formattedEnd,
      capacity: int.tryParse(map['capacity']?.toString() ?? ''),
      registrationCount: int.tryParse(map['registrations_count']?.toString() ?? '0') ?? 0,
      attendanceCount: int.tryParse(map['attendance_count']?.toString() ?? '0') ?? 0,
      status: map['status']?.toString() ?? 'Upcoming',
      registrationType: rawRegType,
      maxTeamSize: parsedMaxTeam,
      registrationFee: parsedFee,
    );
  }

  EventModel copyWith({
    String? id,
    String? eventCode,
    String? name,
    String? category,
    String? venue,
    String? date,
    String? time,
    String? startTime,
    String? endTime,
    int? capacity,
    int? registrationCount,
    int? attendanceCount,
    String? status,
    String? registrationType,
    int? maxTeamSize,
    double? registrationFee,
  }) {
    return EventModel(
      id: id ?? this.id,
      eventCode: eventCode ?? this.eventCode,
      name: name ?? this.name,
      category: category ?? this.category,
      venue: venue ?? this.venue,
      date: date ?? this.date,
      time: time ?? this.time,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      capacity: capacity ?? this.capacity,
      registrationCount: registrationCount ?? this.registrationCount,
      attendanceCount: attendanceCount ?? this.attendanceCount,
      status: status ?? this.status,
      registrationType: registrationType ?? this.registrationType,
      maxTeamSize: maxTeamSize ?? this.maxTeamSize,
      registrationFee: registrationFee ?? this.registrationFee,
    );
  }
}
