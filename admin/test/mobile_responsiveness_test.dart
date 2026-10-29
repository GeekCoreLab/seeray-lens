import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeray_lens_admin/features/analytics/application/analytics_controller.dart';
import 'package:seeray_lens_admin/features/analytics/application/analytics_range.dart';
import 'package:seeray_lens_admin/features/auth/presentation/login_page.dart';
import 'package:seeray_lens_admin/features/landing/presentation/landing_page.dart';
import 'package:seeray_lens_admin/features/sites/application/site_controller.dart';
import 'package:seeray_lens_admin/features/sites/presentation/sites_page.dart';
import 'package:seeray_lens_admin/features/workspaces/application/workspace_controller.dart';
import 'package:seeray_lens_admin/features/workspaces/presentation/workspace_page.dart';
import 'package:seeray_lens_admin/features/analytics/presentation/segment_filter_selector.dart';
import 'package:seeray_lens_admin/shared/presentation/page_help_button.dart';
import 'package:seeray_lens_admin/shared/presentation/site_top_bar.dart';

void main() {
  const mobileSize = Size(375, 667);

  testWidgets('SiteTopBar renders without overflow on mobile screen width', (
    tester,
  ) async {
    tester.view.physicalSize = mobileSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rangeState = AnalyticsRangeState(
      period: AnalyticsPeriod.last30Days,
      range: AnalyticsDateRange(
        DateTime(2026, 9, 29),
        DateTime(2026, 10, 29),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            appBar: SiteTopBar(
              siteId: 'site-1',
              selected: SiteTopTab.dashboard,
              help: const PageHelpButton(
                englishTitle: 'Help',
                chineseTitle: '帮助',
                englishBody: 'Help text',
                chineseBody: '帮助说明',
              ),
              rangeState: rangeState,
              onSelectRange: () {},
              onRefresh: () {},
              segmentFilter: const SegmentFilterSelector(siteId: 'site-1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SiteTopBar), findsOneWidget);
    expect(find.byIcon(Icons.date_range_outlined), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('WorkspacePage renders cleanly on compact mobile width without trailing overflow', (
    tester,
  ) async {
    tester.view.physicalSize = mobileSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceProvider.overrideWith(_MobileFakeWorkspaceController.new),
        ],
        child: const MaterialApp(home: WorkspacePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Analytics mobile workspace'), findsOneWidget);
    expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
    expect(find.byIcon(Icons.extension_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.health_and_safety_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.history), findsNWidgets(2));
    expect(find.byIcon(Icons.group_outlined), findsNWidgets(2));
  });

  testWidgets('LoginPage scrolls safely on small mobile screens when keyboard opens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.text('SeeRay Lens'), findsOneWidget);
  });

  testWidgets('SitesPage renders grid cards without overflow on mobile and tablet widths', (
    tester,
  ) async {
    for (final size in const [Size(375, 667), Size(650, 800)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;

      final container = ProviderContainer(
        overrides: [
          currentWorkspaceProvider.overrideWith(CurrentWorkspaceController.new),
          sitesProvider.overrideWith(_MobileFakeSitesController.new),
        ],
      );
      container.read(currentWorkspaceProvider.notifier).select(
        const Workspace(id: 'w1', name: 'Mobile Work', role: 'owner'),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SitesPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Production Site'), findsOneWidget);
      container.dispose();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('LandingPage renders responsive features on compact mobile width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LandingPage())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sign in'), findsWidgets);
  });
}

class _MobileFakeWorkspaceController extends WorkspaceController {
  @override
  Future<List<Workspace>> build() async => const [
    Workspace(
      id: 'owner-space',
      name: 'Analytics mobile workspace',
      role: 'owner',
    ),
    Workspace(id: 'admin-space', name: 'Admin space', role: 'admin'),
  ];
}

class _MobileFakeSitesController extends SitesController {
  @override
  Future<List<Site>> build() async => const [
    Site(
      id: 'site-1',
      workspaceId: 'w1',
      name: 'Production Site',
      timezone: 'America/Argentina/Buenos_Aires',
      defaultLanguage: null,
      trackingId: 'SRL-PROD-SITE-1',
      trackingEnabled: true,
      requireConsent: true,
      rawRetentionDays: 30,
      aggregateRetentionDays: 730,
      fingerprintRiskEnabled: false,
      fingerprintRetentionDays: 30,
      ipLookupMode: 'DEFAULT',
      ipLookupHeader: null,
    ),
  ];
}
