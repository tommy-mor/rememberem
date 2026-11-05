import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../about/about_screen.dart';
import '../app/app_routes.dart';
import '../app/app_services.dart';
import '../app/brand_logo.dart';
import '../app/empty_state.dart';
import '../app/rememberem_theme.dart';
import '../app/section_header.dart';
import '../places/places_screen.dart';
import '../practice/filtered_practice_screen.dart';
import '../practice/practice_screens.dart';
import '../settings/settings_screen.dart';
import '../timeline/timeline_screen.dart';
import '../trash/trash_screen.dart';
import 'date_groups.dart';
import 'filter_bar.dart';
import 'filter_match_lines.dart';
import 'home_bottom_bar.dart';
import 'memory_tile.dart';
import 'person_card_route.dart';
import 'progress_badge.dart';

/// Home screen: everyone you have met, newest first, narrowed and sorted
/// by the filters above them ([AppServices.listFilters]).
class MemoryListScreen extends StatefulWidget {
  const MemoryListScreen({
    super.key,
    required this.services,
    required this.routeObserver,
    required this.onMeetSomeone,
    this.clock = DateTime.now,
  });

  final AppServices services;

  /// Tells the list when screens above it close, so it can refresh.
  final RouteObserver<ModalRoute<void>> routeObserver;
  final VoidCallback onMeetSomeone;
  final DateTime Function() clock;

  /// Said above the list when some records could not be read.
  static String unreadableText(int count) => count == 1
      ? "1 record couldn't be read. It is kept on this phone, untouched."
      : "$count records couldn't be read. They are kept on this phone, "
            'untouched.';

  @override
  State<MemoryListScreen> createState() => _MemoryListScreenState();
}

class _MemoryListScreenState extends State<MemoryListScreen>
    with RouteAware, WidgetsBindingObserver {
  MemoryRepository get _repository => widget.services.repository;
  List<Memory>? _memories;

  /// Everyone shown, by id, for relationships in the match lines.
  Map<String, String> _activeNames = const {};

  /// How many record files the last load could not read.
  int _unreadable = 0;

  /// Only used to decide whether there are enough people to practice.
  final _facePlanner = FaceQuizPlanner(Random(), DateTime.now);
  final _detailPlanner = DetailQuizPlanner(Random(), DateTime.now);

  /// Only the newest reload may update the list, so an old, slow one can
  /// never overwrite a later trash or undo.
  int _reloadGen = 0;

  /// The reminder permission is asked at most once per run, from here.
  bool _askedReminders = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  /// The date groups follow the clock, so a list left open past midnight
  /// (or past Monday) is regrouped when the app comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) widget.routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _reload();
    // A place may have been named, moved or resized.
    unawaited(
      widget.services.placeNotices?.sync().catchError(
        (Object e) =>
            debugPrint('Rememberem: place sync failed: ${e.runtimeType}'),
      ),
    );
    // An anniversary may have been added or changed.
    unawaited(
      widget.services.reminders?.sync().catchError(
        (Object e) =>
            debugPrint('Rememberem: reminder sync failed: ${e.runtimeType}'),
      ),
    );
  }

  Future<void> _reload() async {
    final gen = ++_reloadGen;
    final memories = await _repository.all();
    final unreadable = _repository.unreadable;
    if (unreadable.isNotEmpty) {
      debugPrint('Rememberem: could not read ${unreadable.join(', ')}');
    }
    if (mounted && gen == _reloadGen) {
      setState(() {
        _memories = memories;
        _activeNames = {for (final m in memories) m.id: m.displayName};
        _unreadable = unreadable.length;
      });
    }
    _maybeAskReminders(memories);
  }

  /// Reminders start on; their permission is asked once, at a calm moment:
  /// back on the list with someone saved, never over the camera.
  void _maybeAskReminders(List<Memory> memories) {
    final reminders = widget.services.reminders;
    if (_askedReminders || reminders == null || memories.isEmpty) return;
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    _askedReminders = true;
    reminders.askOnce().catchError(
      (Object e) =>
          debugPrint('Rememberem: reminder ask failed: ${e.runtimeType}'),
    );
  }

  void _open(Memory memory) =>
      Navigator.of(context)
          .push(PersonCardRoute(services: widget.services, memory: memory));

  void _openTimeline() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TimelineScreen(
          services: widget.services,
          routeObserver: widget.routeObserver,
          onMeetSomeone: widget.onMeetSomeone,
        ),
      ),
    );
  }

  void _openPlaces() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlacesScreen(
          services: widget.services,
          routeObserver: widget.routeObserver,
        ),
      ),
    );
  }

  void _openSettings() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          settings: widget.services.settings,
          links: widget.services.links,
          reminders: widget.services.reminders,
          placeNotices: widget.services.placeNotices,
        ),
      ),
    );
  }

  void _openAbout() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AboutScreen(
          links: widget.services.links,
          reminders: widget.services.reminders,
          placeNotices: widget.services.placeNotices,
        ),
      ),
    );
  }

  void _openTrash() {
    // A pending Undo must not act on someone the Trash screen is showing.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrashScreen(repository: _repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Tooltip(
          message: 'About',
          child: InkWell(
            onTap: _openAbout,
            // A full 48 dp to tap, whatever the logo's height.
            child: const SizedBox(
              height: RememberemTheme.tapTarget,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: BrandLogo(),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Timeline',
            icon: const Icon(Icons.schedule_rounded, size: 22),
            onPressed: _openTimeline,
          ),
          IconButton(
            tooltip: 'Places',
            icon: const Icon(Icons.place_rounded, size: 22),
            onPressed: _openPlaces,
          ),
          IconButton(
            tooltip: 'Trash',
            icon: const Icon(Icons.delete_rounded, size: 22),
            onPressed: _openTrash,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_rounded, size: 22),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _body(),
      bottomNavigationBar: _bottomBar(),
    );
  }

  /// Practice, what is remembered, and Meet, along the bottom.
  Widget _bottomBar() {
    final memories = _memories ?? const <Memory>[];
    return HomeBottomBar(
      // From the list as shown, so a trash or undo updates it at once.
      remembered: RememberedCount.of(
        memories,
        threshold: widget.services.settings.value.rememberedThreshold,
      ),
      showPractice: memories.isNotEmpty,
      canPlayFaces: _facePlanner.canPlay(memories),
      canPlayDetails: _detailPlanner.canPlay(memories),
      onFaces: _practiceFaces,
      onDetails: _practiceDetails,
      onMeet: widget.onMeetSomeone,
    );
  }

  void _practiceFaces() => _practice(PracticeGame.faces);

  void _practiceDetails() => _practice(PracticeGame.details);

  /// Plays [game]; on a filtered list, first asks whether to play with
  /// the filtered people or everyone.
  void _practice(PracticeGame game) {
    final filters = widget.services.listFilters;
    // The practice buttons show only once the list has loaded.
    final memories = _memories!;
    if (!filters.isFiltered) {
      _openGame(PracticeScreens.build(game, widget.services));
      return;
    }
    _openGame(
      FilteredPracticeScreen(
        game: game,
        services: widget.services,
        filters: filters.active,
        filtered: filters.apply(memories),
      ),
      fullscreenDialog: true,
    );
  }

  void _openGame(Widget game, {bool fullscreenDialog = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: fullscreenDialog,
        settings: const RouteSettings(name: AppRoutes.practice),
        builder: (_) => game,
      ),
    );
  }

  Widget _body() {
    final memories = _memories;
    if (memories == null) {
      return const Align(
        alignment: Alignment.topCenter,
        child: LinearProgressIndicator(minHeight: 3, semanticsLabel: 'Loading'),
      );
    }
    if (_unreadable == 0) return _people(memories);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            MemoryListScreen.unreadableText(_unreadable),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        Expanded(child: _people(memories)),
      ],
    );
  }

  Widget _people(List<Memory> memories) {
    if (memories.isEmpty) {
      return const EmptyState(
        title: 'No one yet.',
        help:
            'Tap "Meet" to take a photo. '
            'Tip: long-press the Rememberem icon and drag '
            '"Meet someone" to your home screen for a one-tap shortcut.'
            '\n\nRememberem will ask to use the camera, the microphone and '
            'your location. Photos and notes are kept on this phone, and in '
            'its Google backup if that is on (see About).',
      );
    }
    final filters = widget.services.listFilters;
    return ListenableBuilder(
      listenable: filters,
      builder: (context, _) {
        final shown = filters.apply(memories);
        final active = filters.active;
        // Groups by date met only when sorted by it; otherwise no headers.
        final dated = filters.order.sort == PersonSort.date;
        final rows = <Object>[
          if (dated)
            for (final group in DateGroups(widget.clock).group(
              shown,
              (m) => m.capturedAt,
            )) ...[group.label, ...group.items]
          else
            ...shown,
        ];
        // The filter bar is the first item, so it scrolls with the list.
        return ListView.builder(
          itemCount: rows.length + (shown.isEmpty ? 2 : 1),
          itemBuilder: (context, index) {
            if (index == 0) {
              return FilterBar(
                filters: filters,
                people: memories,
                shown: shown.length,
              );
            }
            if (shown.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(RememberemTheme.gutter),
                child: Text('No one matches.'),
              );
            }
            final row = rows[index - 1];
            return row is Memory
                ? _tile(context, row, active)
                : SectionHeader(title: row as String, tinted: false);
          },
        );
      },
    );
  }

  Widget _tile(
    BuildContext context,
    Memory memory,
    List<FilterCondition> active,
  ) {
    return MemoryTile(
      memory: memory,
      photo: _repository.photoFile(memory),
      onTap: () => _open(memory),
      below: active.isEmpty
          ? null
          : FilterMatchLines(
              memory: memory,
              filters: active,
              nameOf: (id) => _activeNames[id],
            ),
      // A face's progress toward remembered; nothing until it scores.
      trailing: memory.points == 0
          ? null
          : ProgressBadge(
              points: memory.points,
              threshold: widget.services.settings.value.rememberedThreshold,
            ),
    );
  }
}
