import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:srishti_volunteer/core/widgets/app_update_dialog.dart';
import 'package:srishti_volunteer/services/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PackageInfo createPackageInfo(String version, String buildNumber) {
    return PackageInfo(
      appName: 'FEST Volunteer',
      packageName: 'com.srishti.fest.volunteer',
      version: version,
      buildNumber: buildNumber,
      buildSignature: '',
    );
  }

  group('AppVersion Parsing & Semantic Comparison', () {
    test('parses standard release tags correctly', () {
      final v1 = AppVersion.tryParse('v1.0.3');
      expect(v1, isNotNull);
      expect(v1!.major, 1);
      expect(v1.minor, 0);
      expect(v1.patch, 3);
      expect(v1.build, 0);

      final v2 = AppVersion.tryParse('1.0.3');
      expect(v2, isNotNull);
      expect(v2!.patch, 3);

      final v3 = AppVersion.tryParse('v1.0.3+4');
      expect(v3, isNotNull);
      expect(v3!.patch, 3);
      expect(v3.build, 4);

      final v4 = AppVersion.tryParse('1.0.2+3');
      expect(v4, isNotNull);
      expect(v4!.patch, 2);
      expect(v4.build, 3);
    });

    test('ignores non-standard tags with descriptive suffixes like v1.0.2-profile-about', () {
      expect(AppVersion.tryParse('v1.0.2-profile-about'), isNull);
      expect(AppVersion.tryParse('v1.0.2-beta'), isNull);
      expect(AppVersion.tryParse('random-tag'), isNull);
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse(null), isNull);
    });

    test('correctly compares semantic versions and build numbers', () {
      final v102b3 = AppVersion.tryParse('1.0.2+3')!;
      final v103 = AppVersion.tryParse('v1.0.3')!;
      final v103b4 = AppVersion.tryParse('v1.0.3+4')!;
      final v101 = AppVersion.tryParse('v1.0.1')!;

      // 1.0.3 is newer than 1.0.2+3
      expect(v103.isNewerThan(v102b3), isTrue);

      // 1.0.3+4 is newer than 1.0.3
      expect(v103b4.isNewerThan(v103), isTrue);

      // 1.0.2+3 is equal to 1.0.2+3 (not newer)
      expect(v102b3.isNewerThan(AppVersion.tryParse('1.0.2+3')!), isFalse);

      // 1.0.1 is older than 1.0.2+3
      expect(v101.isNewerThan(v102b3), isFalse);
    });
  });

  group('AppUpdateService Update Detection Tests', () {
    setUp(() {
      AppUpdateService.resetSession();
    });

    test('returns update when installed version is older than release', () async {
      final installed = createPackageInfo('1.0.2', '3');

      final releasesJson = jsonEncode([
        {
          'tag_name': 'v1.0.3',
          'html_url': 'https://github.com/Anselrwilliams/SRISHTI--2.7/releases/tag/v1.0.3',
          'draft': false,
          'prerelease': false,
          'assets': [
            {
              'name': 'FEST-Volunteer-v1.0.3.apk',
              'browser_download_url':
                  'https://github.com/Anselrwilliams/SRISHTI--2.7/releases/download/v1.0.3/FEST-Volunteer-v1.0.3.apk',
            }
          ],
        }
      ]);

      final mockClient = MockClient((request) async {
        return http.Response(releasesJson, 200, headers: {'content-type': 'application/json'});
      });

      final update = await AppUpdateService.checkForUpdate(
        client: mockClient,
        packageInfo: installed,
      );

      expect(update, isNotNull);
      expect(update!.version, '1.0.3');
      expect(update.downloadUrl,
          'https://github.com/Anselrwilliams/SRISHTI--2.7/releases/download/v1.0.3/FEST-Volunteer-v1.0.3.apk');
      expect(update.releaseUrl,
          'https://github.com/Anselrwilliams/SRISHTI--2.7/releases/tag/v1.0.3');
    });

    test('returns null when installed version is equal to release', () async {
      final installed = createPackageInfo('1.0.3', '4');

      final releasesJson = jsonEncode([
        {
          'tag_name': 'v1.0.3',
          'html_url': 'https://github.com/Anselrwilliams/SRISHTI--2.7/releases/tag/v1.0.3',
          'draft': false,
          'prerelease': false,
          'assets': [
            {
              'name': 'FEST-Volunteer-v1.0.3.apk',
              'browser_download_url': 'https://example.com/app.apk',
            }
          ],
        }
      ]);

      final mockClient = MockClient((request) async {
        return http.Response(releasesJson, 200);
      });

      final update = await AppUpdateService.checkForUpdate(
        client: mockClient,
        packageInfo: installed,
      );

      expect(update, isNull);
    });

    test('returns null when installed version is newer than release', () async {
      final installed = createPackageInfo('1.0.4', '1');

      final releasesJson = jsonEncode([
        {
          'tag_name': 'v1.0.3',
          'html_url': 'https://example.com',
          'draft': false,
          'prerelease': false,
          'assets': [
            {'name': 'app.apk', 'browser_download_url': 'https://example.com/app.apk'}
          ],
        }
      ]);

      final mockClient = MockClient((request) async => http.Response(releasesJson, 200));

      final update = await AppUpdateService.checkForUpdate(
        client: mockClient,
        packageInfo: installed,
      );

      expect(update, isNull);
    });

    test('ignores suffix tag v1.0.2-profile-about and selects standard releases', () async {
      final installed = createPackageInfo('1.0.2', '3');

      final releasesJson = jsonEncode([
        {
          'tag_name': 'v1.0.2-profile-about',
          'html_url': 'https://github.com/Anselrwilliams/SRISHTI--2.7/releases/tag/v1.0.2-profile-about',
          'draft': false,
          'prerelease': false,
          'assets': [
            {'name': 'FEST-Volunteer-v1.0.2-build3.apk', 'browser_download_url': 'https://example.com/102.apk'}
          ],
        },
        {
          'tag_name': 'v1.0.2',
          'html_url': 'https://github.com/Anselrwilliams/SRISHTI--2.7/releases/tag/v1.0.2',
          'draft': false,
          'prerelease': false,
          'assets': [
            {'name': 'app.apk', 'browser_download_url': 'https://example.com/app.apk'}
          ],
        }
      ]);

      final mockClient = MockClient((request) async => http.Response(releasesJson, 200));

      final update = await AppUpdateService.checkForUpdate(
        client: mockClient,
        packageInfo: installed,
      );

      // Suffix tag is ignored; v1.0.2 is not newer than 1.0.2+3 -> null
      expect(update, isNull);
    });

    test('handles missing APK assets gracefully without throwing', () async {
      final installed = createPackageInfo('1.0.2', '3');

      final releasesJson = jsonEncode([
        {
          'tag_name': 'v1.0.4',
          'html_url': 'https://example.com',
          'draft': false,
          'prerelease': false,
          'assets': [
            {'name': 'source_code.zip', 'browser_download_url': 'https://example.com/src.zip'}
          ],
        }
      ]);

      final mockClient = MockClient((request) async => http.Response(releasesJson, 200));

      final update = await AppUpdateService.checkForUpdate(
        client: mockClient,
        packageInfo: installed,
      );

      expect(update, isNull);
    });

    test('handles malformed release responses without throwing', () async {
      final installed = createPackageInfo('1.0.2', '3');

      final mockClient = MockClient((request) async => http.Response('Invalid JSON response', 200));

      final update = await AppUpdateService.checkForUpdate(
        client: mockClient,
        packageInfo: installed,
      );

      expect(update, isNull);
    });

    test('handles HTTP and network errors gracefully', () async {
      final installed = createPackageInfo('1.0.2', '3');

      final mockClient = MockClient((request) async => throw http.ClientException('Network unreachable'));

      final update = await AppUpdateService.checkForUpdate(
        client: mockClient,
        packageInfo: installed,
      );

      expect(update, isNull);
    });

    testWidgets('displays update dialog modally when update is available',
        (WidgetTester tester) async {
      const updateInfo = AppUpdateInfo(
        version: '1.0.3',
        downloadUrl: 'https://example.com/FEST-Volunteer-v1.0.3.apk',
        releaseUrl: 'https://example.com/release',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AppUpdateDialog.show(context, updateInfo),
                    child: const Text('Check Update'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Check Update'));
      await tester.pumpAndSettle();

      expect(find.text('Update Available'), findsOneWidget);
      expect(find.text('Version 1.0.3 is available.'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
    });
  });
}
