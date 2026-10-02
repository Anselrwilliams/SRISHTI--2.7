import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:srishti_volunteer/features/auth/models/volunteer_model.dart';
import 'package:srishti_volunteer/features/checkin/models/attendance_mode.dart';
import 'package:srishti_volunteer/features/dashboard/screens/dashboard_screen.dart';
import 'package:srishti_volunteer/features/event_staff/screens/event_staff_dashboard_screen.dart';
import 'package:srishti_volunteer/features/registration/screens/registration_dashboard_screen.dart';
import 'package:srishti_volunteer/features/scanner/screens/scan_screen.dart';
import 'package:srishti_volunteer/features/scanner/services/qr_camera_manager.dart';

void main() {
  setUp(() async {
    await QrCameraManager.instance.stopAndDispose();
  });

  tearDown(() async {
    await QrCameraManager.instance.stopAndDispose();
  });

  group('QR Scanner Camera Lifecycle Tests', () {
    test('QrCameraManager starts with no active controller and maintains single instance', () async {
      expect(QrCameraManager.instance.hasActiveController, isFalse);
      expect(QrCameraManager.instance.activeController, isNull);
      expect(QrCameraManager.instance.isRunning, isFalse);
    });

    test('QrCameraManager acquires controller with autoStart set to false (no premature camera run)', () async {
      final controller = await QrCameraManager.instance.acquireController();
      expect(QrCameraManager.instance.hasActiveController, isTrue);
      expect(identical(QrCameraManager.instance.activeController, controller), isTrue);
      expect(controller.autoStart, isFalse);
      expect(controller.value.isRunning, isFalse);
    });

    test('QrCameraManager prevents multiple controllers by disposing previous controller before acquiring a new one', () async {
      final controller1 = await QrCameraManager.instance.acquireController();
      expect(QrCameraManager.instance.hasActiveController, isTrue);
      expect(identical(QrCameraManager.instance.activeController, controller1), isTrue);

      final controller2 = await QrCameraManager.instance.acquireController();
      expect(QrCameraManager.instance.hasActiveController, isTrue);
      expect(identical(QrCameraManager.instance.activeController, controller2), isTrue);
      expect(identical(controller1, controller2), isFalse);
    });

    test('QrCameraManager stopAndDispose clears active controller', () async {
      await QrCameraManager.instance.acquireController();
      expect(QrCameraManager.instance.hasActiveController, isTrue);

      await QrCameraManager.instance.stopAndDispose();
      expect(QrCameraManager.instance.hasActiveController, isFalse);
      expect(QrCameraManager.instance.activeController, isNull);
    });

    testWidgets('1 & 2. Camera does NOT initialize or run when ScanScreen is inactive', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScanScreen(
            isActive: false,
            mode: AttendanceMode.arrival,
          ),
        ),
      );
      await tester.pump();

      // MobileScanner widget must not be present in the widget tree
      expect(find.byType(MobileScanner), findsNothing);
      expect(QrCameraManager.instance.hasActiveController, isFalse);
      expect(QrCameraManager.instance.isRunning, isFalse);
    });

    testWidgets('3. Camera initializes and mounts MobileScanner when ScanScreen isActive is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScanScreen(
            isActive: true,
            mode: AttendanceMode.arrival,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(MobileScanner), findsOneWidget);
      expect(QrCameraManager.instance.hasActiveController, isTrue);
    });

    testWidgets('7. Camera disposes and stops when ScanScreen transitions from active to inactive', (tester) async {
      bool active = true;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() => active = false),
                    child: const Text('Deactivate'),
                  ),
                  Expanded(
                    child: ScanScreen(
                      isActive: active,
                      mode: AttendanceMode.arrival,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(MobileScanner), findsOneWidget);
      expect(QrCameraManager.instance.hasActiveController, isTrue);

      // Deactivate scanner (navigating away)
      await tester.tap(find.text('Deactivate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(MobileScanner), findsNothing);
      expect(QrCameraManager.instance.hasActiveController, isFalse);
    });

    testWidgets('7. Camera disposes and stops when ScanScreen is popped/unmounted', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ScanScreen(isActive: true),
                  ),
                );
              },
              child: const Text('Open Scanner'),
            ),
          ),
        ),
      );

      // Open scanner modally
      await tester.tap(find.text('Open Scanner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ScanScreen), findsOneWidget);
      expect(find.byType(MobileScanner), findsOneWidget);
      expect(QrCameraManager.instance.hasActiveController, isTrue);

      // Tap back button
      final backButtonFinder = find.byIcon(Icons.arrow_back_rounded);
      expect(backButtonFinder, findsOneWidget);
      await tester.tap(backButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Scanner must be unmounted and controller disposed
      expect(find.byType(ScanScreen), findsNothing);
      expect(QrCameraManager.instance.hasActiveController, isFalse);
    });

    testWidgets('5 & 6. Standby screen renders Scan Again button when camera is stopped', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScanScreen(
            isActive: true,
            mode: AttendanceMode.arrival,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Simulate camera stopped (e.g., after scan sheet closed)
      ScanScreen.stopActiveScanner();
      await tester.pump();

      // The standby button exists
      final scanAgainFinder = find.byKey(const Key('scan_again_button'));
      expect(scanAgainFinder, findsOneWidget);

      // Tap the button to restart camera
      await tester.tap(scanAgainFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(MobileScanner), findsOneWidget);
    });

    testWidgets('DashboardScreen initializes with camera stopped at tab 0 (Home)', (tester) async {
      const volunteer = VolunteerModel(
        id: 'vol-1',
        username: 'test_vol',
        name: 'Test Volunteer',
        role: 'volunteer',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(volunteer: volunteer),
        ),
      );
      await tester.pump();

      // We are on tab 0 (Home). ScanScreen must NOT have an active camera or MobileScanner
      expect(find.byType(MobileScanner), findsNothing);
      expect(QrCameraManager.instance.hasActiveController, isFalse);

      // Tap the Scan navigation tab to start scanner
      final scanNavFinder = find.text('Scan');
      expect(scanNavFinder, findsOneWidget);
      await tester.tap(scanNavFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Now on tab 1, camera should be active
      expect(find.byType(MobileScanner), findsOneWidget);
      expect(QrCameraManager.instance.hasActiveController, isTrue);

      // Tap Home tab to navigate away
      final homeNavFinder = find.text('Home');
      await tester.tap(homeNavFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Camera must be stopped and disposed
      expect(find.byType(MobileScanner), findsNothing);
      expect(QrCameraManager.instance.hasActiveController, isFalse);
    });

    testWidgets('RegistrationDashboardScreen initializes with camera stopped at tab 0 (Home)', (tester) async {
      const volunteer = VolunteerModel(
        id: 'vol-reg',
        username: 'test_reg',
        name: 'Reg Volunteer',
        role: 'registration',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationDashboardScreen(volunteer: volunteer),
        ),
      );
      await tester.pump();

      // We are on tab 0. Camera must not be initialized
      expect(find.byType(MobileScanner), findsNothing);
      expect(QrCameraManager.instance.hasActiveController, isFalse);

      // Tap Scan Arrival nav button
      final scanNavFinder = find.text('Scan Arrival');
      expect(scanNavFinder, findsOneWidget);
      await tester.tap(scanNavFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Scanner should be active
      expect(find.byType(MobileScanner), findsOneWidget);
      expect(QrCameraManager.instance.hasActiveController, isTrue);
    });

    testWidgets('EventStaffDashboardScreen initializes with camera stopped at tab 0 (Home)', (tester) async {
      const volunteer = VolunteerModel(
        id: 'vol-staff',
        username: 'test_staff',
        name: 'Staff Volunteer',
        role: 'event_staff',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: EventStaffDashboardScreen(volunteer: volunteer),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Camera must not be running initially
      expect(find.byType(MobileScanner), findsNothing);
      expect(QrCameraManager.instance.hasActiveController, isFalse);
    });
  });
}
