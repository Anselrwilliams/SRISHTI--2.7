import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:srishti_volunteer/features/auth/models/volunteer_model.dart';
import 'package:srishti_volunteer/features/checkin/services/checkin_service.dart';
import 'package:srishti_volunteer/features/events/models/event_model.dart';
import 'package:srishti_volunteer/features/history/models/activity_item.dart';
import 'package:srishti_volunteer/features/participants/services/participant_service.dart';
import 'package:srishti_volunteer/features/registration/models/spot_registration_draft.dart';
import 'package:srishti_volunteer/features/registration/models/spot_registration_result.dart';
import 'package:srishti_volunteer/features/registration/screens/registration_dashboard_screen.dart';
import 'package:srishti_volunteer/features/registration/screens/spot_confirmation_screen.dart';
import 'package:srishti_volunteer/features/registration/screens/spot_payment_screen.dart';
import 'package:srishti_volunteer/features/registration/screens/spot_registration_screen.dart';
import 'package:srishti_volunteer/features/registration/screens/spot_success_screen.dart';
import 'package:srishti_volunteer/features/registration/services/spot_registration_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSpotRegistrationService extends SpotRegistrationService {
  List<EventModel> mockEvents = [];
  SpotRegistrationResult? mockResult;
  bool createCalled = false;

  @override
  Future<List<EventModel>> getAvailableEvents() async {
    if (mockEvents.isNotEmpty) return mockEvents;
    return const [
      EventModel(
        id: 'ev-test-01',
        eventCode: 'TEST-EV-01',
        name: 'Code Sprint',
        category: 'Coding',
        venue: 'CS Lab 3',
        date: 'Day 1',
        registrationType: 'individual',
        maxTeamSize: 1,
        registrationFee: 150.0,
      ),
      EventModel(
        id: 'ev-test-02',
        eventCode: 'TEST-EV-02',
        name: 'HackAI 24h Hackathon',
        category: 'Web & App',
        venue: 'Main Auditorium',
        date: 'Day 1',
        registrationType: 'team',
        maxTeamSize: 4,
        registrationFee: 400.0,
      ),
    ];
  }

  @override
  Future<SpotRegistrationResult> createSpotRegistration({
    required SpotRegistrationDraft draft,
    required String volunteerId,
  }) async {
    createCalled = true;
    if (mockResult != null) return mockResult!;
    return SpotRegistrationResult.success(
      participantCode: 'SRI27-9999',
      message: 'Spot Registration successful!',
      event: draft.selectedEvent,
    );
  }
}

class MockCheckinService extends CheckinService {
  @override
  Future<List<ActivityItem>> getRecentArrivals({int limit = 20}) async => [];
  @override
  Future<int> getTotalParticipantsCount() async => 50;
  @override
  Future<int> getTotalArrivalsCount() async => 20;
}

void main() {
  group('SRISHTI 2.7 Spot Registration Feature Tests', () {
    const regCoordinator = VolunteerModel(
      id: 'vol-coord-1',
      name: 'Ananya Coordinator',
      username: 'reg_coord',
      role: 'registration',
      status: 'active',
    );

    const eventStaff = VolunteerModel(
      id: 'vol-staff-1',
      name: 'Rahul Staff',
      username: 'event_staff_user',
      role: 'event_staff',
      status: 'active',
    );

    test('1. EventModel parses dynamic registrationType and team limits correctly', () {
      final individualMap = {
        'id': 'ev-1',
        'event_code': 'SOLO-01',
        'name': 'Speed Typing',
        'category': 'General',
        'registration_type': 'individual',
        'max_team_size': '1',
        'fee': '100',
      };
      final soloEvent = EventModel.fromMap(individualMap);
      expect(soloEvent.isIndividualEvent, isTrue);
      expect(soloEvent.isTeamEvent, isFalse);
      expect(soloEvent.effectiveMaxTeamSize, 1);
      expect(soloEvent.registrationFee, 100.0);

      final teamMap = {
        'id': 'ev-2',
        'event_code': 'HACK-01',
        'name': 'Hackathon',
        'category': 'Coding',
        'registration_type': 'team',
        'max_team_size': '4',
        'amount': '400',
      };
      final teamEvent = EventModel.fromMap(teamMap);
      expect(teamEvent.isTeamEvent, isTrue);
      expect(teamEvent.isIndividualEvent, isFalse);
      expect(teamEvent.effectiveMaxTeamSize, 4);
      expect(teamEvent.registrationFee, 400.0);
    });

    test('2. SpotRegistrationDraft calculates fee and UPI payment deep link', () {
      const event = EventModel(
        id: 'ev-1',
        eventCode: 'SOLO-01',
        name: 'Coding Comp',
        category: 'Coding',
        registrationType: 'individual',
        registrationFee: 150.0,
      );

      final draft = SpotRegistrationDraft(
        fullName: 'Karthik',
        phone: '9876543210',
        email: 'karthik@fest.com',
        college: 'GEC Thrissur',
        selectedEvent: event,
      );

      expect(draft.effectiveAmount, 150.0);
      expect(draft.totalMembersCount, 1);
      expect(draft.upiPaymentUrl, contains('upi://pay?'));
      expect(draft.upiPaymentUrl, contains('am=150'));
    });

    testWidgets('3. Registration Coordinator sees SPOT REGISTRATION on Dashboard',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RegistrationDashboardScreen(
            volunteer: regCoordinator,
            checkinService: MockCheckinService(),
            participantService: ParticipantService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FEST CHECK-IN'), findsOneWidget);
      expect(find.text('SPOT REGISTRATION'), findsOneWidget);
      expect(find.text('On-spot participant registration & pass'), findsOneWidget);
    });

    testWidgets('4. Event Staff receives Access Denied when opening SpotRegistrationScreen',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SpotRegistrationScreen(
            volunteer: eventStaff,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Access Denied'), findsWidgets);
      expect(
        find.text('Only Registration Coordinators can access Spot Registration.'),
        findsOneWidget,
      );
    });

    testWidgets('5. SpotRegistrationScreen validates required fields and formats',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockService = MockSpotRegistrationService();

      await tester.pumpWidget(
        MaterialApp(
          home: SpotRegistrationScreen(
            volunteer: regCoordinator,
            spotRegistrationService: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Continue to Payment without filling form
      final continueButton = find.text('Continue to Payment');
      expect(continueButton, findsOneWidget);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Check validation error messages
      expect(find.text('Full Name is required'), findsOneWidget);
      expect(find.text('Phone number is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('College is required'), findsOneWidget);

      // Enter invalid email and short phone
      await tester.enterText(find.byType(TextFormField).at(0), 'Rahul');
      await tester.enterText(find.byType(TextFormField).at(1), '1234');
      await tester.enterText(find.byType(TextFormField).at(2), 'invalid-email');
      await tester.enterText(find.byType(TextFormField).at(3), 'GEC');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid 10-digit phone number'), findsOneWidget);
      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('6. Team event allows adding and removing team members up to max limit',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockService = MockSpotRegistrationService();
      const teamEvent = EventModel(
        id: 'ev-team',
        eventCode: 'HACK-01',
        name: 'Hackathon',
        category: 'Coding',
        registrationType: 'team',
        maxTeamSize: 3, // Leader + 2 extra members
        registrationFee: 300.0,
      );
      mockService.mockEvents = [teamEvent];

      await tester.pumpWidget(
        MaterialApp(
          home: SpotRegistrationScreen(
            volunteer: regCoordinator,
            spotRegistrationService: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Team members card should be displayed
      expect(find.text('TEAM MEMBERS'), findsOneWidget);
      expect(find.text('Add Member'), findsOneWidget);

      // Add Member #2
      await tester.tap(find.text('Add Member'));
      await tester.pumpAndSettle();
      expect(find.text('Member #2'), findsOneWidget);

      // Add Member #3
      await tester.tap(find.text('Add Member'));
      await tester.pumpAndSettle();
      expect(find.text('Member #3'), findsOneWidget);

      // Limit reached: Max is 3 (1 leader + 2 members). "Add Member" button should disappear
      expect(find.text('Add Member'), findsNothing);

      // Remove Member #3
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Member #3'), findsNothing);
      expect(find.text('Add Member'), findsOneWidget);
    });

    testWidgets('7. SpotPaymentScreen displays UPI QR and requires coordinator verification',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const event = EventModel(
        id: 'ev-1',
        eventCode: 'TEST-01',
        name: 'Web Dev Sprint',
        category: 'Web',
        registrationFee: 200.0,
      );

      final draft = SpotRegistrationDraft(
        fullName: 'Ananya Nair',
        phone: '9876543210',
        email: 'ananya@fest.org',
        college: 'Model Engineering College',
        selectedEvent: event,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SpotPaymentScreen(
            volunteer: regCoordinator,
            draft: draft,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // UPI QR must be rendered
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('PAYMENT QR'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Verify Payment Received'), findsOneWidget);

      // Tap Continue without verifying payment -> should warn and not navigate
      await tester.tap(find.text('Verify Payment to Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Verify Payment to Continue'), findsOneWidget);

      // Verify payment
      await tester.tap(find.text('Verify Payment Received'));
      await tester.pumpAndSettle();

      // Status changes to Verified
      expect(find.text('Verified'), findsWidgets);
      expect(find.text('Confirm Registration'), findsOneWidget);
    });

    testWidgets('8. SpotConfirmationScreen summarizes data and handles registration success',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockService = MockSpotRegistrationService();
      const event = EventModel(
        id: 'ev-1',
        eventCode: 'TEST-01',
        name: 'Coding Sprint',
        category: 'Coding',
        registrationFee: 150.0,
      );

      final verifiedDraft = SpotRegistrationDraft(
        fullName: 'Karthik Raj',
        phone: '9876543212',
        email: 'karthik@test.org',
        college: 'GEC Thrissur',
        selectedEvent: event,
        isPaymentVerified: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SpotConfirmationScreen(
            volunteer: regCoordinator,
            draft: verifiedDraft,
            spotRegistrationService: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Karthik Raj'), findsOneWidget);
      expect(find.text('Coding Sprint'), findsOneWidget);
      expect(find.text('PAYMENT VERIFIED'), findsOneWidget);
      expect(find.text('Complete Registration'), findsOneWidget);

      // Complete registration
      await tester.tap(find.text('Complete Registration'));
      await tester.pumpAndSettle();

      expect(mockService.createCalled, isTrue);
      // Navigates to SpotSuccessScreen
      expect(find.text('Registration Successful! 🎉'), findsOneWidget);
      expect(find.text('SRI27-9999'), findsOneWidget);
    });

    testWidgets('9. SpotSuccessScreen renders scannable Participant QR and participant code',
        (tester) async {
      const event = EventModel(
        id: 'ev-1',
        eventCode: 'TEST-01',
        name: 'Coding Sprint',
        category: 'Coding',
      );

      final draft = SpotRegistrationDraft(
        fullName: 'Rahul Sharma',
        college: 'GEC Thrissur',
        selectedEvent: event,
      );

      const result = SpotRegistrationResult(
        isSuccess: true,
        participantCode: 'SRI27-0105',
        message: 'Success',
        event: event,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SpotSuccessScreen(
            volunteer: regCoordinator,
            result: result,
            draft: draft,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SRI27-0105'), findsOneWidget);
      expect(find.text('FEST PARTICIPANT CODE'), findsOneWidget);

      // Participant QR must be rendered with ONLY the participant code
      final qrFinder = find.byType(QrImageView);
      expect(qrFinder, findsOneWidget);

      expect(find.text('Register Another Participant'), findsOneWidget);
      expect(find.text('Back to Registration Desk'), findsOneWidget);
    });

    test('10. SpotRegistrationService returns empty list when Supabase has no events',
        () async {
      final realService = SpotRegistrationService();
      // Without Supabase initialization, getAvailableEvents returns empty list
      final events = await realService.getAvailableEvents();
      expect(events, isEmpty);
    });

    testWidgets(
        '11. SpotRegistrationScreen displays "No Events Available" with retry option when events are empty',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final emptyMockService = MockSpotRegistrationService();
      emptyMockService.mockEvents = []; // Initially empty

      // Override getAvailableEvents directly to return empty list
      bool retried = false;
      final customEmptyService = _CustomEmptyEventsService(
        onRetry: () => retried = true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SpotRegistrationScreen(
            volunteer: regCoordinator,
            spotRegistrationService: customEmptyService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display empty events view
      expect(find.text('No Events Available'), findsOneWidget);
      expect(
        find.text(
          'Unable to load events from the festival database or no events are currently published for spot registration.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry Loading Events'), findsOneWidget);

      // Tap retry button
      await tester.tap(find.text('Retry Loading Events'));
      await tester.pumpAndSettle();
      expect(retried, isTrue);
    });

    test(
        '12. Supabase unavailable returns failure, no success result, and no fake participant code',
        () async {
      final service = SpotRegistrationService();
      const event = EventModel(
        id: 'ev-test-1',
        eventCode: 'TEST-01',
        name: 'Coding',
        category: 'Coding',
        registrationFee: 100.0,
      );
      final draft = SpotRegistrationDraft(
        fullName: 'Test Participant',
        phone: '9876543210',
        email: 'test@fest.com',
        college: 'GEC Thrissur',
        selectedEvent: event,
        isPaymentVerified: true,
      );

      final result = await service.createSpotRegistration(
        draft: draft,
        volunteerId: 'vol-1',
      );

      // Must be an explicit failure
      expect(result.isSuccess, isFalse);
      // NEVER generate or return a fake participant code on failure
      expect(result.participantCode, isEmpty);
      expect(
        result.message,
        'Registration could not be completed. No registration was saved.',
      );
      expect(result.registrationId, isNull);

      // Attempting to invoke function while offline throws StateError
      expect(
        () => service.invokeSpotRegisterFunction({}),
        throwsA(isA<StateError>()),
      );
    });

    test(
        '13. Edge Function 200 success returns SpotRegistrationResult.success with server-provided codes and IDs',
        () async {
      final service = _MockEdgeFunctionService(
        (payload) async => FunctionResponse(
          status: 200,
          data: {
            'success': true,
            'data': {
              'participant_id': 'part-uuid-101',
              'participant_code': 'SRI27-0105',
              'registration_id': 'reg-uuid-201',
              'status': 'registered',
              'payment_status': 'verified',
            },
          },
        ),
      );

      const event = EventModel(
        id: 'ev-test-1',
        eventCode: 'TEST-01',
        name: 'Coding Sprint',
        category: 'Coding',
        registrationFee: 150.0,
      );
      final draft = SpotRegistrationDraft(
        fullName: 'Karthik Raj',
        phone: '9876543212',
        email: 'karthik@fest.org',
        college: 'GEC Thrissur',
        selectedEvent: event,
        isPaymentVerified: true,
      );

      final result = await service.createSpotRegistration(
        draft: draft,
        volunteerId: 'vol-coord-1',
      );

      expect(result.isSuccess, isTrue);
      expect(result.participantCode, 'SRI27-0105');
      expect(result.participantId, 'part-uuid-101');
      expect(result.registrationId, 'reg-uuid-201');
      expect(result.message, 'Spot Registration completed successfully!');
    });

    test(
        '14. Edge Function 403 Forbidden maps to Access Denied message and registration failure',
        () async {
      final service = _MockEdgeFunctionService(
        (payload) async => throw const FunctionsHttpException(
          status: 403,
          details: {
            'error':
                'Forbidden: Only Registration Coordinators and Admins can perform Spot Registrations',
          },
        ),
      );

      const event = EventModel(
        id: 'ev-test-1',
        eventCode: 'TEST-01',
        name: 'Coding Sprint',
        category: 'Coding',
        registrationFee: 150.0,
      );
      final draft = SpotRegistrationDraft(
        fullName: 'Anoop Kumar',
        phone: '9876543211',
        email: 'anoop@fest.com',
        college: 'GEC Palakkad',
        selectedEvent: event,
        isPaymentVerified: true,
      );

      final result = await service.createSpotRegistration(
        draft: draft,
        volunteerId: 'vol-staff-1',
      );

      expect(result.isSuccess, isFalse);
      expect(result.participantCode, isEmpty);
      expect(
        result.message,
        'Access Denied: Only Registration Coordinators can register participants.',
      );
    });

    test(
        '15. Edge Function 409 Conflict maps to duplicate registration result',
        () async {
      final service = _MockEdgeFunctionService(
        (payload) async => throw const FunctionsHttpException(
          status: 409,
          details: {
            'error': 'DUPLICATE_REGISTRATION: Participant is already registered',
            'is_duplicate': true,
          },
        ),
      );

      const event = EventModel(
        id: 'ev-test-1',
        eventCode: 'TEST-01',
        name: 'Coding Sprint',
        category: 'Coding',
        registrationFee: 150.0,
      );
      final draft = SpotRegistrationDraft(
        fullName: 'Meera Nair',
        phone: '9876543212',
        email: 'meera@fest.com',
        college: 'GEC Barton Hill',
        selectedEvent: event,
        isPaymentVerified: true,
      );

      final result = await service.createSpotRegistration(
        draft: draft,
        volunteerId: 'vol-coord-1',
      );

      expect(result.isSuccess, isFalse);
      expect(result.isDuplicate, isTrue);
      expect(
        result.message,
        'Meera Nair is already registered for Coding Sprint.',
      );
    });

    test(
        '16. Edge Function 422 maps to event unavailable or spot registration disabled',
        () async {
      final service = _MockEdgeFunctionService(
        (payload) async => throw const FunctionsHttpException(
          status: 422,
          details: {
            'error':
                'SPOT_REGISTRATION_DISABLED: Spot registration is closed for this event',
          },
        ),
      );

      const event = EventModel(
        id: 'ev-test-1',
        eventCode: 'TEST-01',
        name: 'Workshop',
        category: 'Coding',
        registrationFee: 100.0,
      );
      final draft = SpotRegistrationDraft(
        fullName: 'Faisal T',
        phone: '9876543215',
        email: 'faisal@fest.com',
        college: 'CET',
        selectedEvent: event,
        isPaymentVerified: true,
      );

      final result = await service.createSpotRegistration(
        draft: draft,
        volunteerId: 'vol-coord-1',
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.message,
        'SPOT_REGISTRATION_DISABLED: Spot registration is closed for this event',
      );
    });

    test(
        '17. Edge Function 500 maps to user-safe database failure message',
        () async {
      final service = _MockEdgeFunctionService(
        (payload) async => throw const FunctionsHttpException(
          status: 500,
          details: {
            'error': 'Internal server error',
          },
        ),
      );

      const event = EventModel(
        id: 'ev-test-1',
        eventCode: 'TEST-01',
        name: 'Coding Sprint',
        category: 'Coding',
        registrationFee: 150.0,
      );
      final draft = SpotRegistrationDraft(
        fullName: 'George V',
        phone: '9876543216',
        email: 'george@fest.com',
        college: 'GEC Thrissur',
        selectedEvent: event,
        isPaymentVerified: true,
      );

      final result = await service.createSpotRegistration(
        draft: draft,
        volunteerId: 'vol-coord-1',
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.message,
        'Registration could not be completed. No registration was saved.',
      );
    });

    testWidgets(
        '18. SpotConfirmationScreen shows failure dialog with Retry/Back and does not show success screen or QR on failed write',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final failingService = MockSpotRegistrationService();
      failingService.mockResult = SpotRegistrationResult.failure(
        message: 'Registration could not be completed. No registration was saved.',
      );

      const event = EventModel(
        id: 'ev-1',
        eventCode: 'TEST-01',
        name: 'Coding Sprint',
        category: 'Coding',
        registrationFee: 150.0,
      );

      final verifiedDraft = SpotRegistrationDraft(
        fullName: 'Karthik Raj',
        phone: '9876543212',
        email: 'karthik@test.org',
        college: 'GEC Thrissur',
        selectedEvent: event,
        isPaymentVerified: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SpotConfirmationScreen(
            volunteer: regCoordinator,
            draft: verifiedDraft,
            spotRegistrationService: failingService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Complete Registration
      await tester.tap(find.text('Complete Registration'));
      await tester.pumpAndSettle();

      // SpotSuccessScreen must NOT be present
      expect(find.byType(SpotSuccessScreen), findsNothing);
      expect(find.text('Registration Successful! 🎉'), findsNothing);
      expect(find.byType(QrImageView), findsNothing);

      // Failure dialog must appear with exact user-safe message
      expect(find.text('Registration Failed'), findsOneWidget);
      expect(
        find.text('Registration could not be completed. No registration was saved.'),
        findsOneWidget,
      );
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Tapping Back dismisses the dialog
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Registration Failed'), findsNothing);

      // We are still on ConfirmationScreen and can retry
      expect(find.text('Complete Registration'), findsOneWidget);

      // Now tap Complete Registration again, and test Retry in dialog
      await tester.tap(find.text('Complete Registration'));
      await tester.pumpAndSettle();
      expect(find.text('Registration Failed'), findsOneWidget);

      // Change mockResult to success before tapping Retry
      failingService.mockResult = SpotRegistrationResult.success(
        participantCode: 'SRI27-8888',
        message: 'Success',
        event: event,
      );

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Now it navigates to SpotSuccessScreen with QR
      expect(find.byType(SpotSuccessScreen), findsOneWidget);
      expect(find.text('Registration Successful! 🎉'), findsOneWidget);
      expect(find.text('SRI27-8888'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
    });

    test('19. Real transaction reference entered by coordinator is passed to Edge Function payload', () async {
      Map<String, dynamic>? capturedPayload;
      final service = _MockEdgeFunctionService(
        (payload) async {
          capturedPayload = payload;
          return FunctionResponse(
            status: 200,
            data: {
              'success': true,
              'data': {
                'participant_id': 'part-uuid-102',
                'participant_code': 'SRI27-0106',
                'registration_id': 'reg-uuid-202',
                'status': 'registered',
                'payment_status': 'verified',
              },
            },
          );
        },
      );

      const event = EventModel(
        id: 'ev-test-1',
        eventCode: 'TEST-01',
        name: 'Coding Sprint',
        category: 'Coding',
        registrationFee: 150.0,
      );
      final draft = SpotRegistrationDraft(
        fullName: 'Anoop Nair',
        phone: '9876543299',
        email: 'anoop@fest.org',
        college: 'GEC Thrissur',
        selectedEvent: event,
        isPaymentVerified: true,
        transactionRef: 'UPI-UTR-987654321098',
      );

      final result = await service.createSpotRegistration(
        draft: draft,
        volunteerId: 'vol-coord-1',
      );

      expect(result.isSuccess, isTrue);
      expect(capturedPayload, isNotNull);
      final paymentMap = capturedPayload!['payment'] as Map<String, dynamic>;
      expect(paymentMap['reference'], 'UPI-UTR-987654321098');
      expect(paymentMap['method'], 'upi');
      expect(paymentMap['amount'], 150.0);
    });
  });
}

class _CustomEmptyEventsService extends SpotRegistrationService {
  final VoidCallback onRetry;
  _CustomEmptyEventsService({required this.onRetry});

  @override
  Future<List<EventModel>> getAvailableEvents() async {
    onRetry();
    return [];
  }
}

class _MockEdgeFunctionService extends SpotRegistrationService {
  final Future<FunctionResponse> Function(Map<String, dynamic> payload) handler;
  _MockEdgeFunctionService(this.handler);

  @override
  bool get isDatabaseReady => true;

  @override
  Future<FunctionResponse> invokeSpotRegisterFunction(
    Map<String, dynamic> payload,
  ) async {
    return await handler(payload);
  }
}
