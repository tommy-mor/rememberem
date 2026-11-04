import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/app/rememberem_app.dart';
import 'package:rememberem/src/places/background_location.dart';
import 'package:rememberem/src/places/place_arrival.dart';
import 'package:rememberem/src/places/place_fences.dart';
import 'package:rememberem/src/places/place_notice_consent.dart';
import 'package:rememberem/src/places/place_notice_keeper.dart';
import 'package:rememberem/src/places/place_notice_log.dart';
import 'package:rememberem/src/reminders/notice_channel.dart';
import 'package:rememberem/src/reminders/reminder_coordinator.dart';
import 'package:rememberem/src/reminders/reminder_settings_store.dart';
import 'package:rememberem/src/reminders/reminders_section.dart';
import 'package:rememberem/src/settings/app_settings_controller.dart';
import 'package:rememberem/src/settings/settings_store.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_memory_repository.dart';
import 'fakes/fake_reminder_scheduler.dart';
import 'fakes/test_services.dart';

class _MemoryStore implements ReminderSettingsStore {
  ReminderSettings value = const ReminderSettings.defaults();

  @override
  Future<ReminderSettings> load() async => value;

  @override
  Future<bool> hasSaved() async => true;

  @override
  Future<void> save(ReminderSettings settings) async => value = settings;
}

class _Settings implements SettingsStore {
  AppSettings value = const AppSettings(streetMaps: false);

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async => value = settings;
}

class _FakeFences implements PlaceFences {
  List<PlaceFence>? watching;
  int clears = 0;

  @override
  Future<void> sync(List<PlaceFence> fences) async => watching = fences;

  @override
  Future<void> clear() async {
    clears++;
    watching = null;
  }
}

class _FakeLocation implements BackgroundLocation {
  bool always = false;
  LocationAsk answer = LocationAsk.granted;
  bool cannotSay = false;
  int requests = 0;

  @override
  Future<bool> granted() async {
    if (cannotSay) throw StateError('no answer');
    return always;
  }

  @override
  Future<LocationAsk> request() async {
    requests++;
    if (answer == LocationAsk.granted) always = true;
    return answer;
  }
}

class _FailingFences implements PlaceFences {
  @override
  Future<void> sync(List<PlaceFence> fences) async =>
      throw StateError('refused');

  @override
  Future<void> clear() async {}
}

GeoPoint north(double km) => GeoPoint(km / 111.19493, 0);

void main() {
  late FakeMemoryRepository repository;
  late FakeReminderScheduler scheduler;
  late _MemoryStore store;
  late Directory temp;
  late PlaceNoticeLog log;
  var now = DateTime(2026, 11, 3, 9);

  Future<Memory> person(String name, String place, {GeoPoint? at}) async {
    final m = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 10, repository.stored.length + 1),
      place: place,
      location: at ?? north(0),
    );
    final named = m.withField('name', name);
    await repository.save(named);
    return named;
  }

  PlaceArrival arrival() => PlaceArrival(
    repository: repository,
    reminders: store,
    settings: _Settings(),
    log: log,
    scheduler: scheduler,
    clock: () => now,
  );

  setUp(() async {
    repository = FakeMemoryRepository();
    scheduler = FakeReminderScheduler();
    store = _MemoryStore();
    temp = await Directory.systemTemp.createTemp('rememberem_places_');
    log = PlaceNoticeLog(File('${temp.path}/place_notices.json'));
    now = DateTime(2026, 11, 3, 9);
  });

  tearDown(() => temp.delete(recursive: true));

  group('arriving', () {
    final cafe = PlaceNotice.fenceId('Cafe');

    test('nothing while place notices are off', () async {
      await person('Ann', 'Cafe');
      expect(await arrival().handle([cafe]), isFalse);
      expect(scheduler.shown, isEmpty);
    });

    test('on: says who was met there, then rests twelve hours', () async {
      store.value = store.value.copyWith(places: true);
      await person('Ann', 'Cafe');
      await person('Bo', 'Park');
      final gone = await person('Cy', 'Cafe');
      await repository.trash(gone.id, DateTime(2026, 10, 30));

      expect(await arrival().handle([cafe]), isTrue);
      final shown = scheduler.shown.single;
      expect(shown.title, 'At Cafe');
      expect(shown.body, "You've met Ann here.");
      expect(shown.channel, NoticeChannel.places);
      expect(shown.payload, PlaceNotice.wireId(cafe));
      expect(shown.payload, isNot(contains('Cafe')));

      now = now.add(const Duration(hours: 11));
      expect(await arrival().handle([cafe]), isFalse);
      now = now.add(const Duration(hours: 1));
      expect(await arrival().handle([cafe]), isTrue);
    });

    test(
      'each place rests on its own; a quiet one falls through to the next',
      () async {
        store.value = store.value.copyWith(places: true);
        await person('Ann', 'Cafe');
        await person('Bo', 'Park');
        final park = PlaceNotice.fenceId('Park');
        expect(await arrival().handle([cafe]), isTrue);
        expect(await arrival().handle([cafe, park]), isTrue);
        expect(scheduler.shown.last.title, 'At Park');
      },
    );

    test('a notice that could not show leaves the place due', () async {
      store.value = store.value.copyWith(places: true);
      await person('Ann', 'Cafe');
      scheduler.failShow = true;
      expect(await arrival().handle([cafe]), isFalse);
      expect(await log.lastShown(cafe), isNull);
      scheduler.failShow = false;
      expect(await arrival().handle([cafe]), isTrue);
    });

    test(
      'an unknown fence, or a place no one is left at, says nothing',
      () async {
        store.value = store.value.copyWith(places: true);
        final ann = await person('Ann', 'Cafe');
        expect(await arrival().handle(['f00000000']), isFalse);
        await repository.trash(ann.id, DateTime(2026, 10, 30));
        expect(await arrival().handle([cafe]), isFalse);
      },
    );

    test('the log keeps only opaque ids, and damage reads as never', () async {
      await log.record(cafe, now);
      expect(await log.lastShown(cafe), now.toUtc());
      final text = await log.file.readAsString();
      expect(text, isNot(contains('Cafe')));
      await log.file.writeAsString('not json');
      expect(await log.lastShown(cafe), isNull);
    });
  });

  group('keeping fences', () {
    late _FakeFences fences;
    late _FakeLocation location;
    late ReminderCoordinator coordinator;
    late AppSettingsController settings;

    PlaceNoticeKeeper keeper() => PlaceNoticeKeeper(
      fences: fences,
      location: location,
      reminders: coordinator,
      repository: repository,
      settings: settings,
    );

    setUp(() {
      fences = _FakeFences();
      location = _FakeLocation();
      coordinator = ReminderCoordinator(
        scheduler: scheduler,
        store: store,
        repository: repository,
      );
      settings = AppSettingsController(const AppSettings(streetMaps: false));
    });

    test('off: nothing is watched', () async {
      await person('Ann', 'Cafe');
      await keeper().sync();
      expect(fences.watching, isNull);
      expect(fences.clears, 1);
    });

    test('turned on and allowed: the named places are watched', () async {
      await person('Ann', 'Cafe', at: north(0));
      await person('Bo', '', at: north(5));
      expect(await keeper().enable(), LocationAsk.granted);
      expect(store.value.places, isTrue);
      expect(fences.watching!.map((f) => f.id), [PlaceNotice.fenceId('Cafe')]);
    });

    test('refused location all the time: stays off', () async {
      location.answer = LocationAsk.refused;
      expect(await keeper().enable(), LocationAsk.refused);
      expect(store.value.places, isFalse);
      expect(fences.watching, isNull);
    });

    test('notifications refused: location is never asked', () async {
      scheduler.granted = false;
      expect(await keeper().enable(), LocationAsk.refused);
      expect(location.requests, 0);
      expect(store.value.places, isFalse);
    });

    test('while in use: off until Fred chooses all the time in the '
        "phone's settings and comes back", () async {
      await person('Ann', 'Cafe');
      location.answer = LocationAsk.inSettings;
      final k = keeper();
      expect(await k.enable(), LocationAsk.inSettings);
      expect(store.value.places, isFalse);

      location.always = true; // chosen in the settings page
      await k.sync(); // on coming back
      expect(store.value.places, isTrue);
      expect(fences.watching, hasLength(1));
    });

    test(
      'the phone will not watch the places: off, not on in name only',
      () async {
        await person('Ann', 'Cafe');
        fences = _FakeFences();
        final k = PlaceNoticeKeeper(
          fences: _FailingFences(),
          location: location,
          reminders: coordinator,
          repository: repository,
          settings: settings,
        );
        expect(await k.enable(), LocationAsk.refused);
        expect(store.value.places, isFalse);
      },
    );

    test('notifications taken away: off on the next sync', () async {
      await person('Ann', 'Cafe');
      await keeper().enable();
      scheduler.granted = false;
      await keeper().sync();
      expect(store.value.places, isFalse);
      expect(fences.watching, isNull);
    });

    test('a check that cannot answer leaves things as they are', () async {
      await person('Ann', 'Cafe');
      await keeper().enable();
      location.cannotSay = true;
      await keeper().sync();
      expect(store.value.places, isTrue);
    });

    test('iOS watches at most its cap; Android many more', () async {
      for (var i = 0; i < 25; i++) {
        await person('P$i', 'Place $i', at: north(i.toDouble()));
      }
      final k = PlaceNoticeKeeper(
        fences: fences,
        location: location,
        reminders: coordinator,
        repository: repository,
        settings: settings,
        most: 18,
      );
      await k.enable();
      expect(fences.watching, hasLength(18));
    });

    test('syncs at once run one after another', () async {
      await person('Ann', 'Cafe');
      final k = keeper();
      await k.enable();
      await Future.wait([k.sync(), k.sync(), k.sync()]);
      expect(fences.watching, hasLength(1));
    });

    test('location taken away in Settings: off, and nothing watched', () async {
      await person('Ann', 'Cafe');
      await keeper().enable();
      location.always = false;
      await keeper().sync();
      expect(store.value.places, isFalse);
      expect(fences.watching, isNull);
    });

    test("the debug button shows a place's notice now", () async {
      await person('Ann', 'Cafe');
      final k = keeper();
      expect(await k.places(), ['Cafe']);
      await k.showNow('Cafe');
      expect(scheduler.shown.single.body, "You've met Ann here.");
      expect(scheduler.shown.single.id, PlaceNoticeKeeper.debugId);
    });

    testWidgets('the switch shows what location is for before asking, '
        'and No thanks asks nothing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Built in the test's own zone, so its queued saves run.
      coordinator = ReminderCoordinator(
        scheduler: scheduler,
        store: store,
        repository: repository,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RemindersSection(
                coordinator: coordinator,
                placeNotices: keeper(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.widgetWithText(SwitchListTile, 'Place notices');
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byType(PlaceNoticeConsent), findsOneWidget);
      expect(
        find.textContaining('even when the app is closed'),
        findsOneWidget,
      );
      expect(location.requests, 0);
      await tester.tap(find.text('No thanks'));
      await tester.pumpAndSettle();
      expect(location.requests, 0);
      expect(store.value.places, isFalse);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      expect(location.requests, 1);
      expect(store.value.places, isTrue);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    });
  });

  testWidgets('tapping a place notice shows the list filtered to it', (
    tester,
  ) async {
    await person('Ann', 'Cafe');
    await person('Bo', 'Park');
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final base = testServices(repository);
    final services = AppServices(
      repository: repository,
      capture: base.capture,
      dictation: base.dictation,
      location: base.location,
      settings: base.settings,
      links: base.links,
      reminders: ReminderCoordinator(
        scheduler: scheduler,
        store: store,
        repository: repository,
      ),
    );
    await tester.pumpWidget(RememberemApp(services: services));
    await tester.pumpAndSettle();

    scheduler.emitPayload(PlaceNotice.wireId(PlaceNotice.fenceId('Cafe')));
    await tester.pumpAndSettle();

    expect(services.listFilters.active.single, isA<PlaceFilter>());
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('Bo'), findsNothing);
  });

  testWidgets('a junk payload, or a place no one is left at, changes nothing', (
    tester,
  ) async {
    final ann = await person('Ann', 'Cafe');
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final base = testServices(repository);
    final services = AppServices(
      repository: repository,
      capture: base.capture,
      dictation: base.dictation,
      location: base.location,
      settings: base.settings,
      links: base.links,
      reminders: ReminderCoordinator(
        scheduler: scheduler,
        store: store,
        repository: repository,
      ),
    );
    await tester.pumpWidget(RememberemApp(services: services));
    await tester.pumpAndSettle();

    scheduler.emitPayload('arrival:fZZZZZZZZ');
    await tester.pumpAndSettle();
    expect(services.listFilters.active, isEmpty);

    await repository.trash(ann.id, DateTime(2026, 10, 30));
    scheduler.emitPayload(PlaceNotice.wireId(PlaceNotice.fenceId('Cafe')));
    await tester.pumpAndSettle();
    expect(services.listFilters.active, isEmpty);
  });
}
