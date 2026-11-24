import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/i18n/app_i18n.dart';

const Map<String, ({String en, String zh})> _countryNames = {
  'CN': (en: 'China', zh: '中国'),
  'US': (en: 'United States', zh: '美国'),
  'AU': (en: 'Australia', zh: '澳大利亚'),
  'JP': (en: 'Japan', zh: '日本'),
  'GB': (en: 'United Kingdom', zh: '英国'),
  'DE': (en: 'Germany', zh: '德国'),
  'FR': (en: 'France', zh: '法国'),
  'CA': (en: 'Canada', zh: '加拿大'),
  'SG': (en: 'Singapore', zh: '新加坡'),
  'HK': (en: 'Hong Kong', zh: '中国香港'),
  'TW': (en: 'Taiwan', zh: '中国台湾'),
  'MO': (en: 'Macau', zh: '中国澳门'),
  'KR': (en: 'South Korea', zh: '韩国'),
  'IN': (en: 'India', zh: '印度'),
  'NL': (en: 'Netherlands', zh: '荷兰'),
  'RU': (en: 'Russia', zh: '俄罗斯'),
  'BR': (en: 'Brazil', zh: '巴西'),
  'VN': (en: 'Vietnam', zh: '越南'),
  'TH': (en: 'Thailand', zh: '泰国'),
  'MY': (en: 'Malaysia', zh: '马来西亚'),
  'ID': (en: 'Indonesia', zh: '印度尼西亚'),
  'PH': (en: 'Philippines', zh: '菲律宾'),
  'IT': (en: 'Italy', zh: '意大利'),
  'ES': (en: 'Spain', zh: '西班牙'),
  'SE': (en: 'Sweden', zh: '瑞典'),
  'CH': (en: 'Switzerland', zh: '瑞士'),
  'IE': (en: 'Ireland', zh: '爱尔兰'),
  'NZ': (en: 'New Zealand', zh: '新西兰'),
  'MX': (en: 'Mexico', zh: '墨西哥'),
  'PL': (en: 'Poland', zh: '波兰'),
  'TR': (en: 'Turkey', zh: '土耳其'),
  'AE': (en: 'United Arab Emirates', zh: '阿联酋'),
  'SA': (en: 'Saudi Arabia', zh: '沙特阿拉伯'),
  'ZA': (en: 'South Africa', zh: '南非'),
  'NO': (en: 'Norway', zh: '挪威'),
  'FI': (en: 'Finland', zh: '芬兰'),
  'DK': (en: 'Denmark', zh: '丹麦'),
  'AT': (en: 'Austria', zh: '奥地利'),
  'BE': (en: 'Belgium', zh: '比利时'),
  'PT': (en: 'Portugal', zh: '葡萄牙'),
  'UA': (en: 'Ukraine', zh: '乌克兰'),
  'AR': (en: 'Argentina', zh: '阿根廷'),
  'CL': (en: 'Chile', zh: '智利'),
  'CO': (en: 'Colombia', zh: '哥伦比亚'),
  'IL': (en: 'Israel', zh: '以色列'),
  'PK': (en: 'Pakistan', zh: '巴基斯坦'),
  'BD': (en: 'Bangladesh', zh: '孟加拉国'),
  'NG': (en: 'Nigeria', zh: '尼日利亚'),
  'EG': (en: 'Egypt', zh: '埃及'),
};

String? countryDisplayName(BuildContext context, String? countryCode) {
  final code = countryCode?.trim().toUpperCase() ?? '';
  if (code.isEmpty) return null;
  final entry = _countryNames[code];
  if (entry != null) {
    return context.isChinese ? entry.zh : entry.en;
  }
  return code;
}

String formatVisitorLocation(
  BuildContext context, {
  String? countryCode,
  String? region,
  String? city,
}) {
  final country = countryDisplayName(context, countryCode);
  final rawParts = context.isChinese
      ? <String?>[country, region, city]
      : <String?>[city, region, country];
  final seen = <String>{};
  final parts = <String>[];
  for (final raw in rawParts) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) continue;
    final key = trimmed.toLowerCase();
    if (seen.add(key)) {
      parts.add(trimmed);
    }
  }
  return parts.join(' · ');
}

/// A small local marker for country codes. Regional indicator glyphs are
/// rendered by the platform emoji font; the code remains available as a
/// readable fallback beside the marker.
class CountryFlag extends StatelessWidget {
  const CountryFlag({required this.countryCode, this.size = 18, super.key});

  final String? countryCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    final code = countryCode?.trim().toUpperCase() ?? '';
    final valid = RegExp(r'^[A-Z]{2}$').hasMatch(code);
    final glyph = valid
        ? String.fromCharCodes(
            code.codeUnits.map((unit) => 0x1f1e6 + unit - 65),
          )
        : '🌐';
    return Semantics(
      label: valid ? 'Country $code' : 'Unknown country',
      child: SizedBox(
        width: size + 4,
        height: size + 4,
        child: Center(
          child: Text(
            glyph,
            style: TextStyle(fontSize: size, height: 1),
            textScaler: TextScaler.noScaling,
          ),
        ),
      ),
    );
  }
}

enum VisitorPlatformKind { browser, operatingSystem, device }

/// Brand-colored, bundled platform marks with a stable generic fallback.
class VisitorPlatformMark extends StatelessWidget {
  const VisitorPlatformMark({
    required this.kind,
    required this.value,
    this.size = 22,
    super.key,
  });

  final VisitorPlatformKind kind;
  final String value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalized = value.trim().toLowerCase();
    final mark = _platformMark(kind, normalized);
    final isChrome =
        kind == VisitorPlatformKind.browser && normalized.contains('chrome');
    return Tooltip(
      message: value,
      child: Semantics(
        label: value,
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: mark.color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(size * .28),
            ),
            child: Center(
              child: isChrome
                  ? CustomPaint(
                      size: Size.square(size * .76),
                      painter: const _ChromeMarkPainter(),
                    )
                  : mark.glyph != null
                  ? Text(
                      mark.glyph!,
                      style: TextStyle(
                        color: mark.color,
                        fontSize: size * .47,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    )
                  : Icon(mark.icon, color: mark.color, size: size * .66),
            ),
          ),
        ),
      ),
    );
  }
}

({Color color, IconData? icon, String? glyph}) _platformMark(
  VisitorPlatformKind kind,
  String value,
) {
  if (kind == VisitorPlatformKind.browser) {
    if (value.contains('chrome')) {
      return (
        color: const Color(0xff4285f4),
        icon: Icons.language,
        glyph: null,
      );
    }
    if (value.contains('firefox')) {
      return (
        color: const Color(0xffe66000),
        icon: Icons.local_fire_department,
        glyph: null,
      );
    }
    if (value.contains('safari')) {
      return (color: const Color(0xff168cf2), icon: Icons.explore, glyph: null);
    }
    if (value.contains('edge')) {
      return (
        color: const Color(0xff087e8b),
        icon: Icons.change_circle,
        glyph: null,
      );
    }
    if (value.contains('opera')) {
      return (color: const Color(0xffe11b22), icon: null, glyph: 'O');
    }
    if (value.contains('brave')) {
      return (color: const Color(0xfff04b23), icon: Icons.shield, glyph: null);
    }
    if (value.contains('samsung')) {
      return (color: const Color(0xff1428a0), icon: null, glyph: 'S');
    }
    return (color: const Color(0xff54728f), icon: Icons.language, glyph: null);
  }
  if (kind == VisitorPlatformKind.operatingSystem) {
    if (value.contains('windows')) {
      return (color: const Color(0xff087cd8), icon: Icons.window, glyph: null);
    }
    if (value.contains('mac') ||
        value.contains('ios') ||
        value.contains('iphone') ||
        value.contains('ipad')) {
      return (color: const Color(0xff4b5158), icon: Icons.apple, glyph: null);
    }
    if (value.contains('android')) {
      return (color: const Color(0xff3b9b59), icon: Icons.android, glyph: null);
    }
    if (value.contains('linux') ||
        value.contains('ubuntu') ||
        value.contains('debian')) {
      return (
        color: const Color(0xffd07a20),
        icon: Icons.terminal,
        glyph: null,
      );
    }
    return (color: const Color(0xff54728f), icon: Icons.computer, glyph: null);
  }
  if (value.contains('mobile') || value.contains('phone')) {
    return (
      color: const Color(0xff2b8b7c),
      icon: Icons.smartphone,
      glyph: null,
    );
  }
  if (value.contains('tablet')) {
    return (color: const Color(0xff6b63a8), icon: Icons.tablet, glyph: null);
  }
  if (value.contains('desktop')) {
    return (
      color: const Color(0xff456e9d),
      icon: Icons.desktop_windows,
      glyph: null,
    );
  }
  return (
    color: const Color(0xff54728f),
    icon: Icons.devices_other,
    glyph: null,
  );
}

class _ChromeMarkPainter extends CustomPainter {
  const _ChromeMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    const colors = [Color(0xffea4335), Color(0xfffbbc05), Color(0xff34a853)];
    for (var index = 0; index < colors.length; index++) {
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          bounds,
          -math.pi / 2 + index * math.pi * 2 / 3,
          math.pi * 2 / 3,
          false,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = colors[index]);
    }
    canvas.drawCircle(center, radius * .33, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      radius * .23,
      Paint()..color = const Color(0xff4285f4),
    );
  }

  @override
  bool shouldRepaint(covariant _ChromeMarkPainter oldDelegate) => false;
}

typedef FaviconFetcher = Future<Uint8List?> Function(Uri uri);

/// Loads one raster favicon per normalized host and remembers both successful
/// and failed lookups for the lifetime of the process.
class ReferrerFavicon extends StatelessWidget {
  const ReferrerFavicon({
    required this.host,
    this.size = 20,
    this.fetcher,
    super.key,
  });

  final String host;
  final double size;
  final FaviconFetcher? fetcher;

  @override
  Widget build(BuildContext context) {
    final normalized = ReferrerFaviconCache.normalizeHost(host);
    final initial = host.trim().isEmpty ? '?' : host.trim()[0].toUpperCase();
    if (normalized == null) return _fallback(initial);
    return FutureBuilder<Uint8List?>(
      future: ReferrerFaviconCache.load(normalized, fetcher: fetcher),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return _fallback(initial);
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * .22),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => _fallback(initial),
          ),
        );
      },
    );
  }

  Widget _fallback(String initial) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xffe8eff7),
        borderRadius: BorderRadius.circular(size * .22),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: const Color(0xff315e87),
            fontSize: size * .56,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    ),
  );
}

class ReferrerFaviconCache {
  ReferrerFaviconCache._();

  static const _maxBytes = 256 * 1024;
  static const _maxEntries = 160;
  static final Map<String, Future<Uint8List?>> _cache = {};

  @visibleForTesting
  static FaviconFetcher? fetcherOverrideForTest;

  @visibleForTesting
  static bool validateRasterForTest(Uint8List bytes) => _validateRaster(bytes);

  @visibleForTesting
  static void clearForTest() => _cache.clear();

  static String? normalizeHost(String input) {
    final host = input.trim().toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    if (host.length > 253 ||
        !host.contains('.') ||
        host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.endsWith('.internal') ||
        host.endsWith('.test') ||
        host.endsWith('.example') ||
        host.endsWith('.invalid') ||
        host.endsWith('.arpa') ||
        RegExp(r'^[0-9.]+$').hasMatch(host) ||
        host.contains(':')) {
      return null;
    }
    final labels = host.split('.');
    if (labels.any(
      (label) =>
          label.isEmpty ||
          label.length > 63 ||
          !RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(label),
    )) {
      return null;
    }
    if (!RegExp(
      r'^(?:[a-z]{2,63}|xn--[a-z0-9-]{2,59})$',
    ).hasMatch(labels.last)) {
      return null;
    }
    return host;
  }

  static Future<Uint8List?> load(String host, {FaviconFetcher? fetcher}) {
    final normalized = normalizeHost(host);
    if (normalized == null) return Future.value(null);
    final cached = _cache.remove(normalized);
    if (cached != null) {
      _cache[normalized] = cached;
      return cached;
    }
    final uri = Uri.https(normalized, '/favicon.ico');
    final pending = (fetcher ?? fetcherOverrideForTest ?? _fetch)(uri);
    _cache[normalized] = pending;
    while (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    return pending;
  }

  static Future<Uint8List?> _fetch(Uri uri) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..headers['Accept'] =
            'image/png,image/jpeg,image/webp,image/gif,image/x-icon';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200 ||
          response.headers['location'] != null ||
          !_allowedContentType(response.headers['content-type'])) {
        return null;
      }
      final bytes = BytesBuilder(copy: false);
      var length = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 3),
      )) {
        length += chunk.length;
        if (length > _maxBytes) return null;
        bytes.add(chunk);
      }
      final raw = bytes.takeBytes();
      final result = _isIconMime(response.headers['content-type'])
          ? _extractPngFromIcon(raw)
          : raw;
      if (result == null) return null;
      return _validateRaster(result) ? result : null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static bool _allowedContentType(String? value) {
    final mime = value?.split(';').first.trim().toLowerCase();
    return const {
      'image/png',
      'image/jpeg',
      'image/webp',
      'image/gif',
      'image/x-icon',
      'image/vnd.microsoft.icon',
    }.contains(mime);
  }

  static bool _isIconMime(String? value) {
    final mime = value?.split(';').first.trim().toLowerCase();
    return mime == 'image/x-icon' || mime == 'image/vnd.microsoft.icon';
  }

  static Uint8List? _extractPngFromIcon(Uint8List bytes) {
    if (bytes.length < 22) return null;
    final header = ByteData.sublistView(bytes);
    if (header.getUint16(0, Endian.little) != 0 ||
        header.getUint16(2, Endian.little) != 1) {
      return null;
    }
    final count = header.getUint16(4, Endian.little);
    if (count == 0 || count > 32 || bytes.length < 6 + count * 16) {
      return null;
    }
    final entries = <({int area, int offset, int length})>[];
    for (var index = 0; index < count; index++) {
      final offset = 6 + index * 16;
      final width = bytes[offset] == 0 ? 256 : bytes[offset];
      final height = bytes[offset + 1] == 0 ? 256 : bytes[offset + 1];
      final length = header.getUint32(offset + 8, Endian.little);
      final dataOffset = header.getUint32(offset + 12, Endian.little);
      if (width > 256 ||
          height > 256 ||
          length == 0 ||
          dataOffset < 6 + count * 16 ||
          dataOffset + length > bytes.length) {
        continue;
      }
      entries.add((area: width * height, offset: dataOffset, length: length));
    }
    entries.sort((a, b) => b.area.compareTo(a.area));
    for (final entry in entries) {
      final image = Uint8List.sublistView(
        bytes,
        entry.offset,
        entry.offset + entry.length,
      );
      if (image.length >= 24 &&
          image[0] == 0x89 &&
          image[1] == 0x50 &&
          image[2] == 0x4e &&
          image[3] == 0x47) {
        return Uint8List.fromList(image);
      }
    }
    return null;
  }

  static bool _pngDimensionsExceedLimit(Uint8List bytes) {
    if (bytes.length < 24 ||
        bytes[0] != 0x89 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x4e ||
        bytes[3] != 0x47 ||
        bytes[4] != 0x0d ||
        bytes[5] != 0x0a ||
        bytes[6] != 0x1a ||
        bytes[7] != 0x0a) {
      return false;
    }
    final width = ByteData.sublistView(bytes).getUint32(16);
    final height = ByteData.sublistView(bytes).getUint32(20);
    return width == 0 || height == 0 || width > 256 || height > 256;
  }

  static bool _validateRaster(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > _maxBytes) return false;
    if (_isPng(bytes)) return !_pngDimensionsExceedLimit(bytes);
    if (bytes.length >= 10 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) &&
        bytes[5] == 0x61) {
      final width = bytes[6] | bytes[7] << 8;
      final height = bytes[8] | bytes[9] << 8;
      return width > 0 && height > 0 && width <= 256 && height <= 256;
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return _webpHasSafeDimensions(bytes);
    }
    return bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff &&
        _jpegHasSafeDimensions(bytes);
  }

  static bool _webpHasSafeDimensions(Uint8List bytes) {
    if (bytes.length < 30 ||
        bytes[12] != 0x56 ||
        bytes[13] != 0x50 ||
        bytes[14] != 0x38 ||
        bytes[15] != 0x58) {
      return false;
    }
    final width = 1 + bytes[24] + (bytes[25] << 8) + (bytes[26] << 16);
    final height = 1 + bytes[27] + (bytes[28] << 8) + (bytes[29] << 16);
    return width <= 256 && height <= 256;
  }

  static bool _jpegHasSafeDimensions(Uint8List bytes) {
    var offset = 2;
    while (offset + 4 <= bytes.length) {
      if (bytes[offset] != 0xff) return false;
      while (offset < bytes.length && bytes[offset] == 0xff) {
        offset++;
      }
      if (offset >= bytes.length) return false;
      final marker = bytes[offset++];
      if (marker == 0xd9 || marker == 0xda) return false;
      if (marker == 0xd8 ||
          marker == 0x01 ||
          (marker >= 0xd0 && marker <= 0xd7)) {
        continue;
      }
      if (offset + 2 > bytes.length) return false;
      final length = bytes[offset] << 8 | bytes[offset + 1];
      if (length < 2 || offset + length > bytes.length) return false;
      final isStartOfFrame =
          (marker >= 0xc0 && marker <= 0xc3) ||
          (marker >= 0xc5 && marker <= 0xc7) ||
          (marker >= 0xc9 && marker <= 0xcb) ||
          (marker >= 0xcd && marker <= 0xcf);
      if (isStartOfFrame) {
        if (length < 7) return false;
        final height = bytes[offset + 3] << 8 | bytes[offset + 4];
        final width = bytes[offset + 5] << 8 | bytes[offset + 6];
        return width > 0 && height > 0 && width <= 256 && height <= 256;
      }
      offset += length;
    }
    return false;
  }

  static bool _isPng(Uint8List bytes) =>
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a;
}
