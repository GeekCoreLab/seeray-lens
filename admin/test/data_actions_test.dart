import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeray_lens_admin/shared/presentation/data_actions.dart';
import 'package:seeray_lens_admin/shared/presentation/external_url_opener.dart';

void main() {
  test('resolveNavigableUrl and formatCopyableUrl handle URLs safely', () {
    expect(
      resolveNavigableUrl('https://example.com/pricing?a=1')?.toString(),
      'https://example.com/pricing?a=1',
    );
    expect(
      resolveNavigableUrl('http://example.com:8080/test')?.toString(),
      'http://example.com:8080/test',
    );
    expect(
      resolveNavigableUrl('/pricing', fallbackHost: 'example.com')?.toString(),
      'https://example.com/pricing',
    );
    expect(
      resolveNavigableUrl('/pricing', fallbackHost: 'https://example.com/')
          ?.toString(),
      'https://example.com/pricing',
    );
    expect(resolveNavigableUrl('/pricing'), isNull);
    expect(
      formatCopyableUrl('/pricing', fallbackHost: 'example.com'),
      'https://example.com/pricing',
    );
    expect(formatCopyableUrl('/pricing'), '/pricing');
    expect(
      resolveNavigableUrl('blog.example.com/posts')?.toString(),
      'https://blog.example.com/posts',
    );

    expect(resolveNavigableUrl('javascript:alert(1)'), isNull);
    expect(resolveNavigableUrl('data:text/html,hi'), isNull);
    expect(resolveNavigableUrl('not a url'), isNull);
    expect(resolveNavigableUrl(''), isNull);
  });

  testWidgets('CopyIconButton and CopyableIpChip write text to clipboard', (
    tester,
  ) async {
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<Object?, Object?>;
            copiedText = args['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CopyIconButton(
                  text: '203.0.113.45',
                  tooltipEn: 'Copy IP address',
                ),
                CopyableIpChip(ipAddress: '198.51.100.22'),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CopyIconButton));
    await tester.pump();
    expect(copiedText, '203.0.113.45');
    expect(find.text('Copied'), findsOneWidget);

    await tester.tap(find.byType(CopyableIpChip));
    await tester.pump();
    expect(copiedText, '198.51.100.22');
    expect(find.text('IP copied'), findsOneWidget);
  });

  testWidgets('UrlActionButtons copies full URL and invokes external opener', (
    tester,
  ) async {
    String? copiedText;
    Uri? openedUri;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<Object?, Object?>;
            copiedText = args['text'] as String?;
          }
          return null;
        });
    externalUrlOpenerOverrideForTest = (uri) async {
      openedUri = uri;
      return true;
    };
    addTearDown(() {
      externalUrlOpenerOverrideForTest = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(sitePrimaryHostCacheProvider.notifier)
        .setHost('site-1', 'example.com');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: UrlActionButtons(rawUrl: '/pricing', siteId: 'site-1'),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Copy URL'));
    await tester.pump();
    expect(copiedText, 'https://example.com/pricing');

    await tester.tap(find.byTooltip('Open URL'));
    await tester.pump();
    expect(openedUri, Uri.parse('https://example.com/pricing'));
  });
}
