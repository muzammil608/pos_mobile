import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_system/core/constants/app_config.dart';
import 'package:pos_system/services/update_service.dart';
import 'package:pos_system/widgets/app_navigation.dart';
import 'package:pos_system/widgets/update_button.dart';
import 'package:pos_system/widgets/update_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Semantic Versioning and Pre-Release Comparison Tests', () {
    test('Correctly compares major, minor, and patch versions', () {
      final v100 = AppVersion.parse('1.0.0');
      final v110 = AppVersion.parse('1.1.0');
      final v101 = AppVersion.parse('1.0.1');
      final v200 = AppVersion.parse('2.0.0');

      expect(v110.isGreaterThan(v100), isTrue);
      expect(v101.isGreaterThan(v100), isTrue);
      expect(v200.isGreaterThan(v110), isTrue);
      expect(v100.isLessThan(v110), isTrue);
      expect(v100.isEqualTo(AppVersion.parse('1.0.0')), isTrue);
    });

    test('Handles v prefix and build signatures', () {
      final v1 = AppVersion.parse('v1.0.0');
      final v2 = AppVersion.parse('1.0.0');
      final v3 = AppVersion.parse('1.0.0+2');
      final v4 = AppVersion.parse('1.0.0+1');

      expect(v1.isEqualTo(v2), isTrue);
      expect(v3.isGreaterThan(v4), isTrue);
    });

    test('Release version is considered greater than pre-release (1.2.0 > 1.2.0-beta.2)', () {
      final release = AppVersion.parse('1.2.0');
      final beta = AppVersion.parse('1.2.0-beta.2');

      expect(release.isGreaterThan(beta), isTrue);
      expect(beta.isLessThan(release), isTrue);
    });

    test('Correctly compares 1.2.0-beta.2 > 1.2.0-beta.1', () {
      final beta1 = AppVersion.parse('1.2.0-beta.1');
      final beta2 = AppVersion.parse('1.2.0-beta.2');

      expect(beta2.isGreaterThan(beta1), isTrue);
      expect(beta1.isLessThan(beta2), isTrue);
    });

    test('Correctly compares numeric pre-release segments: 1.2.0-beta.10 > 1.2.0-beta.2', () {
      final beta2 = AppVersion.parse('1.2.0-beta.2');
      final beta10 = AppVersion.parse('1.2.0-beta.10');

      // Numeric comparison 10 > 2, not lexicographical '10' < '2'
      expect(beta10.isGreaterThan(beta2), isTrue);
      expect(beta2.isLessThan(beta10), isTrue);
    });

    test('Correctly compares pre-release names: 1.2.0-beta.1 > 1.2.0-alpha.5', () {
      final alpha = AppVersion.parse('1.2.0-alpha.5');
      final beta = AppVersion.parse('1.2.0-beta.1');

      expect(beta.isGreaterThan(alpha), isTrue);
      expect(alpha.isLessThan(beta), isTrue);
    });

    test('Correctly compares longer pre-release parts: 1.2.0-beta.1.1 > 1.2.0-beta.1', () {
      final shortBeta = AppVersion.parse('1.2.0-beta.1');
      final longBeta = AppVersion.parse('1.2.0-beta.1.1');

      expect(longBeta.isGreaterThan(shortBeta), isTrue);
      expect(shortBeta.isLessThan(longBeta), isTrue);
    });
  });

  group('AppRelease JSON Parsing and Asset Selection Tests', () {
    test('Correctly parses release metadata and locates Windows .exe asset', () {
      final json = {
        'tag_name': 'v1.2.0-beta.2',
        'name': 'ShopFlow POS v1.2.0-beta.2 Pre-Release',
        'body': '• Automated background updater\n• Performance improvements',
        'published_at': '2026-08-15T18:00:00Z',
        'html_url': 'https://github.com/muzammil608/pos_mobile/releases/tag/v1.2.0-beta.2',
        'prerelease': true,
        'draft': false,
        'assets': [
          {
            'name': 'source_code.zip',
            'browser_download_url': 'https://github.com/muzammil608/pos_mobile/releases/download/v1.2.0-beta.2/source.zip',
            'size': 1024000,
          },
          {
            'name': 'ShopFlow_POS_Setup_v1.2.0-beta.2.exe',
            'browser_download_url': 'https://github.com/muzammil608/pos_mobile/releases/download/v1.2.0-beta.2/ShopFlow_POS_Setup_v1.2.0-beta.2.exe',
            'size': 47185920,
            'digest': 'sha256:abcd1234efgh5678',
          },
        ],
      };

      final release = AppRelease.fromJson(json);

      expect(release.version, equals('1.2.0-beta.2'));
      expect(release.tagName, equals('v1.2.0-beta.2'));
      expect(release.title, equals('ShopFlow POS v1.2.0-beta.2 Pre-Release'));
      expect(release.isPrerelease, isTrue);
      expect(release.isDraft, isFalse);
      expect(release.assetName, equals('ShopFlow_POS_Setup_v1.2.0-beta.2.exe'));
      expect(release.assetDownloadUrl, equals('https://github.com/muzammil608/pos_mobile/releases/download/v1.2.0-beta.2/ShopFlow_POS_Setup_v1.2.0-beta.2.exe'));
      expect(release.assetDigest, equals('abcd1234efgh5678'));
      expect(release.formattedSize, equals('45.0 MB'));
      expect(release.formattedPublishedDate, contains('Aug 15, 2026'));
    });

    test('Selects the installer matching the release version exactly, ignoring arbitrary or older exes', () {
      final release = AppRelease.fromJson({
        'tag_name': 'v1.2.0-beta.2',
        'assets': [
          {'name': 'other_tool.exe', 'browser_download_url': 'https://example.com/other.exe', 'size': 100},
          {'name': 'ShopFlow_POS_Setup_v1.2.0-beta.1.exe', 'browser_download_url': 'https://example.com/v1.exe', 'size': 200},
          {'name': 'ShopFlow_POS_Setup_v1.2.0-beta.2.exe', 'browser_download_url': 'https://example.com/v2.exe', 'size': 300, 'digest': 'sha256:digest123'},
        ],
      });

      expect(release.assetName, 'ShopFlow_POS_Setup_v1.2.0-beta.2.exe');
      expect(release.assetDownloadUrl, 'https://example.com/v2.exe');
      expect(release.assetSize, 300);
      expect(release.assetDigest, 'digest123');
    });

    test('Does not select stale or non-matching exe when no version-matching installer exists', () {
      final release = AppRelease.fromJson({
        'tag_name': 'v1.2.0-beta.2',
        'assets': [
          {'name': 'ShopFlow_POS_Setup_v1.2.0-beta.1.exe', 'size': 10},
        ],
      });

      expect(release.assetName, isNull);
      expect(release.assetDownloadUrl, isNull);
    });
  });

  group('UpdateService Release Selection and Channel Filtering Tests', () {
    final sampleReleasesJson = jsonEncode([
      {
        'tag_name': 'v1.2.0-beta.2',
        'name': 'v1.2.0-beta.2',
        'body': 'Beta 2 notes',
        'prerelease': true,
        'draft': false,
        'assets': [
          {
            'name': 'ShopFlow_POS_Setup_v1.2.0-beta.2.exe',
            'browser_download_url': 'https://example.com/ShopFlow_POS_Setup_v1.2.0-beta.2.exe',
            'size': 50000000,
          }
        ],
      },
      {
        'tag_name': 'v1.2.0-beta.1',
        'name': 'v1.2.0-beta.1',
        'body': 'Beta 1 notes',
        'prerelease': true,
        'draft': false,
        'assets': [
          {
            'name': 'ShopFlow_POS_Setup_v1.2.0-beta.1.exe',
            'browser_download_url': 'https://example.com/ShopFlow_POS_Setup_v1.2.0-beta.1.exe',
            'size': 50000000,
          }
        ],
      },
      {
        'tag_name': 'v1.3.0-draft',
        'name': 'v1.3.0 Draft',
        'body': 'Unreleased draft',
        'prerelease': false,
        'draft': true,
        'assets': [
          {
            'name': 'ShopFlow_POS_Setup_v1.3.0.exe',
            'browser_download_url': 'https://example.com/ShopFlow_POS_Setup_v1.3.0.exe',
            'size': 50000000,
          }
        ],
      },
      {
        'tag_name': 'v1.1.9',
        'name': 'v1.1.9 Stable',
        'body': 'Stable 1.1.9 notes',
        'prerelease': false,
        'draft': false,
        'assets': [
          {
            'name': 'ShopFlow_POS_Setup_v1.1.9.exe',
            'browser_download_url': 'https://example.com/ShopFlow_POS_Setup_v1.1.9.exe',
            'size': 50000000,
          }
        ],
      },
    ]);

    test('Beta channel detects 1.2.0-beta.2 when current version is 1.2.0-beta.1', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, endsWith('/releases'));
        return http.Response(sampleReleasesJson, 200);
      });

      final result = await UpdateService.checkForUpdates(
        channel: UpdateChannel.beta,
        currentVersionOverride: '1.2.0-beta.1',
        client: mockClient,
      );

      expect(result.status, equals(UpdateStatus.updateAvailable));
      expect(result.release?.version, equals('1.2.0-beta.2'));
      expect(result.release?.isPrerelease, isTrue);
      expect(result.channel, equals(UpdateChannel.beta));
    });

    test('Stable channel ignores pre-releases and selects newest stable release', () async {
      final mockClient = MockClient((request) async {
        return http.Response(sampleReleasesJson, 200);
      });

      final result = await UpdateService.checkForUpdates(
        channel: UpdateChannel.stable,
        currentVersionOverride: '1.1.0',
        client: mockClient,
      );

      expect(result.status, equals(UpdateStatus.updateAvailable));
      expect(result.release?.version, equals('1.1.9'));
      expect(result.release?.isPrerelease, isFalse);
    });

    test('Stable channel reports up to date when current version is already on newest stable', () async {
      final mockClient = MockClient((request) async {
        return http.Response(sampleReleasesJson, 200);
      });

      final result = await UpdateService.checkForUpdates(
        channel: UpdateChannel.stable,
        currentVersionOverride: '1.1.9',
        client: mockClient,
      );

      expect(result.status, equals(UpdateStatus.upToDate));
      expect(result.release?.version, equals('1.1.9'));
    });

    test('Draft releases are ignored even if higher version', () async {
      final mockClient = MockClient((request) async {
        return http.Response(sampleReleasesJson, 200);
      });

      final result = await UpdateService.checkForUpdates(
        channel: UpdateChannel.beta,
        currentVersionOverride: '1.2.0-beta.2',
        client: mockClient,
      );

      // Draft 1.3.0 is ignored, so 1.2.0-beta.2 is already the latest
      expect(result.status, equals(UpdateStatus.upToDate));
      expect(result.release?.version, equals('1.2.0-beta.2'));
    });

    test('Returns clear error when newer release has no matching Windows installer', () async {
      final noInstallerJson = jsonEncode([
        {
          'tag_name': 'v1.2.0-beta.3',
          'name': 'v1.2.0-beta.3',
          'body': 'No installer attached',
          'prerelease': true,
          'draft': false,
          'assets': <dynamic>[],
        }
      ]);

      final mockClient = MockClient((request) async {
        return http.Response(noInstallerJson, 200);
      });

      final result = await UpdateService.checkForUpdates(
        channel: UpdateChannel.beta,
        currentVersionOverride: '1.2.0-beta.1',
        client: mockClient,
      );

      expect(result.status, equals(UpdateStatus.error));
      expect(result.errorMessage, contains('no matching Windows installer'));
    });
  });

  group('AutoUpdateManager and Polling Tests', () {
    setUp(() {
      AutoUpdateManager.instance.resetSessionPromptState();
      AutoUpdateManager.instance.stopPolling();
    });

    tearDown(() {
      AutoUpdateManager.instance.resetSessionPromptState();
      AutoUpdateManager.instance.stopPolling();
    });

    test('Background update check avoids overlapping requests', () async {
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return http.Response('[]', 200);
      });

      final future1 = AutoUpdateManager.instance.checkForUpdatesInBackground(client: mockClient);
      final future2 = AutoUpdateManager.instance.checkForUpdatesInBackground(client: mockClient);

      final result2 = await future2;
      expect(result2, isNull, reason: 'Overlapping request must return immediately without duplicating work');

      final result1 = await future1;
      expect(result1, isNotNull);
      expect(AutoUpdateManager.instance.isChecking, isFalse);
    });

    test('Stop polling cancels active timer schedules', () {
      AutoUpdateManager.instance.startPolling(
        interval: const Duration(minutes: 5),
        initialDelay: const Duration(seconds: 1),
      );

      AutoUpdateManager.instance.stopPolling();
      expect(AutoUpdateManager.instance.isChecking, isFalse);
    });

    testWidgets('Prompts update dialog only once per release during the session', (tester) async {
      final releaseJson = jsonEncode([
        {
          'tag_name': 'v1.2.0-beta.2',
          'name': 'ShopFlow POS v1.2.0-beta.2',
          'body': 'Notes',
          'prerelease': true,
          'draft': false,
          'assets': [
            {
              'name': 'ShopFlow_POS_Setup_v1.2.0-beta.2.exe',
              'browser_download_url': 'https://example.com/ShopFlow_POS_Setup_v1.2.0-beta.2.exe',
              'size': 50000000,
            }
          ],
        }
      ]);

      final mockClient = MockClient((request) async {
        return http.Response(releaseJson, 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          navigatorKey: AutoUpdateManager.navigatorKey,
          home: const Scaffold(body: Text('POS App Body')),
        ),
      );

      // 1. First background check finds update and triggers dialog
      AutoUpdateManager.instance.checkForUpdatesInBackground(client: mockClient);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Software Update Available'), findsOneWidget);
      expect(AutoUpdateManager.instance.lastPromptedReleaseVersion, equals('1.2.0-beta.2'));

      // Dismiss dialog by clicking 'Later'
      await tester.tap(find.text('Later'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Software Update Available'), findsNothing);

      // 2. Subsequent background check for the same release in the same session does NOT re-prompt
      final check2 = await AutoUpdateManager.instance.checkForUpdatesInBackground(client: mockClient);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(check2?.status, equals(UpdateStatus.updateAvailable));
      expect(find.text('Software Update Available'), findsNothing);
    });

    testWidgets('Manual check opens dialog even if previously dismissed', (tester) async {
      final releaseJson = jsonEncode([
        {
          'tag_name': 'v1.2.0-beta.2',
          'name': 'ShopFlow POS v1.2.0-beta.2',
          'body': 'Notes',
          'prerelease': true,
          'draft': false,
          'assets': [
            {
              'name': 'ShopFlow_POS_Setup_v1.2.0-beta.2.exe',
              'browser_download_url': 'https://example.com/ShopFlow_POS_Setup_v1.2.0-beta.2.exe',
              'size': 50000000,
            }
          ],
        }
      ]);

      final mockClient = MockClient((request) async {
        return http.Response(releaseJson, 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          navigatorKey: AutoUpdateManager.navigatorKey,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AutoUpdateManager.instance.performManualCheck(ctx, client: mockClient),
                child: const Text('Manual Check'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Manual Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Software Update Available'), findsOneWidget);
      expect(find.text('v1.2.0-beta.2'), findsOneWidget);
    });
  });

  group('UpdateDialog Widget Tests', () {
    testWidgets('Renders update details and buttons accurately with channel badge', (WidgetTester tester) async {
      const release = AppRelease(
        version: '1.2.0-beta.2',
        tagName: 'v1.2.0-beta.2',
        title: 'ShopFlow POS v1.2.0-beta.2',
        body: '• New Update Checker\n• Speed improvements',
        htmlUrl: 'https://github.com/muzammil608/pos_mobile',
        assetName: 'ShopFlow_POS_Setup_v1.2.0-beta.2.exe',
        assetSize: 47185920,
        isPrerelease: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const Scaffold(
            body: UpdateDialog(
              release: release,
              currentVersion: '1.2.0-beta.1',
              channel: UpdateChannel.beta,
            ),
          ),
        ),
      );

      expect(find.text('Software Update Available'), findsOneWidget);
      expect(find.text('v1.2.0-beta.1'), findsOneWidget);
      expect(find.text('v1.2.0-beta.2'), findsOneWidget);
      expect(find.text('Beta Channel'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.textContaining('New Update Checker'), findsOneWidget);
    });

    testWidgets('Renders Up to Date dialog accurately', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => UpdateDialog.showUpToDateDialog(
                  context,
                  currentVersion: '1.2.0-beta.2',
                ),
                child: const Text('Check'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      expect(find.text("You're Up to Date!"), findsOneWidget);
      expect(find.textContaining('v1.2.0-beta.2 is the latest version available'), findsOneWidget);
      expect(find.text('Great'), findsOneWidget);
    });
  });

  group('AppUpdateButton Widget Tests', () {
    testWidgets('Renders AppUpdateButton with text, tooltip, and icon', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(64),
              child: Row(
                children: [
                  AppUpdateButton(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AppUpdateButton), findsOneWidget);
      expect(find.byIcon(Icons.system_update_alt_rounded), findsOneWidget);
      expect(find.text('Check for Updates'), findsOneWidget);
    });
  });

  group('Safety and Replay Prevention Tests', () {
    test('Temp installer file is named appropriately and located in temp directory', () {
      final file = UpdateService.getTempInstallerFile(version: '1.2.0-beta.2');
      expect(file.path, contains('ShopFlow_Update'));
      expect(file.path, endsWith('ShopFlow_POS_Setup_v1.2.0-beta.2.exe'));
    });

    test('Expected installer filename is derived from version correctly', () {
      expect(AppRelease.expectedInstallerFileName('1.2.0-beta.2'), equals('ShopFlow_POS_Setup_v1.2.0-beta.2.exe'));
      expect(AppRelease.expectedInstallerFileName('v1.2.0'), equals('ShopFlow_POS_Setup_v1.2.0.exe'));
    });
  });

  group('Sidebar Collapse/Expand Persistence Tests', () {
    test('Default sidebar behavior is collapsed', () {
      AppNavigationShell.setSidebarExpanded(false);
      expect(AppNavigationShell.isSidebarExpanded, isFalse);
    });

    test('Toggling updates persistent state across screens', () {
      AppNavigationShell.setSidebarExpanded(false);
      expect(AppNavigationShell.isSidebarExpanded, isFalse);

      AppNavigationShell.toggleSidebar();
      expect(AppNavigationShell.isSidebarExpanded, isTrue);

      AppNavigationShell.toggleSidebar();
      expect(AppNavigationShell.isSidebarExpanded, isFalse);
    });
  });
}
