import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/places/background_location.dart';
import 'package:rememberem/src/places/place_arrival.dart';
import 'package:rememberem/src/places/place_fences.dart';
import 'package:rememberem/src/places/place_notice_keeper.dart';
import 'package:rememberem/src/places/place_notice_log.dart';
import 'package:rememberem/src/places/places_screen.dart';
import 'package:rememberem/src/reminders/reminder_coordinator.dart';
import 'package:rememberem/src/reminders/reminder_settings_store.dart';
import 'package:rememberem/src/settings/app_settings_controller.dart';
import 'package:rememberem/src/settings/settings_store.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
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
  _Settings([this.value = const AppSettings(streetMaps: false)]);

  final AppSettings value;

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async {}
}

class _FakeFences implements PlaceFences {
  List<PlaceFence>? watching;
  int syncs = 0;

  @override
  Future<void> sync(List<PlaceFence> fences) async {
    syncs++;
    watching = fences;
  }

  @override
  Future<void> clear() async {
    watching = null;
  }
}

class _AlwaysAllowed implements BackgroundLocation {
  @override
  Future<bool> granted() async => true;

  @override
  Future<LocationAsk> request() async => LocationAsk.granted;
}

GeoPoint north(double km) => GeoPoint(km / 111.19493, 0);

void main() {
  late FakeMemoryRepository repository;
  late FakeReminderScheduler scheduler;
  late _MemoryStore store;
  late _FakeFences fences;
  late AppServices services;
  const cafe = 'Cafe';

  Future<void> person(String name, String place, double km) async {
    final m = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 10, repository.stored.length + 1),
      place: place,
      location: north(km),
    );
    await repository.save(m.withField('name', name));
  }

  Finder box(String place) => find.byWidgetPredicate(
    (w) => w is Checkbox && w.semanticLabel == 'Notify on arrival at $place',
  );

  bool ticked(WidgetTester tester, String place) =>
      tester.widget<Checkbox>(box(place)).value!;

  List<String> watched() => [for (final f in fences.watching!) f.id]..sort();

  setUp(() async {
    repository = FakeMemoryRepository();
    scheduler = FakeReminderScheduler();
    store = _MemoryStore();
    fences = _FakeFences();
    final settings = AppSettingsController(
      const AppSettings(streetMaps: false),
    );
    final keeper = PlaceNoticeKeeper(
      fences: fences,
      location: _AlwaysAllowed(),
      reminders: ReminderCoordinator(
        scheduler: scheduler,
        store: store,
        repository: repository,
      ),
      repository: repository,
      settings: settings,
    );
    services = AppServices(
      repository: repository,
      capture: testServices(repository).capture,
      dictation: FakeDictation(),
      location: FakeLocation(),
      settings: settings,
      placeNotices: keeper,
    );
    await person('Ann', 'Home', 0);
    await person('Bo', cafe, 5);
    store.value = store.value.copyWith(places: true);
  });

  Future<void> showPlaces(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final observer = RouteObserver<ModalRoute<void>>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: PlacesScreen(services: services, routeObserver: observer),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(services.placeNotices!.sync);
    fences.syncs = 0; // setup's enable() synced; only ticks are tested
  }

  /// Lets the keeper's background work finish. Its steps hop between the
  /// real event loop and the fake clock's microtasks, so take turns.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
  }

  testWidgets('Home starts unticked and Cafe ticked', (tester) async {
    await showPlaces(tester);

    expect(ticked(tester, 'Home'), isFalse);
    expect(ticked(tester, cafe), isTrue);
    expect(watched(), [PlaceNotice.fenceId(cafe)]);
  });

  testWidgets('the radius pill and the Notify box keep a gap when they wrap', (
    tester,
  ) async {
    await showPlaces(tester);

    final wrap = tester.widget<Wrap>(
      find
          .ancestor(
            of: find.byType(Checkbox).first,
            matching: find.byType(Wrap),
          )
          .first,
    );
    expect(wrap.spacing, 8);
    expect(wrap.runSpacing, 8);
  });

  testWidgets('ticking and unticking saves the choice in settings', (
    tester,
  ) async {
    await showPlaces(tester);

    await tester.tap(box('Home'));
    await tester.pump();
    expect(ticked(tester, 'Home'), isTrue);
    expect(services.settings.value.notifies('Home'), isTrue);

    await tester.tap(box(cafe));
    await tester.pump();
    expect(ticked(tester, cafe), isFalse);
    expect(services.settings.value.notifies(cafe), isFalse);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a second after the last tick the fences follow', (tester) async {
    await showPlaces(tester);

    await tester.tap(box(cafe));
    await settle(tester); // the timer starts once the save has finished
    await tester.pump(const Duration(milliseconds: 900));
    expect(fences.syncs, 0); // not yet
    expect(watched(), [PlaceNotice.fenceId(cafe)]);
    await tester.pump(const Duration(milliseconds: 200));
    await settle(tester);
    expect(fences.syncs, 1);
    expect(watched(), isEmpty); // the unticked place is no longer watched

    await tester.tap(box('Home'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(watched(), [PlaceNotice.fenceId('Home')]);

    await tester.tap(box(cafe));
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(
      watched(),
      [PlaceNotice.fenceId('Home'), PlaceNotice.fenceId(cafe)]..sort(),
    );
  });

  testWidgets('three quick ticks cause one sync', (tester) async {
    await showPlaces(tester);

    await tester.tap(box(cafe));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(box(cafe));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(box(cafe));
    await tester.pump(const Duration(milliseconds: 600));
    expect(fences.syncs, 0); // each tick restarted the wait
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    expect(fences.syncs, 1);
    expect(ticked(tester, cafe), isFalse);
    expect(watched(), isEmpty);
  });

  testWidgets('leaving the page with a tick pending syncs at once', (
    tester,
  ) async {
    await showPlaces(tester);

    await tester.tap(box(cafe));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(fences.syncs, 0);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.pump();

    expect(fences.syncs, 1);
    expect(watched(), isEmpty);
  });

  test(
    'arriving: a quiet place is skipped; a later due one still shows',
    () async {
      final temp = await Directory.systemTemp.createTemp('rememberem_notify_');
      addTearDown(() => temp.delete(recursive: true));
      await store.save(store.value.copyWith(places: true));
      final arrival = PlaceArrival(
        repository: repository,
        reminders: store,
        settings: _Settings(),
        log: PlaceNoticeLog(File('${temp.path}/place_notices.json')),
        scheduler: scheduler,
        clock: () => DateTime(2026, 11, 3, 9),
      );
      final home = PlaceNotice.fenceId('Home');

      expect(await arrival.handle([home]), isFalse); // quiet by default
      expect(scheduler.shown, isEmpty);

      expect(await arrival.handle([home, PlaceNotice.fenceId(cafe)]), isTrue);
      expect(scheduler.shown.single.title, 'At Cafe');
    },
  );

  test('arriving follows Fred\'s own ticks: an unticked place is skipped, '
      'a ticked Home shows', () async {
    final temp = await Directory.systemTemp.createTemp('rememberem_notify_');
    addTearDown(() => temp.delete(recursive: true));
    await store.save(store.value.copyWith(places: true));
    final arrival = PlaceArrival(
      repository: repository,
      reminders: store,
      settings: _Settings(
        const AppSettings(streetMaps: false)
            .withPlaceNotify(cafe, false)
            .withPlaceNotify('Home', true),
      ),
      log: PlaceNoticeLog(File('${temp.path}/place_notices.json')),
      scheduler: scheduler,
      clock: () => DateTime(2026, 11, 3, 9),
    );

    expect(
      await arrival.handle([
        PlaceNotice.fenceId(cafe),
        PlaceNotice.fenceId('Home'),
      ]),
      isTrue,
    );
    expect(scheduler.shown.single.title, 'At Home');
  });
}
