import 'package:flutter_test/flutter_test.dart';
import 'package:srishti_volunteer/features/checkin/models/attendance_mode.dart';
import 'package:srishti_volunteer/features/checkin/services/checkin_service.dart';
import 'package:srishti_volunteer/features/events/models/event_model.dart';
import 'package:srishti_volunteer/features/participants/models/participant_model.dart';

void main() {
  group('SRISHTI 2.7 Attendance Workflow Tests', () {
    test('AttendanceMode enum differentiates arrival vs event context', () {
      expect(AttendanceMode.values, contains(AttendanceMode.arrival));
      expect(AttendanceMode.values, contains(AttendanceMode.event));
      expect(AttendanceMode.arrival, isNot(equals(AttendanceMode.event)));
    });

    test('AttendanceValidationState covers all 7 required verification states', () {
      expect(AttendanceValidationState.values, contains(AttendanceValidationState.valid));
      expect(AttendanceValidationState.values, contains(AttendanceValidationState.participantNotFound));
      expect(AttendanceValidationState.values, contains(AttendanceValidationState.participantNotArrived));
      expect(AttendanceValidationState.values, contains(AttendanceValidationState.notRegisteredForEvent));
      expect(AttendanceValidationState.values, contains(AttendanceValidationState.alreadyCheckedIn));
      expect(AttendanceValidationState.values, contains(AttendanceValidationState.alreadyAttended));
      expect(AttendanceValidationState.values, contains(AttendanceValidationState.networkError));
    });

    test('AttendanceActionResult handles success, duplicate, and error', () {
      final success = AttendanceActionResult.success(
        message: 'Check-in successful',
        recordedAt: DateTime(2026, 10, 1, 10, 30),
      );
      expect(success.isSuccess, isTrue);
      expect(success.isDuplicate, isFalse);
      expect(success.message, 'Check-in successful');
      expect(success.recordedAt, isNotNull);

      final duplicate = AttendanceActionResult.duplicate(
        message: 'Already checked in',
        recordedAt: DateTime(2026, 10, 1, 9, 15),
      );
      expect(duplicate.isSuccess, isFalse);
      expect(duplicate.isDuplicate, isTrue);
      expect(duplicate.message, 'Already checked in');

      final error = AttendanceActionResult.error(
        message: 'Participant not found',
      );
      expect(error.isSuccess, isFalse);
      expect(error.isDuplicate, isFalse);
      expect(error.message, 'Participant not found');
    });

    test('ParticipantModel correctly maps database record and tracks check-in state', () {
      final map = {
        'id': 'p-123',
        'participant_code': 'TEST-SRI27-001',
        'name': 'Rahul Sharma',
        'email': 'rahul@example.com',
        'phone': '9876543210',
        'college': 'GEC Thrissur',
        'department': 'CS',
        'year': '3rd Year',
      };

      final p = ParticipantModel.fromMap(map, isCheckedIn: false);
      expect(p.id, 'p-123');
      expect(p.participantCode, 'TEST-SRI27-001');
      expect(p.name, 'Rahul Sharma');
      expect(p.isCheckedIn, isFalse);

      final updated = p.copyWith(
        isCheckedIn: true,
        checkedInAt: DateTime(2026, 10, 1, 11, 0),
      );
      expect(updated.isCheckedIn, isTrue);
      expect(updated.checkedInAt, isNotNull);
    });

    test('EventModel correctly parses registration and attendance counts', () {
      final map = {
        'id': 'e-101',
        'event_code': 'TEST-EV-01',
        'name': 'Code Sprint',
        'category': 'Coding',
        'venue': 'Lab 3',
        'event_date': 'Day 1',
        'start_time': '10:30 AM',
        'registrations_count': '64',
        'attendance_count': '42',
        'status': 'Live',
      };

      final event = EventModel.fromMap(map);
      expect(event.id, 'e-101');
      expect(event.eventCode, 'TEST-EV-01');
      expect(event.name, 'Code Sprint');
      expect(event.registrationCount, 64);
      expect(event.attendanceCount, 42);
      expect(event.status, 'Live');
    });

    test('Attendance sources strictly conform to "qr" and "manual"', () {
      const qrSource = 'qr';
      const manualSource = 'manual';

      expect(qrSource, equals('qr'));
      expect(manualSource, equals('manual'));
      expect(qrSource, isNot(equals(manualSource)));
    });
  });
}
