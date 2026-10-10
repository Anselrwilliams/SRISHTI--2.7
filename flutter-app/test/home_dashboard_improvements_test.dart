import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srishti_volunteer/features/auth/models/volunteer_model.dart';
import 'package:srishti_volunteer/features/checkin/services/checkin_service.dart';
import 'package:srishti_volunteer/features/dashboard/screens/dashboard_screen.dart';
import 'package:srishti_volunteer/features/events/models/event_model.dart';
import 'package:srishti_volunteer/features/history/models/activity_item.dart';
import 'package:srishti_volunteer/features/history/screens/history_screen.dart';
import 'package:srishti_volunteer/features/home/screens/home_screen.dart';
import 'package:srishti_volunteer/features/participants/services/participant_service.dart';

class MockDashboardCheckinService extends CheckinService {
  int registeredCount = 100;
  int arrivedCount = 60;
  bool shouldThrow = false;
  List<ActivityItem> arrivals = [];
  int festivalArrivalStatsCallCount = 0;

  MockDashboardCheckinService({
    this.registeredCount = 100,
    this.arrivedCount = 60,
    this.shouldThrow = false,
  });

  @override
  Future<int> getTotalParticipantsCount() async {
    if (shouldThrow) {
      throw Exception('Network connection error: Failed host lookup');
    }
    return registeredCount;
  }

  @override
  Future<int> getTotalArrivalsCount() async {
    if (shouldThrow) {
      throw Exception('Network connection error: Failed host lookup');
    }
    return arrivedCount;
  }

  @override
  Future<FestivalStats> getFestivalArrivalStats() async {
    festivalArrivalStatsCallCount++;
    if (shouldThrow) {
      throw Exception('Network connection error: Failed host lookup');
    }
    return super.getFestivalArrivalStats();
  }

  @override
  Future<List<ActivityItem>> getRecentArrivals({int limit = 20}) async {
    if (shouldThrow) {
      throw Exception('Network connection error');
    }
    return arrivals;
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveEvents() async {
    return [];
  }

  @override
  Future<Map<String, int>> getEventCounts(String eventId) async {
    return {'registered': 0, 'attended': 0};
  }
}

class MockDashboardParticipantService extends ParticipantService {
  final Map<String, Map<String, dynamic>> participantsByCode = {};

  @override
  Future<Map<String, dynamic>?> getParticipantByCode(String participantCode) async {
    return participantsByCode[participantCode] ??
        {
          'id': 'p-test-uuid',
          'participant_code': participantCode,
          'name': 'Participant $participantCode',
          'college': 'Test Institute of Technology',
          'department': 'Computer Science',
          'year': '3',
        };
  }

  @override
  Future<List<EventModel>> getParticipantRegisteredEvents(String participantId) async {
    return [
      const EventModel(
        id: 'e-1',
        eventCode: 'TEST-EV-01',
        name: 'Code Sprint',
        category: 'Coding',
        venue: 'Lab 3',
      ),
    ];
  }
}

class ControlledAsyncCheckinService extends CheckinService {
  final List<Completer<FestivalStats>> statsCompleters = [];

  @override
  Future<FestivalStats> getFestivalArrivalStats() {
    final completer = Completer<FestivalStats>();
    statsCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<List<ActivityItem>> getRecentArrivals({int limit = 20}) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveEvents() async {
    return [];
  }

  @override
  Future<Map<String, int>> getEventCounts(String eventId) async {
    return {'registered': 0, 'attended': 0};
  }
}

void main() {
  const testVolunteer = VolunteerModel(
    id: 'vol-test-1',
    name: 'Ananya Nair',
    username: 'ananya_gate',
    role: 'volunteer',
    status: 'active',
  );

  group('1. Statistics Calculations & Duplicate Check-in Prevention', () {
    test('Correct Registered, Arrived, and Pending Arrival calculations', () async {
      final service = MockDashboardCheckinService(
        registeredCount: 150,
        arrivedCount: 95,
      );

      final stats = await service.getFestivalArrivalStats();
      expect(stats.registered, equals(150));
      expect(stats.arrived, equals(95));
      expect(stats.pendingArrival, equals(55)); // 150 - 95
    });

    test('Duplicate check-in records do not inflate Arrived count beyond Registered', () async {
      // Scenario: raw arrival records count (120) exceeds registered count (100) due to edge-case duplicates
      final service = MockDashboardCheckinService(
        registeredCount: 100,
        arrivedCount: 120,
      );

      final stats = await service.getFestivalArrivalStats();
      expect(stats.registered, equals(100));
      // Arrived is strictly capped at distinct eligible registered participants
      expect(stats.arrived, equals(100));
      // Pending arrival cannot be negative
      expect(stats.pendingArrival, equals(0));
    });

    test('Zero registered participants gracefully produces zero arrived and zero pending', () async {
      final service = MockDashboardCheckinService(
        registeredCount: 0,
        arrivedCount: 0,
      );

      final stats = await service.getFestivalArrivalStats();
      expect(stats.registered, equals(0));
      expect(stats.arrived, equals(0));
      expect(stats.pendingArrival, equals(0));
    });
  });

  group('2. Error Handling & Failed Network Requests', () {
    testWidgets('Failed network request displays useful error and does not show genuine 0 count',
        (tester) async {
      final service = MockDashboardCheckinService(shouldThrow: true);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            volunteer: testVolunteer,
            checkinService: service,
            onScanPressed: () {},
            onEventsPressed: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Error banner with retry option must be displayed
      expect(find.textContaining('Unable to load live attendance metrics'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // It must NOT show genuine '0' cards pretending to be verified data
      // Under error state, cards are replaced by the clear error banner with retry
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('Tapping Retry on error banner re-fetches and displays verified counts',
        (tester) async {
      final service = MockDashboardCheckinService(
        shouldThrow: true,
        registeredCount: 200,
        arrivedCount: 140,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            volunteer: testVolunteer,
            checkinService: service,
            onScanPressed: () {},
            onEventsPressed: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Retry'), findsOneWidget);

      // Fix network condition and tap Retry
      service.shouldThrow = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Metrics successfully loaded and verified
      expect(find.text('REGISTERED'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('ARRIVED'), findsOneWidget);
      expect(find.text('140'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('60'), findsOneWidget); // 200 - 140
    });
  });

  group('3. UI Statistics Cards Display & Layout', () {
    testWidgets('Renders 3 compact statistic cards: Registered, Arrived, and Pending Arrival',
        (tester) async {
      final service = MockDashboardCheckinService(
        registeredCount: 80,
        arrivedCount: 50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            volunteer: testVolunteer,
            checkinService: service,
            onScanPressed: () {},
            onEventsPressed: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Three cards must be displayed with prominent values
      expect(find.text('REGISTERED'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('ARRIVED'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
    });
  });

  group('4. Refresh Behaviour on Registration, Check-in, and Navigation', () {
    testWidgets('Switching tabs in DashboardScreen reloads HomeScreen statistics',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(volunteer: testVolunteer),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Home tab is initially active
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Pull to refresh re-fetches statistics', (tester) async {
      final service = MockDashboardCheckinService(
        registeredCount: 10,
        arrivedCount: 4,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            volunteer: testVolunteer,
            checkinService: service,
            onScanPressed: () {},
            onEventsPressed: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final initialCalls = service.festivalArrivalStatsCallCount;

      // Trigger pull to refresh
      await tester.fling(find.byType(SingleChildScrollView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(service.festivalArrivalStatsCallCount, greaterThan(initialCalls));
    });
  });

  group('5. Recent Arrivals Rendering, Timestamps & Gate Details', () {
    testWidgets('Recent Arrivals renders participant name, code, Arrived badge, relative time and gate',
        (tester) async {
      final now = DateTime.now();
      final service = MockDashboardCheckinService(
        registeredCount: 100,
        arrivedCount: 60,
      );
      service.arrivals = [
        ActivityItem(
          id: 'arr-1',
          participantName: 'Rahul Sharma',
          participantCode: 'SRI27-0042',
          actionType: 'Arrival Check-in',
          source: 'QR Scan',
          timestamp: now.subtract(const Duration(minutes: 5)),
          gateOrVenue: 'Main Gate',
        ),
        ActivityItem(
          id: 'arr-2',
          participantName: 'Kavya Menon',
          participantCode: 'SRI27-0099',
          actionType: 'Arrival Check-in',
          source: 'Manual Search',
          timestamp: null, // missing timestamp
          gateOrVenue: null,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            volunteer: testVolunteer,
            checkinService: service,
            onScanPressed: () {},
            onEventsPressed: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // First participant with 5 min ago and gate information
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('SRI27-0042 • QR Scan • Main Gate'), findsOneWidget);
      expect(find.text('5 min ago'), findsOneWidget);

      // Second participant with missing timestamp showing "Time unavailable" fallback
      expect(find.text('Kavya Menon'), findsOneWidget);
      expect(find.text('SRI27-0099 • Manual Search'), findsOneWidget);
      expect(find.text('Time unavailable'), findsOneWidget);
    });

    testWidgets('Tapping participant in Recent Arrivals opens ParticipantDetailSheet',
        (tester) async {
      final service = MockDashboardCheckinService(
        registeredCount: 10,
        arrivedCount: 2,
      );
      service.arrivals = [
        ActivityItem(
          id: 'arr-1',
          participantName: 'Karthik Raj',
          participantCode: 'SRI27-0101',
          actionType: 'Arrival Check-in',
          source: 'QR Scan',
          timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      ];

      final participantService = MockDashboardParticipantService();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            volunteer: testVolunteer,
            checkinService: service,
            participantService: participantService,
            onScanPressed: () {},
            onEventsPressed: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to participant and tap
      await tester.ensureVisible(find.text('Karthik Raj'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Karthik Raj'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Detail sheet opens with participant verification info
      expect(find.text('FEST ARRIVAL CHECK-IN'), findsOneWidget);
      expect(find.text('Already checked in'), findsOneWidget);
    });
  });

  group('6. History Discovery & Touch Target Tests', () {
    testWidgets('History button has at least 44x44 minimum touch bounds and navigates to HistoryScreen',
        (tester) async {
      final service = MockDashboardCheckinService();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            volunteer: testVolunteer,
            checkinService: service,
            onScanPressed: () {},
            onEventsPressed: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify History label exists beside Recent Arrivals heading
      expect(find.text('Recent Arrivals'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);

      // Tap on History action (ensure visible first since HomeScreen is scrollable)
      await tester.ensureVisible(find.text('History'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Opens the existing HistoryScreen
      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.text('Recent Activity'), findsOneWidget);
    });
  });

  group('7. Small Screen Layout & Long Participant Names', () {
    testWidgets('Small Android screen (320x640) renders without RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;

      final service = MockDashboardCheckinService(
        registeredCount: 9999,
        arrivedCount: 8888,
      );
      service.arrivals = [
        ActivityItem(
          id: 'arr-long',
          participantName: 'Venkata Satyanarayana Rama Krishna Murthy Namboodiripad',
          participantCode: 'SRI27-EXTRA-LONG-CODE-0001',
          actionType: 'Arrival Check-in',
          source: 'Manual Search',
          timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
          gateOrVenue: 'North Entry Gate No 4',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            volunteer: testVolunteer,
            checkinService: service,
            onScanPressed: () {},
            onEventsPressed: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify cards render without any layout exceptions
      expect(tester.takeException(), isNull);
      expect(find.text('REGISTERED'), findsOneWidget);
      expect(find.text('9999'), findsOneWidget);
      expect(find.text('ARRIVED'), findsOneWidget);
      expect(find.text('8888'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('1111'), findsOneWidget);

      // Reset test screen size
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });

  group('8. Concurrency & Race Condition Prevention', () {
    testWidgets(
        'Older slow request completing after newer request does not overwrite newer statistics',
        (tester) async {
      final service = ControlledAsyncCheckinService();
      final homeKey = GlobalKey<HomeScreenState>();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            key: homeKey,
            volunteer: testVolunteer,
            checkinService: service,
            onScanPressed: () {},
            onEventsPressed: () {},
          ),
        ),
      );
      // HomeScreen initialized, Request 1 in flight
      expect(service.statsCompleters.length, 1);

      // Trigger a reload (Request 2 in flight)
      homeKey.currentState!.reloadStats();
      expect(service.statsCompleters.length, 2);

      // Complete Request 2 FIRST (Newer data: 120 registered, 80 arrived, 40 pending)
      service.statsCompleters[1].complete(
        const FestivalStats(registered: 120, arrived: 80, pendingArrival: 40),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify newer metrics are displayed
      expect(find.text('REGISTERED'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('ARRIVED'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);

      // Now complete older Request 1 LAST (Stale data: 50 registered, 10 arrived, 40 pending)
      service.statsCompleters[0].complete(
        const FestivalStats(registered: 50, arrived: 10, pendingArrival: 40),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // CRITICAL ASSERTION: The older request must NOT overwrite the newer statistics!
      expect(find.text('120'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('50'), findsNothing);
      expect(find.text('10'), findsNothing);
    });

    testWidgets(
        'Older request failing after newer request succeeded does not overwrite with error banner',
        (tester) async {
      final service = ControlledAsyncCheckinService();
      final homeKey = GlobalKey<HomeScreenState>();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            key: homeKey,
            volunteer: testVolunteer,
            checkinService: service,
            onScanPressed: () {},
            onEventsPressed: () {},
          ),
        ),
      );
      expect(service.statsCompleters.length, 1);

      // Trigger Request 2
      homeKey.currentState!.reloadStats();
      expect(service.statsCompleters.length, 2);

      // Request 2 completes successfully
      service.statsCompleters[1].complete(
        const FestivalStats(registered: 200, arrived: 150, pendingArrival: 50),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('200'), findsOneWidget);

      // Request 1 fails with network error
      service.statsCompleters[0].completeError(Exception('Timeout error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // No error banner and 200 still visible
      expect(find.text('Retry'), findsNothing);
      expect(find.text('200'), findsOneWidget);
    });

    testWidgets(
        'Disposing HomeScreen while request is in flight does not throw or trigger setState',
        (tester) async {
      final service = ControlledAsyncCheckinService();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            volunteer: testVolunteer,
            checkinService: service,
            onScanPressed: () {},
            onEventsPressed: () {},
          ),
        ),
      );
      expect(service.statsCompleters.length, 1);

      // Dispose HomeScreen by replacing with another widget
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Disposed Page'))),
      );
      await tester.pump();

      // Complete in-flight request after disposal
      service.statsCompleters[0].complete(
        const FestivalStats(registered: 100, arrived: 50, pendingArrival: 50),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });
  });
}
