/// Model representing a team member in a multi-person event registration.
class TeamMemberModel {
  final String name;
  final String phone;
  final String? email;
  final String? college;
  final String? year;

  const TeamMemberModel({
    required this.name,
    required this.phone,
    this.email,
    this.college,
    this.year,
  });

  bool get isValid => name.trim().isNotEmpty && phone.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'phone': phone.trim(),
      if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
      if (college != null && college!.trim().isNotEmpty) 'college': college!.trim(),
      if (year != null && year!.trim().isNotEmpty) 'year': year!.trim(),
    };
  }

  factory TeamMemberModel.fromMap(Map<String, dynamic> map) {
    return TeamMemberModel(
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString(),
      college: map['college']?.toString(),
      year: map['year']?.toString(),
    );
  }

  TeamMemberModel copyWith({
    String? name,
    String? phone,
    String? email,
    String? college,
    String? year,
  }) {
    return TeamMemberModel(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      college: college ?? this.college,
      year: year ?? this.year,
    );
  }
}
