import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srishti_volunteer/core/widgets/app_update_dialog.dart';
import 'package:srishti_volunteer/services/app_update_service.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  group('AppUpdateDialog UI and Action Tests', () {
    const testUpdateInfo = AppUpdateInfo(
      version: '1.0.0',
      downloadUrl:
          'https://github.com/Anselrwilliams/SRISHTI--2.7/releases/download/v1.0.0/app-release.apk',
      releaseUrl:
          'https://github.com/Anselrwilliams/SRISHTI--2.7/releases/tag/v1.0.0',
    );

    testWidgets('renders all required elements and exact text content',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AppUpdateDialog.show(context, testUpdateInfo),
                    child: const Text('Show Dialog'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Trigger dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('Update Available'), findsOneWidget);

      // Verify Version Text
      expect(find.text('Version 1.0.0 is available.'), findsOneWidget);

      // Verify Description Text
      expect(
        find.text(
          'A new version of the SRISHTI 2.7 app is available with new features and fixes.',
        ),
        findsOneWidget,
      );

      // Verify Buttons
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
    });

    testWidgets('tapping "Later" dismisses the dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AppUpdateDialog.show(context, testUpdateInfo),
                    child: const Text('Show Dialog'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap Later
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('tapping "Update Now" triggers external application launch with APK URL',
        (WidgetTester tester) async {
      Uri? capturedUri;
      LaunchMode? capturedMode;
      int callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AppUpdateDialog.show(
                      context,
                      testUpdateInfo,
                      launchUrlHandler: (uri, mode) async {
                        callCount++;
                        capturedUri = uri;
                        capturedMode = mode;
                        return true;
                      },
                    ),
                    child: const Text('Show Dialog'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Tap Update Now
      await tester.tap(find.text('Update Now'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
      expect(capturedUri.toString(), testUpdateInfo.downloadUrl);
      expect(capturedMode, LaunchMode.externalApplication);
      // No failure snackbar should be displayed on success
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('tapping "Update Now" displays graceful SnackBar if launching fails',
        (WidgetTester tester) async {
      int callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AppUpdateDialog.show(
                      context,
                      testUpdateInfo,
                      launchUrlHandler: (uri, mode) async {
                        callCount++;
                        return false;
                      },
                    ),
                    child: const Text('Show Dialog'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Tap Update Now
      await tester.tap(find.text('Update Now'));
      await tester.pumpAndSettle();

      // First tried externalApplication, then tried platformDefault fallback
      expect(callCount, 2);
      // Graceful error SnackBar shown to the user
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text(
          'Unable to open the download link. Please check your browser or network settings.',
        ),
        findsOneWidget,
      );
    });
  });
}
