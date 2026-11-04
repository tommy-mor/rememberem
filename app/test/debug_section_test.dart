import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/about/about_screen.dart';
import 'package:rememberem/src/about/debug_section.dart';
import 'package:rememberem/src/reminders/reminder_coordinator.dart';
import 'package:rememberem/src/reminders/reminder_settings_store.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_memory_repository.dart';
import 'fakes/fake_reminder_scheduler.dart';
import 'fakes/test_services.dart';

class _MemoryStore implements ReminderSettingsStore {
  @override
  Future<ReminderSettings> load() async => const ReminderSettings.defaults();

  @override
  Future<bool> hasSaved() async => false;

  @override
  Future<void> save(ReminderSettings settings) async {}
}

void main() {
  testWidgets('a debug build shows the debug controls on About, and they '
      'fire notices', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scheduler = FakeReminderScheduler();
    final coordinator = ReminderCoordinator(
      scheduler: scheduler,
      store: _MemoryStore(),
      repository: FakeMemoryRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AboutScreen(links: FakeLinkOpener(), reminders: coordinator),
      ),
    );

    // Tests run as a debug build.
    await tester.scrollUntilVisible(find.text('Practice reminder now'), 300);
    expect(find.byType(DebugSection), findsOneWidget);
    await tester.tap(find.text('Practice reminder now'));
    await tester.pump();
    expect(scheduler.shown.single.payload, PracticeGame.faces.wireId);

    await tester.tap(find.text('Anniversary notice for…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(scheduler.shown, hasLength(2));
    expect(scheduler.shown.last.body, 'No anniversaries this week.');
    // The day picked (today, the picker's start) is the notice's day.
    expect(
      scheduler.shown.last.payload,
      AnniversaryNotice.wireId(LocalDay.of(DateTime.now())),
    );
  });

  testWidgets('without reminders there are no debug controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AboutScreen(links: FakeLinkOpener())),
    );
    expect(find.byType(DebugSection), findsNothing);
  });
}
