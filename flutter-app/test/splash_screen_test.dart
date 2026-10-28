import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:srishti_volunteer/features/auth/screens/login_screen.dart';
import 'package:srishti_volunteer/main.dart';
import 'package:srishti_volunteer/services/app_update_service.dart';

void main() {
  setUp(() {
    AppUpdateService.hasShownDialog = true;
    AppUpdateService.isCheckInProgress = false;
  });
  tearDown(AppUpdateService.resetSession);

  testWidgets('shows the brand splash for at least 1000 ms', (tester) async {
    final navigatorObserver = _CountingNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [navigatorObserver],
        home: SrishtiStartupSplash(
          initiallyReady: true,
          destinationBuilder: (onReady, _) {
            onReady();
            return const Scaffold(body: Text('Ready'));
          },
        ),
      ),
    );

    expect(find.text('SRISHTI'), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      Colors.black,
    );

    await tester.pump(const Duration(milliseconds: 999));
    expect(find.text('SRISHTI'), findsOneWidget);
    expect(find.text('Ready'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Ready'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(navigatorObserver.pushes, 1);
  });

  testWidgets('cancels the splash timer when disposed', (tester) async {
    final navigatorObserver = _CountingNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [navigatorObserver],
        home: SrishtiStartupSplash(
          destinationBuilder: (onReady, splashComplete) =>
              const Scaffold(body: Text('Ready')),
        ),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: Text('Replaced')));
    await tester.pump(const Duration(seconds: 4));

    expect(tester.takeException(), isNull);
    expect(find.text('Replaced'), findsOneWidget);
    expect(navigatorObserver.pushes, 1);
  });

  testWidgets('unauthenticated startup reveals the existing login after 3s', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SrishtiStartupSplash(
          destinationBuilder: (onReady, splashComplete) => AuthGate(
            authEvents: Stream.value(
              const AuthState(AuthChangeEvent.initialSession, null),
            ),
            onDestinationReady: onReady,
            splashComplete: splashComplete,
          ),
        ),
      ),
    );

    expect(find.text('SRISHTI'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('SRISHTI'), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
    'authenticated startup keeps splash until delayed role lookup ends',
    (tester) async {
      final profile = Completer<Map<String, dynamic>?>();
      final retriedProfile = Completer<Map<String, dynamic>?>();
      var profileRequests = 0;
      final session = Session(
        accessToken: 'test-token',
        tokenType: 'bearer',
        user: const User(
          id: 'auth-user-1',
          appMetadata: {},
          userMetadata: null,
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00Z',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SrishtiStartupSplash(
            destinationBuilder: (onReady, splashComplete) => AuthGate(
              authEvents: Stream.value(
                AuthState(AuthChangeEvent.initialSession, session),
              ),
              startupSession: session,
              profileLoader: () {
                profileRequests++;
                return profileRequests == 1
                    ? profile.future
                    : retriedProfile.future;
              },
              currentEmail: 'test@example.test',
              onDestinationReady: onReady,
              splashComplete: splashComplete,
            ),
          ),
        ),
      );

      expect(profileRequests, 1);
      expect(find.text('SRISHTI'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('SRISHTI'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      profile.complete(null);
      await tester.pumpAndSettle();

      expect(find.text('SRISHTI'), findsNothing);
      expect(
        find.text('No volunteer profile was found for this account.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(profileRequests, 2);
      expect(find.text('Retrying...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      retriedProfile.complete({
        'id': 'volunteer-1',
        'name': 'Test Volunteer',
        'username': 'test-volunteer',
        'role': 'volunteer',
        'status': 'inactive',
      });
      await tester.pumpAndSettle();
      expect(
        find.text('Your volunteer account is not active.'),
        findsOneWidget,
      );
      expect(profileRequests, 2);
    },
  );
}

class _CountingNavigatorObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}
