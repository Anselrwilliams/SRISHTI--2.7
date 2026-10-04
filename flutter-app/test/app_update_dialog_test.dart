import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srishti_volunteer/core/widgets/app_update_dialog.dart';
import 'package:srishti_volunteer/services/app_update_service.dart';

void main() {
  group('AppUpdateDialog UI Tests', () {
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
  });
}
