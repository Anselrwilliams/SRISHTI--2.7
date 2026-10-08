import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:srishti_volunteer/core/services/supabase_service.dart';
import 'package:srishti_volunteer/features/auth/screens/login_screen.dart';

void main() {
  group('Registration / Coordinator Login Error Handling Tests', () {
    testWidgets('Empty username and password displays "Username and password are required"',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap login without entering credentials
      final loginBtn = find.text('Sign In');
      expect(loginBtn, findsOneWidget);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      // Verify required error message banner
      expect(find.text('Username and password are required'), findsOneWidget);
    });

    testWidgets('Empty password with username entered displays "Username and password are required"',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter username only
      await tester.enterText(
        find.byType(TextFormField).first,
        'srishti_registration',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Verify required error message banner
      expect(find.text('Username and password are required'), findsOneWidget);
    });

    testWidgets('Empty username with password entered displays "Username and password are required"',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter password only
      await tester.enterText(
        find.byType(TextFormField).last,
        'password123',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Verify required error message banner
      expect(find.text('Username and password are required'), findsOneWidget);
    });

    test('signInWithUsername throws AuthException with "Username and password are required" on empty input',
        () async {
      expect(
        () => SupabaseService.instance.signInWithUsername(
          username: '',
          password: '',
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Username and password are required',
          ),
        ),
      );

      expect(
        () => SupabaseService.instance.signInWithUsername(
          username: 'valid_user',
          password: '',
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Username and password are required',
          ),
        ),
      );

      expect(
        () => SupabaseService.instance.signInWithUsername(
          username: '   ',
          password: 'valid_password',
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Username and password are required',
          ),
        ),
      );
    });

    testWidgets('Wrong credentials displays "Invalid username or password"',
        (tester) async {
      final mockService = MockSupabaseService(
        onSignIn: ({required username, required password}) async {
          throw const AuthException('Invalid username or password');
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(supabaseService: mockService),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'wrong_user',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'wrong_pass',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid username or password'), findsOneWidget);
    });

    testWidgets('Network failure displays "Network connection error"',
        (tester) async {
      final mockService = MockSupabaseService(
        onSignIn: ({required username, required password}) async {
          throw const AuthException('Network connection error');
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(supabaseService: mockService),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'test_user',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'test_pass',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Network connection error'), findsOneWidget);
    });

    testWidgets('Edge function / server failure displays "Login service unavailable"',
        (tester) async {
      final mockService = MockSupabaseService(
        onSignIn: ({required username, required password}) async {
          throw const AuthException('Login service unavailable');
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(supabaseService: mockService),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'test_user',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'test_pass',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Login service unavailable'), findsOneWidget);
    });

    testWidgets('Rate limit failure displays "Too many failed login attempts. Please try again later."',
        (tester) async {
      final mockService = MockSupabaseService(
        onSignIn: ({required username, required password}) async {
          throw const AuthException('Too many failed login attempts. Please try again later.');
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(supabaseService: mockService),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'test_user',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'test_pass',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(
        find.text('Too many failed login attempts. Please try again later.'),
        findsOneWidget,
      );
    });
  });
}

class MockSupabaseService implements SupabaseService {
  final Future<Map<String, dynamic>> Function({
    required String username,
    required String password,
  })? onSignIn;

  MockSupabaseService({this.onSignIn});

  @override
  Future<Map<String, dynamic>> signInWithUsername({
    required String username,
    required String password,
  }) async {
    if (onSignIn != null) {
      return onSignIn!(username: username, password: password);
    }
    return {'success': true};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

