import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/app/rememberem_theme.dart';
import 'package:rememberem/src/memories/filter_match_lines.dart';
import 'package:rememberem/src/memories/home_bottom_bar.dart';
import 'package:rememberem/src/memories/memory_list_screen.dart';
import 'package:rememberem/src/memories/progress_badge.dart';
import 'package:rememberem/src/trash/trash_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

/// Home as a ledger: date groups, the count bar, the bottom bar; and Trash
/// grouped by when people were trashed. Thursday 5 Nov 2026: this week
/// began Monday 2 Nov, last week Monday 26 Oct.
void main() {
  late FakeMemoryRepository repository;
  late AppServices services;
  var now = DateTime(2026, 11, 5, 12);

  Future<Memory> person(
    String name, {
    required DateTime met,
    String place = '',
    int points = 0,
  }) async {
    final memory = await repository.add(
      photoJpeg: [],
      capturedAt: met,
      place: place,
    );
    final named = memory.withField('name', name);
    await repository.save(named);
    if (points > 0) {
      for (var i = 0; i < points; i++) {
        await repository.recordAnswer(
          memory.id,
          correctFirstTry: true,
          at: DateTime.utc(2026),
        );
      }
    }
    return named;
  }

  Future<void> showHome(WidgetTester tester) async {
    final observer = RouteObserver<ModalRoute<void>>();
    await tester.pumpWidget(
      MaterialApp(
        theme: RememberemTheme.light(const AppSettings(rememberedThreshold: 5)),
        navigatorObservers: [observer],
        home: MemoryListScreen(
          services: services,
          routeObserver: observer,
          onMeetSomeone: () {},
          clock: () => now,
        ),
      ),
    );
    await tester.pump();
  }

  /// The button around a tooltip: its tap area, bigger than its icon.
  Finder buttonFor(String tooltip) => find.ancestor(
    of: find.byTooltip(tooltip),
    matching: find.byType(IconButton),
  );

  setUp(() {
    now = DateTime(2026, 11, 5, 12);
    repository = FakeMemoryRepository();
    services = testServices(
      repository,
      settings: const AppSettings(streetMaps: false, rememberedThreshold: 5),
    );
  });

  group('Home', () {
    testWidgets('groups by date met, newest first, with a header each', (
      tester,
    ) async {
      await person('Ann', met: DateTime(2026, 11, 3));
      await person('Bo', met: DateTime(2026, 10, 28));
      await person('Cy', met: DateTime(2026, 10, 3));
      await person('Di', met: DateTime(2025, 10, 3));
      await showHome(tester);

      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('LAST WEEK'), findsOneWidget);
      expect(find.text('OCTOBER'), findsOneWidget);
      expect(find.text('OCTOBER 2025'), findsOneWidget);
      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('Ann'), lessThan(y('LAST WEEK')));
      expect(y('Bo'), lessThan(y('OCTOBER')));
      expect(y('Cy'), lessThan(y('OCTOBER 2025')));
      expect(find.text('TODAY'), findsNothing);
    });

    testWidgets('the newest encounter decides the group', (tester) async {
      final ann = await person('Ann', met: DateTime(2025, 3, 3));
      await repository.save(
        Memory(
          id: ann.id,
          fields: ann.fields,
          encounters: [
            ...ann.encounters,
            Encounter(
              photoFileName: '${ann.id}.b.jpg',
              capturedAt: DateTime(2026, 11, 4),
            ),
          ],
        ),
      );
      await showHome(tester);

      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('MARCH 2025'), findsNothing);
    });

    testWidgets('a filter that empties a group takes its header away', (
      tester,
    ) async {
      await person('Ann', met: DateTime(2026, 11, 3), place: 'Cafe');
      await person('Bo', met: DateTime(2026, 10, 28), place: 'Park');
      await showHome(tester);
      expect(find.text('LAST WEEK'), findsOneWidget);

      services.listFilters.show([const PlaceFilter('Cafe')]);
      await tester.pump();

      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('LAST WEEK'), findsNothing);
      expect(find.text('1 person'), findsOneWidget);
    });

    testWidgets('sorted by name there are no date headers; oldest first '
        'reverses the groups', (tester) async {
      await person('Ann', met: DateTime(2026, 11, 3));
      await person('Bo', met: DateTime(2026, 10, 28));
      await showHome(tester);

      services.listFilters.sortBy(PersonSort.date); // again: oldest first
      await tester.pump();
      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('LAST WEEK'), lessThan(y('THIS WEEK')));

      services.listFilters.sortBy(PersonSort.firstName);
      await tester.pump();
      expect(find.text('THIS WEEK'), findsNothing);
      expect(find.text('LAST WEEK'), findsNothing);
      expect(find.text('Ann'), findsOneWidget);
    });

    testWidgets('the groups are regrouped on resume, after Monday 00:00 '
        'passes', (tester) async {
      now = DateTime(2026, 11, 8, 23, 59); // Sunday night
      await person('Ann', met: DateTime(2026, 11, 7));
      await showHome(tester);
      expect(find.text('THIS WEEK'), findsOneWidget);

      now = DateTime(2026, 11, 9, 0, 1); // Monday
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(find.text('THIS WEEK'), findsNothing);
      expect(find.text('LAST WEEK'), findsOneWidget);
    });

    testWidgets('a row is a 38 x 48 photo, at least 58 dp tall, and the match '
        'lines start at 66 dp', (tester) async {
      await person('Ann', met: DateTime(2026, 11, 3), place: 'Cafe');
      await showHome(tester);
      services.listFilters.show([const NameFilter('Ann')]);
      await tester.pump();

      final tile = find.widgetWithText(ListTile, 'Ann');
      expect(tester.getSize(tile).height, greaterThanOrEqualTo(58));
      final photo = find.descendant(of: tile, matching: find.byType(ClipRRect));
      expect(tester.getSize(photo.first), const Size(38, 48));
      final lines = tester.getTopLeft(find.byType(FilterMatchLines)).dx;
      expect(lines - tester.getTopLeft(tile).dx, 66);
      expect(find.byType(CircleAvatar), findsNothing);
    });

    testWidgets('a long place and meeting wrap to two lines', (tester) async {
      await person(
        'Ann',
        met: DateTime(2026, 11, 3),
        place: 'The Very Long Named Community Centre By The Old Station',
      );
      await showHome(tester);
      final subtitle = tester.widget<ListTile>(find.byType(ListTile)).subtitle!;
      expect((subtitle as Text).maxLines, 2);
    });

    testWidgets('the app bar actions are 48 dp and fit at 320 dp, with the '
        'logo, so no overflow menu', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await person('Ann', met: DateTime(2026, 11, 3));
      await showHome(tester);

      for (final tip in ['Timeline', 'Places', 'Trash', 'Settings']) {
        final size = tester.getSize(buttonFor(tip));
        expect(size.width, greaterThanOrEqualTo(48), reason: tip);
        expect(size.height, greaterThanOrEqualTo(48), reason: tip);
      }
      expect(
        tester.getSize(find.byTooltip('About')).height,
        greaterThanOrEqualTo(48),
      );
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the count bar and bottom bar offer Filter, sort, Faces, '
        'Details and Meet', (tester) async {
      await person('Ann', met: DateTime(2026, 11, 3));
      await showHome(tester);

      expect(find.text('1 person'), findsOneWidget);
      expect(find.byTooltip('Add filter'), findsOneWidget);
      expect(find.text('Date met'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Faces'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Details'), findsOneWidget);
      // The quiz label sits above the buttons, at the gutter.
      final label = find.text(HomeBottomBar.quizzesLabel);
      expect(label, findsOneWidget);
      expect(tester.getTopLeft(label).dx, 16);
      expect(
        tester.getBottomLeft(label).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.widgetWithText(OutlinedButton, 'Faces')).dy,
        ),
      );
      expect(
        tester.getSize(find.byTooltip('Meet someone')).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('an empty Home says so, flush left at the gutter, with Meet '
        'still on offer', (tester) async {
      await showHome(tester);

      expect(find.text('No one yet.'), findsOneWidget);
      expect(tester.getTopLeft(find.text('No one yet.')).dx, 16);
      expect(find.byTooltip('Meet someone'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Faces'), findsNothing);
      expect(find.text(HomeBottomBar.quizzesLabel), findsNothing);
      // The copy names the button as it reads: "Meet".
      expect(find.textContaining('Tap "Meet" to take a photo'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Meet'), findsOneWidget);
    });

    testWidgets('loading is a linear bar, not a spinner', (tester) async {
      await person('Ann', met: DateTime(2026, 11, 3));
      final observer = RouteObserver<ModalRoute<void>>();
      await tester.pumpWidget(
        MaterialApp(
          home: MemoryListScreen(
            services: services,
            routeObserver: observer,
            onMeetSomeone: () {},
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .semanticsLabel,
        'Loading',
      );
      await tester.pump();
    });
  });

  group('progress badge', () {
    testWidgets('a 48 x 6 bar with the old words, then a green check', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Column(
            children: [
              ProgressBadge(points: 2, threshold: 5),
              ProgressBadge(points: 5, threshold: 5),
            ],
          ),
        ),
      );
      final bar = find.byType(ProgressBadge).first;
      expect(
        tester.getSize(
          find.descendant(of: bar, matching: find.byType(Container)).first,
        ),
        const Size(48, 6),
      );
      expect(
        find.bySemanticsLabel('Face: 2 of 5 right answers to remember'),
        findsOneWidget,
      );
      expect(find.byTooltip('2 of 5 right'), findsOneWidget);
      expect(find.bySemanticsLabel('Name remembered'), findsOneWidget);
      expect(find.byTooltip('Name remembered'), findsOneWidget);
      final check = tester.widget<Icon>(
        find.byIcon(Icons.check_circle_rounded),
      );
      expect(check.color, RememberemTheme.rememberedGreen);
      expect(check.size, 20);
      handle.dispose();
    });
  });

  group('Trash', () {
    Future<void> showTrash(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrashScreen(repository: repository, clock: () => now),
        ),
      );
      await tester.pump();
    }

    testWidgets('groups by when they were trashed: Today, This week, months, '
        'with the count in the title', (tester) async {
      final ann = await person('Ann', met: DateTime(2026, 1, 1));
      final bo = await person('Bo', met: DateTime(2026, 1, 1));
      final cy = await person('Cy', met: DateTime(2026, 1, 1));
      await repository.trash(ann.id, DateTime(2026, 11, 5, 8).toUtc());
      await repository.trash(bo.id, DateTime(2026, 11, 3).toUtc());
      await repository.trash(cy.id, DateTime(2026, 10, 3).toUtc());
      await showTrash(tester);

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('OCTOBER'), findsOneWidget);
      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('TODAY'), lessThan(y('Ann')));
      expect(y('Ann'), lessThan(y('THIS WEEK')));
      expect(y('Bo'), lessThan(y('OCTOBER')));
      expect(find.text('Trash  3'), findsOneWidget);
    });

    testWidgets('Restore is a labelled pill, deleting forever is an icon in '
        'the error colour, and there is no Empty trash', (tester) async {
      final ann = await person('Ann', met: DateTime(2026, 1, 1));
      await repository.trash(ann.id, DateTime(2026, 11, 5, 8).toUtc());
      await showTrash(tester);

      expect(find.text('Restore'), findsOneWidget);
      expect(find.byTooltip('Restore'), findsOneWidget);
      expect(find.textContaining('Empty trash'), findsNothing);
      expect(find.byTooltip('Empty trash'), findsNothing);
      final forever = tester.widget<Icon>(
        find.byIcon(Icons.delete_forever_rounded),
      );
      expect(
        forever.color,
        Theme.of(tester.element(find.byType(TrashScreen))).colorScheme.error,
      );
      expect(
        tester.getSize(buttonFor('Delete forever')).width,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('empty says what the Trash is for', (tester) async {
      await showTrash(tester);
      expect(find.text('Trash is empty.'), findsOneWidget);
      expect(
        find.text('People you delete wait here until you delete them forever.'),
        findsOneWidget,
      );
    });
  });
}
