import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Model representing an authorized SRISHTI 2.7 volunteer/coordinator.
class VolunteerModel {
  final String id;
  final String name;
  final String username;
  final String role;
  final String status;
  final String? email;

  const VolunteerModel({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.status = 'active',
    this.email,
  });

  factory VolunteerModel.fromMap(Map<String, dynamic> map, {String? email}) {
    return VolunteerModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Volunteer',
      username: map['username']?.toString() ?? '',
      role: map['role']?.toString().toLowerCase() ?? 'volunteer',
      status: map['status']?.toString() ?? 'active',
      email: email ?? map['email']?.toString(),
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isEventStaff => role == 'event_staff';
  bool get isRegistration => role == 'registration';
  bool get isVolunteer => role == 'volunteer';

  String get roleDisplay {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'registration':
        return 'Registration Desk';
      case 'event_staff':
        return 'Event Coordinator';
      case 'volunteer':
      default:
        return 'Volunteer';
    }
  }

  Color get roleColor {
    switch (role) {
      case 'admin':
        return AppColors.purple;
      case 'registration':
        return AppColors.success;
      case 'event_staff':
        return AppColors.cyan;
      case 'volunteer':
      default:
        return AppColors.electricBlue;
    }
  }

  IconData get roleIcon {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'registration':
        return Icons.how_to_reg_rounded;
      case 'event_staff':
        return Icons.event_available_rounded;
      case 'volunteer':
      default:
        return Icons.badge_rounded;
    }
  }
}
