import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/app/meet_shortcut.dart';
import 'package:rememberem/src/app/rememberem_app.dart';
import 'package:rememberem/src/capture/capture_screen.dart';
import 'package:rememberem/src/location/device_location.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem/src/practice/face_game_screen.dart';
import 'package:rememberem/src/reminders/file_reminder_settings_store.dart';
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
  /// Null until something is saved.
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

/// all() can be held open or made to fail.
class _ControlledRepository extends FakeMemoryRepository {
  Completer<void>? hold;
  bool fail = false;

  @override
  Future<List<Memory>> all() async {
    final wait = hold;
    if (wait != null) await wait.future;
    if (fail) throw const FormatException('corrupt');
    return super.all();
  }
}

void main() {
  late _ControlledRepository repository;
  late FakeReminderScheduler scheduler;
  late _MemoryStore store;
  late ReminderCoordinator coordinator;

  Future<void> people(List<String> names) async {
    for (final (i, name) in names.indexed) {
      final m = await repository.add(
        photoJpeg: [],
        capturedAt: DateTime(2026, 10, i + 1),
        place: 'Stake Center',
        meeting: 'Sunday',
      );
      await repository.save(
        m.withField('name', name).withDetails([
          Detail(
            id: '${m.id}-d',
            text: 'Sings in the choir',
            at: DateTime.utc(2026),
          ),
        ]),
      );
    }
  }

  /// Builds the coordinator in the calling zone: a widget test's fake
  /// time cannot run work queued from a zone made in setUp.
  void makeCoordinator() => coordinator = ReminderCoordinator(
    scheduler: scheduler,
    store: store,
    repository: repository,
  );

  setUp(() {
    repository = _ControlledRepository();
    scheduler = FakeReminderScheduler();
    store = _MemoryStore();
    makeCoordinator();
  });

  group('coordinator', () {
    test('enabling at 19:00 schedules once; changing time replaces it; '
        'disabling cancels', () async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);

      expect(await coordinator.setEnabled(true), EnableResult.enabled);
      expect(scheduler.calls.where((c) => c.startsWith('schedule')), [
        'schedule 19:0',
      ]);

      await coordinator.setTime(7, 30);
      expect(scheduler.scheduled, (7, 30));
      await coordinator.setEnabled(false);
      expect(scheduler.scheduled, isNull);
      expect(store.value!.enabled, isFalse);
    });

    test('a refused permission stays off', () async {
      scheduler.granted = false;

      expect(await coordinator.setEnabled(true), EnableResult.denied);
      expect(store.value!.enabled, isFalse);
      expect(scheduler.scheduled, isNull);
    });

    test('before the first ask, a launch never asks and never switches '
        'off', () async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      scheduler.granted = false;

      await coordinator.sync();

      expect(scheduler.calls.where((c) => c != 'cancel'), isEmpty);
      expect(store.value, isNull);
    });

    test('on by default: with permission already there it schedules at '
        '19:00 without asking', () async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);

      await coordinator.sync();

      expect(scheduler.scheduled, (19, 0));
      expect(scheduler.calls, isNot(contains('request')));
    });

    test('askOnce asks, saves a yes, and schedules', () async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      scheduler.granted = false;
      scheduler.grantOnRequest = true;

      await coordinator.askOnce();

      expect(scheduler.calls.where((c) => c == 'request'), hasLength(1));
      expect(store.value!.enabled, isTrue);
      expect(scheduler.scheduled, (19, 0));
    });

    test('askOnce saves a no, and never asks again', () async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      scheduler.granted = false;

      await coordinator.askOnce();
      await coordinator.askOnce();

      expect(scheduler.calls.where((c) => c == 'request'), hasLength(1));
      expect(store.value!.enabled, isFalse);
      expect(scheduler.scheduled, isNull);
    });

    test('askOnce does nothing once a choice is saved', () async {
      store.value = const ReminderSettings.off();
      scheduler.granted = false;

      await coordinator.askOnce();

      expect(scheduler.calls, isNot(contains('request')));
      expect(store.value!.enabled, isFalse);
    });

    test('a permission taken away in Settings turns reminders off', () async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      store.value = const ReminderSettings(enabled: true, hour: 19, minute: 0);
      scheduler.granted = false;

      await coordinator.sync();

      expect(store.value!.enabled, isFalse);
      expect(scheduler.scheduled, isNull);
      expect(scheduler.calls, isNot(contains('request')));
    });

    test('nothing to practise cancels without switching off; people '
        'coming back restore it', () async {
      store.value = const ReminderSettings(enabled: true, hour: 19, minute: 0);

      await coordinator.sync();
      expect(scheduler.scheduled, isNull);
      expect(store.value!.enabled, isTrue);
      expect(coordinator.waitingForPeople, isTrue);

      await people(['Ann', 'Bo', 'Cy', 'Di']);
      await coordinator.sync();
      expect(scheduler.scheduled, (19, 0));
    });

    test('a read error leaves the schedule alone', () async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      await coordinator.setEnabled(true);
      repository.fail = true;

      await coordinator.sync();

      expect(scheduler.scheduled, (19, 0));
    });

    test('turning off while a sync is reading wins', () async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      store.value = const ReminderSettings(enabled: true, hour: 19, minute: 0);
      repository.hold = Completer<void>();

      final syncing = coordinator.sync();
      final turningOff = coordinator.setEnabled(false);
      repository.hold!.complete();
      repository.hold = null;
      await Future.wait([syncing, turningOff]);

      expect(scheduler.scheduled, isNull);
    });
  });

  test('the store starts at the defaults, round-trips, and reads a corrupt '
      'file as off', () async {
    final temp = await Directory.systemTemp.createTemp('rememberem_rem_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/reminders.json');
    final fileStore = FileReminderSettingsStore(file);

    expect(await fileStore.load(), const ReminderSettings.defaults());
    expect(await fileStore.hasSaved(), isFalse);
    const set = ReminderSettings(enabled: true, hour: 6, minute: 45);
    await fileStore.save(set);
    expect(await fileStore.load(), set);
    expect(await fileStore.hasSaved(), isTrue);
    await file.writeAsString('{oops');
    expect(await fileStore.load(), const ReminderSettings.off());
    expect(await fileStore.hasSaved(), isTrue);
  });

  test('the notification names no one and carries only a game id', () async {
    await people(['Zebulon Quixote']);
    final everything = [
      LocalNotificationsScheduler.title,
      LocalNotificationsScheduler.body,
      for (final g in PracticeGame.values) g.wireId,
    ].join(' ');

    for (final secret in ['Zebulon', 'Quixote', 'Stake', 'Sunday', 'choir']) {
      expect(everything, isNot(contains(secret)));
    }
  });

  group('reminders screen', () {
    Future<void> show(WidgetTester tester) async {
      makeCoordinator();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RemindersSection(coordinator: coordinator)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('on by default at 7 PM; off hides the time', (tester) async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      await show(tester);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.text('Around 7:00 PM'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.textContaining('Around'), findsNothing);
    });

    testWidgets('refused permission stays off and explains', (tester) async {
      scheduler.granted = false;
      store.value = const ReminderSettings.off();
      await show(tester);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(
        find.textContaining('Notifications are turned off'),
        findsOneWidget,
      );
    });

    testWidgets('picking a time reschedules', (tester) async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      store.value = const ReminderSettings(enabled: true, hour: 19, minute: 0);
      await show(tester);
      await coordinator.sync();
      scheduler.calls.clear();

      await tester.tap(find.text('Around 7:00 PM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(scheduler.calls.where((c) => c.startsWith('schedule')), [
        'schedule 19:0',
      ]);
    });
  });

  group('tapping a reminder', () {
    late _FakeShortcut shortcut;
    late AppServices services;

    Future<void> boot(WidgetTester tester) async {
      makeCoordinator();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      shortcut = _FakeShortcut();
      services = AppServices(
        repository: repository,
        capture: PortraitCapture(
          repository: repository,
          faceLocator: _NoFaces(),
          workFolder: Directory.systemTemp,
        ),
        dictation: FakeDictation(),
        location: DeviceLocation(),
        reminders: coordinator,
      );
      await tester.pumpWidget(
        RememberemApp(services: services, shortcut: shortcut),
      );
      await tester.pumpAndSettle();
    }

    NavigatorState navigator(WidgetTester tester) =>
        tester.state<NavigatorState>(find.byType(Navigator).first);

    Future<void> tap(WidgetTester tester, PracticeGame? game) async {
      scheduler.emitTap(game);
      await tester.pumpAndSettle();
    }

    testWidgets('a cold-start reminder opens the game once; Back is the list', (
      tester,
    ) async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      scheduler.launch = PracticeGame.faces;

      await boot(tester);

      expect(find.byType(FaceGameScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Rememberem'), findsOneWidget);
      expect(navigator(tester).canPop(), isFalse);
    });

    testWidgets('two warm taps open one game', (tester) async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      await boot(tester);

      await tap(tester, PracticeGame.faces);
      await tap(tester, PracticeGame.faces);

      expect(find.byType(FaceGameScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(navigator(tester).canPop(), isFalse);
    });

    testWidgets('with nothing to practise the list stays', (tester) async {
      await people(['Ann']);
      await boot(tester);

      await tap(tester, PracticeGame.faces);

      expect(find.byType(FaceGameScreen), findsNothing);
      expect(navigator(tester).canPop(), isFalse);
    });

    testWidgets('a tap from a card keeps what was typed', (tester) async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      await boot(tester);
      await tester.tap(find.text('Ann'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Ann'), 'Annie');

      await tap(tester, PracticeGame.faces);

      expect(find.byType(FaceGameScreen), findsOneWidget);
      expect(find.byType(MemoryEditScreen), findsNothing);
      expect(
        repository.stored.values.any(
          (m) => m.field(MemoryField.name) == 'Annie',
        ),
        isTrue,
      );
    });

    testWidgets('a tap while the camera is open is ignored', (tester) async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      await boot(tester);
      shortcut.trigger!();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      scheduler.emitTap(PracticeGame.faces);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CaptureScreen), findsOneWidget);
      expect(find.byType(FaceGameScreen), findsNothing);
    });

    testWidgets('coming back to the app brings the reminder up to date', (
      tester,
    ) async {
      store.value = const ReminderSettings(enabled: true, hour: 19, minute: 0);
      await boot(tester);
      await coordinator.sync();
      await tester.pump();
      expect(scheduler.scheduled, isNull); // nobody to practise yet

      await people(['Ann', 'Bo', 'Cy', 'Di']);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(scheduler.scheduled, (19, 0));
    });

    testWidgets('unknown payloads do nothing; a later real tap works', (
      tester,
    ) async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      await boot(tester);

      await tap(tester, null);
      expect(navigator(tester).canPop(), isFalse);
      expect(tester.takeException(), isNull);

      await tap(tester, PracticeGame.faces);
      expect(find.byType(FaceGameScreen), findsOneWidget);
    });
  });
}
