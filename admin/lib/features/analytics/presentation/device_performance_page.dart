import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../shared/presentation/page_help_button.dart';
import '../../../shared/presentation/site_top_bar.dart';
import '../application/analytics_controller.dart';
import '../application/analytics_range.dart';
import '../application/analytics_segment.dart';
import '../application/device_performance_controller.dart';
import 'device_performance_badge.dart';
import 'segment_filter_selector.dart';
import 'timeline_date_formatter.dart';
import 'visitor_visuals.dart';

class DevicePerformancePage extends ConsumerStatefulWidget {
  const DevicePerformancePage({
    required this.siteId,
    this.embedded = false,
    super.key,
  });

  final String siteId;
  final bool embedded;

  @override
  ConsumerState<DevicePerformancePage> createState() =>
      _DevicePerformancePageState();
}

class _DevicePerformancePageState extends ConsumerState<DevicePerformancePage> {
  String _tierFilter = 'all';
  String _sortBy = 'latest';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(analyticsRangeProvider(widget.siteId));
      if (current.period != AnalyticsPeriod.realtime) return;
      final to = analyticsDateOnly(DateTime.now());
      ref
          .read(analyticsRangeProvider(widget.siteId).notifier)
          .setRange(
            AnalyticsRangeState(
              period: AnalyticsPeriod.custom,
              range: AnalyticsDateRange(
                to.subtract(const Duration(days: 29)),
                to,
              ),
            ),
          );
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(analyticsRangeProvider(widget.siteId));
    final segmentId = ref.watch(
      analyticsSegmentSelectionProvider(widget.siteId),
    );
    final query = AnalyticsDashboardQuery(
      widget.siteId,
      range.range,
      segmentId: segmentId,
    );
    final report = ref.watch(analyticsDevicePerformanceProvider(query));
    return Scaffold(
      backgroundColor: const Color(0xfff3f5f8),
      appBar: widget.embedded
          ? null
          : SiteTopBar(
              siteId: widget.siteId,
              selected: SiteTopTab.devicePerformance,
              help: const PageHelpButton(
                englishTitle: 'Device performance report',
                chineseTitle: '设备性能报表说明',
                englishBody:
                    'Summarizes client hardware capacity (CPU cores, device memory), network conditions, page load timing, JS heap usage, and rendering frame rate across visitors. Scores (0–100) are weighted dynamically across the signals each browser exposes.',
                chineseBody:
                    '汇总访客端设备硬件能力（CPU 核心数、设备内存）、网络状况、页面加载耗时、JS 堆内存与渲染帧率（FPS）。0–100 综合性能分会根据各浏览器实际开放的指标动态加权计算。',
              ),
              rangeState: range,
              segmentFilter: SegmentFilterSelector(siteId: widget.siteId),
              onSelectRange: () => _selectRange(context, range),
              onRefresh: () =>
                  ref.invalidate(analyticsDevicePerformanceProvider(query)),
            ),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.tr(
                'Could not load device performance report',
                '无法加载设备性能报表',
              ),
            ),
          ),
        ),
        data: (data) => _DevicePerformanceBody(
          siteId: widget.siteId,
          report: data,
          tierFilter: _tierFilter,
          onTierFilterChanged: (value) => setState(() => _tierFilter = value),
          sortBy: _sortBy,
          onSortChanged: (value) => setState(() => _sortBy = value),
          searchController: _search,
          onSearchChanged: () => setState(() {}),
        ),
      ),
    );
  }

  Future<void> _selectRange(
    BuildContext context,
    AnalyticsRangeState current,
  ) async {
    final selected = await showAnalyticsRangePicker(context, current);
    if (selected == null || !mounted) return;
    ref.read(analyticsRangeProvider(widget.siteId).notifier).setRange(selected);
  }
}

class _DevicePerformanceBody extends StatelessWidget {
  const _DevicePerformanceBody({
    required this.siteId,
    required this.report,
    required this.tierFilter,
    required this.onTierFilterChanged,
    required this.sortBy,
    required this.onSortChanged,
    required this.searchController,
    required this.onSearchChanged,
  });

  final String siteId;
  final DevicePerformanceReport report;
  final String tierFilter;
  final ValueChanged<String> onTierFilterChanged;
  final String sortBy;
  final ValueChanged<String> onSortChanged;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;

  @override
  Widget build(BuildContext context) {
    if (report.totalSessions == 0) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            context.tr('Device performance', '设备性能'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.tr(
                  'No visits match this date range and audience. Try a wider date range or clear the selected segment.',
                  '当前日期范围和分群内暂无访问记录。请扩大日期范围或清除当前分群。',
                ),
              ),
            ),
          ),
        ],
      );
    }

    final avgScore = report.averagePerformanceScore;
    final avgTier = avgScore == null
        ? null
        : avgScore >= 75
        ? 'high'
        : avgScore >= 45
        ? 'medium'
        : 'low';
    final lowPct = report.measuredSessions == 0
        ? 0.0
        : report.lowTierSessions / report.measuredSessions * 100;
    final hardwareSummary = [
      if (report.averageCpuCores != null)
        context.tr(
          '${report.averageCpuCores!.toStringAsFixed(1)} cores',
          '${report.averageCpuCores!.toStringAsFixed(1)} 核',
        ),
      if (report.averageDeviceMemoryGb != null)
        '${report.averageDeviceMemoryGb!.toStringAsFixed(1)} GB',
      if (report.p75PageLoadMs != null)
        'p75 ${formatPerformanceMs(report.p75PageLoadMs!.round())}',
      if (report.averageFrameRateFps != null)
        '${report.averageFrameRateFps!.round()} FPS',
    ].join(' · ');

    final filteredVisitors = _filterAndSortVisitors(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          context.tr('Device performance', '设备性能'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          context.tr(
            'Hardware capacity, network conditions, runtime timing and smoothness scored per visitor and session.',
            '按访客和访问会话统计终端硬件能力、网络状况、加载耗时与渲染流畅度。',
          ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1160
                ? 4
                : constraints.maxWidth >= 640
                ? 2
                : 1;
            const spacing = 12.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: width,
                  child: _KpiCard(
                    icon: Icons.speed_outlined,
                    label: context.tr('Average device score', '平均设备性能分'),
                    value: avgScore == null
                        ? context.tr('N/A', '暂无')
                        : '${avgScore.round()} / 100',
                    detail: report.medianPerformanceScore == null
                        ? context.tr('Awaiting signals', '等待性能信号')
                        : context.tr(
                            'Median ${report.medianPerformanceScore!.round()}',
                            '中位数 ${report.medianPerformanceScore!.round()}',
                          ),
                    trailing: avgTier == null
                        ? null
                        : DevicePerformanceTierBadge(
                            tier: avgTier,
                            compact: true,
                          ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _KpiCard(
                    icon: Icons.devices_outlined,
                    label: context.tr('Measured visitors', '已采集访客'),
                    value: '${report.measuredVisitors} / ${report.totalVisitors}',
                    detail: context.tr(
                      '${report.measuredSessions} / ${report.totalSessions} visits measured',
                      '已采集 ${report.measuredSessions} / ${report.totalSessions} 次访问',
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _KpiCard(
                    icon: Icons.warning_amber_outlined,
                    label: context.tr('Low-performance visits', '低性能访问占比'),
                    value: report.measuredSessions == 0
                        ? '0.0%'
                        : '${lowPct.toStringAsFixed(1)}%',
                    detail: context.tr(
                      'High ${report.highTierSessions} · Med ${report.mediumTierSessions} · Low ${report.lowTierSessions}',
                      '高 ${report.highTierSessions} · 中 ${report.mediumTierSessions} · 低 ${report.lowTierSessions}',
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _KpiCard(
                    icon: Icons.memory_outlined,
                    label: context.tr('Average hardware & load', '平均硬件与加载'),
                    value: report.p75PageLoadMs == null
                        ? (report.averageCpuCores == null
                              ? context.tr('N/A', '暂无')
                              : context.tr(
                                  '${report.averageCpuCores!.toStringAsFixed(1)} cores',
                                  '${report.averageCpuCores!.toStringAsFixed(1)} 核',
                                ))
                        : 'p75 ${formatPerformanceMs(report.p75PageLoadMs!.round())}',
                    detail: hardwareSummary.isEmpty
                        ? context.tr('No timing samples yet', '暂无耗时样本')
                        : hardwareSummary,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1160
                ? 3
                : constraints.maxWidth >= 760
                ? 2
                : 1;
            const spacing = 16.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            final sections = [
              (
                kind: 'tier',
                title: context.tr('Performance tiers', '性能等级分布'),
                rows: report.tierBreakdown,
              ),
              (
                kind: 'cpu',
                title: context.tr('CPU cores', 'CPU 核心数'),
                rows: report.cpuBreakdown,
              ),
              (
                kind: 'memory',
                title: context.tr('Device memory', '设备内存'),
                rows: report.memoryBreakdown,
              ),
              (
                kind: 'network',
                title: context.tr('Network type', '网络类型'),
                rows: report.networkBreakdown,
              ),
              (
                kind: 'load_time',
                title: context.tr('Page load time', '页面加载耗时'),
                rows: report.loadTimeBreakdown,
              ),
              (
                kind: 'fps',
                title: context.tr('Rendering frame rate', '渲染帧率 FPS'),
                rows: report.fpsBreakdown,
              ),
            ];
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final section in sections)
                  SizedBox(
                    width: width,
                    child: _DistributionCard(
                      kind: section.kind,
                      title: section.title,
                      rows: section.rows,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_outline),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(
                              'Visitor device performance',
                              '访客设备性能明细',
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            context.tr(
                              'Showing ${filteredVisitors.length} of ${report.visitors.length} visitors in the selected period. Tap any visitor to inspect their full profile.',
                              '显示所选周期内 ${report.visitors.length} 位访客中的 ${filteredVisitors.length} 位。点击访客可查看完整访客画像。',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final option in [
                      ('all', context.tr('All', '全部')),
                      ('high', context.tr('High', '高性能')),
                      ('medium', context.tr('Medium', '中等性能')),
                      ('low', context.tr('Low', '低性能')),
                      ('unmeasured', context.tr('Unmeasured', '未采集')),
                    ])
                      ChoiceChip(
                        label: Text(option.$2),
                        selected: tierFilter == option.$1,
                        onSelected: (_) => onTierFilterChanged(option.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final searchField = TextField(
                      controller: searchController,
                      onChanged: (_) => onSearchChanged(),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search),
                        hintText: context.tr(
                          'Filter by IP, browser, OS, device or network',
                          '按 IP、浏览器、系统、设备或网络筛选',
                        ),
                        suffixIcon: searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: context.tr('Clear search', '清除搜索'),
                                onPressed: () {
                                  searchController.clear();
                                  onSearchChanged();
                                },
                                icon: const Icon(Icons.close),
                              ),
                        border: const OutlineInputBorder(),
                      ),
                    );
                    final sortDropdown = DropdownButtonFormField<String>(
                      initialValue: sortBy,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: context.tr('Sort by', '排序方式'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'latest',
                          child: Text(context.tr('Latest seen', '最近活跃')),
                        ),
                        DropdownMenuItem(
                          value: 'score_asc',
                          child: Text(
                            context.tr('Lowest score first', '性能分从低到高'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'score_desc',
                          child: Text(
                            context.tr('Highest score first', '性能分从高到低'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'load_desc',
                          child: Text(
                            context.tr('Slowest page load', '加载耗时从慢到快'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) onSortChanged(value);
                      },
                    );
                    if (constraints.maxWidth < 680) {
                      return Column(
                        children: [
                          searchField,
                          const SizedBox(height: 10),
                          sortDropdown,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(flex: 3, child: searchField),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: sortDropdown),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (filteredVisitors.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        context.tr(
                          'No visitors match the current filters.',
                          '没有符合当前筛选条件的访客。',
                        ),
                      ),
                    ),
                  )
                else
                  for (final visitor in filteredVisitors)
                    _VisitorPerformanceCard(siteId: siteId, visitor: visitor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<VisitorDevicePerformance> _filterAndSortVisitors(BuildContext context) {
    final needle = searchController.text.trim().toLowerCase();
    final filtered = report.visitors
        .where((visitor) {
          final tierMatches = switch (tierFilter) {
            'high' => visitor.performanceTier == 'high',
            'medium' => visitor.performanceTier == 'medium',
            'low' => visitor.performanceTier == 'low',
            'unmeasured' => visitor.performanceTier == null,
            _ => true,
          };
          if (!tierMatches) return false;
          if (needle.isEmpty) return true;
          final ipText =
              (visitor.ipAddress ?? context.tr('IP unavailable', 'IP 暂不可用'))
                  .toLowerCase();
          return ipText.contains(needle) ||
              (visitor.browser ?? '').toLowerCase().contains(needle) ||
              (visitor.operatingSystem ?? '').toLowerCase().contains(needle) ||
              (visitor.deviceType ?? '').toLowerCase().contains(needle) ||
              (visitor.connectionType ?? '').toLowerCase().contains(needle) ||
              devicePerformanceTierLabel(
                context,
                visitor.performanceTier,
              ).toLowerCase().contains(needle);
        })
        .toList(growable: true);

    filtered.sort((a, b) {
      switch (sortBy) {
        case 'score_asc':
          final sa = a.performanceScore;
          final sb = b.performanceScore;
          if (sa == null && sb == null) {
            return b.lastSeenAt.compareTo(a.lastSeenAt);
          }
          if (sa == null) return 1;
          if (sb == null) return -1;
          final cmp = sa.compareTo(sb);
          return cmp != 0 ? cmp : b.lastSeenAt.compareTo(a.lastSeenAt);
        case 'score_desc':
          final sa = a.performanceScore;
          final sb = b.performanceScore;
          if (sa == null && sb == null) {
            return b.lastSeenAt.compareTo(a.lastSeenAt);
          }
          if (sa == null) return 1;
          if (sb == null) return -1;
          final cmp = sb.compareTo(sa);
          return cmp != 0 ? cmp : b.lastSeenAt.compareTo(a.lastSeenAt);
        case 'load_desc':
          final la = a.pageLoadMs;
          final lb = b.pageLoadMs;
          if (la == null && lb == null) {
            return b.lastSeenAt.compareTo(a.lastSeenAt);
          }
          if (la == null) return 1;
          if (lb == null) return -1;
          final cmp = lb.compareTo(la);
          return cmp != 0 ? cmp : b.lastSeenAt.compareTo(a.lastSeenAt);
        default:
          return b.lastSeenAt.compareTo(a.lastSeenAt);
      }
    });
    return filtered;
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(value, style: Theme.of(context).textTheme.titleLarge),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({
    required this.kind,
    required this.title,
    required this.rows,
  });

  final String kind;
  final String title;
  final List<DevicePerformanceBucket> rows;

  @override
  Widget build(BuildContext context) {
    final totalSessions = rows.fold<int>(0, (sum, row) => sum + row.sessions);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text(context.tr('Bucket', '分组'))),
                SizedBox(
                  width: 54,
                  child: Text(
                    context.tr('Visits', '访问'),
                    textAlign: TextAlign.end,
                  ),
                ),
                SizedBox(
                  width: 54,
                  child: Text(
                    context.tr('Visitors', '访客'),
                    textAlign: TextAlign.end,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    context.tr('Score', '均分'),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            for (final row in rows) ...[
              Row(
                children: [
                  if (kind == 'tier') ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: devicePerformanceTierColor(row.label),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      _bucketLabel(context, kind, row.label),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 54,
                    child: Text('${row.sessions}', textAlign: TextAlign.end),
                  ),
                  SizedBox(
                    width: 54,
                    child: Text('${row.visitors}', textAlign: TextAlign.end),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      row.averageScore == null
                          ? '—'
                          : '${row.averageScore!.round()}',
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                value: totalSessions == 0 ? 0 : row.sessions / totalSessions,
                minHeight: 4,
                borderRadius: BorderRadius.circular(4),
                color: kind == 'tier'
                    ? devicePerformanceTierColor(row.label)
                    : null,
                backgroundColor: const Color(0xffe7ebf0),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  String _bucketLabel(BuildContext context, String kind, String raw) {
    if (kind == 'tier') return devicePerformanceTierLabel(context, raw);
    if (raw == 'Unknown') return context.tr('Unknown', '未知');
    if (kind == 'network') return raw.toUpperCase();
    if (kind == 'cpu') {
      return switch (raw) {
        '1–2 cores' => context.tr('1–2 cores', '1–2 核'),
        '3–4 cores' => context.tr('3–4 cores', '3–4 核'),
        '5–8 cores' => context.tr('5–8 cores', '5–8 核'),
        '9–16 cores' => context.tr('9–16 cores', '9–16 核'),
        '17+ cores' => context.tr('17+ cores', '17+ 核'),
        _ => raw,
      };
    }
    return raw;
  }
}

class _VisitorPerformanceCard extends StatelessWidget {
  const _VisitorPerformanceCard({
    required this.siteId,
    required this.visitor,
  });

  final String siteId;
  final VisitorDevicePerformance visitor;

  @override
  Widget build(BuildContext context) {
    final ipLabel =
        visitor.ipAddress ?? context.tr('IP unavailable', 'IP 暂不可用');
    final chips = formatDeviceHardwareChips(
      context,
      hardwareConcurrency: visitor.hardwareConcurrency,
      deviceMemoryGb: visitor.deviceMemoryGb,
      connectionType: visitor.connectionType,
      connectionDownlinkMbps: visitor.connectionDownlinkMbps,
      connectionRttMs: visitor.connectionRttMs,
      saveData: visitor.saveData,
      ttfbMs: visitor.ttfbMs,
      domInteractiveMs: visitor.domInteractiveMs,
      pageLoadMs: visitor.pageLoadMs,
      jsHeapUsedMb: visitor.jsHeapUsedMb,
      jsHeapLimitMb: visitor.jsHeapLimitMb,
      frameRateFps: visitor.frameRateFps,
    );
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(
          '/sites/$siteId/visitors/${Uri.encodeComponent(visitor.visitorId)}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (visitor.deviceType != null) ...[
                    VisitorPlatformMark(
                      kind: VisitorPlatformKind.device,
                      value: visitor.deviceType!,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                  ] else ...[
                    const CircleAvatar(
                      radius: 14,
                      child: Icon(Icons.devices_outlined, size: 16),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ipLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '${visitor.sessions} ${context.tr('visits', '次访问')} · ${formatTimelineTime(context, visitor.lastSeenAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DevicePerformanceTierBadge(
                    tier: visitor.performanceTier,
                    score: visitor.performanceScore,
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (visitor.browser != null ||
                  visitor.operatingSystem != null ||
                  chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    if (visitor.browser != null)
                      Chip(
                        avatar: VisitorPlatformMark(
                          kind: VisitorPlatformKind.browser,
                          value: visitor.browser!,
                          size: 17,
                        ),
                        label: Text(visitor.browser!),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    if (visitor.operatingSystem != null)
                      Chip(
                        avatar: VisitorPlatformMark(
                          kind: VisitorPlatformKind.operatingSystem,
                          value: visitor.operatingSystem!,
                          size: 17,
                        ),
                        label: Text(visitor.operatingSystem!),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    for (final chip in chips)
                      Chip(
                        avatar: Icon(chip.icon, size: 16),
                        label: Text(
                          chip.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
