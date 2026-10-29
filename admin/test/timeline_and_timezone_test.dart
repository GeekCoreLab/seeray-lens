import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeray_lens_admin/features/analytics/presentation/merged_timeline_action.dart';
import 'package:seeray_lens_admin/features/analytics/presentation/timeline_date_formatter.dart';
import 'package:seeray_lens_admin/features/analytics/presentation/visitor_timezone_utils.dart';

void main() {
  group('mergeConsecutiveActions', () {
    test('merges consecutive identical actions and preserves order', () {
      final now = DateTime(2026, 10, 29, 10, 0);
      final raw = [
        {'type': 'page_view', 'title': 'Home', 'at': now},
        {'type': 'page_view', 'title': 'Home', 'at': now.subtract(const Duration(seconds: 10))},
        {'type': 'page_view', 'title': 'Home', 'at': now.subtract(const Duration(seconds: 20))},
        {'type': 'click', 'title': 'Button', 'at': now.subtract(const Duration(seconds: 30))},
        {'type': 'page_view', 'title': 'Home', 'at': now.subtract(const Duration(seconds: 40))},
      ];

      final merged = mergeConsecutiveActions<Map<String, dynamic>>(
        items: raw,
        keyOf: (item) => '${item['type']}|${item['title']}',
        timeOf: (item) => item['at'] as DateTime,
      );

      expect(merged.length, 3);
      expect(merged[0].sample['title'], 'Home');
      expect(merged[0].count, 3);
      expect(merged[1].sample['title'], 'Button');
      expect(merged[1].count, 1);
      expect(merged[2].sample['title'], 'Home');
      expect(merged[2].count, 1);
    });

    test('handles empty list', () {
      final merged = mergeConsecutiveActions<String>(
        items: [],
        keyOf: (s) => s,
        timeOf: (_) => DateTime.now(),
      );
      expect(merged, isEmpty);
    });
  });

  group('formatTimelineTime & formatTimelineDateOnly', () {
    testWidgets('formats dates relative to now (today, yesterday, this month, this year, older)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: const [Locale('zh'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) {
              final referenceNow = DateTime(2026, 10, 29, 10, 4, 0);

              // Today
              final todayTime = DateTime(2026, 10, 29, 8, 30);
              expect(
                formatTimelineTime(context, todayTime, now: referenceNow),
                '今天 08:30',
              );
              expect(
                formatTimelineDateOnly(context, todayTime, now: referenceNow),
                '今天',
              );

              // Yesterday
              final yesterdayTime = DateTime(2026, 10, 28, 22, 15);
              expect(
                formatTimelineTime(context, yesterdayTime, now: referenceNow),
                '昨天 22:15',
              );
              expect(
                formatTimelineDateOnly(context, yesterdayTime, now: referenceNow),
                '昨天',
              );

              // Same month (e.g. Oct 15)
              final sameMonth = DateTime(2026, 10, 15, 14, 0);
              expect(
                formatTimelineTime(context, sameMonth, now: referenceNow),
                '15日 14:00',
              );
              expect(
                formatTimelineDateOnly(context, sameMonth, now: referenceNow),
                '15日',
              );

              // Same year, different month (e.g. Sep 5)
              final sameYear = DateTime(2026, 9, 5, 9, 10);
              expect(
                formatTimelineTime(context, sameYear, now: referenceNow),
                '9月5日 09:10',
              );
              expect(
                formatTimelineDateOnly(context, sameYear, now: referenceNow),
                '9月5日',
              );

              // Different year (e.g. 2025-11-20)
              final diffYear = DateTime(2025, 11, 20, 18, 45);
              expect(
                formatTimelineTime(context, diffYear, now: referenceNow),
                '2025年11月20日 18:45',
              );
              expect(
                formatTimelineDateOnly(context, diffYear, now: referenceNow),
                '2025年11月20日',
              );

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });

  group('formatTimezoneComparison', () {
    testWidgets('formats comparison with visitor timezone and marks DST', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: const [Locale('zh'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) {
              final referenceNow = DateTime.utc(2026, 10, 29, 2, 4, 0);
              final comparison = formatTimezoneComparison(
                context: context,
                time: referenceNow,
                visitorTimezone: 'America/New_York',
                now: referenceNow.toLocal(),
              );

              expect(comparison, contains('America/New_York'));
              expect(comparison, contains('夏令时'));
              expect(comparison, contains(' - '));

              // Non-DST timezone
              final comparisonNoDst = formatTimezoneComparison(
                context: context,
                time: referenceNow,
                visitorTimezone: 'Asia/Tokyo',
                now: referenceNow.toLocal(),
              );
              expect(comparisonNoDst, contains('Asia/Tokyo'));
              expect(comparisonNoDst, isNot(contains('夏令时')));

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });
}
