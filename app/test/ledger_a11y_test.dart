import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/about/about_screen.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/app/rememberem_theme.dart';
import 'package:rememberem/src/capture/capture_screen.dart';
import 'package:rememberem/src/capture/face_picker_screen.dart';
import 'package:rememberem/src/capture/group_details_screen.dart';
import 'package:rememberem/src/capture/photo_check.dart';
import 'package:rememberem/src/capture/photo_picker.dart';
import 'package:rememberem/src/capture/picked_photo.dart';
import 'package:rememberem/src/maps/location_picker_screen.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem/src/memories/memory_list_screen.dart';
import 'package:rememberem/src/memories/memory_tile.dart';
import 'package:rememberem/src/memories/merge_picker_screen.dart';
import 'package:rememberem/src/places/place_notice_consent.dart';
import 'package:rememberem/src/places/place_row.dart';
import 'package:rememberem/src/places/places_screen.dart';
import 'package:rememberem/src/practice/answer_row.dart';
import 'package:rememberem/src/practice/detail_game_screen.dart';
import 'package:rememberem/src/practice/face_game_screen.dart';
import 'package:rememberem/src/practice/quiz_result.dart';
import 'package:rememberem/src/practice/quiz_results_view.dart';
import 'package:rememberem/src/reminders/reminder_coordinator.dart';
import 'package:rememberem/src/reminders/reminder_settings_store.dart';
import 'package:rememberem/src/settings/settings_screen.dart';
import 'package:rememberem/src/timeline/timeline_screen.dart';
import 'package:rememberem/src/trash/trash_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/detail_finders.dart';
import 'fakes/fake_memory_repository.dart';
import 'fakes/fake_reminder_scheduler.dart';
import 'fakes/test_services.dart';

/// A control that fails a guideline and is left as it is, on purpose.
/// Each needs Eric's sign-off (see the story 36 report).
class Waiver {
  const Waiver({
    required this.screen,
    required this.control,
    required this.location,
    required this.reason,
  });

  /// The table entry it applies to.
  final String screen;

  /// Text that appears in the failing node's description.
  final String control;

  /// file:line of the control.
  final String location;
  final String reason;
}

/// Every waiver. An unwaived failure fails the test; nothing is skipped
/// and no screen is left out. Empty means every control passes.
const waivers = <Waiver>[];

/// One screen the table checks: how to build it, and a marker found on it
/// before checking, so an empty or failed screen cannot pass.
class _Entry {
  const _Entry(
    this.name,
    this.marker,
    this.build, {
    this.afterShow,
    this.keyboard = false,
    this.exempt = const [],
    this.landscape = false,
  });

  final String name;
  final Finder Function() marker;
  final Widget Function(_World world) build;

  /// Taps to get the screen into the state under test.
  final Future<void> Function(WidgetTester tester, _World world)? afterShow;

  /// With the keyboard up (300 dp), at text scale 2.0 only.
  final bool keyboard;

  /// Text that marks a node as exempt from the guidelines. A quiz's wrong
  /// answer is dimmed to 35 % and disabled on purpose, so that it reads
  /// as set aside and never as red; it is not meant to be read or tapped.
  final List<String> exempt;

  /// Also checked for overflow on its side, at 568 x 320.
  final bool landscape;

  /// The text scales it is checked at.
  List<double> get scales => keyboard ? const [2.0] : const [1.0, 2.0];
}

/// A gallery that offers nothing, so the camera screen shows its button.
class _NoGallery implements PhotoPicker {
  @override
  Future<PickedPhoto?> pick() async => null;

  @override
  Future<void> openSettings() async {}
}

/// A photo of three faces, as the picker and group page get it.
final _draft = CaptureDraft(
  photo: UprightPhoto(Uint8List.fromList([1, 2, 3]), 400, 500),
  faces: const [
    PixelRect(20, 100, 60, 80),
    PixelRect(160, 120, 60, 80),
    PixelRect(300, 90, 60, 80),
  ],
  capturedAt: DateTime(2026, 11, 5, 12),
  place: 'Hall',
  meeting: 'Choir',
);

/// Reminder settings kept in memory, all off.
class _MemoryStore implements ReminderSettingsStore {
  @override
  Future<ReminderSettings> load() async => const ReminderSettings.defaults();

  @override
  Future<bool> hasSaved() async => false;

  @override
  Future<void> save(ReminderSettings settings) async {}
}

class _World {
  _World(this.repository, this.services, this.ann);

  final FakeMemoryRepository repository;
  final AppServices services;

  /// The person the card and the merge picker open.
  final Memory ann;
}

/// The themes Fred can end up in: light and dark, on a light and a dark
/// chosen background each where they apply.
const _looks = <(String, int)>[
  ('light on cream', 0xFFFCEFC7),
  ('light on light blue', 0xFFD3DEFA),
  ('dark on midnight', 0xFF0F1B33),
  ('dark on charcoal', 0xFF1E2023),
];

ThemeData _themeFor(int background) {
  final settings = AppSettings(backgroundColor: background);
  return AppPalette.isDark(background)
      ? RememberemTheme.dark(settings)
      : RememberemTheme.light(settings);
}

final _entries = <_Entry>[
  _Entry(
    'Home',
    () => find.text('4 people'),
    (w) => MemoryListScreen(
      services: w.services,
      routeObserver: RouteObserver<ModalRoute<void>>(),
      onMeetSomeone: () {},
      clock: () => DateTime(2026, 11, 5, 12),
    ),
  ),
  _Entry(
    'Trash',
    () => find.text('Bo Chen'),
    (w) => TrashScreen(
      repository: w.repository,
      clock: () => DateTime(2026, 11, 5, 12),
    ),
  ),
  _Entry(
    'Person card, collapsed',
    () => find.text('Ann Lee'),
    (w) => MemoryEditScreen(memory: w.ann, services: w.services),
  ),
  _Entry(
    'Person card, one detail open',
    () => find.byTooltip('Close Fact'),
    (w) => MemoryEditScreen(memory: w.ann, services: w.services),
    afterShow: (tester, world) async {
      // Scrolled to only when it is out of reach..
      if (openToggle('Fact').hitTestable().evaluate().isEmpty) {
        await tester.ensureVisible(openToggle('Fact'));
      }
      await tester.tap(openToggle('Fact'));
      await tester.pumpAndSettle();
    },
  ),
  _Entry(
    'Person card, keyboard up',
    () => find.byTooltip('Close Fact'),
    (w) => MemoryEditScreen(memory: w.ann, services: w.services),
    keyboard: true,
    afterShow: (tester, world) async {
      // Scrolled to only when it is out of reach..
      if (openToggle('Fact').hitTestable().evaluate().isEmpty) {
        await tester.ensureVisible(openToggle('Fact'));
      }
      await tester.tap(openToggle('Fact'));
      await tester.pumpAndSettle();
    },
  ),
  _Entry(
    'Merge',
    () => find.byType(MemoryTile),
    (w) => MergePickerScreen(
      repository: w.repository,
      source: w.ann,
      clock: () => DateTime(2026, 11, 5, 12),
    ),
  ),
  _Entry(
    'Merge, one picked',
    () => find.widgetWithText(FilledButton, 'Merge'),
    (w) => MergePickerScreen(
      repository: w.repository,
      source: w.ann,
      clock: () => DateTime(2026, 11, 5, 12),
    ),
    afterShow: (tester, world) async {
      await tester.tap(find.byType(MemoryTile).first);
      await tester.pumpAndSettle();
    },
  ),
  _Entry(
    'Timeline',
    () => find.text('Ann'),
    (w) => TimelineScreen(
      services: w.services,
      routeObserver: RouteObserver<ModalRoute<void>>(),
      onMeetSomeone: () {},
    ),
  ),
  _Entry(
    'Faces, names showing',
    () => find.byType(AnswerRow),
    (w) => _faces(w, showDelay: false),
    landscape: true,
  ),
  _Entry(
    'Faces, a wrong answer',
    () => find.textContaining('Not '),
    (w) => _faces(w, showDelay: false),
    afterShow: (tester, world) async {
      final image =
          tester.widget<Image>(find.byType(Image).first).image as FileImage;
      final id = image.file.uri.pathSegments.last.split('.').first;
      final shown = world.repository.stored[id]!.field(MemoryField.name);
      final wrong = tester
          .widgetList<AnswerRow>(find.byType(AnswerRow))
          .firstWhere((row) => row.name != shown)
          .name;
      // Scrolled to only when it is out of reach.
      await tester.ensureVisible(find.text(wrong));
      await tester.tap(find.text(wrong));
      await tester.pump();
    },
    exempt: const ['not this one'],
    landscape: true,
  ),
  _Entry(
    'Faces, countdown',
    () => find.text('Show names'),
    (w) => _faces(w),
    landscape: true,
  ),
  _Entry(
    'Details, people showing',
    () => find.textContaining('About '),
    (w) => _details(w, showDelay: false),
    landscape: true,
  ),
  _Entry(
    'Details, a wrong answer',
    () => find.textContaining('Not '),
    (w) => _details(w, showDelay: false),
    afterShow: (tester, world) async {
      final subject = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((t) => t.startsWith('About '))
          .substring('About '.length);
      final wrong = [
        'Ann Lee',
        'Cy Doe',
        'Di Fox',
        'Ed Kim',
      ].firstWhere((n) => n != subject);
      // Scrolled to only when it is out of reach.
      await tester.ensureVisible(find.text(wrong));
      await tester.tap(find.text(wrong));
      await tester.pump();
    },
    exempt: const ['not this one'],
    landscape: true,
  ),
  _Entry(
    'Details, countdown',
    () => find.text('Show people'),
    (w) => _details(w),
    landscape: true,
  ),
  _Entry(
    'Places',
    () => find.byType(PlaceRow),
    (w) => PlacesScreen(
      services: w.services,
      routeObserver: RouteObserver<ModalRoute<void>>(),
    ),
  ),
  _Entry(
    'Places, selected with people showing',
    // Below the list's fold on a short screen, but built.
    () => find.byType(MemoryTile, skipOffstage: false),
    (w) => PlacesScreen(
      services: w.services,
      routeObserver: RouteObserver<ModalRoute<void>>(),
    ),
    afterShow: (tester, world) async {
      final expander = find.byIcon(Icons.expand_more_rounded);
      await _scrollTo(tester, expander);
      await tester.tap(expander);
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.textContaining('people'));
      await tester.tap(find.textContaining('people'));
      await tester.pumpAndSettle();
      // Back to the top, where the rows are whole.
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
    },
  ),
  _Entry(
    'Places, sliding the radius',
    () => find.byTooltip('Done'),
    (w) => PlacesScreen(
      services: w.services,
      routeObserver: RouteObserver<ModalRoute<void>>(),
    ),
    afterShow: (tester, world) async {
      await _scrollTo(tester, find.textContaining(' radius'));
      await tester.tap(find.textContaining(' radius'));
      // Not settled: the slider pulses.
      await tester.pump();
    },
  ),
  _Entry(
    'Location picker',
    () => find.text('Use this spot'),
    (w) => LocationPickerScreen(services: w.services, initial: GeoPoint(0, 0)),
    landscape: true,
  ),
  _Entry(
    'Settings',
    () => find.text('REMINDERS'),
    (w) => SettingsScreen(
      settings: w.services.settings,
      links: w.services.links,
      reminders: _reminders(w),
    ),
  ),
  _Entry(
    'Settings, scrolled to the end',
    () => find.text('About Rememberem'),
    (w) => SettingsScreen(
      settings: w.services.settings,
      links: w.services.links,
      reminders: _reminders(w),
    ),
    afterShow: (tester, world) async {
      await _scrollToEnd(tester);
    },
  ),
  _Entry(
    'About',
    () => find.text('Suggestions are welcome!'),
    (w) => AboutScreen(links: w.services.links, reminders: _reminders(w)),
  ),
  _Entry(
    'About, scrolled to the end',
    () => find.text('Practice reminder now'),
    (w) => AboutScreen(links: w.services.links, reminders: _reminders(w)),
    afterShow: (tester, world) async {
      await _scrollToEnd(tester);
    },
  ),
  _Entry(
    'Place notices consent',
    () => find.text('Location in the background'),
    (w) => const PlaceNoticeConsent(),
    landscape: true,
  ),
  _Entry(
    // The camera itself is a platform view that cannot be pumped; with no
    // camera plugin the shutter row stands alone.
    'Capture, no camera',
    () => find.byTooltip('Take photo'),
    (w) => CaptureScreen(
      services: testServices(w.repository, photoPicker: _NoGallery()),
    ),
    landscape: true,
  ),
  _Entry(
    'Photo check',
    () => find.text('Use photo'),
    (w) => PhotoCheck(jpeg: Uint8List(3), onUse: () {}, onRetake: () {}),
    landscape: true,
  ),
  _Entry(
    'Face picker',
    () => find.text('Tap each face to keep'),
    (w) => FacePickerScreen(draft: _draft, services: w.services),
    landscape: true,
  ),
  _Entry(
    'Face picker, one chosen',
    () => find.byIcon(Icons.check_circle_rounded),
    (w) => FacePickerScreen(draft: _draft, services: w.services),
    afterShow: (tester, world) async {
      // Scrolled to only when it is out of reach.
      await tester.ensureVisible(find.byTooltip('Face 2'));
      await tester.tap(find.byTooltip('Face 2'));
      // Settled, so the button is done turning gold.
      await tester.pumpAndSettle();
    },
    landscape: true,
  ),
  _Entry(
    'Group details',
    () => find.text('PLACE'),
    (w) => GroupDetailsScreen(
      draft: _draft,
      faces: _draft.faces,
      services: w.services,
    ),
    landscape: true,
  ),
  _Entry(
    'Results',
    () => find.text('Back to list'),
    (w) => Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: SafeArea(
        child: QuizResultsView(
          results: [
            QuizResult(
              person: w.ann,
              rightFirstTry: true,
              pointsBefore: 4,
              pointsAfter: 5,
            ),
            QuizResult(
              person: w.ann,
              detailText: 'About Ann Lee',
              rightFirstTry: false,
              pointsBefore: 2,
              pointsAfter: 0,
            ),
          ],
          threshold: 5,
          photoOf: (r) => w.repository.photoFile(r.person),
          onDone: () {},
        ),
      ),
    ),
  ),
];

/// Drags a lazy list to its end: its length is only known as it is built.
Future<void> _scrollToEnd(WidgetTester tester) async {
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  for (var i = 0; i < 20; i++) {
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

ReminderCoordinator _reminders(_World w) => ReminderCoordinator(
  scheduler: FakeReminderScheduler(),
  store: _MemoryStore(),
  repository: w.repository,
);

/// Scrolls the places list until [target] is inside it. (`ensureVisible`
/// does not move a target in a row taller than the list.)
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  final list = tester.getRect(find.byType(ListView).first);
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  final at = tester.getCenter(target).dy;
  if (at > list.bottom - 24) {
    position.jumpTo(
      (position.pixels + at - list.bottom + 48).clamp(
        0.0,
        position.maxScrollExtent,
      ),
    );
    await tester.pumpAndSettle();
  }
}

Widget _faces(_World w, {bool showDelay = true}) => FaceGameScreen(
  repository: w.repository,
  planner: FaceQuizPlanner(Random(1), () => DateTime(2026, 11, 5, 12)),
  clock: () => DateTime(2026, 11, 5, 12),
  showDelay: showDelay,
  pauseAfterRight: const Duration(hours: 1),
  settings: w.services.settings,
);

Widget _details(_World w, {bool showDelay = true}) => DetailGameScreen(
  repository: w.repository,
  planner: DetailQuizPlanner(Random(1), () => DateTime(2026, 11, 5, 12)),
  clock: () => DateTime(2026, 11, 5, 12),
  showDelay: showDelay,
  pauseAfterRight: const Duration(hours: 1),
  settings: w.services.settings,
);

void main() {
  late FakeMemoryRepository repository;
  late _World world;

  setUp(() async {
    repository = FakeMemoryRepository();
    Future<Memory> person(String name, DateTime met, {int points = 0}) async {
      final memory = await repository.add(
        photoJpeg: [],
        capturedAt: met,
        place: 'Home',
        location: const GeoPoint(0, 0),
      );
      // A detail each, so the details quiz has something to ask.
      final named = memory.withField('name', name).withDetails([
        Detail(id: 'd-$name', text: 'About $name', at: DateTime(2026, 11, 3)),
      ]);
      await repository.save(named);
      for (var i = 0; i < points; i++) {
        await repository.recordAnswer(
          memory.id,
          correctFirstTry: true,
          at: DateTime.utc(2026),
        );
      }
      return named;
    }

    final named = await person('Ann Lee', DateTime(2026, 11, 3), points: 2);
    // One fact, for the card's open state.
    final ann = named.withDetails([
      Detail(id: 'f', text: 'Tall', at: DateTime(2026, 11, 3)),
    ]);
    await repository.save(ann);
    world = _World(
      repository,
      testServices(
        repository,
        settings: const AppSettings(streetMaps: false, rememberedThreshold: 5),
      ),
      ann,
    );
    await person('Cy Doe', DateTime(2026, 10, 28), points: 5);
    await person('Di Fox', DateTime(2026, 10, 3));
    await person('Ed Kim', DateTime(2026, 9, 2));
    final bo = await person('Bo Chen', DateTime(2026, 1, 1));
    await repository.trash(bo.id, DateTime(2026, 11, 5, 8).toUtc());
  });

  Future<void> show(
    WidgetTester tester,
    _Entry entry,
    int background, {
    required double scale,
    Size size = const Size(360, 640),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    if (entry.keyboard) {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
    }
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final theme = _themeFor(background);
    await tester.pumpWidget(
      MaterialApp(theme: theme, home: entry.build(world)),
    );
    await tester.pump();
    await tester.pump();
    await entry.afterShow?.call(tester, world);
    // The marker first: an empty or failed screen would pass any guideline.
    expect(entry.marker(), findsWidgets, reason: '${entry.name} marker');
  }

  /// Runs [guideline]; failures a [Waiver] covers are let through, the
  /// rest fail the test.
  Future<void> check(
    WidgetTester tester,
    _Entry entry,
    AccessibilityGuideline guideline,
    String where,
  ) async {
    final result = await guideline.evaluate(tester);
    if (result.passed) return;
    // A failure that says nothing cannot be waived line by line.
    expect(
      (result.reason ?? '').trim(),
      isNotEmpty,
      reason: '${entry.name} $where: guideline failed with no reason',
    );
    final failures = (result.reason ?? '').split('\n');
    final unwaived = [
      for (final line in failures)
        if (line.trim().isNotEmpty &&
            !entry.exempt.any(line.contains) &&
            !waivers.any(
              (w) => w.screen == entry.name && line.contains(w.control),
            ))
          line,
    ];
    expect(unwaived, isEmpty, reason: '${entry.name} $where');
  }

  for (final entry in _entries) {
    for (final (look, background) in _looks) {
      group('${entry.name}, $look', () {
        for (final scale in entry.scales) {
          testWidgets('tap targets are 48 x 48 at text scale $scale', (
            tester,
          ) async {
            final handle = tester.ensureSemantics();
            await show(tester, entry, background, scale: scale);
            await check(
              tester,
              entry,
              androidTapTargetGuideline,
              'tap targets, scale $scale',
            );
            handle.dispose();
          });
        }

        if (entry.scales.contains(1.0)) {
          testWidgets('text contrast at text scale 1.0', (tester) async {
            final handle = tester.ensureSemantics();
            await show(tester, entry, background, scale: 1);
            await check(tester, entry, textContrastGuideline, 'contrast');
            handle.dispose();
          });
        }

        if (entry.landscape) {
          testWidgets('no overflow on its side, 568 x 320', (tester) async {
            await show(
              tester,
              entry,
              background,
              scale: 1,
              size: const Size(568, 320),
            );
            expect(tester.takeException(), isNull);
          });
        }

        testWidgets('no overflow at 320 x 568 and text scale 2.0', (
          tester,
        ) async {
          await show(
            tester,
            entry,
            background,
            scale: 2,
            size: const Size(320, 568),
          );
          expect(tester.takeException(), isNull);
        });
      });
    }
  }
}
