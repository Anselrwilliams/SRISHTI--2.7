import 'package:flutter_test/flutter_test.dart';
import 'package:srishti_volunteer/features/auth/models/volunteer_model.dart';
import 'package:srishti_volunteer/features/events/models/event_model.dart';

void main() {
  group('SRISHTI 2.7 Role-Based Dashboard Architecture Tests', () {
    test('VolunteerModel correctly parses and identifies event_staff role', () {
      final map = {
        'id': 'v-101',
        'name': 'Rahul Coordinator',
        'username': 'quiz123',
        'role': 'event_staff',
        'status': 'active',
      };

      final volunteer = VolunteerModel.fromMap(map);
      expect(volunteer.id, 'v-101');
      expect(volunteer.name, 'Rahul Coordinator');
      expect(volunteer.username, 'quiz123');
      expect(volunteer.role, 'event_staff');
      expect(volunteer.isEventStaff, isTrue);
      expect(volunteer.isAdmin, isFalse);
      expect(volunteer.isRegistration, isFalse);
      expect(volunteer.isVolunteer, isFalse);
      expect(volunteer.roleDisplay, 'Event Coordinator');
    });

    test('VolunteerModel correctly parses and identifies registration role', () {
      final map = {
        'id': 'v-102',
        'name': 'Ananya Gate',
        'username': 'reg_lead',
        'role': 'registration',
        'status': 'active',
      };

      final volunteer = VolunteerModel.fromMap(map);
      expect(volunteer.isRegistration, isTrue);
      expect(volunteer.isEventStaff, isFalse);
      expect(volunteer.roleDisplay, 'Registration Desk');
    });

    test('VolunteerModel correctly parses and identifies admin role', () {
      final map = {
        'id': 'v-103',
        'name': 'Fest Admin',
        'username': 'admin_root',
        'role': 'admin',
        'status': 'active',
      };

      final volunteer = VolunteerModel.fromMap(map);
      expect(volunteer.isAdmin, isTrue);
      expect(volunteer.roleDisplay, 'Administrator');
    });

    test('VolunteerModel defaults to general volunteer for unknown or volunteer role', () {
      final map = {
        'id': 'v-104',
        'name': 'Karthik General',
        'username': 'kart_vol',
        'role': 'volunteer',
        'status': 'active',
      };

      final volunteer = VolunteerModel.fromMap(map);
      expect(volunteer.isVolunteer, isTrue);
      expect(volunteer.roleDisplay, 'Volunteer');
    });

    test('EventModel copyWith updates dynamic registration and attendance counts', () {
      const initial = EventModel(
        id: 'ev-01',
        eventCode: 'TEST-EV-01',
        name: 'Code Sprint',
        category: 'Coding',
        venue: 'CS Lab 3',
        registrationCount: 0,
        attendanceCount: 0,
      );

      final updated = initial.copyWith(
        registrationCount: 64,
        attendanceCount: 42,
      );

      expect(updated.id, 'ev-01');
      expect(updated.name, 'Code Sprint');
      expect(updated.registrationCount, 64);
      expect(updated.attendanceCount, 42);
    });
  });
}
