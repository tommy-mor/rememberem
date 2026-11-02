import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/rememberem_app.dart';
import 'package:rememberem/src/settings/app_settings_controller.dart';
import 'package:rememberem/src/settings/file_settings_store.dart';
import 'package:rememberem/src/settings/settings_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

void main() {
  group('file store', () {
    late Directory temp;
    late File file;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('rememberem_settings_');
      file = File('${temp.path}/settings.json');
    });
    tearDown(() => temp.delete(recursive: true));

    test('starts at the defaults and round-trips', () async {
      final store = FileSettingsStore(file);
      expect(await store.load(), const AppSettings());

      const changed = AppSettings(gameTurns: 6, sounds: false);
      await store.save(changed);
      expect(await store.load(), changed);
      expect(File('${file.path}.tmp').existsSync(), isFalse);
    });

    test('garbage, empty, an array or wrong types give the defaults', () async {
      final store = FileSettingsStore(file);
      for (final content in ['{oops', '', '[1, 2]', '{"gameTurns": "x"}']) {
        await file.writeAsString(content);
        expect(await store.load(), const AppSettings(), reason: content);
      }
    });
  });

  testWidgets('steppers change settings at once and stop at their limits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = AppSettingsController(const AppSettings(gameTurns: 19));
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(settings: controller)),
    );

    final turns = find.ancestor(
      of: find.text('Questions per game'),
      matching: find.byType(ListTile),
    );
    final more = find.descendant(of: turns, matching: find.byTooltip('More'));
    await tester.tap(more);
    await tester.pump();
    expect(controller.value.gameTurns, 20);
    expect(find.text('20'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(of: more, matching: find.byType(IconButton)),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.widgetWithText(SwitchListTile, 'Sounds'));
    await tester.pump();
    expect(controller.value.sounds, isFalse);
  });

  testWidgets('dark mode, colours and detail text size apply to the whole '
      'app at once', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final services = testServices(FakeMemoryRepository());
    final controller = services.settings;
    await tester.pumpWidget(RememberemApp(services: services));
    await tester.pumpAndSettle();
    MaterialApp app() => tester.widget(find.byType(MaterialApp));
    expect(app().themeMode, ThemeMode.light);
    expect(
      app().theme!.scaffoldBackgroundColor,
      const Color(0xFFE9EEFC), // light blue, the logo's hue
    );

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Dark mode'));
    await tester.pumpAndSettle();
    expect(controller.value.darkMode, isTrue);
    expect(app().themeMode, ThemeMode.dark);

    await tester.tap(find.byTooltip('Teal'));
    await tester.pumpAndSettle();
    expect(controller.value.themeColor, 0xFF00695C);
    expect(app().theme!.colorScheme.primary, const Color(0xFF00695C));

    final size = find.ancestor(
      of: find.text('Detail text size'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: size, matching: find.text('80 %')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: size, matching: find.byTooltip('More')),
    );
    await tester.pump();
    expect(controller.value.detailTextPercent, 90);
  });
}
