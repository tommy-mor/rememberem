import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/about/about_screen.dart';
import 'package:rememberem/src/places/place_notice_consent.dart';
import 'package:rememberem/src/settings/app_settings_controller.dart';
import 'package:rememberem/src/settings/colour_choice.dart';
import 'package:rememberem/src/settings/setting_stepper.dart';
import 'package:rememberem/src/settings/settings_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

void main() {
  void phone(WidgetTester tester, {Size size = const Size(360, 2400)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<AppSettingsController> settingsPage(WidgetTester tester) async {
    final services = testServices(FakeMemoryRepository());
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          settings: services.settings,
          links: services.links,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return services.settings;
  }

  group('Settings', () {
    testWidgets('a stepper is one pill: 48 dp buttons round a value at '
        'least 64 dp wide', (tester) async {
      phone(tester);
      await settingsPage(tester);
      final stepper = find.ancestor(
        of: find.text('Questions per game'),
        matching: find.byType(SettingStepper),
      );
      for (final tip in ['Less', 'More']) {
        final size = tester.getSize(
          find.descendant(of: stepper, matching: find.byTooltip(tip)),
        );
        expect(size.width, greaterThanOrEqualTo(48), reason: tip);
        expect(size.height, greaterThanOrEqualTo(48), reason: tip);
      }
      final value = find.descendant(of: stepper, matching: find.text('10'));
      final box = find.ancestor(
        of: value,
        matching: find.byType(ConstrainedBox),
      );
      expect(tester.getSize(box.first).width, greaterThanOrEqualTo(64));
      expect(tester.widget<Text>(value).style!.fontWeight, FontWeight.w800);
    });

    testWidgets('colour swatches are 32 dp with 48 dp tap areas, the chosen '
        'one ticked, and they wrap', (tester) async {
      phone(tester, size: const Size(320, 2400));
      await settingsPage(tester);
      final background = find.ancestor(
        of: find.text('Background'),
        matching: find.byType(ColourChoice),
      );
      final swatches = find.descendant(
        of: background,
        matching: find.byType(InkResponse),
      );
      expect(swatches, findsNWidgets(AppPalette.backgrounds.length));
      expect(tester.getSize(swatches.first), const Size(48, 48));
      // Wrapped onto more than one row on a 320 dp phone.
      final rows = {
        for (var i = 0; i < AppPalette.backgrounds.length; i++)
          tester.getTopLeft(swatches.at(i)).dy,
      };
      expect(rows.length, greaterThan(1));
      // The 48 dp tap areas of one row do not touch the next row's.
      final tops = rows.toList()..sort();
      expect(tops[1] - tops[0], greaterThanOrEqualTo(48 + 8));
      // Only the chosen one carries a tick.
      final ticks = find.descendant(
        of: background,
        matching: find.byIcon(Icons.check_rounded),
      );
      expect(ticks, findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.byTooltip('Light blue'),
            matching: find.byType(Tooltip),
          ),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a swatch can be tapped by a screen reader', (tester) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      final settings = await settingsPage(tester);
      tester.semantics.tap(find.semantics.byLabel('Teal'));
      await tester.pump();
      expect(settings.value.themeColor, 0xFF005B4F);
      handle.dispose();
    });

    testWidgets('the Street maps privacy note is shown whole', (tester) async {
      phone(tester, size: const Size(320, 2400));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await settingsPage(tester);
      final note = find.textContaining(
        'Fetches map pictures from OpenStreetMap',
      );
      // The list builds rows as they come into view.
      for (var i = 0; i < 40 && note.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pump();
      }
      expect(note, findsOneWidget);
      final text = tester.widget<Text>(note);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
      expect(
        text.data,
        'Fetches map pictures from OpenStreetMap, which sees the area '
        'you are looking at. Off shows places on a blank map.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('switch rows have a 15 sp bold title', (tester) async {
      phone(tester);
      await settingsPage(tester);
      final style = tester
          .widget<DefaultTextStyle>(
            find
                .ancestor(
                  of: find.text('Sounds'),
                  matching: find.byType(DefaultTextStyle),
                )
                .first,
          )
          .style;
      expect(style.fontSize, 15);
      expect(style.fontWeight, FontWeight.w700);
    });

    testWidgets('About is the last row, with a chevron', (tester) async {
      phone(tester);
      await settingsPage(tester);
      final about = find.widgetWithText(ListTile, 'About Rememberem');
      expect(
        find.descendant(
          of: about,
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsOneWidget,
      );
      final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(tester.widget<ListTile>(about), same(tiles.last));
    });
  });

  group('About', () {
    testWidgets('links are rows with open_in_new, and the data text sits '
        'under YOUR DATA', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(home: AboutScreen(links: FakeLinkOpener())),
      );
      for (final title in ['ericjorgensen.com', 'Privacy questions']) {
        expect(
          find.descendant(
            of: find.widgetWithText(ListTile, title),
            matching: find.byIcon(Icons.open_in_new_rounded),
          ),
          findsOneWidget,
          reason: title,
        );
      }
      expect(find.text('YOUR DATA'), findsOneWidget);
      final first = find.textContaining('private storage');
      expect(
        tester.widget<Text>(first).style!.fontSize,
        Theme.of(tester.element(first)).textTheme.bodyMedium!.fontSize,
      );
    });
  });

  group('Place notices consent', () {
    // The words as they were before the ledger polish: the page's look
    // changed, its wording must not.
    const before = [
      'Rememberem uses your location in the background, even when the app '
          'is closed or not in use, to notice when you arrive at a place where '
          'you have met people, and tells you who.',
      "Your phone's own location service watches the places you have named "
          '(on Android, through Google Play services). Rememberem never sends '
          'your location anywhere; it stays on this phone.',
      'On the next screen, choose "Allow all the time". You can turn place '
          'notices off in Settings whenever you like.',
    ];

    testWidgets('every string is as it was', (tester) async {
      phone(tester, size: const Size(360, 1600));
      await tester.pumpWidget(const MaterialApp(home: PlaceNoticeConsent()));
      expect(PlaceNoticeConsent.paragraphs, before);
      final shown = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      expect(
        shown,
        unorderedEquals([
          'Place notices',
          'Location in the background',
          ...before,
          'No thanks',
          'Allow',
        ]),
      );
    });

    testWidgets('the title is 21 sp bold, and the buttons sit in a bar '
        'below the scrolling text: "No thanks" left and 48 dp tall, "Allow" '
        'gold on the right', (tester) async {
      phone(tester, size: const Size(360, 640));
      await tester.pumpWidget(const MaterialApp(home: PlaceNoticeConsent()));
      final title = tester.widget<Text>(
        find.text('Location in the background'),
      );
      expect(title.style!.fontSize, 21);
      expect(title.style!.fontWeight, FontWeight.w800);

      final no = find.widgetWithText(OutlinedButton, 'No thanks');
      final yes = find.widgetWithText(FilledButton, 'Allow');
      expect(tester.getSize(no).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(yes).height, greaterThanOrEqualTo(46));
      expect(tester.getTopLeft(no).dx, lessThan(tester.getTopLeft(yes).dx));
      expect(
        tester.getBottomLeft(find.byType(ListView)).dy,
        lessThanOrEqualTo(tester.getTopLeft(no).dy),
      );
    });
  });
}
