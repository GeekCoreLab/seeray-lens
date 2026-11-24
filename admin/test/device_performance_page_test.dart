import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:seeray_lens_admin/core/network/seeray_api.dart';
import 'package:seeray_lens_admin/features/analytics/presentation/device_performance_page.dart';
import 'package:seeray_lens_admin/features/auth/application/auth_controller.dart';

void main() {
  testWidgets('displays device performance distributions and per-visitor cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _DevicePerformanceApi();
    String? openedVisitorRoute;
    final router = GoRouter(
      initialLocation: '/sites/site-1/visitors/device-performance',
      routes: [
        GoRoute(
          path: '/sites/:siteId/visitors/device-performance',
          builder: (context, state) => DevicePerformancePage(
            siteId: state.pathParameters['siteId']!,
            embedded: true,
          ),
        ),
        GoRoute(
          path: '/sites/:siteId/visitors/:visitorId',
          builder: (context, state) {
            openedVisitorRoute = state.uri.toString();
            return const Scaffold(body: Text('Opened visitor profile'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.lastPath, contains('/analytics/device-performance'));
    expect(find.text('Device performance'), findsOneWidget);
    expect(find.text('62 / 100'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);
    expect(find.text('Performance tiers'), findsOneWidget);
    expect(find.text('CPU cores'), findsOneWidget);
    expect(find.text('Device memory'), findsOneWidget);
    expect(find.text('Network type'), findsOneWidget);
    expect(find.text('Page load time'), findsOneWidget);
    expect(find.text('Rendering frame rate'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Visitor device performance'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('203.0.113.10'), findsOneWidget);
    expect(find.text('203.0.113.20'), findsOneWidget);
    expect(
      find.text('San Francisco · California · United States'),
      findsOneWidget,
    );
    expect(find.text('南京市 · 江苏省 · 中国'), findsNothing);
    expect(find.text('南京市 · 江苏省 · China'), findsOneWidget);
    expect(find.textContaining('visitor-secret-high'), findsNothing);
    expect(find.textContaining('visitor-secret-low'), findsNothing);
    expect(find.text('High · 92'), findsOneWidget);
    expect(find.text('Low · 32'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Low'));
    await tester.pumpAndSettle();
    expect(find.text('203.0.113.20'), findsOneWidget);
    expect(find.text('203.0.113.10'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '南京市');
    await tester.pumpAndSettle();
    expect(find.text('203.0.113.20'), findsOneWidget);
    expect(find.text('203.0.113.10'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '203.0.113.10');
    await tester.pumpAndSettle();
    final matchedVisitorText = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == '203.0.113.10',
    );
    expect(matchedVisitorText, findsOneWidget);
    expect(find.text('203.0.113.20'), findsNothing);

    await tester.tap(matchedVisitorText);
    await tester.pumpAndSettle();
    expect(openedVisitorRoute, '/sites/site-1/visitors/visitor-secret-high');
    expect(find.text('Opened visitor profile'), findsOneWidget);

    router.dispose();
  });

  testWidgets('renders device performance page cleanly on compact mobile width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(_DevicePerformanceApi())],
        child: const MaterialApp(
          home: DevicePerformancePage(siteId: 'site-1', embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Device performance'), findsOneWidget);
  });
}

class _DevicePerformanceApi extends SeeRayApi {
  _DevicePerformanceApi() : super(baseUrl: 'https://lens.example.test');

  String? lastPath;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    bool retried = false,
  }) async {
    lastPath = path;
    if (path.endsWith('/segments')) return const <dynamic>[];
    if (path.contains('/analytics/device-performance')) {
      return {
        'totalSessions': 3,
        'measuredSessions': 2,
        'totalVisitors': 3,
        'measuredVisitors': 2,
        'averagePerformanceScore': 62.0,
        'medianPerformanceScore': 62.0,
        'highTierSessions': 1,
        'mediumTierSessions': 0,
        'lowTierSessions': 1,
        'averageCpuCores': 7.0,
        'averageDeviceMemoryGb': 8.5,
        'p75PageLoadMs': 6000.0,
        'p75DomInteractiveMs': 4200.0,
        'p75TtfbMs': 1500.0,
        'averageFrameRateFps': 41.0,
        'tierBreakdown': [
          {'label': 'high', 'sessions': 1, 'visitors': 1, 'averageScore': 92.0},
          {'label': 'low', 'sessions': 1, 'visitors': 1, 'averageScore': 32.0},
          {
            'label': 'unknown',
            'sessions': 1,
            'visitors': 1,
            'averageScore': null,
          },
        ],
        'cpuBreakdown': [
          {
            'label': '9–16 cores',
            'sessions': 1,
            'visitors': 1,
            'averageScore': 92.0,
          },
          {
            'label': '1–2 cores',
            'sessions': 1,
            'visitors': 1,
            'averageScore': 32.0,
          },
        ],
        'memoryBreakdown': [
          {
            'label': '>8 GB',
            'sessions': 1,
            'visitors': 1,
            'averageScore': 92.0,
          },
          {
            'label': '≤1 GB',
            'sessions': 1,
            'visitors': 1,
            'averageScore': 32.0,
          },
        ],
        'networkBreakdown': [
          {'label': '4g', 'sessions': 1, 'visitors': 1, 'averageScore': 92.0},
          {'label': '2g', 'sessions': 1, 'visitors': 1, 'averageScore': 32.0},
        ],
        'loadTimeBreakdown': [
          {
            'label': '<1.5s',
            'sessions': 1,
            'visitors': 1,
            'averageScore': 92.0,
          },
          {'label': '5s+', 'sessions': 1, 'visitors': 1, 'averageScore': 32.0},
        ],
        'fpsBreakdown': [
          {
            'label': '55+ fps',
            'sessions': 1,
            'visitors': 1,
            'averageScore': 92.0,
          },
          {
            'label': '<30 fps',
            'sessions': 1,
            'visitors': 1,
            'averageScore': 32.0,
          },
        ],
        'visitors': [
          {
            'visitorId': 'visitor-secret-high',
            'ipAddress': '203.0.113.10',
            'countryCode': 'US',
            'region': 'California',
            'city': 'San Francisco',
            'lastSeenAt': '2026-10-01T10:00:00Z',
            'sessions': 1,
            'browser': 'Chrome',
            'operatingSystem': 'macOS',
            'deviceType': 'desktop',
            'performanceScore': 92,
            'performanceTier': 'high',
            'hardwareConcurrency': 12,
            'deviceMemoryGb': 16.0,
            'connectionType': '4g',
            'connectionDownlinkMbps': 40.0,
            'connectionRttMs': 20,
            'saveData': false,
            'ttfbMs': 110,
            'domInteractiveMs': 600,
            'pageLoadMs': 1050,
            'jsHeapUsedMb': 42.0,
            'jsHeapLimitMb': 2048.0,
            'frameRateFps': 60,
          },
          {
            'visitorId': 'visitor-secret-low',
            'ipAddress': '203.0.113.20',
            'countryCode': 'CN',
            'region': '江苏省',
            'city': '南京市',
            'lastSeenAt': '2026-10-01T09:00:00Z',
            'sessions': 1,
            'browser': 'Firefox',
            'operatingSystem': 'Android',
            'deviceType': 'mobile',
            'performanceScore': 32,
            'performanceTier': 'low',
            'hardwareConcurrency': 2,
            'deviceMemoryGb': 1.0,
            'connectionType': '2g',
            'connectionDownlinkMbps': 0.4,
            'connectionRttMs': 600,
            'saveData': true,
            'ttfbMs': 2100,
            'domInteractiveMs': 6200,
            'pageLoadMs': 8200,
            'frameRateFps': 22,
          },
        ],
      };
    }
    throw StateError('Unexpected API request: $method $path');
  }
}
