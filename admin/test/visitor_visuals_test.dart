import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeray_lens_admin/features/analytics/presentation/visitor_visuals.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('country and platform marks expose readable fallbacks', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            CountryFlag(countryCode: 'us'),
            CountryFlag(countryCode: '???'),
            VisitorPlatformMark(
              kind: VisitorPlatformKind.browser,
              value: 'Unknown browser',
            ),
            VisitorPlatformMark(
              kind: VisitorPlatformKind.operatingSystem,
              value: 'Windows 11',
            ),
            VisitorPlatformMark(
              kind: VisitorPlatformKind.device,
              value: 'tablet',
            ),
          ],
        ),
      ),
    );

    expect(find.byType(CountryFlag), findsNWidgets(2));
    expect(find.byTooltip('Unknown browser'), findsOneWidget);
    expect(find.byTooltip('Windows 11'), findsOneWidget);
    expect(find.byTooltip('tablet'), findsOneWidget);
  });

  test('favicon hosts reject URLs, local names, IPs, and malformed labels', () {
    expect(ReferrerFaviconCache.normalizeHost('Example.COM.'), 'example.com');
    expect(ReferrerFaviconCache.normalizeHost('http://example.com'), isNull);
    expect(ReferrerFaviconCache.normalizeHost('localhost'), isNull);
    expect(ReferrerFaviconCache.normalizeHost('router.local'), isNull);
    expect(ReferrerFaviconCache.normalizeHost('192.168.1.1'), isNull);
    expect(ReferrerFaviconCache.normalizeHost('bad host.example'), isNull);
  });

  test(
    'favicon fetch is single-flight and cached by normalized host',
    () async {
      ReferrerFaviconCache.clearForTest();
      var calls = 0;
      final bytes = Uint8List.fromList(const [1, 2, 3]);
      Future<Uint8List?> fetcher(Uri uri) async {
        calls++;
        expect(uri.scheme, 'https');
        expect(uri.host, 'example.com');
        expect(uri.path, '/favicon.ico');
        await Future<void>.delayed(const Duration(milliseconds: 1));
        return bytes;
      }

      final results = await Future.wait([
        ReferrerFaviconCache.load('EXAMPLE.com', fetcher: fetcher),
        ReferrerFaviconCache.load('example.com', fetcher: fetcher),
      ]);
      expect(calls, 1);
      expect(identical(results.first, bytes), isTrue);
      expect(identical(results.last, bytes), isTrue);
    },
  );

  test('favicon failures are cached for the current process', () async {
    ReferrerFaviconCache.clearForTest();
    var calls = 0;
    Future<Uint8List?> fetcher(Uri uri) async {
      calls++;
      return null;
    }

    expect(
      await ReferrerFaviconCache.load('missing.com', fetcher: fetcher),
      isNull,
    );
    expect(
      await ReferrerFaviconCache.load('missing.com', fetcher: fetcher),
      isNull,
    );
    expect(calls, 1);
  });

  test('favicon payload validation accepts raster images only', () {
    final onePixelPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
    );
    expect(ReferrerFaviconCache.validateRasterForTest(onePixelPng), isTrue);
    expect(
      ReferrerFaviconCache.validateRasterForTest(
        Uint8List.fromList('<html><script>alert(1)</script></html>'.codeUnits),
      ),
      isFalse,
    );
    expect(
      ReferrerFaviconCache.validateRasterForTest(
        Uint8List.fromList('<svg onload="alert(1)"/>'.codeUnits),
      ),
      isFalse,
    );
  });
}
