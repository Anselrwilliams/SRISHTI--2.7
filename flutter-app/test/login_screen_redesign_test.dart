import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srishti_volunteer/core/services/supabase_service.dart';
import 'package:srishti_volunteer/features/auth/screens/login_screen.dart';

class MockSlowSupabaseService implements SupabaseService {
  final Completer<Map<String, dynamic>> completer = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> signInWithUsername({
    required String username,
    required String password,
  }) async {
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SRISHTI 2.7 Login Screen Redesign Tests', () {
    testWidgets('Renders all redesigned visual elements (heading, subtitle, logo, labels, placeholders)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Heading & Subtitle
      expect(find.text('SRISHTI 2.7'), findsOneWidget);
      expect(find.text('Sign in to continue'), findsOneWidget);

      // Logo Asset
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final Image imageWidget = tester.widget(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      expect((imageWidget.image as AssetImage).assetName, 'assets/images/srishti_logo.jpg');

      // Username Field
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Enter your username'), findsOneWidget);

      // Password Field
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);

      // Primary Button
      expect(find.text('Sign In'), findsOneWidget);

      // Security / Volunteer notice
      expect(find.text('Authorized volunteers and event team only'), findsOneWidget);
    });

    testWidgets('Password field is obscured by default and toggles on icon tap',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final passwordFieldFinder = find.byType(TextFormField).last;
      TextField textField = tester.widget<TextField>(
        find.descendant(of: passwordFieldFinder, matching: find.byType(TextField)),
      );
      expect(textField.obscureText, isTrue);

      // Tap show/hide password toggle button
      final toggleFinder = find.byIcon(Icons.visibility_outlined);
      expect(toggleFinder, findsOneWidget);
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Should now be unobscured
      textField = tester.widget<TextField>(
        find.descendant(of: passwordFieldFinder, matching: find.byType(TextField)),
      );
      expect(textField.obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      // Tap again to obscure
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      textField = tester.widget<TextField>(
        find.descendant(of: passwordFieldFinder, matching: find.byType(TextField)),
      );
      expect(textField.obscureText, isTrue);
    });

    testWidgets('Does NOT contain unwanted elements (social login, signup, forgot password, remember me)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Google'), findsNothing);
      expect(find.text('Apple'), findsNothing);
      expect(find.text('Facebook'), findsNothing);
      expect(find.text('Sign Up'), findsNothing);
      expect(find.text('Sign up'), findsNothing);
      expect(find.text('Create Account'), findsNothing);
      expect(find.text('Create account'), findsNothing);
      expect(find.text('Forgot Password'), findsNothing);
      expect(find.text('Forgot password?'), findsNothing);
      expect(find.text('Remember me'), findsNothing);
    });

    testWidgets('Shows loading spinner and disables sign in button during authentication',
        (tester) async {
      final mockService = MockSlowSupabaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(supabaseService: mockService),
        ),
      );
      await tester.pumpAndSettle();

      // Enter valid fields
      await tester.enterText(find.byType(TextFormField).first, 'coordinator');
      await tester.enterText(find.byType(TextFormField).last, 'secret');

      // Tap Sign In
      await tester.tap(find.text('Sign In'));
      await tester.pump(); // Start async login

      // CircularProgressIndicator should be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete future
      mockService.completer.complete({'success': true});
      await tester.pumpAndSettle();
    });

    testWidgets('Back button behaves correctly when navigation can pop',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: Builder(
                    builder: (innerContext) => ElevatedButton(
                      onPressed: () {
                        Navigator.of(innerContext).push(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text('Open Login'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Login
      await tester.tap(find.text('Open Login'));
      await tester.pumpAndSettle();

      // Verify back button is visible when canPop is true
      final backButton = find.byIcon(Icons.arrow_back_rounded);
      expect(backButton, findsOneWidget);

      // Tap back button
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // We should be back on Open Login screen
      expect(find.text('Open Login'), findsOneWidget);
      expect(find.text('Sign in to continue'), findsNothing);
    });
  });
}
