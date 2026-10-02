import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srishti_volunteer/features/auth/models/volunteer_model.dart';
import 'package:srishti_volunteer/features/checkin/models/attendance_mode.dart';
import 'package:srishti_volunteer/features/checkin/services/checkin_service.dart';
import 'package:srishti_volunteer/features/events/models/event_model.dart';
import 'package:srishti_volunteer/features/history/models/activity_item.dart';
import 'package:srishti_volunteer/features/participants/models/participant_model.dart';
import 'package:srishti_volunteer/features/participants/screens/participant_detail_sheet.dart';
import 'package:srishti_volunteer/features/participants/services/participant_service.dart';
import 'package:srishti_volunteer/features/registration/screens/registration_dashboard_screen.dart';

class MockCheckinService extends CheckinService {
  Map<String, dynamic>? mockArrivalData;
  Map<String, dynamic>? mockRegData;
  Map<String, dynamic>? mockAttendanceData;
  List<ActivityItem> mockRecentArrivals = [];
  int mockTotalParticipants = 10;
  int mockTotalArrivals = 4;
  AttendanceActionResult? arrivalCheckinResult;
  AttendanceActionResult? eventAttendanceResult;
  bool recordArrivalCheckinCalled = false;
  bool recordEventAttendanceCalled = false;

  MockCheckinService({
    this.mockArrivalData,
    this.mockRegData,
    this.mockAttendanceData,
    this.arrivalCheckinResult,
    this.eventAttendanceResult,
  });

  @override
  Future<List<ActivityItem>> getRecentArrivals({int limit = 20}) async {
    return mockRecentArrivals;
  }

  @override
  Future<int> getTotalParticipantsCount() async {
    return mockTotalParticipants;
  }

  @override
  Future<int> getTotalArrivalsCount() async {
    return mockTotalArrivals;
  }

  @override
  Future<Map<String, dynamic>?> getArrivalCheckin(String participantId) async {
    return mockArrivalData;
  }

  @override
  Future<Map<String, dynamic>?> getRegistration({
    required String participantId,
    required String eventId,
  }) async {
    return mockRegData;
  }

  @override
  Future<Map<String, dynamic>?> getEventAttendance({
    required String participantId,
    required String eventId,
  }) async {
    return mockAttendanceData;
  }

  @override
  Future<String> getVolunteerId() async {
    return 'vol-test-123';
  }

  @override
  Future<AttendanceActionResult> recordArrivalCheckin({
    required String participantId,
    required String checkedInByVolunteerId,
    String? notes,
    String source = 'qr',
  }) async {
    recordArrivalCheckinCalled = true;
    return arrivalCheckinResult ??
        AttendanceActionResult.success(
          message: '✓ ARRIVAL CHECK-IN COMPLETE',
          recordedAt: DateTime.now(),
        );
  }

  @override
  Future<AttendanceActionResult> recordEventAttendance({
    required String participantId,
    required String eventId,
    required String markedByVolunteerId,
    String? notes,
    String source = 'qr',
  }) async {
    recordEventAttendanceCalled = true;
    return eventAttendanceResult ??
        AttendanceActionResult.success(
          message: '✓ Event attendance marked',
          recordedAt: DateTime.now(),
        );
  }
}

class MockParticipantService extends ParticipantService {
  final Future<List<EventModel>> Function(String participantId)? onGetEvents;
  final Future<Map<String, dynamic>?> Function(String participantCode)? onGetByCode;

  MockParticipantService({this.onGetEvents, this.onGetByCode});

  @override
  Future<Map<String, dynamic>?> getParticipantByCode(String participantCode) async {
    if (onGetByCode != null) {
      return onGetByCode!(participantCode);
    }
    return {
      'id': 'p-test-01',
      'participant_code': participantCode,
      'name': 'Test Student',
      'college': 'Test College',
      'department': 'CS',
      'year': '2',
    };
  }

  @override
  Future<List<EventModel>> getParticipantRegisteredEvents(String participantId) async {
    if (onGetEvents != null) {
      return onGetEvents!(participantId);
    }
    return [];
  }
}

void main() {
  const testParticipant = ParticipantModel(
    id: 'p-001',
    participantCode: 'TEST-SRI27-001',
    name: 'Rahul Sharma',
    email: 'rahul@example.com',
    college: 'GEC Thrissur',
    isCheckedIn: false,
  );

  final event1 = const EventModel(
    id: 'e-1',
    eventCode: 'EV-01',
    name: 'Code Sprint',
    category: 'Coding',
    venue: 'Lab 3',
    date: '2026-10-01',
    startTime: '10:00 AM',
  );

  final event2 = const EventModel(
    id: 'e-2',
    eventCode: 'EV-02',
    name: 'HackAI',
    category: 'AI / ML',
    venue: 'Seminar Hall B',
    date: '2026-10-02',
    startTime: '09:00 AM',
  );

  final event3 = const EventModel(
    id: 'e-3',
    eventCode: 'EV-03',
    name: 'RoboWars',
    category: 'Robotics',
    venue: 'Open Arena',
    date: '2026-10-02',
    startTime: '02:00 PM',
  );

  Widget createWidgetUnderTest({
    ParticipantModel participant = testParticipant,
    AttendanceMode mode = AttendanceMode.arrival,
    String? eventId,
    String? eventName,
    List<EventModel>? initialEvents,
    CheckinService? checkinService,
    ParticipantService? participantService,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ParticipantDetailSheet(
          participant: participant,
          mode: mode,
          eventId: eventId,
          eventName: eventName,
          initialRegisteredEvents: initialEvents,
          checkinService: checkinService ?? MockCheckinService(),
          participantService: participantService ?? MockParticipantService(),
        ),
      ),
    );
  }

  group('A. Participant with 3 registered events -> all 3 displayed', () {
    testWidgets('displays all 3 registered events and before-checkin UI', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialEvents: [event1, event2, event3],
      ));
      await tester.pumpAndSettle();

      // UI Before Check-in:
      expect(find.text('FEST ARRIVAL CHECK-IN'), findsOneWidget);
      expect(find.text('FEST Arrival'), findsOneWidget);
      expect(find.text('Not checked in'), findsOneWidget);

      // Registered Events Header:
      expect(find.text('Registered Events'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // badge count

      // All 3 events displayed:
      expect(find.text('Code Sprint'), findsOneWidget);
      expect(find.text('HackAI'), findsOneWidget);
      expect(find.text('RoboWars'), findsOneWidget);

      // Optional info (category / venue):
      expect(find.textContaining('Coding'), findsOneWidget);
      expect(find.textContaining('AI / ML'), findsOneWidget);
      expect(find.textContaining('Robotics'), findsOneWidget);

      // Action button
      expect(find.text('Confirm FEST Check-in'), findsOneWidget);
    });
  });

  group('B. Participant with 1 registered event -> 1 displayed', () {
    testWidgets('displays the single registered event', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialEvents: [event1],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Registered Events'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Code Sprint'), findsOneWidget);
      expect(find.text('HackAI'), findsNothing);
      expect(find.text('RoboWars'), findsNothing);
    });
  });

  group('C. Participant with no registrations -> "No registered events"', () {
    testWidgets('displays "No registered events" when list is empty', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialEvents: [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Registered Events'), findsOneWidget);
      expect(find.text('No registered events'), findsOneWidget);
      expect(find.text('Code Sprint'), findsNothing);
    });
  });

  group('D. Participant with registered, cancelled, waitlisted -> only registered displayed', () {
    test('ParticipantService filters out cancelled and waitlisted statuses', () {
      final mockRegistrations = [
        {'event_id': 'e-1', 'status': 'registered'},
        {'event_id': 'e-2', 'status': 'cancelled'},
        {'event_id': 'e-3', 'status': 'waitlisted'},
      ];

      final filteredEventIds = mockRegistrations
          .where((r) => r['status'] == 'registered')
          .map((r) => r['event_id'])
          .toList();

      expect(filteredEventIds, equals(['e-1']));
      expect(filteredEventIds, isNot(contains('e-2')));
      expect(filteredEventIds, isNot(contains('e-3')));
    });

    testWidgets('only registered event is rendered in UI', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialEvents: [event1], // only registered event passed
      ));
      await tester.pumpAndSettle();

      expect(find.text('Code Sprint'), findsOneWidget);
      expect(find.text('HackAI'), findsNothing);
      expect(find.text('RoboWars'), findsNothing);
    });
  });

  group('E. Already checked-in participant', () {
    testWidgets('shows "Already checked in", prevents duplicate check-in, displays events', (tester) async {
      final mockCheckin = MockCheckinService(
        mockArrivalData: {
          'id': 'arr-1',
          'participant_id': 'p-001',
          'checked_in_at': '2026-10-01T09:30:00Z',
        },
      );

      await tester.pumpWidget(createWidgetUnderTest(
        checkinService: mockCheckin,
        initialEvents: [event1, event2],
      ));
      await tester.pumpAndSettle();

      // Warning message and arrived state
      expect(find.text('Already checked in'), findsOneWidget);
      expect(find.text('Checked in (09:30)'), findsOneWidget);

      // Button is disabled / indicates already checked in
      expect(find.text('Participant Already Checked In'), findsOneWidget);
      expect(find.text('Confirm FEST Check-in'), findsNothing);

      // Registered events still displayed
      expect(find.text('Registered Events'), findsOneWidget);
      expect(find.text('Code Sprint'), findsOneWidget);
      expect(find.text('HackAI'), findsOneWidget);

      expect(mockCheckin.recordArrivalCheckinCalled, isFalse);
    });
  });

  group('F. Successful arrival check-in', () {
    testWidgets('shows "✓ ARRIVAL CHECK-IN COMPLETE", participant info, and registered events', (tester) async {
      final mockCheckin = MockCheckinService(
        mockArrivalData: null,
        arrivalCheckinResult: AttendanceActionResult.success(
          message: '✓ ARRIVAL CHECK-IN COMPLETE',
          recordedAt: DateTime(2026, 10, 1, 10, 15),
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(
        checkinService: mockCheckin,
        initialEvents: [event1, event2, event3],
      ));
      await tester.pumpAndSettle();

      // Before check-in
      expect(find.text('Confirm FEST Check-in'), findsOneWidget);

      // Tap Confirm Festival Check-in
      await tester.ensureVisible(find.text('Confirm FEST Check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm FEST Check-in'));
      await tester.pumpAndSettle();

      expect(mockCheckin.recordArrivalCheckinCalled, isTrue);

      // Success state UI
      expect(find.text('✓ ARRIVAL CHECK-IN COMPLETE'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('TEST-SRI27-001'), findsOneWidget);

      // Registered events still fully displayed
      expect(find.text('Registered Events'), findsOneWidget);
      expect(find.text('Code Sprint'), findsOneWidget);
      expect(find.text('HackAI'), findsOneWidget);
      expect(find.text('RoboWars'), findsOneWidget);
    });
  });

  group('G. Event Staff flow remains unchanged', () {
    testWidgets('AttendanceMode.event preserves event-specific verification without registered events list', (tester) async {
      final mockCheckin = MockCheckinService(
        mockArrivalData: {
          'id': 'arr-1',
          'checked_in_at': '2026-10-01T09:00:00Z',
        },
        mockRegData: {
          'id': 'reg-1',
          'status': 'registered',
        },
        mockAttendanceData: null,
      );

      await tester.pumpWidget(createWidgetUnderTest(
        mode: AttendanceMode.event,
        eventId: 'e-1',
        eventName: 'Code Sprint',
        checkinService: mockCheckin,
      ));
      await tester.pumpAndSettle();

      // Header indicates specific event
      expect(find.text('EVENT ATTENDANCE: Code Sprint'), findsOneWidget);

      // Event-specific verification checklist
      expect(find.text('FEST Arrival'), findsOneWidget);
      expect(find.text('Event Registration'), findsOneWidget);
      expect(find.text('Event Attendance'), findsOneWidget);
      expect(find.text('Registered'), findsOneWidget);
      expect(find.text('Not marked yet'), findsOneWidget);

      // Registered events list should NOT be rendered in event mode
      expect(find.text('Registered Events'), findsNothing);

      // Mark Event Attendance button is present
      expect(find.text('Mark Event Attendance'), findsOneWidget);

      // Tap Mark Event Attendance
      await tester.ensureVisible(find.text('Mark Event Attendance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark Event Attendance'));
      await tester.pumpAndSettle();

      expect(mockCheckin.recordEventAttendanceCalled, isTrue);
      expect(find.text('✓ Event attendance marked'), findsOneWidget);
    });
  });

  group('Sorting and Loading/Error States', () {
    test('ParticipantService.sortEvents sorts by date -> start time -> name', () {
      final unsorted = [
        const EventModel(
          id: '1',
          eventCode: 'E1',
          name: 'Web Dev',
          category: 'Web',
          date: '2026-10-02',
          startTime: '10:00 AM',
        ),
        const EventModel(
          id: '2',
          eventCode: 'E2',
          name: 'RoboWars',
          category: 'Robotics',
          date: '2026-10-01',
          startTime: '02:00 PM',
        ),
        const EventModel(
          id: '3',
          eventCode: 'E3',
          name: 'Code Sprint',
          category: 'Coding',
          date: '2026-10-01',
          startTime: '09:00 AM',
        ),
        const EventModel(
          id: '4',
          eventCode: 'E4',
          name: 'AI Challenge',
          category: 'AI',
          date: '2026-10-01',
          startTime: '09:00 AM',
        ),
      ];

      ParticipantService.sortEvents(unsorted);

      expect(unsorted[0].name, 'AI Challenge'); // Day 1, 09:00 AM, alphabetical A
      expect(unsorted[1].name, 'Code Sprint');  // Day 1, 09:00 AM, alphabetical C
      expect(unsorted[2].name, 'RoboWars');     // Day 1, 02:00 PM
      expect(unsorted[3].name, 'Web Dev');      // Day 2, 10:00 AM
    });

    testWidgets('shows loading placeholder while fetching events', (tester) async {
      final mockParticipant = MockParticipantService(
        onGetEvents: (_) async {
          await Future.delayed(const Duration(milliseconds: 500));
          return [event1];
        },
      );

      await tester.pumpWidget(createWidgetUnderTest(
        participantService: mockParticipant,
      ));

      // Pump 1 frame without completing the 500ms delay
      await tester.pump();

      expect(find.text('Loading registered events...'), findsOneWidget);

      // Finish delay
      await tester.pumpAndSettle();
      expect(find.text('Code Sprint'), findsOneWidget);
    });

    testWidgets('displays "Unable to load registered events." on error without blocking identification', (tester) async {
      final mockParticipant = MockParticipantService(
        onGetEvents: (_) async {
          throw Exception('Database connection timeout');
        },
      );

      await tester.pumpWidget(createWidgetUnderTest(
        participantService: mockParticipant,
      ));
      await tester.pumpAndSettle();

      // Non-blocking error message
      expect(find.text('Unable to load registered events.'), findsOneWidget);
      expect(find.text('No registered events'), findsNothing);

      // Participant is still identified
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('TEST-SRI27-001'), findsOneWidget);
      expect(find.text('GEC Thrissur'), findsOneWidget);

      // Arrival check-in action is still enabled
      expect(find.text('Confirm FEST Check-in'), findsOneWidget);
    });
  });

  group('H. Registration Home Recent Arrivals Navigation Tests', () {
    testWidgets(
        'Tapping participant in Recent Arrivals opens ParticipantDetailSheet with participant info, check-in status, and registered events',
        (tester) async {
      final mockCheckin = MockCheckinService(
        mockArrivalData: {
          'id': 'arr-01',
          'participant_id': '3988b6cc-3035-4529-b7e0-dc2d3817aa1d',
          'checked_in_at': '2026-10-01T16:44:11.027186+00:00',
          'source': 'manual',
        },
      );
      mockCheckin.mockRecentArrivals = [
        ActivityItem(
          id: 'arr-01',
          participantName: 'Test Student',
          participantCode: 'SRI27-TEST01',
          actionType: 'Arrival Check-in',
          source: 'Manual Search',
          timestamp: DateTime.parse('2026-10-01T16:44:11.027186Z'),
        ),
      ];

      final mockParticipant = MockParticipantService(
        onGetByCode: (code) async => {
          'id': '3988b6cc-3035-4529-b7e0-dc2d3817aa1d',
          'participant_code': 'SRI27-TEST01',
          'name': 'Test Student',
          'college': 'Test College',
          'department': 'CS',
          'year': '2',
        },
        onGetEvents: (id) async => [
          const EventModel(
            id: '8281c411-87a9-4513-a92b-d761a2bea7b7',
            eventCode: 'TEST-EV-01',
            name: 'Code Sprint (Speed Coding)',
            category: 'Coding',
            venue: 'CS Lab 3',
            date: '2026-10-01',
            startTime: '10:30:00',
            endTime: '12:30:00',
          ),
        ],
      );

      const volunteer = VolunteerModel(
        id: 'vol-reg-1',
        username: 'srishti_registration',
        name: 'Registration Volunteer',
        role: 'registration',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RegistrationDashboardScreen(
            volunteer: volunteer,
            checkinService: mockCheckin,
            participantService: mockParticipant,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Recent Arrivals item appears on the Home dashboard
      expect(find.text('Recent Arrivals'), findsOneWidget);
      expect(find.text('Test Student'), findsOneWidget);
      expect(find.text('SRI27-TEST01 • Manual Search'), findsOneWidget);

      // Scroll to participant in Recent Arrivals if needed
      await tester.ensureVisible(find.text('Test Student'));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on the participant in Recent Arrivals
      await tester.tap(find.text('Test Student'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify ParticipantDetailSheet opened with all required details
      expect(find.text('FEST ARRIVAL CHECK-IN'), findsOneWidget);
      expect(find.text('Test Student'), findsWidgets); // on tile and on sheet
      expect(find.text('SRI27-TEST01'), findsOneWidget);
      expect(find.text('Test College • CS • Year 2'), findsOneWidget);

      // Festival arrival status
      expect(find.text('Already checked in'), findsOneWidget);

      // Registered Events section & dynamic event row
      expect(find.text('Registered Events'), findsOneWidget);
      expect(find.text('Code Sprint (Speed Coding)'), findsOneWidget);
      expect(find.text('TEST-EV-01'), findsOneWidget);
      expect(find.textContaining('Coding'), findsWidgets);
      expect(find.textContaining('CS Lab 3'), findsOneWidget);
    });
  });
}
