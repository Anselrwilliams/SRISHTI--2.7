import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srishti_volunteer/core/services/haptic_feedback_service.dart';
import 'package:srishti_volunteer/features/checkin/models/attendance_mode.dart';
import 'package:srishti_volunteer/features/checkin/services/checkin_service.dart';
import 'package:srishti_volunteer/features/participants/models/participant_model.dart';
import 'package:srishti_volunteer/features/participants/screens/participant_detail_sheet.dart';
import 'package:srishti_volunteer/features/participants/services/participant_service.dart';

// Test mock for CheckinService
class MockCheckinService extends CheckinService {
  final AttendanceActionResult? arrivalResult;
  final AttendanceActionResult? attendanceResult;
  final Map<String, dynamic>? mockArrivalData;
  final Map<String, dynamic>? mockRegData;
  final Map<String, dynamic>? mockAttendanceData;

  MockCheckinService({
    this.arrivalResult,
    this.attendanceResult,
    this.mockArrivalData,
    this.mockRegData,
    this.mockAttendanceData,
  });

  @override
  Future<String> getVolunteerId() async => 'vol-test-123';

  @override
  Future<Map<String, dynamic>?> getArrivalCheckin(String participantId) async {
    return mockArrivalData;
  }

  @override
  Future<Map<String, dynamic>?> getRegistration({
    required String participantId,
    required String eventId,
  }) async {
    return mockRegData ?? {'id': 'reg-1', 'status': 'registered'};
  }

  @override
  Future<Map<String, dynamic>?> getEventAttendance({
    required String participantId,
    required String eventId,
  }) async {
    return mockAttendanceData;
  }

  @override
  Future<AttendanceActionResult> recordArrivalCheckin({
    required String participantId,
    required String checkedInByVolunteerId,
    String source = 'qr',
    String? notes,
  }) async {
    return arrivalResult ?? AttendanceActionResult.success(message: 'Arrival recorded');
  }

  @override
  Future<AttendanceActionResult> recordEventAttendance({
    required String participantId,
    required String eventId,
    required String markedByVolunteerId,
    String source = 'qr',
    String? notes,
  }) async {
    return attendanceResult ?? AttendanceActionResult.success(message: 'Attendance recorded');
  }
}

// Test mock for ParticipantService
class MockParticipantService extends ParticipantService {
  final Map<String, dynamic>? mockParticipant;

  MockParticipantService({this.mockParticipant});

  @override
  Future<Map<String, dynamic>?> getParticipantByCode(String participantCode) async {
    return mockParticipant;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<String> capturedHapticEvents = [];

  setUp(() {
    capturedHapticEvents.clear();
    HapticFeedbackService.testHook = (event) {
      capturedHapticEvents.add(event);
    };
  });

  tearDown(() {
    HapticFeedbackService.testHook = null;
    capturedHapticEvents.clear();
  });

  group('HapticFeedbackService Unit Tests', () {
    test('success() triggers success event pattern', () async {
      await HapticFeedbackService.instance.success();
      expect(capturedHapticEvents, contains('success'));
    });

    test('error() triggers error event pattern', () async {
      await HapticFeedbackService.instance.error();
      expect(capturedHapticEvents, contains('error'));
    });

    test('duplicate() triggers duplicate event pattern', () async {
      await HapticFeedbackService.instance.duplicate();
      expect(capturedHapticEvents, contains('duplicate'));
    });

    test('disabled service suppresses async platform invocation but notifies hook', () async {
      HapticFeedbackService.instance.enabled = false;
      await HapticFeedbackService.instance.success();
      expect(capturedHapticEvents, contains('success'));
      HapticFeedbackService.instance.enabled = true;
    });
  });

  group('ParticipantDetailSheet Haptic Feedback Tests', () {
    final testParticipant = ParticipantModel(
      id: 'part-123',
      participantCode: 'SRI27-1001',
      name: 'Aditya Verma',
      email: 'aditya@example.com',
      phone: '9876543210',
      college: 'College of Engineering',
    );

    Widget createSheetUnderTest({
      required AttendanceMode mode,
      String? eventId,
      String? eventName,
      required CheckinService checkinService,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ParticipantDetailSheet(
            participant: testParticipant,
            mode: mode,
            eventId: eventId,
            eventName: eventName,
            checkinService: checkinService,
            participantService: MockParticipantService(),
            initialRegisteredEvents: const [],
          ),
        ),
      );
    }

    testWidgets('Successful arrival check-in triggers success haptic', (tester) async {
      final mockCheckin = MockCheckinService(
        arrivalResult: AttendanceActionResult.success(
          message: 'Arrival recorded successfully',
          recordedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(createSheetUnderTest(
        mode: AttendanceMode.arrival,
        checkinService: mockCheckin,
      ));
      await tester.pumpAndSettle();

      // Tap Confirm FEST Check-in
      await tester.ensureVisible(find.text('Confirm FEST Check-in'));
      await tester.tap(find.text('Confirm FEST Check-in'));
      await tester.pumpAndSettle();

      expect(capturedHapticEvents, contains('success'));
      expect(find.text('✓ ARRIVAL CHECK-IN COMPLETE'), findsOneWidget);
    });

    testWidgets('Duplicate arrival check-in triggers duplicate haptic', (tester) async {
      final mockCheckin = MockCheckinService(
        arrivalResult: AttendanceActionResult.duplicate(
          message: 'Participant is already checked in to SRISHTI.',
          recordedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(createSheetUnderTest(
        mode: AttendanceMode.arrival,
        checkinService: mockCheckin,
      ));
      await tester.pumpAndSettle();

      // Tap Confirm FEST Check-in
      await tester.ensureVisible(find.text('Confirm FEST Check-in'));
      await tester.tap(find.text('Confirm FEST Check-in'));
      await tester.pumpAndSettle();

      expect(capturedHapticEvents, contains('duplicate'));
      expect(find.text('Already checked in'), findsOneWidget);
    });

    testWidgets('Successful event attendance triggers success haptic', (tester) async {
      final mockCheckin = MockCheckinService(
        mockArrivalData: {
          'id': 'arr-1',
          'checked_in_at': '2026-10-01T09:00:00Z',
        },
        mockRegData: {
          'id': 'reg-1',
          'status': 'registered',
        },
        attendanceResult: AttendanceActionResult.success(
          message: 'Attendance recorded',
          recordedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(createSheetUnderTest(
        mode: AttendanceMode.event,
        eventId: 'event-uuid-1',
        eventName: 'Code Sprint',
        checkinService: mockCheckin,
      ));
      await tester.pumpAndSettle();

      // Tap Mark Event Attendance
      await tester.ensureVisible(find.text('Mark Event Attendance'));
      await tester.tap(find.text('Mark Event Attendance'));
      await tester.pumpAndSettle();

      expect(capturedHapticEvents, contains('success'));
      expect(find.text('✓ Event attendance marked'), findsOneWidget);
    });

    testWidgets('Duplicate event attendance triggers duplicate haptic', (tester) async {
      final mockCheckin = MockCheckinService(
        mockArrivalData: {
          'id': 'arr-1',
          'checked_in_at': '2026-10-01T09:00:00Z',
        },
        mockRegData: {
          'id': 'reg-1',
          'status': 'registered',
        },
        attendanceResult: AttendanceActionResult.duplicate(
          message: 'Already marked present',
          recordedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(createSheetUnderTest(
        mode: AttendanceMode.event,
        eventId: 'event-uuid-1',
        eventName: 'Code Sprint',
        checkinService: mockCheckin,
      ));
      await tester.pumpAndSettle();

      // Tap Mark Event Attendance
      await tester.ensureVisible(find.text('Mark Event Attendance'));
      await tester.tap(find.text('Mark Event Attendance'));
      await tester.pumpAndSettle();

      expect(capturedHapticEvents, contains('duplicate'));
      expect(find.text('Already marked present'), findsWidgets);
    });
  });
}
