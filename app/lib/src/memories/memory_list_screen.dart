import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../about/about_screen.dart';
import '../app/app_routes.dart';
import '../app/app_services.dart';
import '../app/brand_logo.dart';
import '../places/places_screen.dart';
import '../practice/practice_screens.dart';
import '../settings/settings_screen.dart';
import '../timeline/timeline_screen.dart';
import '../trash/trash_screen.dart';
import 'filter_list_screen.dart';
import 'memory_tile.dart';
import 'person_card_route.dart';
import 'remembered_label.dart';

/// Home screen: everyone you have met, newest first.
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

  /// What a screen reader says for the Faces practice button.
  static const facesLabel =
      'Practice faces. Needs sight; Practice details works with a screen '
      'reader.';

  /// Said above the list when some records could not be read.
  static String unreadableText(int count) => count == 1
      ? "1 record couldn't be read. It is kept on this phone, untouched."
      : "$count records couldn't be read. They are kept on this phone, "
            'untouched.';

  @override
  State<MemoryListScreen> createState() => _MemoryListScreenState();
}

class _MemoryListScreenState extends State<MemoryListScreen> with RouteAware {
  MemoryRepository get _repository => widget.services.repository;
  List<Memory>? _memories;

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
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) widget.routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    widget.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => _reload();

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
      (Object e) => debugPrint('Rememberem: reminder ask failed: $e'),
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

  void _openFilterList() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FilterListScreen(
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
          placeAlerts: widget.services.placeAlerts,
        ),
      ),
    );
  }

  void _openAbout() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AboutScreen(links: widget.services.links),
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
          child: InkWell(onTap: _openAbout, child: const BrandLogo()),
        ),
        actions: [
          IconButton(
            tooltip: 'Timeline',
            icon: const Icon(Icons.schedule),
            onPressed: _openTimeline,
          ),
          IconButton(
            tooltip: 'Filter List',
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterList,
          ),
          IconButton(
            tooltip: 'Places',
            icon: const Icon(Icons.place),
            onPressed: _openPlaces,
          ),
          IconButton(
            tooltip: 'Trash',
            icon: const Icon(Icons.delete),
            onPressed: _openTrash,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _body(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onMeetSomeone,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Meet someone'),
      ),
      bottomNavigationBar: _practiceBar(),
    );
  }

  /// Practice controls along the bottom, below the "Meet someone" button.
  Widget? _practiceBar() {
    final memories = _memories;
    if (memories == null || memories.isEmpty) return null;
    final canPlayFaces = _facePlanner.canPlay(memories);
    final canPlayDetails = _detailPlanner.canPlay(memories);
    final small = Theme.of(context).textTheme.bodySmall;
    final remembered = RememberedCount.of(
      memories,
      threshold: widget.services.settings.value.rememberedThreshold,
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // From the list as shown, so a trash or undo updates it at once.
            if (remembered.isNothing)
              const SizedBox.shrink()
            else ...[
              RememberedLabel(remembered),
              const SizedBox(height: 4),
            ],
            if (!canPlayFaces)
              Text(
                'Name at least 4 different people to practice faces.',
                textAlign: TextAlign.center,
                style: small,
              ),
            if (!canPlayDetails)
              Text(
                'Add a detail and have 4 people to practice details.',
                textAlign: TextAlign.center,
                style: small,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canPlayFaces ? _practiceFaces : null,
                    icon: const Icon(Icons.face),
                    label: const Text(
                      'Faces',
                      semanticsLabel: MemoryListScreen.facesLabel,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canPlayDetails ? _practiceDetails : null,
                    icon: const Icon(Icons.notes),
                    label: const Text('Details'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _practiceFaces() =>
      _openGame(PracticeScreens.build(PracticeGame.faces, widget.services));

  void _practiceDetails() =>
      _openGame(PracticeScreens.build(PracticeGame.details, widget.services));

  void _openGame(Widget game) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.practice),
        builder: (_) => game,
      ),
    );
  }

  Widget _body() {
    final memories = _memories;
    if (memories == null) {
      return const Center(child: CircularProgressIndicator());
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No one yet.\n\nTap "Meet someone" to take a photo. '
            'Tip: long-press the Rememberem icon and drag '
            '"Meet someone" to your home screen for a one-tap shortcut.'
            '\n\nRememberem will ask to use the camera, the microphone and '
            'your location. Photos and notes are kept on this phone, and in '
            'its Google backup if that is on (see About).',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: memories.length,
      itemBuilder: (context, index) {
        final memory = memories[index];
        final points = MemoryTile.pointsOf(memory);
        return MemoryTile(
          memory: memory,
          photo: _repository.photoFile(memory),
          onTap: () => _open(memory),
          trailing: points == 0
              ? null
              : Tooltip(
                  message: '$points practice points',
                  child: Badge(
                    label: Text('$points'),
                    largeSize: 20,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    textColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
        );
      },
    );
  }
}
