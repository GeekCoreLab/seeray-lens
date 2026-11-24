import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_i18n.dart';
import '../../features/domains/application/domain_controller.dart';
import 'external_url_opener.dart';

class SitePrimaryHostCache extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void setHost(String siteId, String? host) {
    final trimmed = host?.trim() ?? '';
    if (trimmed.isEmpty) {
      if (!state.containsKey(siteId)) return;
      final next = Map<String, String>.from(state)..remove(siteId);
      state = next;
      return;
    }
    if (state[siteId] == trimmed) return;
    state = {...state, siteId: trimmed};
  }
}

final sitePrimaryHostCacheProvider =
    NotifierProvider<SitePrimaryHostCache, Map<String, String>>(
      SitePrimaryHostCache.new,
    );

String? resolvePrimaryHostFromDomains(List<AllowedDomain> domains) {
  for (final domain in domains) {
    if (domain.enabled && domain.host.trim().isNotEmpty) {
      return domain.host.trim();
    }
  }
  for (final domain in domains) {
    if (domain.host.trim().isNotEmpty) {
      return domain.host.trim();
    }
  }
  return null;
}

String _cleanFallbackHost(String host) {
  var value = host.trim();
  if (value.startsWith('https://')) {
    value = value.substring(8);
  } else if (value.startsWith('http://')) {
    value = value.substring(7);
  }
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

Uri? resolveNavigableUrl(String? raw, {String? fallbackHost}) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty || RegExp(r'\s').hasMatch(trimmed)) return null;
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null &&
        (parsed.scheme == 'http' || parsed.scheme == 'https') &&
        parsed.host.isNotEmpty) {
      return parsed;
    }
    return null;
  }
  if (trimmed.startsWith('/')) {
    final host = fallbackHost == null ? '' : _cleanFallbackHost(fallbackHost);
    if (host.isEmpty) return null;
    final parsed = Uri.tryParse('https://$host$trimmed');
    if (parsed != null && parsed.host.isNotEmpty) return parsed;
    return null;
  }
  if (trimmed.contains(':') && !trimmed.contains('/')) {
    // Could be host:port without scheme if left side has dot or is localhost.
    final hostPart = trimmed.split(':').first;
    if (!hostPart.contains('.') && hostPart != 'localhost') return null;
  } else if (trimmed.contains(':')) {
    // Reject non-http schemes such as javascript:, data:, file:, mailto:.
    final firstColon = trimmed.indexOf(':');
    final firstSlash = trimmed.indexOf('/');
    if (firstSlash < 0 || firstColon < firstSlash) return null;
  }
  final hostCandidate = trimmed.split('/').first.split('?').first;
  if (hostCandidate.contains('.') ||
      hostCandidate.startsWith('localhost:') ||
      hostCandidate == 'localhost') {
    final parsed = Uri.tryParse('https://$trimmed');
    if (parsed != null &&
        (parsed.scheme == 'http' || parsed.scheme == 'https') &&
        parsed.host.isNotEmpty) {
      return parsed;
    }
  }
  return null;
}

String formatCopyableUrl(String raw, {String? fallbackHost}) =>
    resolveNavigableUrl(raw, fallbackHost: fallbackHost)?.toString() ??
    raw.trim();

Future<String?> ensurePrimarySiteHost(WidgetRef ref, String siteId) async {
  final cached = ref.read(sitePrimaryHostCacheProvider)[siteId];
  if (cached != null && cached.isNotEmpty) return cached;
  try {
    final domains = await ref.read(domainsProvider(siteId).future);
    final host = resolvePrimaryHostFromDomains(domains);
    if (host != null) {
      ref.read(sitePrimaryHostCacheProvider.notifier).setHost(siteId, host);
    }
    return host;
  } catch (_) {
    return null;
  }
}

Future<void> copyDataText(
  BuildContext context,
  String value, {
  String? englishMessage,
  String? chineseMessage,
}) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        context.tr(englishMessage ?? 'Copied', chineseMessage ?? '已复制'),
      ),
    ),
  );
}

Future<void> openNavigableUrl(BuildContext context, Uri uri) async {
  final opened = await openExternalUrl(uri);
  if (!opened && context.mounted) {
    await copyDataText(
      context,
      uri.toString(),
      englishMessage: 'Could not open link directly; copied to clipboard',
      chineseMessage: '无法直接打开链接，已复制到剪贴板',
    );
  }
}

class CopyIconButton extends StatelessWidget {
  const CopyIconButton({
    required this.text,
    this.tooltipEn,
    this.tooltipZh,
    this.copiedEn,
    this.copiedZh,
    this.iconSize = 15,
    super.key,
  });

  final String text;
  final String? tooltipEn;
  final String? tooltipZh;
  final String? copiedEn;
  final String? copiedZh;
  final double iconSize;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.tr(tooltipEn ?? 'Copy', tooltipZh ?? '复制'),
    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    padding: const EdgeInsets.all(4),
    visualDensity: VisualDensity.compact,
    icon: Icon(Icons.copy_outlined, size: iconSize),
    onPressed: () => unawaited(
      copyDataText(
        context,
        text,
        englishMessage: copiedEn ?? 'Copied',
        chineseMessage: copiedZh ?? '已复制',
      ),
    ),
  );
}

class UrlActionButtons extends ConsumerWidget {
  const UrlActionButtons({
    required this.rawUrl,
    this.siteId,
    this.fallbackHost,
    this.showOpen = true,
    this.iconSize = 15,
    super.key,
  });

  final String rawUrl;
  final String? siteId;
  final String? fallbackHost;
  final bool showOpen;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cachedHost =
        fallbackHost ??
        (siteId == null
            ? null
            : ref.watch(sitePrimaryHostCacheProvider)[siteId]);
    final resolvedUri = resolveNavigableUrl(rawUrl, fallbackHost: cachedHost);
    final trimmed = rawUrl.trim();
    final canAttemptOpen =
        showOpen &&
        (resolvedUri != null || (siteId != null && trimmed.startsWith('/')));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: context.tr('Copy URL', '复制链接'),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: const EdgeInsets.all(4),
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.copy_outlined, size: iconSize),
          onPressed: () => unawaited(
            copyDataText(
              context,
              formatCopyableUrl(rawUrl, fallbackHost: cachedHost),
              englishMessage: 'URL copied',
              chineseMessage: '链接已复制',
            ),
          ),
        ),
        if (canAttemptOpen)
          IconButton(
            tooltip: context.tr('Open URL', '打开链接'),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: const EdgeInsets.all(4),
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.open_in_new, size: iconSize),
            onPressed: () => unawaited(_open(context, ref, resolvedUri)),
          ),
      ],
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Uri? directUri,
  ) async {
    Uri? target = directUri;
    if (target == null && siteId != null) {
      final host = await ensurePrimarySiteHost(ref, siteId!);
      target = resolveNavigableUrl(rawUrl, fallbackHost: host);
    }
    if (!context.mounted) return;
    if (target == null) {
      await copyDataText(
        context,
        rawUrl.trim(),
        englishMessage: 'Configure an allowed domain to open relative paths',
        chineseMessage: '请先配置允许的域名以直接打开相对路径',
      );
      return;
    }
    await openNavigableUrl(context, target);
  }
}

class CopyableIpChip extends StatelessWidget {
  const CopyableIpChip({required this.ipAddress, super.key});

  final String ipAddress;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: const Icon(Icons.lan_outlined, size: 16),
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${context.tr('IP', 'IP')}: $ipAddress',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: 4),
        const Icon(Icons.copy_outlined, size: 13),
      ],
    ),
    tooltip: context.tr('Copy IP address', '复制 IP 地址'),
    visualDensity: VisualDensity.compact,
    onPressed: () => unawaited(
      copyDataText(
        context,
        ipAddress,
        englishMessage: 'IP copied',
        chineseMessage: '已复制 IP',
      ),
    ),
  );
}
