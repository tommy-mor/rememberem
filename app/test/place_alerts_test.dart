import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_routes.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/app/meet_shortcut.dart';
import 'package:rememberem/src/app/rememberem_app.dart';
import 'package:rememberem/src/capture/capture_screen.dart';
import 'package:rememberem/src/location/device_location.dart';
import 'package:rememberem/src/memories/filter_list_screen.dart';
import 'package:rememberem/src/place_alerts/android_place_fencer.dart';
import 'package:rememberem/src/place_alerts/place_alert_access.dart';
import 'package:rememberem/src/place_alerts/place_alert_coordinator.dart';
import 'package:rememberem/src/place_alerts/place_alert_explainer.dart';
import 'package:rememberem/src/place_alerts/place_alerts_section.dart';
import 'package:rememberem/src/places/places_screen.dart';
import 'package:rememberem/src/places/rename_place_dialog.dart';
import 'package:rememberem/src/practice/face_game_screen.dart';
import 'package:rememberem/src/reminders/reminder_coordinator.dart';
import 'package:rememberem/src/reminders/reminder_settings_store.dart';
import 'package:rememberem/src/settings/app_settings_controller.dart';
import 'package:rememberem/src/settings/settings_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';
import 'fakes/fake_place_fencer.dart';
import 'fakes/fake_reminder_scheduler.dart';
import 'fakes/test_services.dart';

class _NoFaces implements FaceLocator {
  @override
  Future<List<PixelRect>> findFaces(File photo) async => [];
}

/// all() and save() can be made to fail.
class _FlakyRepository extends FakeMemoryRepository {
  bool failReads = false;
  bool failSaves = false;

  @override
  Future<List<Memory>> all() {
    if (failReads) throw const FileSystemException('unreadable');
    return super.all();
  }

  @override
  Future<void> save(Memory memory) {
    if (failSaves) throw const FileSystemException('disk full');
    return super.save(memory);
  }
}

class _FakeShortcut extends MeetShortcut {
  void Function()? trigger;

  @override
  Future<void> install(void Function() onMeet) async => trigger = onMeet;
}

class _MemoryReminderStore implements ReminderSettingsStore {
  ReminderSettings? value;

  @override
  Future<ReminderSettings> load() async =>
      value ?? const ReminderSettings.defaults();

  @override
  Future<bool> hasSaved() async => value != null;

  @override
  Future<void> save(ReminderSettings settings) async => value = settings;
}

GeoPoint north(double km) => GeoPoint(km / 111.19493, 0);

void main() {
  late _FlakyRepository repository;
  late FakePlaceFencer fencer;
  late AppSettingsController settings;
  // Built on first use, inside the test: a widget test's fake clock must
  // own the coordinator's serial chain, or it never runs during a pump.
  PlaceAlertCoordinator? built;
  PlaceAlertCoordinator coordinator() => built ??= PlaceAlertCoordinator(
    fencer: fencer,
    settings: settings,
    repository: repository,
  );

  setUp(() {
    repository = _FlakyRepository();
    fencer = FakePlaceFencer();
    settings = AppSettingsController(const AppSettings(streetMaps: false));
    built = null;
  });

  Future<Memory> person(String name, String place, GeoPoint? location) async {
    final memory = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 11, repository.stored.length + 1),
      location: location,
      place: place,
    );
    final named = memory.withField('name', name);
    await repository.save(named);
    return named;
  }

  List<String> watched() => [for (final f in fencer.watched ?? []) f.name];

  AppServices services() => AppServices(
    repository: repository,
    capture: PortraitCapture(
      repository: repository,
      faceLocator: _NoFaces(),
      workFolder: Directory.systemTemp,
    ),
    dictation: FakeDictation(),
    location: FakeLocation(),
    settings: settings,
    links: FakeLinkOpener(),
    placeAlerts: coordinator(),
  );

  group('coordinator', () {
    test('off: sync watches nothing and never asks', () async {
      await person('Ann', 'Cafe', north(0));
      await coordinator().sync();
      expect(fencer.calls, ['replace ']);
    });

    test(
      'turning on asks; refused stays off and says what is missing',
      () async {
        await person('Ann', 'Cafe', north(0));
        fencer.allowed = PlaceAlertAccess.background;

        final result = await coordinator().setEnabled(true);

        expect(result, PlaceAlertAccess.background);
        expect(settings.value.placeAlerts, isFalse);
        expect(fencer.calls, ['request']);
      },
    );

    test('turning on with access watches the places that notify', () async {
      await person('Ann', 'Cafe', north(0));
      await person('Bo', 'Home', north(5));
      await person('Cy', 'Somewhere', null);

      expect(await coordinator().setEnabled(true), PlaceAlertAccess.granted);

      expect(settings.value.placeAlerts, isTrue);
      expect(watched(), ['Cafe']);
    });

    test('allowed later in Settings: the next sync turns it on', () async {
      await person('Ann', 'Cafe', north(0));
      fencer.allowed = PlaceAlertAccess.background;
      await coordinator().setEnabled(true);

      await coordinator().sync(); // back, but not allowed yet
      expect(settings.value.placeAlerts, isFalse);

      fencer.allowed = PlaceAlertAccess.granted; // allowed after all
      await coordinator().sync();

      expect(settings.value.placeAlerts, isTrue);
      expect(watched(), ['Cafe']);
    });

    test("a check that can't tell keeps the setting and the places", () async {
      await person('Ann', 'Cafe', north(0));
      await coordinator().setEnabled(true);
      final before = [...fencer.calls];

      fencer.unknown = true;
      await coordinator().sync();

      expect(settings.value.placeAlerts, isTrue);
      expect(fencer.calls, before);
    });

    test('taken away in Settings: sync turns off and stops watching', () async {
      await person('Ann', 'Cafe', north(0));
      await coordinator().setEnabled(true);
      expect(watched(), ['Cafe']);

      fencer.allowed = PlaceAlertAccess.location;
      await coordinator().sync();

      expect(settings.value.placeAlerts, isFalse);
      expect(fencer.calls.last, 'replace ');
      expect(watched(), isEmpty);
    });

    test('an unreadable repository leaves the watched places alone', () async {
      await person('Ann', 'Cafe', north(0));
      await coordinator().setEnabled(true);
      final before = [...fencer.calls];

      repository.failReads = true;
      await coordinator().sync();

      expect(fencer.calls, before);
      expect(settings.value.placeAlerts, isTrue);
    });

    test('people in the trash are not watched', () async {
      final ann = await person('Ann', 'Cafe', north(0));
      await person('Bo', 'Park', north(5));
      await repository.trash(ann.id, DateTime(2026, 11, 20));

      await coordinator().setEnabled(true);

      expect(watched(), ['Park']);
    });

    test('a phone that cannot watch is reported', () async {
      await person('Ann', 'Cafe', north(0));
      fencer.replaceWorks = false;

      await coordinator().setEnabled(true);

      expect(coordinator().unavailable, isTrue);
      fencer.replaceWorks = true;
      await coordinator().sync();
      expect(coordinator().unavailable, isFalse);
    });

    test(
      'silencing a place stops watching it; a rename moves the choice',
      () async {
        await person('Ann', 'Cafe', north(0));
        await person('Bo', 'Park', north(5));
        await coordinator().setEnabled(true);

        await coordinator().setPlace('Cafe', false);
        expect(watched(), ['Park']);

        await coordinator().renamed('Cafe', 'Coffee', false);
        expect(settings.value.placeAlertChoices, {'Coffee': false});
      },
    );

    test('turning off stops watching and forgets a pending wish', () async {
      await person('Ann', 'Cafe', north(0));
      fencer.allowed = PlaceAlertAccess.background;
      await coordinator().setEnabled(true);
      await coordinator().setEnabled(false);

      fencer.allowed = PlaceAlertAccess.granted;
      await coordinator().sync();

      expect(settings.value.placeAlerts, isFalse);
      expect(watched(), isEmpty);
    });
  });

  group('Android channel', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel(AndroidPlaceFencer.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> log;

    void answer(Object? Function(MethodCall call) reply) {
      log = [];
      messenger.setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        return reply(call);
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }

    test('replace sends each fence as the phone reads it', () async {
      answer((_) => true);
      final fencer = AndroidPlaceFencer();

      final ok = await fencer.replace([
        PlaceFence(name: 'Cafe', center: north(0), radiusMeters: 150),
      ]);

      expect(ok, isTrue);
      expect(log.single.method, 'replace');
      expect(log.single.arguments, [
        {'name': 'Cafe', 'latitude': 0.0, 'longitude': 0.0, 'radius': 150.0},
      ]);
    });

    test('access names map to PlaceAlertAccess; unknown is location', () async {
      var reply = 'background';
      answer((_) => reply);
      final fencer = AndroidPlaceFencer();

      expect(await fencer.access(), PlaceAlertAccess.background);
      reply = 'granted';
      expect(await fencer.requestAccess(), PlaceAlertAccess.granted);
      reply = 'nonsense';
      expect(await fencer.access(), PlaceAlertAccess.location);
    });

    test('errors never escape', () async {
      answer((_) => throw PlatformException(code: 'boom'));
      final fencer = AndroidPlaceFencer();

      expect(await fencer.access(), isNull);
      expect(await fencer.replace(const []), isFalse);
      expect(await fencer.launchPlace(), isNull);
      await fencer.openSettings();
    });

    test('the launch place is trimmed, cut to size, and given once', () async {
      answer((_) => '  ${'x' * 300}  ');
      final fencer = AndroidPlaceFencer();

      expect(
        await fencer.launchPlace(),
        'x' * AndroidPlaceFencer.maxNameLength,
      );
      expect(await fencer.launchPlace(), isNull);
    });

    test('a tap from the phone reaches taps; junk is dropped', () async {
      answer((_) => null);
      final fencer = AndroidPlaceFencer();
      final taps = <String>[];
      final sub = fencer.taps.listen(taps.add);
      addTearDown(sub.cancel);
      const codec = StandardMethodCodec();

      for (final value in <Object?>[' Cafe ', '   ', 42, null]) {
        await messenger.handlePlatformMessage(
          AndroidPlaceFencer.channelName,
          codec.encodeMethodCall(MethodCall('tap', value)),
          (_) {},
        );
      }
      await Future<void>.delayed(Duration.zero);

      expect(taps, ['Cafe']);
    });
  });

  group('Settings section', () {
    Future<void> showSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            settings: settings,
            links: FakeLinkOpener(),
            placeAlerts: coordinator(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    SwitchListTile toggle(WidgetTester tester) => tester.widget(
      find.widgetWithText(SwitchListTile, PlaceAlertsSection.switchLabel),
    );

    Future<void> openPlaces(WidgetTester tester) async {
      await tester.tap(find.text('Places'));
      await tester.pumpAndSettle();
    }

    bool? ticked(WidgetTester tester, String place) => tester
        .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, place))
        .value;

    testWidgets('off by default; the list has each located, named place '
        'with home unticked', (tester) async {
      await person('Ann', 'Cafe', north(0));
      await person('Bo', 'Home', north(5));
      await person('Cy', 'Library', null);
      await person('Di', '', north(9));
      await showSettings(tester);

      expect(toggle(tester).value, isFalse);
      await openPlaces(tester);
      expect(ticked(tester, 'Cafe'), isTrue);
      expect(ticked(tester, 'Home'), isFalse);
      expect(find.widgetWithText(CheckboxListTile, 'Library'), findsNothing);
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
    });

    testWidgets('unticking a place saves the choice', (tester) async {
      await person('Ann', 'Cafe', north(0));
      await showSettings(tester);
      await openPlaces(tester);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Cafe'));
      await tester.pumpAndSettle();

      expect(settings.value.placeAlertChoices, {'Cafe': false});
      expect(ticked(tester, 'Cafe'), isFalse);
    });

    testWidgets('turning on explains first; Continue asks and turns it on', (
      tester,
    ) async {
      await person('Ann', 'Cafe', north(0));
      await showSettings(tester);

      await tester.tap(find.text(PlaceAlertsSection.switchLabel));
      await tester.pumpAndSettle();
      expect(find.text(PlaceAlertExplainer.title), findsOneWidget);
      expect(fencer.calls, isEmpty);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(fencer.calls.first, 'request');
      expect(toggle(tester).value, isTrue);
      expect(watched(), ['Cafe']);
    });

    testWidgets('Not now asks nothing and stays off', (tester) async {
      await showSettings(tester);

      await tester.tap(find.text(PlaceAlertsSection.switchLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(fencer.calls, isEmpty);
      expect(toggle(tester).value, isFalse);
    });

    testWidgets('refused: says what is missing, with a way to Settings', (
      tester,
    ) async {
      fencer.allowed = PlaceAlertAccess.background;
      await showSettings(tester);

      await tester.tap(find.text(PlaceAlertsSection.switchLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(toggle(tester).value, isFalse);
      expect(
        find.text(PlaceAlertsSection.missingText(PlaceAlertAccess.background)),
        findsOneWidget,
      );
      await tester.tap(find.text('Open settings'));
      expect(fencer.calls.last, 'settings');

      // Fred allows it there and comes back.
      fencer.allowed = PlaceAlertAccess.granted;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(toggle(tester).value, isTrue);
      expect(find.text('Open settings'), findsNothing);
    });

    testWidgets('a phone that cannot watch says so', (tester) async {
      await person('Ann', 'Cafe', north(0));
      fencer.replaceWorks = false;
      await showSettings(tester);

      await tester.tap(find.text(PlaceAlertsSection.switchLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text(PlaceAlertsSection.unavailableText), findsOneWidget);

      // Location back on; returning to the app clears the line.
      fencer.replaceWorks = true;
      await coordinator().sync();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(PlaceAlertsSection.unavailableText), findsNothing);
    });

    testWidgets('hidden where there are no place notifications (iOS)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(settings: settings, links: FakeLinkOpener()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Place notifications'), findsNothing);
    });
  });

  group('rename dialog', () {
    Future<void> showPlaces(WidgetTester tester, {bool alerts = true}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final observer = RouteObserver<ModalRoute<void>>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: PlacesScreen(
            services: alerts ? services() : testServices(repository),
            routeObserver: observer,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder box() =>
        find.widgetWithText(CheckboxListTile, RenamePlaceDialog.notifyLabel);

    bool? ticked(WidgetTester tester) =>
        tester.widget<CheckboxListTile>(box()).value;

    Future<void> rename(WidgetTester tester, String place) async {
      await tester.tap(find.byTooltip('Rename $place'));
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('starts from the choice; follows the typed name until '
        'touched', (tester) async {
      await person('Ann', 'Cafe', north(0));
      await showPlaces(tester);
      await rename(tester, 'Cafe');

      expect(ticked(tester), isTrue);
      await tester.enterText(find.byType(TextField), 'Home');
      await tester.pump();
      expect(ticked(tester), isFalse);

      await tester.tap(box());
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Church');
      await tester.pump();
      expect(ticked(tester), isTrue); // Fred's tick now wins

      await save(tester);
      expect(settings.value.placeAlertChoices, {'Church': true});
      expect(repository.stored.values.single.encounters.single.place, 'Church');
    });

    testWidgets('renaming into an existing place gives it the box', (
      tester,
    ) async {
      await person('Ann', 'Cafe', north(0));
      await person('Bo', 'Park', north(5));
      await coordinator().setPlace('Park', true);
      await showPlaces(tester);
      await rename(tester, 'Cafe');

      await tester.enterText(find.byType(TextField), 'Park');
      await tester.pump();
      await tester.tap(box());
      await tester.pump();
      await save(tester);

      expect(settings.value.placeAlertChoices, {'Park': false});
    });

    testWidgets('keeping the name only changes the choice', (tester) async {
      await person('Ann', 'Cafe', north(0));
      await showPlaces(tester);
      final saves = repository.saves.length;
      await rename(tester, 'Cafe');

      await tester.tap(box());
      await tester.pump();
      await save(tester);

      expect(repository.saves.length, saves);
      expect(settings.value.placeAlertChoices, {'Cafe': false});
    });

    testWidgets('renaming a silenced place keeps it silenced', (tester) async {
      await person('Ann', 'Cafe', north(0));
      await coordinator().setPlace('Cafe', false);
      await showPlaces(tester);
      await rename(tester, 'Cafe');

      await tester.enterText(find.byType(TextField), 'Coffee');
      await tester.pump();
      expect(ticked(tester), isFalse);
      await save(tester);

      expect(settings.value.placeAlertChoices, {'Coffee': false});
    });

    testWidgets('a failed rename keeps the old choice', (tester) async {
      await person('Ann', 'Cafe', north(0));
      await coordinator().setPlace('Cafe', false);
      await showPlaces(tester);
      await rename(tester, 'Cafe');

      repository.failSaves = true;
      await tester.enterText(find.byType(TextField), 'Coffee');
      await tester.pump();
      await save(tester);

      expect(settings.value.placeAlertChoices, {'Cafe': false});
      expect(find.textContaining('Could not rename'), findsOneWidget);
    });

    testWidgets('naming an unknown place uses the typed name', (tester) async {
      await person('Ann', '', north(0));
      await showPlaces(tester);
      await rename(tester, 'unknown');

      await tester.enterText(find.byType(TextField), 'Work');
      await tester.pump();
      expect(ticked(tester), isFalse);
      await save(tester);

      expect(settings.value.placeAlertChoices, {'Work': false});
    });

    testWidgets('no box without place notifications', (tester) async {
      await person('Ann', 'Cafe', north(0));
      await showPlaces(tester, alerts: false);
      await rename(tester, 'Cafe');
      expect(box(), findsNothing);
    });
  });

  group('tapping a notice', () {
    late _FakeShortcut shortcut;

    Future<void> boot(
      WidgetTester tester, {
      ReminderCoordinator? reminders,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      shortcut = _FakeShortcut();
      final base = services();
      await tester.pumpWidget(
        RememberemApp(
          services: AppServices(
            repository: base.repository,
            capture: base.capture,
            dictation: base.dictation,
            location: DeviceLocation(),
            settings: settings,
            links: base.links,
            placeAlerts: coordinator(),
            reminders: reminders,
          ),
          shortcut: shortcut,
        ),
      );
      await tester.pumpAndSettle();
    }

    NavigatorState navigator(WidgetTester tester) =>
        tester.state<NavigatorState>(find.byType(Navigator).first);

    Future<void> tap(WidgetTester tester, String place) async {
      fencer.emitTap(place);
      await tester.pumpAndSettle();
    }

    Future<void> twoPlaces() async {
      await person('Ann', 'Cafe', north(0));
      await person('Bo', 'Park', north(5));
    }

    void expectFilteredToCafe() {
      expect(find.byType(FilterListScreen), findsOneWidget);
      expect(find.text('1 person'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FilterListScreen),
          matching: find.text('Ann'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(FilterListScreen),
          matching: find.text('Bo'),
        ),
        findsNothing,
      );
    }

    testWidgets('a cold-start notice opens the list for that place; Back '
        'is the list', (tester) async {
      await twoPlaces();
      fencer.launch = 'Cafe';

      await boot(tester);

      expectFilteredToCafe();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(FilterListScreen), findsNothing);
      expect(navigator(tester).canPop(), isFalse);
    });

    testWidgets('a warm tap does the same; spaces are trimmed', (tester) async {
      await twoPlaces();
      await boot(tester);

      await tap(tester, ' Cafe ');

      expectFilteredToCafe();
    });

    testWidgets('a second tap replaces the first, never stacks', (
      tester,
    ) async {
      await twoPlaces();
      await boot(tester);

      await tap(tester, 'Park');
      await tap(tester, 'Cafe');

      expectFilteredToCafe();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(navigator(tester).canPop(), isFalse);
    });

    testWidgets('a blank or unknown place never breaks the list', (
      tester,
    ) async {
      await twoPlaces();
      await boot(tester);

      await tap(tester, '   ');
      expect(navigator(tester).canPop(), isFalse);

      await tap(tester, 'Nowhere');
      expect(find.byType(FilterListScreen), findsOneWidget);
      expect(find.text('No one matches.'), findsOneWidget);
    });

    testWidgets('a tap while the camera is open is ignored', (tester) async {
      await twoPlaces();
      await boot(tester);
      shortcut.trigger!();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      fencer.emitTap('Cafe');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CaptureScreen), findsOneWidget);
      expect(find.byType(FilterListScreen), findsNothing);
    });

    testWidgets('a tap during a game is ignored', (tester) async {
      await twoPlaces();
      await boot(tester);
      navigator(tester).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRoutes.practice),
          builder: (_) => const Scaffold(body: Text('a game')),
        ),
      );
      await tester.pumpAndSettle();

      await tap(tester, 'Cafe');

      expect(find.text('a game'), findsOneWidget);
      expect(find.byType(FilterListScreen), findsNothing);
    });

    testWidgets('a notice and a reminder at launch leave one page over '
        'the list (the game)', (tester) async {
      for (final name in ['Ann', 'Bo', 'Cy', 'Di']) {
        await person(name, 'Cafe', north(0));
      }
      final scheduler = FakeReminderScheduler(launch: PracticeGame.faces);
      final reminders = ReminderCoordinator(
        scheduler: scheduler,
        store: _MemoryReminderStore(),
        repository: repository,
      );
      fencer.launch = 'Cafe';

      await boot(tester, reminders: reminders);

      expect(find.byType(FaceGameScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(navigator(tester).canPop(), isFalse);
    });
  });
}
