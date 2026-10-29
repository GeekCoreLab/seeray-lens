import 'package:flutter/material.dart';

import '../../../core/i18n/app_i18n.dart';

/// Formats date-time with smart reduction of redundant date information:
/// - Same calendar day as [now]: "Today" ("今天") + HH:mm
/// - Previous calendar day as [now]: "Yesterday" ("昨天") + HH:mm
/// - Same calendar year and month: "D日 HH:mm" / "D HH:mm"
/// - Same calendar year: "M月D日 HH:mm" / "MMM D HH:mm"
/// - Different year: "YYYY年M月D日 HH:mm" / "YYYY-MM-DD HH:mm"
String formatTimelineTime(
  BuildContext context,
  DateTime time, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final localTime = time.toLocal();
  final localNow = current.toLocal();

  final timePart =
      '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';

  final isToday = localTime.year == localNow.year &&
      localTime.month == localNow.month &&
      localTime.day == localNow.day;
  if (isToday) {
    return '${context.tr('Today', '今天')} $timePart';
  }

  final yesterday = localNow.subtract(const Duration(days: 1));
  final isYesterday = localTime.year == yesterday.year &&
      localTime.month == yesterday.month &&
      localTime.day == yesterday.day;
  if (isYesterday) {
    return '${context.tr('Yesterday', '昨天')} $timePart';
  }

  final isChinese = Localizations.localeOf(context).languageCode == 'zh';

  // Within the same year and same month
  if (localTime.year == localNow.year && localTime.month == localNow.month) {
    return isChinese
        ? '${localTime.day}日 $timePart'
        : '${_shortMonth(localTime.month)} ${localTime.day} $timePart';
  }

  // Within the same year
  if (localTime.year == localNow.year) {
    return isChinese
        ? '${localTime.month}月${localTime.day}日 $timePart'
        : '${_shortMonth(localTime.month)} ${localTime.day} $timePart';
  }

  // Different year
  return isChinese
      ? '${localTime.year}年${localTime.month}月${localTime.day}日 $timePart'
      : '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} $timePart';
}

/// Formats date without time for day-level summaries:
/// - Today -> "Today" ("今天")
/// - Yesterday -> "Yesterday" ("昨天")
/// - Same month -> "D日" / "MMM D"
/// - Same year -> "M月D日" / "MMM D"
/// - Older -> "YYYY年M月D日" / "YYYY-MM-DD"
String formatTimelineDateOnly(
  BuildContext context,
  DateTime time, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final localTime = time.toLocal();
  final localNow = current.toLocal();

  final isToday = localTime.year == localNow.year &&
      localTime.month == localNow.month &&
      localTime.day == localNow.day;
  if (isToday) {
    return context.tr('Today', '今天');
  }

  final yesterday = localNow.subtract(const Duration(days: 1));
  final isYesterday = localTime.year == yesterday.year &&
      localTime.month == yesterday.month &&
      localTime.day == yesterday.day;
  if (isYesterday) {
    return context.tr('Yesterday', '昨天');
  }

  final isChinese = Localizations.localeOf(context).languageCode == 'zh';

  if (localTime.year == localNow.year && localTime.month == localNow.month) {
    return isChinese ? '${localTime.day}日' : '${_shortMonth(localTime.month)} ${localTime.day}';
  }

  if (localTime.year == localNow.year) {
    return isChinese
        ? '${localTime.month}月${localTime.day}日'
        : '${_shortMonth(localTime.month)} ${localTime.day}';
  }

  return isChinese
      ? '${localTime.year}年${localTime.month}月${localTime.day}日'
      : '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}';
}

String _shortMonth(int month) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return months[(month - 1).clamp(0, 11)];
}
