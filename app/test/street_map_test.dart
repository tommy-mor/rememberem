import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/maps/street_map.dart';

import 'fakes/test_services.dart';

void main() {
  Future<FakeLinkOpener> showMap(WidgetTester tester, bool streetMaps) async {
    final links = FakeLinkOpener();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreetMap(
            streetMaps: streetMaps,
            markers: const [],
            links: links,
          ),
        ),
      ),
    );
    await tester.pump();
    return links;
  }

  testWidgets('street maps credit OpenStreetMap in view, linking its '
      'copyright page', (tester) async {
    final links = await showMap(tester, true);

    await tester.tap(find.text('OpenStreetMap contributors'));

    expect(links.opened, [StreetMap.copyright]);
  });

  testWidgets('a plain map fetches nothing and credits no one', (tester) async {
    await showMap(tester, false);

    expect(find.text('OpenStreetMap contributors'), findsNothing);
  });
}
