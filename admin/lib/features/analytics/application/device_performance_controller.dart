import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import 'analytics_controller.dart';

class DevicePerformanceBucket {
  const DevicePerformanceBucket({
    required this.label,
    required this.sessions,
    required this.visitors,
    required this.averageScore,
  });

  final String label;
  final int sessions;
  final int visitors;
  final double? averageScore;

  factory DevicePerformanceBucket.fromJson(Map<String, dynamic> json) =>
      DevicePerformanceBucket(
        label: json['label'] as String? ?? 'Unknown',
        sessions: (json['sessions'] as num?)?.toInt() ?? 0,
        visitors: (json['visitors'] as num?)?.toInt() ?? 0,
        averageScore: (json['averageScore'] as num?)?.toDouble(),
      );
}

class VisitorDevicePerformance {
  const VisitorDevicePerformance({
    required this.visitorId,
    required this.ipAddress,
    required this.lastSeenAt,
    required this.sessions,
    required this.browser,
    required this.operatingSystem,
    required this.deviceType,
    required this.performanceScore,
    required this.performanceTier,
    required this.hardwareConcurrency,
    required this.deviceMemoryGb,
    required this.connectionType,
    required this.connectionDownlinkMbps,
    required this.connectionRttMs,
    required this.saveData,
    required this.ttfbMs,
    required this.domInteractiveMs,
    required this.pageLoadMs,
    required this.jsHeapUsedMb,
    required this.jsHeapLimitMb,
    required this.frameRateFps,
  });

  final String visitorId;
  final String? ipAddress;
  final DateTime lastSeenAt;
  final int sessions;
  final String? browser;
  final String? operatingSystem;
  final String? deviceType;
  final int? performanceScore;
  final String? performanceTier;
  final int? hardwareConcurrency;
  final double? deviceMemoryGb;
  final String? connectionType;
  final double? connectionDownlinkMbps;
  final int? connectionRttMs;
  final bool? saveData;
  final int? ttfbMs;
  final int? domInteractiveMs;
  final int? pageLoadMs;
  final double? jsHeapUsedMb;
  final double? jsHeapLimitMb;
  final int? frameRateFps;

  factory VisitorDevicePerformance.fromJson(Map<String, dynamic> json) {
    final rawLastSeen = json['lastSeenAt'] as String?;
    return VisitorDevicePerformance(
      visitorId: json['visitorId'] as String? ?? '',
      ipAddress: json['ipAddress'] as String?,
      lastSeenAt: rawLastSeen == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(rawLastSeen).toLocal(),
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      browser: json['browser'] as String?,
      operatingSystem: json['operatingSystem'] as String?,
      deviceType: json['deviceType'] as String?,
      performanceScore: (json['performanceScore'] as num?)?.toInt(),
      performanceTier: json['performanceTier'] as String?,
      hardwareConcurrency: (json['hardwareConcurrency'] as num?)?.toInt(),
      deviceMemoryGb: (json['deviceMemoryGb'] as num?)?.toDouble(),
      connectionType: json['connectionType'] as String?,
      connectionDownlinkMbps:
          (json['connectionDownlinkMbps'] as num?)?.toDouble(),
      connectionRttMs: (json['connectionRttMs'] as num?)?.toInt(),
      saveData: json['saveData'] as bool?,
      ttfbMs: (json['ttfbMs'] as num?)?.toInt(),
      domInteractiveMs: (json['domInteractiveMs'] as num?)?.toInt(),
      pageLoadMs: (json['pageLoadMs'] as num?)?.toInt(),
      jsHeapUsedMb: (json['jsHeapUsedMb'] as num?)?.toDouble(),
      jsHeapLimitMb: (json['jsHeapLimitMb'] as num?)?.toDouble(),
      frameRateFps: (json['frameRateFps'] as num?)?.toInt(),
    );
  }
}

class DevicePerformanceReport {
  const DevicePerformanceReport({
    required this.totalSessions,
    required this.measuredSessions,
    required this.totalVisitors,
    required this.measuredVisitors,
    required this.averagePerformanceScore,
    required this.medianPerformanceScore,
    required this.highTierSessions,
    required this.mediumTierSessions,
    required this.lowTierSessions,
    required this.averageCpuCores,
    required this.averageDeviceMemoryGb,
    required this.p75PageLoadMs,
    required this.p75DomInteractiveMs,
    required this.p75TtfbMs,
    required this.averageFrameRateFps,
    required this.tierBreakdown,
    required this.cpuBreakdown,
    required this.memoryBreakdown,
    required this.networkBreakdown,
    required this.loadTimeBreakdown,
    required this.fpsBreakdown,
    required this.visitors,
  });

  final int totalSessions;
  final int measuredSessions;
  final int totalVisitors;
  final int measuredVisitors;
  final double? averagePerformanceScore;
  final double? medianPerformanceScore;
  final int highTierSessions;
  final int mediumTierSessions;
  final int lowTierSessions;
  final double? averageCpuCores;
  final double? averageDeviceMemoryGb;
  final double? p75PageLoadMs;
  final double? p75DomInteractiveMs;
  final double? p75TtfbMs;
  final double? averageFrameRateFps;
  final List<DevicePerformanceBucket> tierBreakdown;
  final List<DevicePerformanceBucket> cpuBreakdown;
  final List<DevicePerformanceBucket> memoryBreakdown;
  final List<DevicePerformanceBucket> networkBreakdown;
  final List<DevicePerformanceBucket> loadTimeBreakdown;
  final List<DevicePerformanceBucket> fpsBreakdown;
  final List<VisitorDevicePerformance> visitors;

  factory DevicePerformanceReport.fromJson(Map<String, dynamic> json) =>
      DevicePerformanceReport(
        totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
        measuredSessions: (json['measuredSessions'] as num?)?.toInt() ?? 0,
        totalVisitors: (json['totalVisitors'] as num?)?.toInt() ?? 0,
        measuredVisitors: (json['measuredVisitors'] as num?)?.toInt() ?? 0,
        averagePerformanceScore:
            (json['averagePerformanceScore'] as num?)?.toDouble(),
        medianPerformanceScore:
            (json['medianPerformanceScore'] as num?)?.toDouble(),
        highTierSessions: (json['highTierSessions'] as num?)?.toInt() ?? 0,
        mediumTierSessions: (json['mediumTierSessions'] as num?)?.toInt() ?? 0,
        lowTierSessions: (json['lowTierSessions'] as num?)?.toInt() ?? 0,
        averageCpuCores: (json['averageCpuCores'] as num?)?.toDouble(),
        averageDeviceMemoryGb:
            (json['averageDeviceMemoryGb'] as num?)?.toDouble(),
        p75PageLoadMs: (json['p75PageLoadMs'] as num?)?.toDouble(),
        p75DomInteractiveMs:
            (json['p75DomInteractiveMs'] as num?)?.toDouble(),
        p75TtfbMs: (json['p75TtfbMs'] as num?)?.toDouble(),
        averageFrameRateFps:
            (json['averageFrameRateFps'] as num?)?.toDouble(),
        tierBreakdown: _buckets(json['tierBreakdown']),
        cpuBreakdown: _buckets(json['cpuBreakdown']),
        memoryBreakdown: _buckets(json['memoryBreakdown']),
        networkBreakdown: _buckets(json['networkBreakdown']),
        loadTimeBreakdown: _buckets(json['loadTimeBreakdown']),
        fpsBreakdown: _buckets(json['fpsBreakdown']),
        visitors: (json['visitors'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => VisitorDevicePerformance.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .where((item) => item.visitorId.isNotEmpty)
            .toList(growable: false),
      );

  static List<DevicePerformanceBucket> _buckets(Object? input) =>
      (input as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => DevicePerformanceBucket.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
}

final analyticsDevicePerformanceProvider =
    FutureProvider.family<DevicePerformanceReport, AnalyticsDashboardQuery>((
      ref,
      query,
    ) async {
      final path = Uri(
        path: '/api/v1/sites/${query.siteId}/analytics/device-performance',
        queryParameters: {
          'from': query.range.fromQuery,
          'to': query.range.toQuery,
          'limit': '100',
          if (query.segmentId != null) 'segmentId': query.segmentId!,
        },
      );
      final result =
          await ref.read(apiProvider).request('GET', path.toString())
              as Map<String, dynamic>;
      return DevicePerformanceReport.fromJson(result);
    });
