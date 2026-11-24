import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeray_lens_admin/core/network/seeray_api.dart';
import 'package:seeray_lens_admin/features/analytics/presentation/realtime_page.dart';
import 'package:seeray_lens_admin/features/auth/application/auth_controller.dart';

void main() {
  testWidgets('shows active visits and expands their recent action trail', (
    tester,
  ) async {
    final api = _LiveApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: RealtimePage(siteId: 'site-1', embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.lastPath, contains('/analytics/realtime?windowMinutes=30'));
    expect(find.text('Live visitors'), findsOneWidget);
    expect(find.text('Active visitors'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.textContaining('203.0.113.12'), findsOneWidget);
    expect(
      find.textContaining('San Francisco · California · United States'),
      findsWidgets,
    );
    expect(find.textContaining('12345678'), findsNothing);
    expect(find.text('Pricing overview'), findsNWidgets(2));
    expect(find.byTooltip('Copy IP'), findsNWidgets(2));
    expect(find.byTooltip('Copy URL'), findsNWidgets(2));

    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();

    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.textContaining('page_view ·'), findsOneWidget);
    expect(find.textContaining('Entry: /pricing'), findsOneWidget);
    expect(find.byTooltip('Copy IP address'), findsOneWidget);
    expect(find.byTooltip('Copy location'), findsOneWidget);
    expect(find.byTooltip('Copy URL'), findsWidgets);
    expect(find.byTooltip('Open URL'), findsWidgets);
  });

  testWidgets('renders live visitor device performance metrics when expanded', (
    tester,
  ) async {
    final api = _LiveApi(includePerformance: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: RealtimePage(siteId: 'site-1', embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();

    expect(find.text('High · 90'), findsOneWidget);
    expect(find.text('8 cores'), findsOneWidget);
    expect(find.text('8 GB RAM'), findsOneWidget);
    expect(find.text('60 FPS'), findsOneWidget);
  });
}

class _LiveApi extends SeeRayApi {
  _LiveApi({this.includePerformance = false})
    : super(baseUrl: 'https://lens.example.test');

  final bool includePerformance;
  String? lastPath;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    bool retried = false,
  }) async {
    lastPath = path;
    final now = DateTime.now().toUtc().toIso8601String();
    final sharedVisit = <String, dynamic>{
      'visitorId': '12345678-1234-4234-8234-123456789012',
      'ipAddress': '203.0.113.12',
      'sessionId': '22345678-1234-4234-8234-123456789012',
      'startedAt': now,
      'lastActivityAt': now,
      'events': 2,
      'pageViews': 1,
      'entryPage': '/pricing',
      'lastEventType': 'page_view',
      'currentPage': '/pricing',
      'currentTitle': 'Pricing overview',
      'countryCode': 'US',
      'region': 'California',
      'city': 'San Francisco',
      'browser': 'Chrome',
      'operatingSystem': 'Linux',
      'deviceType': 'desktop',
      'language': 'en-US',
      'durationMs': 1800,
      'uniqueIdentity': true,
      if (includePerformance) ...{
        'performanceScore': 90,
        'performanceTier': 'high',
        'hardwareConcurrency': 8,
        'deviceMemoryGb': 8.0,
        'connectionType': '4g',
        'pageLoadMs': 1100,
        'frameRateFps': 60,
      },
      'actions': [
        {
          'at': now,
          'eventType': 'page_view',
          'path': '/pricing',
          'title': 'Pricing overview',
        },
      ],
    };
    return [
      sharedVisit,
      {
        ...sharedVisit,
        'visitorId': '32345678-1234-4234-8234-123456789012',
        'ipAddress': '203.0.113.34',
        'sessionId': '42345678-1234-4234-8234-123456789012',
        'uniqueIdentity': false,
      },
    ];
  }
}
