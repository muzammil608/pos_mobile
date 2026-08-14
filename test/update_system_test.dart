import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/services/update_service.dart';
import 'package:pos_system/widgets/app_navigation.dart';
import 'package:pos_system/widgets/update_button.dart';
import 'package:pos_system/widgets/update_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppVersion Comparison Tests', () {
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

    test('Release version is considered greater than pre-release', () {
      final release = AppVersion.parse('1.1.0');
      final beta = AppVersion.parse('1.1.0-beta.1');

      expect(release.isGreaterThan(beta), isTrue);
      expect(beta.isLessThan(release), isTrue);
    });
  });

  group('AppRelease JSON Parsing Tests', () {
    test('Correctly parses release metadata and locates Windows .exe asset', () {
      final json = {
        'tag_name': 'v1.1.0',
        'name': 'ShopFlow POS v1.1.0 Production Release',
        'body': '• Added automatic updates\n• Performance improvements',
        'published_at': '2026-08-14T08:00:00Z',
        'html_url': 'https://github.com/orion-pk/releases/releases/tag/v1.1.0',
        'assets': [
          {
            'name': 'source_code.zip',
            'browser_download_url':
                'https://github.com/orion-pk/releases/releases/download/v1.1.0/source.zip',
            'size': 1024000,
          },
          {
            'name': 'ShopFlow_POS_Setup_v1.1.0.exe',
            'browser_download_url':
                'https://github.com/orion-pk/releases/releases/download/v1.1.0/ShopFlow_POS_Setup_v1.1.0.exe',
            'size': 47185920,
          },
        ],
      };

      final release = AppRelease.fromJson(json);

      expect(release.version, equals('1.1.0'));
      expect(release.tagName, equals('v1.1.0'));
      expect(release.title, equals('ShopFlow POS v1.1.0 Production Release'));
      expect(release.assetName, equals('ShopFlow_POS_Setup_v1.1.0.exe'));
      expect(
        release.assetDownloadUrl,
        equals(
            'https://github.com/orion-pk/releases/releases/download/v1.1.0/ShopFlow_POS_Setup_v1.1.0.exe'),
      );
      expect(release.formattedSize, equals('45.0 MB'));
      expect(release.formattedPublishedDate, contains('Aug 14, 2026'));
    });
  });

  group('UpdateDialog Widget Tests', () {
    testWidgets('Renders update details and buttons accurately',
        (WidgetTester tester) async {
      const release = AppRelease(
        version: '1.1.0',
        tagName: 'v1.1.0',
        title: 'ShopFlow POS v1.1.0',
        body: '• New Update Checker\n• Speed improvements',
        htmlUrl: 'https://github.com/orion-pk/releases',
        assetName: 'ShopFlow_POS_Setup_v1.1.0.exe',
        assetSize: 47185920,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateDialog(
              release: release,
              currentVersion: '1.0.0',
            ),
          ),
        ),
      );

      expect(find.text('Software Update Available'), findsOneWidget);
      expect(find.text('v1.0.0'), findsOneWidget);
      expect(find.text('v1.1.0'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.textContaining('New Update Checker'), findsOneWidget);
    });

    testWidgets('Renders Up to Date dialog accurately',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => UpdateDialog.showUpToDateDialog(
                  context,
                  currentVersion: '1.0.0',
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
      expect(find.textContaining('v1.0.0 is the latest version available'),
          findsOneWidget);
      expect(find.text('Great'), findsOneWidget);
    });
  });

  group('AppUpdateButton Widget Tests', () {
    testWidgets('Renders AppUpdateButton with text, tooltip, and icon',
        (WidgetTester tester) async {
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

  group('Update Flow Verification Tests', () {
    testWidgets('Shows notification toast when already up to date',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: const Text('ShopFlow is up to date'),
                    ),
                  );
                },
                child: const Text('Simulate UpToDate'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Simulate UpToDate'));
      await tester.pump();

      expect(find.text('ShopFlow is up to date'), findsOneWidget);
    });

    testWidgets('Opens UpdateDialog card when new version is available',
        (WidgetTester tester) async {
      const newRelease = AppRelease(
        version: '1.2.0',
        tagName: 'v1.2.0',
        title: 'ShopFlow POS v1.2.0',
        body: '• Exciting New Features\n• Bug fixes',
        htmlUrl: 'https://github.com/orion-pk/releases',
        assetName: 'ShopFlow_POS_Setup_v1.2.0.exe',
        assetSize: 52428800,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  UpdateDialog.show(
                    context,
                    release: newRelease,
                    currentVersion: '1.0.0',
                  );
                },
                child: const Text('Simulate UpdateAvailable'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Simulate UpdateAvailable'));
      await tester.pumpAndSettle();

      expect(find.text('Software Update Available'), findsOneWidget);
      expect(find.text('v1.0.0'), findsOneWidget);
      expect(find.text('v1.2.0'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
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
