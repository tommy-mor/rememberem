import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/app/rememberem_app.dart';
import 'package:rememberem/src/app/rememberem_theme.dart';
import 'package:rememberem/src/capture/photo_check.dart';
import 'package:rememberem/src/settings/settings_screen.dart';
import 'package:rememberem/src/settings/settings_section.dart';
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
    testWidgets('each section is a box with its title on the border, 30% '
        'larger', (tester) async {
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
          .widgetList<SettingsSection>(find.byType(SettingsSection))
          .map((s) => s.title)
          .toList();
      expect(titles, ['Display', 'Matching', 'Practice', 'Maps']);

      final context = tester.element(find.byType(SettingsSection).first);
      final base = Theme.of(context).textTheme.titleMedium!.fontSize!;
      final decorator = tester.widget<InputDecorator>(
        find
            .descendant(
              of: find.byType(SettingsSection).first,
              matching: find.byType(InputDecorator),
            )
            .first,
      );
      // Drawn at 3/4 of its style, as every floating label is.
      expect(
        decorator.decoration.floatingLabelStyle!.fontSize! * 0.75,
        closeTo(base * 1.3, 0.01),
      );
      expect(decorator.decoration.filled, isTrue);
      expect(decorator.decoration.enabledBorder, isA<OutlineInputBorder>());
      // Darker than the light page it sits on.
      final surface = Theme.of(context).colorScheme.surface;
      expect(
        decorator.decoration.fillColor!.computeLuminance(),
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
      final decorator = tester.widget<InputDecorator>(
        find
            .descendant(
              of: find.byType(SettingsSection).first,
              matching: find.byType(InputDecorator),
            )
            .first,
      );
      final page = Color(AppPalette.darkBackgrounds.first);
      final fill = decorator.decoration.fillColor!;
      expect(fill.computeLuminance(), greaterThan(page.computeLuminance()));
      expect(
        RememberemTheme.contrast(Colors.white, fill),
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

    testWidgets('Use photo is the big button; each button does its job', (
      tester,
    ) async {
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
      final use = tester.getSize(
        find.widgetWithText(FilledButton, 'Use photo'),
      );
      final retake = tester.getSize(
        find.widgetWithText(OutlinedButton, 'Retake'),
      );
      expect(use.width, greaterThan(retake.width));
      expect(use.height, greaterThanOrEqualTo(56));

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

    testWidgets('Show details adds dated details with their own words', (
      tester,
    ) async {
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
      expect(find.text('Library'), findsNothing);
      expect(find.textContaining('Book club'), findsNothing);
      // The box sits just before its label, with no explainer.
      final toggle = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(toggle.controlAffinity, ListTileControlAffinity.leading);
      expect(toggle.subtitle, isNull);

      await tester.tap(find.text('Show details'));
      await tester.pumpAndSettle();

      expect(services.timelineDetails.value, isTrue);
      expect(find.text('Library'), findsOneWidget);
      expect(
        find.text('Ann Lee – Tag · Book club: Hosts in June'),
        findsOneWidget,
      );
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
    });
  });
}
