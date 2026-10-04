import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeray_lens_admin/features/analytics/presentation/world_map_chart.dart';

void main() {
  testWidgets('map hover shows totals and tap selects a country', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 720,
            child: WorldMapChart(
              sessionsByCountry: const {'US': 14, 'JP': 5},
              visitorsByCountry: const {'US': 9, 'JP': 3},
              countryLabels: const {'US': 'United States'},
              onCountrySelected: (code) => selected = code,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final map = find.byKey(const Key('world-country-map'));
    expect(map, findsOneWidget);
    final origin = tester.getTopLeft(map);
    final size = tester.getSize(map);
    final countryPoint =
        origin + Offset(size.width * (80 / 360), size.height * (50 / 180));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(countryPoint);
    await tester.pump();
    expect(find.text('United States · US'), findsOneWidget);
    expect(find.textContaining('14 visits'), findsOneWidget);
    await gesture.moveTo(Offset.zero);
    await tester.pump();
    await gesture.removePointer();

    await tester.tapAt(countryPoint);
    expect(selected, 'US');
  });
}
