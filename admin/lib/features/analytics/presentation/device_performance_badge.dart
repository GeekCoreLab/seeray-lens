import 'package:flutter/material.dart';

import '../../../core/i18n/app_i18n.dart';

String devicePerformanceTierLabel(BuildContext context, String? tier) =>
    switch (tier) {
      'high' => context.tr('High', '高性能'),
      'medium' => context.tr('Medium', '中等性能'),
      'low' => context.tr('Low', '低性能'),
      _ => context.tr('Unmeasured', '未采集'),
    };

Color devicePerformanceTierColor(String? tier) => switch (tier) {
  'high' => const Color(0xff157f3d),
  'medium' => const Color(0xffb45309),
  'low' => const Color(0xffb42318),
  _ => const Color(0xff52606d),
};

class DevicePerformanceTierBadge extends StatelessWidget {
  const DevicePerformanceTierBadge({
    required this.tier,
    this.score,
    this.compact = false,
    super.key,
  });

  final String? tier;
  final int? score;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = devicePerformanceTierColor(tier);
    final label = devicePerformanceTierLabel(context, tier);
    final text = score == null ? label : '$label · $score';
    return Semantics(
      label: text,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 3 : 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.speed_outlined, size: compact ? 14 : 16, color: color),
              const SizedBox(width: 5),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatPerformanceMemory(double gb) {
  if ((gb - gb.roundToDouble()).abs() < 0.05) {
    return '${gb.round()} GB';
  }
  final formatted = gb.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return '$formatted GB';
}

String formatPerformanceMs(int ms) {
  if (ms < 1000) return '${ms}ms';
  return '${(ms / 1000).toStringAsFixed(2)}s';
}

String? formatPerformanceSummaryLine(
  BuildContext context, {
  int? hardwareConcurrency,
  double? deviceMemoryGb,
  String? connectionType,
  int? pageLoadMs,
  int? frameRateFps,
}) {
  final parts = <String>[
    if (hardwareConcurrency != null)
      context.tr('$hardwareConcurrency cores', '$hardwareConcurrency 核'),
    if (deviceMemoryGb != null) formatPerformanceMemory(deviceMemoryGb),
    if (connectionType != null && connectionType.isNotEmpty)
      connectionType.toUpperCase(),
    if (pageLoadMs != null) formatPerformanceMs(pageLoadMs),
    if (frameRateFps != null) '$frameRateFps FPS',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

List<({IconData icon, String label})> formatDeviceHardwareChips(
  BuildContext context, {
  int? hardwareConcurrency,
  double? deviceMemoryGb,
  String? connectionType,
  double? connectionDownlinkMbps,
  int? connectionRttMs,
  bool? saveData,
  int? ttfbMs,
  int? domInteractiveMs,
  int? pageLoadMs,
  double? jsHeapUsedMb,
  double? jsHeapLimitMb,
  int? frameRateFps,
}) {
  final chips = <({IconData icon, String label})>[];
  if (hardwareConcurrency != null) {
    chips.add((
      icon: Icons.memory_outlined,
      label: context.tr('$hardwareConcurrency cores', '$hardwareConcurrency 核'),
    ));
  }
  if (deviceMemoryGb != null) {
    chips.add((
      icon: Icons.sd_storage_outlined,
      label: '${formatPerformanceMemory(deviceMemoryGb)} RAM',
    ));
  }
  if (connectionType != null ||
      connectionDownlinkMbps != null ||
      connectionRttMs != null ||
      saveData == true) {
    final networkParts = <String>[
      if (connectionType != null && connectionType.isNotEmpty)
        connectionType.toUpperCase(),
      if (connectionDownlinkMbps != null)
        '${connectionDownlinkMbps.toStringAsFixed(1)} Mbps',
      if (connectionRttMs != null) 'RTT ${connectionRttMs}ms',
      if (saveData == true) context.tr('Save-Data', '省流模式'),
    ];
    chips.add((
      icon: Icons.network_check_outlined,
      label: networkParts.join(' · '),
    ));
  }
  if (pageLoadMs != null) {
    chips.add((
      icon: Icons.timer_outlined,
      label: context.tr(
        'Load ${formatPerformanceMs(pageLoadMs)}',
        '加载 ${formatPerformanceMs(pageLoadMs)}',
      ),
    ));
  }
  if (domInteractiveMs != null) {
    chips.add((
      icon: Icons.bolt_outlined,
      label: 'DOM ${formatPerformanceMs(domInteractiveMs)}',
    ));
  }
  if (ttfbMs != null) {
    chips.add((
      icon: Icons.dns_outlined,
      label: 'TTFB ${formatPerformanceMs(ttfbMs)}',
    ));
  }
  if (frameRateFps != null) {
    chips.add((icon: Icons.monitor_heart_outlined, label: '$frameRateFps FPS'));
  }
  if (jsHeapUsedMb != null) {
    final used = jsHeapUsedMb.round();
    final heapText = jsHeapLimitMb != null
        ? '$used/${jsHeapLimitMb.round()} MB'
        : '$used MB';
    chips.add((
      icon: Icons.developer_board_outlined,
      label: context.tr('Heap $heapText', '堆内存 $heapText'),
    ));
  }
  return chips;
}
