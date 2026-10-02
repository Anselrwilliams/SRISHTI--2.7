import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srishti_volunteer/features/events/models/event_model.dart';
import 'package:srishti_volunteer/features/events/screens/event_detail_sheet.dart';
import 'package:srishti_volunteer/features/events/widgets/event_card.dart';
import 'package:srishti_volunteer/features/participants/models/participant_model.dart';
import 'package:srishti_volunteer/features/participants/screens/participant_detail_sheet.dart';
import 'package:srishti_volunteer/features/checkin/models/attendance_mode.dart';
import 'package:srishti_volunteer/features/checkin/services/checkin_service.dart';
import 'package:srishti_volunteer/features/history/models/activity_item.dart';
import 'package:srishti_volunteer/features/participants/services/participant_service.dart';

class MockCheckinServiceForTest extends Fake implements CheckinService {
  @override
  Future<Map<String, int>> getEventCounts(String eventId) async {
    return {'registered': 25, 'attended': 10};
  }

  @override
  Future<List<ActivityItem>> getEventRecentActivities(String eventId, {int limit = 20}) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getEventRoster(String eventId) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getArrivalCheckin(String participantId) async {
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getEventAttendance({
    required String eventId,
    required String participantId,
  }) async {
    return null;
  }
}

class MockParticipantServiceForTest extends Fake implements ParticipantService {
  final List<EventModel> events;
  MockParticipantServiceForTest({this.events = const []});

  @override
  Future<List<EventModel>> getParticipantRegisteredEvents(String participantId) async {
    return events;
  }
}

void main() {
  group('Event Time Display Tests - 12-Hour AM/PM Format', () {
    test('EventModel.fromMap parses 24-hour start_time and end_time to 12-hour AM/PM', () {
      final map1 = {
        'id': 'ev-1',
        'event_code': 'EV-01',
        'name': 'Code Sprint',
        'category': 'Coding',
        'start_time': '13:00:00',
        'end_time': '15:00:00',
        'date': 'Day 1',
      };
      final event1 = EventModel.fromMap(map1);
      expect(event1.startTime, equals('1:00 PM'));
      expect(event1.endTime, equals('3:00 PM'));
      expect(event1.time, equals('1:00 PM - 3:00 PM'));

      final map2 = {
        'id': 'ev-2',
        'event_code': 'EV-02',
        'name': 'Hackathon',
        'category': 'Web',
        'start_time': '10:00:00',
        'end_time': '12:00:00',
        'date': 'Day 2',
      };
      final event2 = EventModel.fromMap(map2);
      expect(event2.startTime, equals('10:00 AM'));
      expect(event2.endTime, equals('12:00 PM'));
      expect(event2.time, equals('10:00 AM - 12:00 PM'));

      final map3 = {
        'id': 'ev-3',
        'event_code': 'EV-03',
        'name': 'RoboWars',
        'category': 'Robotics',
        'start_time': '14:00:00',
        'end_time': '16:00:00',
        'date': 'Day 1',
      };
      final event3 = EventModel.fromMap(map3);
      expect(event3.time, equals('2:00 PM - 4:00 PM'));

      final map4 = {
        'id': 'ev-4',
        'event_code': 'EV-04',
        'name': 'Workshop',
        'category': 'AI',
        'start_time': '09:30:00',
        'end_time': '11:30:00',
        'date': 'Day 1',
      };
      final event4 = EventModel.fromMap(map4);
      expect(event4.time, equals('9:30 AM - 11:30 AM'));
    });

    testWidgets('EventCard displays 12-hour AM/PM formatted event time', (tester) async {
      const event = EventModel(
        id: 'ev-1',
        eventCode: 'EV-01',
        name: 'Speed Coding',
        category: 'Coding',
        venue: 'Lab 3',
        date: 'Day 1',
        time: '13:00:00 - 15:00:00',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EventCard(event: event),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Day 1 • 1:00 PM - 3:00 PM'), findsOneWidget);
    });

    testWidgets('EventDetailSheet displays 12-hour AM/PM formatted Scheduled Time', (tester) async {
      const event = EventModel(
        id: 'ev-1',
        eventCode: 'EV-01',
        name: 'AI Hackathon',
        category: 'Web',
        venue: 'Auditorium',
        date: 'Day 2',
        time: '14:00:00 - 16:00:00',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EventDetailSheet(event: event),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2:00 PM - 4:00 PM'), findsOneWidget);
    });

    testWidgets('ParticipantDetailSheet displays registered events in 12-hour AM/PM format', (tester) async {
      const participant = ParticipantModel(
        id: 'p-1',
        participantCode: 'SRI-001',
        name: 'Test Student',
      );

      final event = EventModel.fromMap({
        'id': 'e-1',
        'event_code': 'EV-01',
        'name': 'Web Workshop',
        'category': 'Workshops',
        'venue': 'Seminar Hall',
        'date': 'Day 1',
        'start_time': '09:30:00',
        'end_time': '11:30:00',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParticipantDetailSheet(
              participant: participant,
              mode: AttendanceMode.arrival,
              initialRegisteredEvents: [event],
              checkinService: MockCheckinServiceForTest(),
              participantService: MockParticipantServiceForTest(events: [event]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Web Workshop'), findsOneWidget);
      expect(find.textContaining('9:30 AM - 11:30 AM'), findsOneWidget);
    });
  });
}
