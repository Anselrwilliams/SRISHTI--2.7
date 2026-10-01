/// Model representing a SRISHTI participant.
class ParticipantModel {
  final String id;
  final String participantCode;
  final String name;
  final String? email;
  final String? phone;
  final String? college;
  final String? department;
  final String? year;
  final bool isCheckedIn;
  final DateTime? checkedInAt;

  const ParticipantModel({
    required this.id,
    required this.participantCode,
    required this.name,
    this.email,
    this.phone,
    this.college,
    this.department,
    this.year,
    this.isCheckedIn = false,
    this.checkedInAt,
  });

  factory ParticipantModel.fromMap(Map<String, dynamic> map, {bool isCheckedIn = false, DateTime? checkedInAt}) {
    return ParticipantModel(
      id: map['id']?.toString() ?? '',
      participantCode: map['participant_code']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Participant',
      email: map['email']?.toString(),
      phone: map['phone']?.toString(),
      college: map['college']?.toString(),
      department: map['department']?.toString(),
      year: map['year']?.toString(),
      isCheckedIn: isCheckedIn,
      checkedInAt: checkedInAt ?? (map['checked_in_at'] != null ? DateTime.tryParse(map['checked_in_at'].toString()) : null),
    );
  }

  ParticipantModel copyWith({
    bool? isCheckedIn,
    DateTime? checkedInAt,
  }) {
    return ParticipantModel(
      id: id,
      participantCode: participantCode,
      name: name,
      email: email,
      phone: phone,
      college: college,
      department: department,
      year: year,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      checkedInAt: checkedInAt ?? this.checkedInAt,
    );
  }
}
