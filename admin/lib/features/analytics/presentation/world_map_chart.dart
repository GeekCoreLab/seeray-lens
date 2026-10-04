import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_i18n.dart';

class WorldMapChart extends StatefulWidget {
  const WorldMapChart({
    required this.sessionsByCountry,
    required this.onCountrySelected,
    this.visitorsByCountry = const {},
    this.countryLabels = const {},
    this.selectedCountryCode,
    super.key,
  });

  final Map<String, int> sessionsByCountry;
  final Map<String, int> visitorsByCountry;
  final Map<String, String> countryLabels;
  final ValueChanged<String> onCountrySelected;
  final String? selectedCountryCode;

  @override
  State<WorldMapChart> createState() => _WorldMapChartState();
}

class _WorldMapChartState extends State<WorldMapChart> {
  static final Future<List<_CountryShape>> _shapes = _loadShapes();
  String? _hoveredCountryCode;
  Size? _cachedSize;
  List<_CountryPath>? _cachedPaths;

  static Future<List<_CountryShape>> _loadShapes() async {
    final bytes = await rootBundle.load('assets/maps/world-countries.json');
    final source = utf8.decode(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    final json = jsonDecode(source) as Map<String, dynamic>;
    return (json['features'] as List)
        .whereType<Map>()
        .map((feature) => _CountryShape.fromJson(feature))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<_CountryShape>>(
    future: _shapes,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return SizedBox(
          height: 220,
          child: Center(
            child: Text(
              context.tr('World map data could not be loaded.', '无法加载世界地图数据。'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final shapes = snapshot.data!;
      final maxSessions = widget.sessionsByCountry.values.fold<int>(
        0,
        math.max,
      );
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxWidth / 2);
          final paths = _pathsFor(shapes, size);
          return MouseRegion(
            onHover: (event) {
              final country = _hitTest(paths, event.localPosition);
              if (country?.code != _hoveredCountryCode) {
                setState(() => _hoveredCountryCode = country?.code);
              }
            },
            onExit: (_) => setState(() => _hoveredCountryCode = null),
            child: GestureDetector(
              key: const Key('world-country-map'),
              behavior: HitTestBehavior.opaque,
              onTapUp: (event) {
                final country = _hitTest(paths, event.localPosition);
                if (country != null &&
                    widget.sessionsByCountry.containsKey(country.code)) {
                  widget.onCountrySelected(country.code);
                }
              },
              child: Semantics(
                label: context.tr(
                  'Interactive world map. Hover or tap a shaded country for visits.',
                  '可交互世界地图。悬停或点击有数据的国家查看访问量。',
                ),
                child: SizedBox.fromSize(
                  size: size,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _WorldMapPainter(
                          paths: paths,
                          sessionsByCountry: widget.sessionsByCountry,
                          maxSessions: maxSessions,
                          selectedCountryCode: widget.selectedCountryCode,
                          hoveredCountryCode: _hoveredCountryCode,
                        ),
                      ),
                      if (_hoveredCountryCode case final code?)
                        Positioned(
                          left: 10,
                          top: 10,
                          child: IgnorePointer(
                            child: _MapTooltip(
                              code: code,
                              label: widget.countryLabels[code] ?? code,
                              sessions: widget.sessionsByCountry[code] ?? 0,
                              visitors: widget.visitorsByCountry[code] ?? 0,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  _CountryShape? _hitTest(List<_CountryPath> paths, Offset position) {
    for (final countryPath in paths.reversed) {
      if (countryPath.path.contains(position)) return countryPath.country;
    }
    return null;
  }

  List<_CountryPath> _pathsFor(List<_CountryShape> shapes, Size size) {
    if (_cachedSize == size && _cachedPaths != null) return _cachedPaths!;
    final paths = [
      for (final country in shapes)
        _CountryPath(country: country, path: country.path(size)),
    ];
    _cachedSize = size;
    _cachedPaths = paths;
    return paths;
  }
}

class _MapTooltip extends StatelessWidget {
  const _MapTooltip({
    required this.code,
    required this.label,
    required this.sessions,
    required this.visitors,
  });

  final String code;
  final String label;
  final int sessions;
  final int visitors;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xee18364f),
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(
          color: Color(0x26000000),
          blurRadius: 12,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label · $code',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${sessions.toString()} ${context.tr('visits', '次访问')}  ·  ${visitors.toString()} ${context.tr('visitors', '位访客')}',
            style: const TextStyle(color: Color(0xffd7e6f3), fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _CountryShape {
  const _CountryShape({required this.code, required this.rings});

  final String code;
  final List<List<Offset>> rings;

  factory _CountryShape.fromJson(Map feature) {
    final properties = Map<String, dynamic>.from(feature['properties'] as Map);
    final geometry = Map<String, dynamic>.from(feature['geometry'] as Map);
    final coordinates = geometry['coordinates'] as List;
    final polygons = switch (geometry['type']) {
      'Polygon' => [coordinates],
      'MultiPolygon' => coordinates,
      _ => const [],
    };
    final rings = <List<Offset>>[];
    for (final polygon in polygons) {
      if (polygon is! List || polygon.isEmpty || polygon.first is! List) {
        continue;
      }
      final points = <Offset>[];
      for (final point in polygon.first as List) {
        if (point is List && point.length >= 2) {
          final longitude = (point[0] as num).toDouble();
          final latitude = (point[1] as num).toDouble();
          if (longitude.isFinite && latitude.isFinite) {
            points.add(Offset(longitude, latitude));
          }
        }
      }
      if (points.length >= 3) rings.add(points);
    }
    return _CountryShape(code: properties['code'] as String, rings: rings);
  }

  Path path(Size size) {
    final path = Path();
    for (final ring in rings) {
      var started = false;
      double? lastLongitude;
      for (final point in ring) {
        final longitude = point.dx;
        final latitude = point.dy;
        final projected = Offset(
          (longitude + 180) / 360 * size.width,
          (90 - latitude) / 180 * size.height,
        );
        if (!started ||
            lastLongitude != null && (longitude - lastLongitude).abs() > 180) {
          if (started) path.close();
          path.moveTo(projected.dx, projected.dy);
          started = true;
        } else {
          path.lineTo(projected.dx, projected.dy);
        }
        lastLongitude = longitude;
      }
      if (started) path.close();
    }
    return path;
  }
}

class _CountryPath {
  const _CountryPath({required this.country, required this.path});

  final _CountryShape country;
  final Path path;
}

class _WorldMapPainter extends CustomPainter {
  const _WorldMapPainter({
    required this.paths,
    required this.sessionsByCountry,
    required this.maxSessions,
    required this.selectedCountryCode,
    required this.hoveredCountryCode,
  });

  final List<_CountryPath> paths;
  final Map<String, int> sessionsByCountry;
  final int maxSessions;
  final String? selectedCountryCode;
  final String? hoveredCountryCode;

  static const _water = Color(0xfff1f6fb);
  static const _land = Color(0xffdce5ee);
  static const _low = Color(0xffcfe0f1);
  static const _high = Color(0xff245f98);
  static const _border = Color(0xffaab8c6);
  static const _selected = Color(0xffff9c4a);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _water);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .55
      ..color = _border
      ..isAntiAlias = true;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final countryPath in paths) {
      final code = countryPath.country.code;
      final path = countryPath.path;
      final sessions = sessionsByCountry[code] ?? 0;
      final baseColor = _countryColor(sessions);
      fill.color = code == selectedCountryCode
          ? Color.lerp(baseColor, _selected.withValues(alpha: .55), .55)!
          : code == hoveredCountryCode
          ? Color.lerp(baseColor, _high.withValues(alpha: .5), .42)!
          : baseColor;
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
      if (code == selectedCountryCode || code == hoveredCountryCode) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = code == selectedCountryCode ? 1.8 : 1.45
            ..color = code == selectedCountryCode
                ? _selected
                : const Color(0xff315e87)
            ..isAntiAlias = true,
        );
      }
    }
  }

  Color _countryColor(int sessions) {
    if (sessions <= 0 || maxSessions <= 0) return _land;
    final ratio = math.log(sessions + 1) / math.log(maxSessions + 1);
    return Color.lerp(_low, _high, ratio.clamp(0.0, 1.0))!;
  }

  @override
  bool shouldRepaint(covariant _WorldMapPainter oldDelegate) =>
      !identical(paths, oldDelegate.paths) ||
      !identical(sessionsByCountry, oldDelegate.sessionsByCountry) ||
      maxSessions != oldDelegate.maxSessions ||
      selectedCountryCode != oldDelegate.selectedCountryCode ||
      hoveredCountryCode != oldDelegate.hoveredCountryCode;
}
