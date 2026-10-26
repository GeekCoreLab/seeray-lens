import 'package:flutter/material.dart';

import '../../../core/i18n/app_i18n.dart';

enum VisitorAssociationView { ip, tls, browser }

class VisitorAssociationControls extends StatelessWidget {
  const VisitorAssociationControls({
    required this.view,
    required this.onViewChanged,
    required this.aggregate,
    required this.onAggregateChanged,
    super.key,
  });

  final VisitorAssociationView view;
  final ValueChanged<VisitorAssociationView> onViewChanged;
  final bool aggregate;
  final ValueChanged<bool> onAggregateChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 14,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<VisitorAssociationView>(
            value: view,
            underline: const SizedBox.shrink(),
            onChanged: (value) {
              if (value != null) onViewChanged(value);
            },
            items: [
              DropdownMenuItem(
                value: VisitorAssociationView.ip,
                child: Text(context.tr('View by IP', '按 IP 查看')),
              ),
              DropdownMenuItem(
                value: VisitorAssociationView.tls,
                child: Text(
                  context.tr('View by TLS fingerprint', '按 TLS 指纹查看'),
                ),
              ),
              DropdownMenuItem(
                value: VisitorAssociationView.browser,
                child: Text(
                  context.tr('View by browser fingerprint', '按浏览器指纹查看'),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(value: aggregate, onChanged: onAggregateChanged),
              Text(context.tr('Group related visits', '聚合疑似关联访客')),
            ],
          ),
        ],
      ),
      Text(
        context.tr(
          'Groups use the selected signal and the same anonymous browser ID. They are display hints, not identity merges.',
          '分组依据为所选信号和相同的匿名浏览器标识，仅用于展示关联线索，不会合并身份。',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

List<List<T>> visitorAssociationGroups<T>({
  required List<T> records,
  required bool aggregate,
  required String? Function(T) visitorId,
  required String? Function(T) associationKey,
}) {
  if (!aggregate) return records.map((record) => [record]).toList();

  final parents = List<int>.generate(records.length, (index) => index);
  int root(int value) {
    if (parents[value] != value) parents[value] = root(parents[value]);
    return parents[value];
  }

  void join(int first, int second) {
    final firstRoot = root(first);
    final secondRoot = root(second);
    if (firstRoot != secondRoot) parents[secondRoot] = firstRoot;
  }

  final seen = <String, int>{};
  for (var index = 0; index < records.length; index++) {
    final id = visitorId(records[index]);
    final relation = associationKey(records[index]);
    for (final key in [
      if (id != null && id.isNotEmpty) 'visitor:$id',
      if (relation != null && relation.isNotEmpty) 'signal:$relation',
    ]) {
      final earlier = seen[key];
      if (earlier == null) {
        seen[key] = index;
      } else {
        join(index, earlier);
      }
    }
  }

  final grouped = <int, List<T>>{};
  for (var index = 0; index < records.length; index++) {
    grouped.putIfAbsent(root(index), () => []).add(records[index]);
  }
  return grouped.values.toList(growable: false);
}

String visitorAssociationValue(
  BuildContext context,
  VisitorAssociationView view, {
  required String? ipAddress,
  required String? tlsFingerprintGroup,
  required String? browserFingerprintGroup,
}) => switch (view) {
  VisitorAssociationView.ip =>
    ipAddress ?? context.tr('IP unavailable', 'IP 暂不可用'),
  VisitorAssociationView.tls =>
    tlsFingerprintGroup == null
        ? context.tr('TLS fingerprint unavailable', 'TLS 指纹暂不可用')
        : context.tr(
            'TLS fingerprint group $tlsFingerprintGroup',
            'TLS 指纹组 $tlsFingerprintGroup',
          ),
  VisitorAssociationView.browser =>
    browserFingerprintGroup == null
        ? context.tr('Browser fingerprint unavailable', '浏览器指纹暂不可用')
        : context.tr(
            'Browser fingerprint group $browserFingerprintGroup',
            '浏览器指纹组 $browserFingerprintGroup',
          ),
};
