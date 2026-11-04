import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/app/meet_shortcut.dart';
import 'package:rememberem/src/app/rememberem_app.dart';
import 'package:rememberem/src/capture/capture_screen.dart';
import 'package:rememberem/src/location/device_location.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem/src/memories/memory_list_screen.dart';
import 'package:rememberem/src/reminders/local_notifications_scheduler.dart';
import 'package:rememberem/src/reminders/reminder_coordinator.dart';
import 'package:rememberem/src/reminders/reminder_settings_store.dart';
import 'package:rememberem/src/reminders/reminders_section.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';
import 'fakes/fake_reminder_scheduler.dart';

class _NoFaces implements FaceLocator {
  @override
  Future<List<PixelRect>> findFaces(File photo) async => [];
}

class _MemoryStore implements ReminderSettingsStore {
  ReminderSettings? value;

  @override
  Future<ReminderSettings> load() async =>
      value ?? const ReminderSettings.defaults();

  @override
  Future<bool> hasSaved() async => value != null;

  @override
  Future<void> save(ReminderSettings settings) async => value = settings;
}

class _FakeShortcut extends MeetShortcut {
  void Function()? trigger;

  @override
  Future<void> install(void Function() onMeet) async => trigger = onMeet;
}

void main() {
  late FakeMemoryRepository repository;
  late FakeReminderScheduler scheduler;
  late _MemoryStore store;
  late ReminderCoordinator coordinator;

  /// 1 November 2026, before the morning notice.
  DateTime today() => DateTime(2026, 11, 1, 8);

  Future<void> person(String name, {DateTime? anniversary}) async {
    final m = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 1, 1),
      place: 'Stake Center',
      meeting: 'Sunday',
    );
    await repository.save(
      m.withField('name', name).withDetails([
        if (anniversary != null)
          Detail(
            id: '${m.id}-a',
            text: 'Loves cake',
            at: DateTime.utc(2026),
            type: DetailKind.anniversary,
            label: 'birthday',
            eventDate: anniversary,
          ),
      ]),
    );
  }

  /// Built in the calling zone, as in reminders_test.dart.
  void makeCoordinator() => coordinator = ReminderCoordinator(
    scheduler: scheduler,
    store: store,
    repository: repository,
    clock: today,
  );

  setUp(() {
    repository = FakeMemoryRepository();
    scheduler = FakeReminderScheduler();
    store = _MemoryStore();
    makeCoordinator();
  });

  final week = [for (var d = 13; d <= 20; d++) LocalDay(2026, 11, d)];

  group('coordinator', () {
    test('a notice on each day whose week has an anniversary', () async {
      await person('Ann', anniversary: DateTime(1990, 11, 20));
      await person('Bo');

      await coordinator.sync();

      expect(scheduler.notices, week);
    });

    test('each notice names who, and a rename reaches it', () async {
      await person('Ann', anniversary: DateTime(1990, 11, 20));

      await coordinator.sync();

      expect(
        scheduler.noticeTexts[const LocalDay(2026, 11, 13)],
        "Ann's birthday is next Friday.",
      );
      expect(
        scheduler.noticeTexts[const LocalDay(2026, 11, 20)],
        "Ann's birthday is today.",
      );

      final ann = repository.stored.values.single;
      await repository.save(ann.withField('name', 'Annie'));
      await coordinator.sync();
      expect(
        scheduler.noticeTexts[const LocalDay(2026, 11, 20)],
        "Annie's birthday is today.",
      );
    });

    test('someone in the trash is never named', () async {
      await person('Ann', anniversary: DateTime(1990, 11, 20));
      await person('Bo', anniversary: DateTime(1990, 11, 20));
      final bo = repository.stored.values.firstWhere(
        (m) => m.displayName == 'Bo',
      );
      await repository.trash(bo.id, DateTime(2026, 10, 1));

      await coordinator.sync();

      expect(scheduler.noticeTexts.values, everyElement(isNot(contains('Bo'))));
    });

    test('the debug buttons show the real notice and reminder now', () async {
      await person('Ann', anniversary: DateTime(1990, 11, 20));

      await coordinator.showAnniversaryNow(const LocalDay(2026, 11, 18));
      await coordinator.showReminderNow();

      expect(scheduler.shown, hasLength(2));
      expect(scheduler.shown.first.title, AnniversaryNotice.title);
      expect(scheduler.shown.first.body, "Ann's birthday is on Friday.");
      expect(scheduler.shown.first.payload, 'anniversaries:2026-11-18');
      expect(scheduler.shown.last.payload, PracticeGame.faces.wireId);
      expect(scheduler.shown.last.body, isNot(contains('Ann')));
    });

    test('no anniversaries, no notices', () async {
      await person('Ann');
      scheduler.notices = [const LocalDay(2026, 11, 2)];

      await coordinator.sync();

      expect(scheduler.notices, isEmpty);
    });

    test('notices off: none, and the practice reminder is untouched', () async {
      await person('Ann', anniversary: DateTime(1990, 11, 20));
      for (final n in ['Bo', 'Cy', 'Di']) {
        await person(n);
      }
      store.value = const ReminderSettings(
        enabled: true,
        hour: 19,
        minute: 0,
        anniversaries: false,
      );

      await coordinator.sync();

      expect(scheduler.notices, isEmpty);
      expect(scheduler.scheduled, (19, 0));
    });

    test('practice off: notices still come', () async {
      await person('Ann', anniversary: DateTime(1990, 11, 20));
      store.value = const ReminderSettings(
        enabled: false,
        hour: 19,
        minute: 0,
        anniversaries: true,
      );

      await coordinator.sync();

      expect(scheduler.notices, week);
      expect(scheduler.scheduled, isNull);
    });

    test('a permission taken away turns both off', () async {
      await person('Ann', anniversary: DateTime(1990, 11, 20));
      store.value = const ReminderSettings.defaults();
      await coordinator.sync();
      expect(scheduler.notices, week);
      scheduler.granted = false;

      await coordinator.sync();

      expect(store.value!.enabled, isFalse);
      expect(store.value!.anniversaries, isFalse);
      expect(scheduler.notices, isEmpty);
    });

    test('one ask answers both; a no turns both off', () async {
      scheduler.granted = false;

      await coordinator.askOnce();

      expect(scheduler.calls.where((c) => c == 'request'), hasLength(1));
      expect(store.value!.enabled, isFalse);
      expect(store.value!.anniversaries, isFalse);
    });

    test('refused when turning notices on: only notices stay off', () async {
      store.value = const ReminderSettings(
        enabled: true,
        hour: 19,
        minute: 0,
        anniversaries: false,
      );
      scheduler.granted = false;

      expect(await coordinator.setAnniversaries(true), EnableResult.denied);

      expect(store.value!.anniversaries, isFalse);
      expect(store.value!.enabled, isTrue);
    });

    test('turning notices on and off reschedules', () async {
      await person('Ann', anniversary: DateTime(1990, 11, 20));
      store.value = const ReminderSettings(
        enabled: false,
        hour: 19,
        minute: 0,
        anniversaries: false,
      );

      await coordinator.setAnniversaries(true);
      expect(scheduler.notices, week);

      await coordinator.setAnniversaries(false);
      expect(scheduler.notices, isEmpty);
    });
  });

  test('notices show nothing on a locked phone, and show all their words', () {
    final android = LocalNotificationsScheduler.noticeDetails.android!;
    expect(android.channelId, 'anniversaries_named');
    expect(android.visibility, NotificationVisibility.secret);
    expect(android.styleInformation, isA<BigTextStyleInformation>());
  });

  test('a renamed person changes the notices, so they are scheduled anew', () {
    final plan = AnniversaryNotice.plan([
      const LocalDay(2026, 11, 20),
    ], DateTime(2026, 11, 1));
    String key(String text) => LocalNotificationsScheduler.noticeKey(plan, {
      const LocalDay(2026, 11, 20): text,
    });
    expect(key("Ann's birthday is today."), key("Ann's birthday is today."));
    expect(
      key("Ann's birthday is today."),
      isNot(key("Annie's birthday is today.")),
    );
  });

  test("backup leaves out the plugin's store of scheduled notices", () {
    for (final file in [
      'android/app/src/main/res/xml/backup_rules.xml',
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ]) {
      final xml = File(file).readAsStringSync();
      expect(
        'path="scheduled_notifications.xml"'.allMatches(xml).length,
        file.contains('extraction') ? 2 : 1,
        reason: file,
      );
    }
  });

  test('the notice title names no one; its payload is only the day', () {
    expect(AnniversaryNotice.title, 'Anniversaries this week');
    expect(LocalNotificationsScheduler.noticeChannel, 'anniversaries_named');
    expect(
      AnniversaryNotice.wireId(const LocalDay(2026, 11, 13)),
      'anniversaries:2026-11-13',
    );
  });

  testWidgets('the switch turns notices off and on', (tester) async {
    await person('Ann', anniversary: DateTime(1990, 11, 20));
    store.value = const ReminderSettings.defaults();
    makeCoordinator();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RemindersSection(coordinator: coordinator),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.widgetWithText(SwitchListTile, 'Anniversary notices');
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(store.value!.anniversaries, isFalse);
    expect(scheduler.notices, isEmpty);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(store.value!.anniversaries, isTrue);
    expect(scheduler.notices, week);
  });

  group('tapping a notice', () {
    late _FakeShortcut shortcut;

    Future<void> boot(WidgetTester tester) async {
      makeCoordinator();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      shortcut = _FakeShortcut();
      await tester.pumpWidget(
        RememberemApp(
          services: AppServices(
            repository: repository,
            capture: PortraitCapture(
              repository: repository,
              faceLocator: _NoFaces(),
              workFolder: Directory.systemTemp,
            ),
            dictation: FakeDictation(),
            location: DeviceLocation(),
            reminders: coordinator,
          ),
          shortcut: shortcut,
        ),
      );
      await tester.pumpAndSettle();
    }

    final notice = AnniversaryNotice.wireId(const LocalDay(2026, 11, 15));

    Finder onList(String text) => find.descendant(
      of: find.byType(MemoryListScreen),
      matching: find.text(text),
    );

    /// The Anniversary filter's row on the list.
    Finder anniversaryRow() =>
        find.widgetWithText(InputDecorator, 'Anniversary');

    Future<void> twoPeople() async {
      await person('Ann', anniversary: DateTime(1990, 11, 20));
      await person('Bo', anniversary: DateTime(1990, 12, 25));
    }

    testWidgets('filters the list to that week', (tester) async {
      await twoPeople();
      await boot(tester);

      scheduler.emitPayload(notice);
      await tester.pumpAndSettle();

      expect(anniversaryRow(), findsOneWidget);
      expect(onList('Ann'), findsOneWidget);
      expect(onList('Bo'), findsNothing);
      expect(onList('1 person'), findsOneWidget);

      // A second tap does not add another filter.
      scheduler.emitPayload(notice);
      await tester.pumpAndSettle();
      expect(anniversaryRow(), findsOneWidget);
    });

    testWidgets('a newer notice replaces the filter', (tester) async {
      await twoPeople();
      await boot(tester);
      scheduler.emitPayload(notice);
      await tester.pumpAndSettle();

      scheduler.emitPayload(
        AnniversaryNotice.wireId(const LocalDay(2026, 12, 20)),
      );
      await tester.pumpAndSettle();

      expect(anniversaryRow(), findsOneWidget);
      expect(onList('Bo'), findsOneWidget);
      expect(onList('Ann'), findsNothing);
    });

    testWidgets('a notice over a card closes it onto the list', (tester) async {
      await twoPeople();
      await boot(tester);
      await tester.tap(find.text('Bo'));
      await tester.pumpAndSettle();
      expect(find.byType(MemoryEditScreen), findsOneWidget);

      scheduler.emitPayload(notice);
      await tester.pumpAndSettle();

      expect(find.byType(MemoryEditScreen), findsNothing);
      expect(onList('Ann'), findsOneWidget);
    });

    testWidgets('coming back to the list counts a new anniversary', (
      tester,
    ) async {
      await person('Ann');
      await boot(tester);
      await tester.tap(find.text('Ann'));
      await tester.pumpAndSettle();
      final ann = repository.stored.values.single;
      await repository.save(
        ann.withDetails([
          Detail(
            id: 'a',
            text: '',
            at: DateTime.utc(2026),
            type: DetailKind.anniversary,
            label: 'birthday',
            eventDate: DateTime(1990, 11, 20),
          ),
        ]),
      );
      expect(scheduler.notices, isEmpty);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(scheduler.notices, week);
    });

    testWidgets('from a cold start too; Clear all shows everyone', (
      tester,
    ) async {
      await twoPeople();
      scheduler.launch = notice;

      await boot(tester);

      expect(onList('Ann'), findsOneWidget);
      expect(onList('Bo'), findsNothing);
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(onList('Bo'), findsOneWidget);
    });

    testWidgets('a stale notice, with no one in its week, leaves the list', (
      tester,
    ) async {
      await person('Bo', anniversary: DateTime(1990, 12, 25));
      await boot(tester);

      scheduler.emitPayload(notice);
      await tester.pumpAndSettle();

      expect(anniversaryRow(), findsNothing);
      expect(onList('Bo'), findsOneWidget);
    });

    testWidgets('ignored for junk, and while the camera is open', (
      tester,
    ) async {
      await twoPeople();
      await boot(tester);
      scheduler.emitPayload('anniversaries:2026-13-01');
      await tester.pumpAndSettle();
      expect(anniversaryRow(), findsNothing);

      shortcut.trigger!();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      scheduler.emitPayload(notice);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CaptureScreen), findsOneWidget);
      expect(anniversaryRow(), findsNothing);
    });
  });
}
