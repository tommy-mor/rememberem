import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_routes.dart';
import '../app/app_services.dart';
import '../app/brand_logo.dart';
import '../places/places_screen.dart';
import '../practice/practice_screens.dart';
import '../settings/settings_screen.dart';
import '../timeline/timeline_screen.dart';
import '../trash/trash_screen.dart';
import 'matching_screen.dart';
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

  @override
  State<MemoryListScreen> createState() => _MemoryListScreenState();
}

class _MemoryListScreenState extends State<MemoryListScreen> with RouteAware {
  MemoryRepository get _repository => widget.services.repository;
  List<Memory>? _memories;

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
    if (mounted && gen == _reloadGen) setState(() => _memories = memories);
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

  void _openMatching() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchingScreen(
          services: widget.services,
          routeObserver: widget.routeObserver,
        ),
      ),
    );
  }

  Future<void> _trash(Memory memory) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(
      () => _memories = [
        for (final m in _memories ?? <Memory>[])
          if (m.id != memory.id) m,
      ],
    );
    try {
      await _repository.trash(memory.id, widget.clock());
    } on Object {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not move ${MemoryTile.nameOf(memory)} to trash'),
        ),
      );
      await _reload();
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Moved ${MemoryTile.nameOf(memory)} to trash'),
          // Undo snackbars would otherwise stay until dismissed.
          persist: false,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _undoTrash(memory),
          ),
        ),
      );
    await _reload();
  }

  Future<void> _undoTrash(Memory memory) async {
    try {
      await _repository.restore(memory.id);
    } on StateError {
      // Already deleted forever from the Trash screen; nothing to undo.
    }
    await _reload();
  }

  void _openSettings() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          settings: widget.services.settings,
          reminders: widget.services.reminders,
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
        title: const BrandLogo(),
        actions: [
          IconButton(
            tooltip: 'Timeline',
            icon: const Icon(Icons.schedule),
            onPressed: _openTimeline,
          ),
          IconButton(
            tooltip: 'Match people',
            icon: const Icon(Icons.search),
            onPressed: _openMatching,
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // From the list as shown, so a trash or undo updates it at once.
            RememberedLabel(
              RememberedCount.of(
                memories,
                threshold: widget.services.settings.value.rememberedThreshold,
              ),
            ),
            const SizedBox(height: 4),
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
                    label: const Text('Faces'),
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
    if (memories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No one yet.\n\nTap "Meet someone" to take a photo. '
            'Tip: long-press the Rememberem icon and drag '
            '"Meet someone" to your home screen for a one-tap shortcut.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: memories.length,
      itemBuilder: (context, index) {
        final memory = memories[index];
        return MemoryTile(
          memory: memory,
          photo: _repository.photoFile(memory),
          onTap: () => _open(memory),
          trailing: IconButton(
            tooltip: 'Move to trash',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _trash(memory),
          ),
        );
      },
    );
  }
}
