import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_i18n.dart';
import '../application/analytics_controller.dart';
import '../application/analytics_range.dart';
import '../application/analytics_segment.dart';
import '../application/visitor_profile_controller.dart';
import 'timeline_date_formatter.dart';
import 'visitor_association_controls.dart';

class VisitorLogPanel extends ConsumerStatefulWidget {
  const VisitorLogPanel({required this.siteId, super.key});

  final String siteId;

  @override
  ConsumerState<VisitorLogPanel> createState() => _VisitorLogPanelState();
}

class _VisitorLogPanelState extends ConsumerState<VisitorLogPanel> {
  final _search = TextEditingController();
  VisitorAssociationView _associationView = VisitorAssociationView.ip;
  bool _aggregate = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rangeState = ref.watch(analyticsRangeProvider(widget.siteId));
    final segmentId = ref.watch(
      analyticsSegmentSelectionProvider(widget.siteId),
    );
    final query = AnalyticsDashboardQuery(
      widget.siteId,
      rangeState.range,
      segmentId: segmentId,
    );
    final visits = ref.watch(analyticsVisitorLogProvider(query));

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.manage_search_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('Recent visits', '近期访问'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Refresh', '刷新'),
                  onPressed: () =>
                      ref.invalidate(analyticsVisitorLogProvider(query)),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'Search visits, then open a profile to inspect the selected period. IP addresses follow a 30-day retention policy and are cleared by the daily cleanup.',
                '搜索访问记录并打开访客画像查看所选周期。IP 地址按 30 天策略保留，并由每日清理任务删除。',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            VisitorAssociationControls(
              view: _associationView,
              onViewChanged: (value) =>
                  setState(() => _associationView = value),
              aggregate: _aggregate,
              onAggregateChanged: (value) => setState(() => _aggregate = value),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: context.tr(
                  'Filter by selected signal or page',
                  '按当前查看方式或页面筛选',
                ),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.tr('Clear search', '清除搜索'),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            visits.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(
                  context.tr('Could not load recent visits', '无法加载访问记录'),
                ),
                trailing: TextButton(
                  onPressed: () =>
                      ref.invalidate(analyticsVisitorLogProvider(query)),
                  child: Text(context.tr('Retry', '重试')),
                ),
              ),
              data: (items) {
                final needle = _search.text.trim().toLowerCase();
                final filtered = items
                    .where((item) {
                      if (needle.isEmpty) return true;
                      return visitorAssociationValue(
                            context,
                            _associationView,
                            ipAddress: item.ipAddress,
                            tlsFingerprintGroup: item.tlsFingerprintGroup,
                            browserFingerprintGroup:
                                item.browserFingerprintGroup,
                          ).toLowerCase().contains(needle) ||
                          (item.entryPage ?? '').toLowerCase().contains(
                            needle,
                          ) ||
                          (item.exitPage ?? '').toLowerCase().contains(needle);
                    })
                    .toList(growable: false);
                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Center(
                      child: Text(
                        items.isEmpty
                            ? context.tr(
                                'No visits in this date range.',
                                '所选日期范围内暂无访问记录。',
                              )
                            : context.tr(
                                'No visits match this search.',
                                '没有匹配的访问记录。',
                              ),
                      ),
                    ),
                  );
                }
                final groups = visitorAssociationGroups(
                  records: filtered,
                  aggregate: _aggregate,
                  visitorId: (item) => item.visitorId,
                  associationKey: (item) => switch (_associationView) {
                    VisitorAssociationView.ip => item.ipAddress,
                    VisitorAssociationView.tls => item.tlsFingerprintGroup,
                    VisitorAssociationView.browser =>
                      item.browserFingerprintGroup,
                  },
                );
                return Column(
                  children: [
                    for (var index = 0; index < groups.length; index++)
                      if (_aggregate && groups[index].length > 1)
                        _VisitorVisitGroup(
                          siteId: widget.siteId,
                          index: index + 1,
                          entries: groups[index],
                          view: _associationView,
                        )
                      else
                        _VisitorVisitTile(
                          siteId: widget.siteId,
                          entry: groups[index].first,
                          view: _associationView,
                        ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          context.tr(
                            'Showing up to 100 recent visits. The visitor profile contains lifetime first/last seen dates and period details for the selected audience.',
                            '最多显示最近 100 次访问。访客画像提供首次/最近出现时间，以及所选分群和周期内的访问详情。',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitorVisitTile extends StatelessWidget {
  const _VisitorVisitTile({
    required this.siteId,
    required this.entry,
    required this.view,
  });

  final String siteId;
  final AnalyticsVisitorLogEntry entry;
  final VisitorAssociationView view;

  @override
  Widget build(BuildContext context) {
    final path = [entry.entryPage, entry.exitPage]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return Card(
      margin: const EdgeInsets.only(top: 7),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Icon(
            entry.visitorType == 'returning'
                ? Icons.history
                : Icons.person_outline,
          ),
        ),
        title: Text(
          visitorAssociationValue(
            context,
            view,
            ipAddress: entry.ipAddress,
            tlsFingerprintGroup: entry.tlsFingerprintGroup,
            browserFingerprintGroup: entry.browserFingerprintGroup,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (path.isNotEmpty) path.join('  →  '),
            '${formatTimelineTime(context, entry.startedAt)} · ${entry.pageViews} ${context.tr('pages', '页')} · ${entry.events} ${context.tr('events', '事件')}',
            if (entry.fingerprintRiskLevel != 'none')
              !entry.fingerprintEvidenceTypes.contains('browser') &&
                      entry.fingerprintConfidence == 'low'
                  ? context.tr(
                      'JA4 match: ${entry.fingerprintRelatedVisitorCount} visitors · low confidence',
                      'JA4 匹配：${entry.fingerprintRelatedVisitorCount} 个访客 · 低置信度',
                    )
                  : context.tr(
                      'Browser fingerprint match: ${entry.fingerprintRelatedVisitorCount} visitors · accounts: ${entry.fingerprintRelatedAccountCount}',
                      '浏览器指纹匹配：${entry.fingerprintRelatedVisitorCount} 个访客 · 账号数：${entry.fingerprintRelatedAccountCount}',
                    ),
          ].join('\n'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.fingerprintRiskLevel != 'none')
              Tooltip(
                message: context.tr('Fingerprint risk signal', '指纹风险信号'),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            IconButton(
              tooltip: context.tr('Open visitor profile', '打开访客画像'),
              onPressed: () => context.go(
                '/sites/$siteId/visitors/${Uri.encodeComponent(entry.visitorId)}',
              ),
              icon: const Icon(Icons.arrow_forward),
            ),
          ],
        ),
        onTap: () => context.go(
          '/sites/$siteId/visitors/${Uri.encodeComponent(entry.visitorId)}',
        ),
      ),
    );
  }

  // Keep fallback or helper if needed
}

class _VisitorVisitGroup extends StatelessWidget {
  const _VisitorVisitGroup({
    required this.siteId,
    required this.index,
    required this.entries,
    required this.view,
  });

  final String siteId;
  final int index;
  final List<AnalyticsVisitorLogEntry> entries;
  final VisitorAssociationView view;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 8),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      leading: const CircleAvatar(child: Icon(Icons.hub_outlined)),
      title: Text(context.tr('Possible related group $index', '疑似关联组 $index')),
      subtitle: Text(
        context.tr('${entries.length} visits', '${entries.length} 次访问'),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      children: [
        for (final entry in entries)
          _VisitorVisitTile(siteId: siteId, entry: entry, view: view),
      ],
    ),
  );
}
