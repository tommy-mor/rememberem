import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/app/rememberem_app.dart';
import 'package:rememberem/src/app/rememberem_theme.dart';
import 'package:rememberem/src/app/section_header.dart';
import 'package:rememberem/src/capture/photo_check.dart';
import 'package:rememberem/src/settings/settings_screen.dart';
import 'package:rememberem/src/timeline/timeline_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('settings sections', () {
    testWidgets('each section is a tinted, capitalised header over its '
        'rows', (tester) async {
      phone(tester);
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

      final titles = tester
          .widgetList<SectionHeader>(find.byType(SectionHeader))
          .map((s) => s.title)
          .toList();
      expect(titles, ['Display', 'Matching', 'Practice', 'Maps']);
      expect(find.text('DISPLAY'), findsOneWidget);
      // No boxed sections, and so no local field theme.
      expect(find.byType(InputDecorator), findsNothing);

      final context = tester.element(find.byType(SectionHeader).first);
      final strip = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(SectionHeader).first,
              matching: find.byType(Container),
            )
            .first,
      );
      final surface = Theme.of(context).colorScheme.surface;
      // Darker than the light page it sits on.
      expect(
        (strip.color!).computeLuminance(),
        lessThan(surface.computeLuminance()),
      );
    });
  });

  group('backgrounds', () {
    test('body text reads on every background (4.5:1)', () {
      for (final value in AppPalette.backgrounds) {
        final settings = AppSettings(backgroundColor: value);
        final theme = settings.darkPages
            ? RememberemTheme.dark(settings)
            : RememberemTheme.light(settings);
        expect(
          theme.scaffoldBackgroundColor,
          Color(value),
          reason: AppPalette.names[value],
        );
        expect(
          RememberemTheme.contrast(
            theme.colorScheme.onSurface,
            theme.scaffoldBackgroundColor,
          ),
          greaterThanOrEqualTo(4.5),
          reason: AppPalette.names[value],
        );
      }
    });

    test('text in every theme colour reads on every light page and section '
        '(4.5:1)', () {
      for (final bg in AppPalette.backgrounds) {
        if (AppPalette.isDark(bg)) continue;
        final page = Color(bg);
        final section = Color.alphaBlend(
          RememberemTheme.light(AppSettings(backgroundColor: bg))
              .colorScheme
              .onSurface
              .withAlpha(12),
          page,
        );
        for (final c in AppPalette.themeColors) {
          for (final under in [page, section]) {
            expect(
              RememberemTheme.contrast(Color(c), under),
              greaterThanOrEqualTo(4.5),
              reason: '${AppPalette.names[c]} on ${AppPalette.names[bg]}',
            );
          }
        }
      }
    });

    test('an older forest or rust theme keeps its name', () {
      expect(
        AppSettings.fromJson({'themeColor': 0xFF2E7D32}).themeColor,
        0xFF1B5E20,
      );
      expect(
        AppSettings.fromJson({'themeColor': 0xFFB4532A}).themeColor,
        0xFF8F3A1C,
      );
    });

    testWidgets('on dark pages a section is lighter than the page', (
      tester,
    ) async {
      phone(tester);
      final services = testServices(
        FakeMemoryRepository(),
        settings: AppSettings(
          streetMaps: false,
          backgroundColor: AppPalette.darkBackgrounds.first,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: RememberemTheme.dark(services.settings.value),
          home: SettingsScreen(
            settings: services.settings,
            links: services.links,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final strip = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(SectionHeader).first,
              matching: find.byType(Container),
            )
            .first,
      );
      final page = Color(AppPalette.darkBackgrounds.first);
      final fill = strip.color!;
      expect(fill.computeLuminance(), greaterThan(page.computeLuminance()));
      // The overline reads on the strip.
      expect(
        RememberemTheme.contrast(
          Theme.of(tester.element(find.byType(SectionHeader).first))
              .colorScheme
              .onSurfaceVariant,
          fill,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('choosing a dark background makes the whole app dark', (
      tester,
    ) async {
      final services = testServices(
        FakeMemoryRepository(),
        settings: AppSettings(
          streetMaps: false,
          backgroundColor: AppPalette.darkBackgrounds.first,
        ),
      );
      await tester.pumpWidget(RememberemApp(services: services));
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(
        app.darkTheme!.scaffoldBackgroundColor,
        Color(AppPalette.darkBackgrounds.first),
      );
    });
  });

  group('photo check', () {
    // A 1x1 grey JPEG.
    final jpeg = Uint8List.fromList(const [
      0xFF,
      0xD8,
      0xFF,
      0xDB,
      0x00,
      0x43,
      0x00,
      0x08,
      0x06,
      0x06,
      0x07,
      0x06,
      0x05,
      0x08,
      0x07,
      0x07,
      0x07,
      0x09,
      0x09,
      0x08,
      0x0A,
      0x0C,
      0x14,
      0x0D,
      0x0C,
      0x0B,
      0x0B,
      0x0C,
      0x19,
      0x12,
      0x13,
      0x0F,
      0x14,
      0x1D,
      0x1A,
      0x1F,
      0x1E,
      0x1D,
      0x1A,
      0x1C,
      0x1C,
      0x20,
      0x24,
      0x2E,
      0x27,
      0x20,
      0x22,
      0x2C,
      0x23,
      0x1C,
      0x1C,
      0x28,
      0x37,
      0x29,
      0x2C,
      0x30,
      0x31,
      0x34,
      0x34,
      0x34,
      0x1F,
      0x27,
      0x39,
      0x3D,
      0x38,
      0x32,
      0x3C,
      0x2E,
      0x33,
      0x34,
      0x32,
      0xFF,
      0xD9,
    ]);

    testWidgets('Use photo is the gold button on the right; each button does '
        'its job', (tester) async {
      var used = 0;
      var retaken = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoCheck(
              jpeg: jpeg,
              onUse: () => used++,
              onRetake: () => retaken++,
            ),
          ),
        ),
      );
      final use = find.widgetWithText(FilledButton, 'Use photo');
      final retake = find.widgetWithText(TextButton, 'Retake');
      expect(tester.getCenter(retake).dx, lessThan(tester.getCenter(use).dx));
      expect(tester.getSize(use).height, greaterThanOrEqualTo(46));
      expect(tester.getSize(retake).height, greaterThanOrEqualTo(48));
      expect(
        tester.widget<FilledButton>(use).style?.backgroundColor?.resolve({}),
        RememberemTheme.gold,
      );

      await tester.tap(find.text('Retake'));
      await tester.tap(find.text('Use photo'));
      expect([used, retaken], [1, 1]);
    });
  });

  group('timeline details', () {
    late FakeMemoryRepository repository;
    late AppServices services;

    setUp(() async {
      repository = FakeMemoryRepository();
      services = testServices(repository);
      final m = await repository.add(
        photoJpeg: [],
        capturedAt: DateTime(2026, 10, 1, 12),
        place: 'Cafe',
      );
      await repository.save(
        m.withField('name', 'Ann Lee').withDetails([
          Detail(
            id: 't',
            text: 'Hosts in June',
            at: DateTime.utc(2026),
            type: DetailKind.tag,
            label: 'book club',
            eventDate: DateTime(2026, 9, 5),
            place: 'Library',
          ),
        ]),
      );
    });

    Future<void> showTimeline(WidgetTester tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: TimelineScreen(
            services: services,
            routeObserver: RouteObserver<ModalRoute<void>>(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the Details switch adds dated details with their own words, '
        'and takes them away again', (tester) async {
      await showTimeline(tester);
      expect(find.text('Library'), findsNothing);
      expect(find.textContaining('Book club'), findsNothing);
      // An icon and the visible word, in the bar; no checkbox row.
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Details'),
        ),
        findsOneWidget,
      );
      expect(
        find.byIcon(Icons.check_box_outline_blank_rounded),
        findsOneWidget,
      );

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(services.timelineDetails.value, isTrue);
      expect(find.text('Library'), findsOneWidget);
      expect(
        find.text('Ann Lee – Tag · Book club: Hosts in June'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(services.timelineDetails.value, isFalse);
      expect(find.text('Library'), findsNothing);
      expect(find.textContaining('Book club'), findsNothing);
    });

    testWidgets('the switch says Details, and whether it is on', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await showTimeline(tester);

      expect(
        tester.getSemantics(find.text('Details')),
        matchesSemantics(
          label: 'Details',
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
          hasEnabledState: false,
        ),
      );
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Details')),
        matchesSemantics(
          label: 'Details',
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
