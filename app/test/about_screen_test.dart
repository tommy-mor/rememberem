import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/about/about_screen.dart';

import 'fakes/test_services.dart';

void main() {
  testWidgets('About says where people are kept, including the Google '
      'backup, and links the privacy policy and licences', (tester) async {
    final links = FakeLinkOpener();
    await tester.pumpWidget(MaterialApp(home: AboutScreen(links: links)));

    expect(find.text('YOUR DATA'), findsOneWidget);
    expect(find.textContaining('backs up to Google'), findsOneWidget);

    await tester.tap(find.text('Privacy questions'));
    await tester.pump();
    expect(links.opened.single.toString(), 'mailto:rememberem@niftibits.com');
    links.opened.clear();

    await tester.scrollUntilVisible(find.text('Privacy policy'), 200);
    await tester.tap(find.text('Privacy policy'));
    await tester.pump();
    expect(links.opened, [AboutScreen.privacy]);
    expect(find.textContaining('people you photograph'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Licences'), 200);
    await tester.tap(find.text('Licences'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
