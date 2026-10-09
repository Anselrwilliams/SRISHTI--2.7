import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:srishti_volunteer/core/theme/app_theme.dart';
import 'package:srishti_volunteer/features/auth/models/volunteer_model.dart';
import 'package:srishti_volunteer/features/profile/screens/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testVolunteer = VolunteerModel(
    id: 'vol-test-1',
    name: 'Test Volunteer',
    username: 'test_volunteer',
    role: 'event_staff',
    status: 'active',
  );

  group('ProfileScreen App Version Information Tests', () {
    setUp(() {
      PackageInfo.setMockInitialValues(
        appName: 'FEST Volunteer',
        packageName: 'com.srishti.fest.volunteer',
        version: '1.0.2',
        buildNumber: '3',
        buildSignature: '',
      );
    });

    testWidgets('renders About this app section with exact required text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProfileScreen(volunteer: testVolunteer),
        ),
      );

      await tester.pumpAndSettle();

      // Verify "About this app" header
      expect(find.text('About this app'), findsOneWidget);

      // Verify exact combined version string: FEST Volunteer v1.0.2 (Build 3)
      expect(
        find.text('FEST Volunteer v1.0.2 (Build 3)'),
        findsOneWidget,
      );

      // Verify detail rows
      expect(find.text('App name'), findsOneWidget);
      expect(find.text('FEST Volunteer'), findsOneWidget);
      expect(find.text('Version'), findsOneWidget);
      expect(find.text('v1.0.2'), findsNWidgets(2)); // Version badge + detail row
      expect(find.text('Build'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Verify that Sign Out button is still present above the About section
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets(
        'dynamically reflects updated version and build number from PackageInfo',
        (WidgetTester tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'FEST Volunteer',
        packageName: 'com.srishti.fest.volunteer',
        version: '1.1.0',
        buildNumber: '15',
        buildSignature: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProfileScreen(volunteer: testVolunteer),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('FEST Volunteer v1.1.0 (Build 15)'),
        findsOneWidget,
      );
      expect(find.text('v1.1.0'), findsNWidgets(2));
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('gracefully falls back when platform metadata is unavailable',
        (WidgetTester tester) async {
      // Create with volunteer without setting mock or allowing fallback
      await tester.pumpWidget(
        MaterialApp(
          home: const ProfileScreen(volunteer: testVolunteer),
        ),
      );

      await tester.pumpAndSettle();

      // Screen should not crash and should render About section
      expect(find.text('About this app'), findsOneWidget);
      expect(find.textContaining('FEST Volunteer'), findsWidgets);
    });

    testWidgets('renders cleanly in dark theme mode without overflow',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: const ProfileScreen(volunteer: testVolunteer),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('About this app'), findsOneWidget);
      expect(
        find.text('FEST Volunteer v1.0.2 (Build 3)'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
