import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/home_button.dart';
import 'game_feedback.dart';

enum _Phase { loading, reveal, choose, finished, stopped }

/// Face practice: up to [turns] turns, each showing a face for a moment
/// with no name, then four names to choose from. No one is asked twice in
/// a game, so with fewer people the game is shorter. A first-try right
/// answer earns the person a point; any miss resets their points.
class FaceGameScreen extends StatefulWidget {
  const FaceGameScreen({
    super.key,
    required this.repository,
    required this.planner,
    this.clock = DateTime.now,
    this.reveal = const Duration(seconds: 3),
    this.turns = 10,
    this.feedback,
    this.pauseAfterRight = const Duration(seconds: 1),
  });

  final MemoryRepository repository;
  final FaceQuizPlanner planner;
  final DateTime Function() clock;
  final Duration reveal;
  final int turns;
  final GameFeedback? feedback;

  /// How long a right answer shows before the next question.
  final Duration pauseAfterRight;

  @override
  State<FaceGameScreen> createState() => _FaceGameScreenState();
}

class _FaceGameScreenState extends State<FaceGameScreen>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.loading;
  int _turn = 0;

  /// Fixed when the first question is picked: [FaceGameScreen.turns], or
  /// fewer when there are fewer people.
  int? _total;
  final Set<String> _asked = {};
  int _rightFirstTry = 0;
  Memory? _person;
  List<String> _choices = [];
  final Set<String> _wrong = {};
  bool _missed = false;
  bool _writing = false;

  /// Set from a right answer until the next turn shows, so a second tap
  /// cannot score again or skip a turn.
  bool _advancing = false;

  /// The right answer just chosen, shown green during the pause.
  String? _correct;

  /// What the last answer was, spoken by screen readers as it changes.
  String? _said;
  bool _hidden = false;
  bool _ended = false;
  String _stopReason = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nextTurn();
  }

  @override
  void dispose() {
    _ended = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        // Keep the face off the app switcher and out of sight; no scoring.
        _timer?.cancel();
        setState(() => _hidden = true);
      case AppLifecycleState.resumed:
        setState(() => _hidden = false);
        if (_phase == _Phase.reveal) _startReveal();
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _ended = true;
        _timer?.cancel();
        if (mounted) Navigator.of(context).maybePop();
      case AppLifecycleState.detached:
        break;
    }
  }

  bool get _live => mounted && !_ended;

  int get _turns => _total ?? widget.turns;

  Future<void> _nextTurn() async {
    if (_turn >= _turns) {
      _finish();
      return;
    }
    final List<Memory> people;
    try {
      people = await widget.repository.all();
    } catch (_) {
      if (_live) _stop('Could not load people.');
      return;
    }
    if (!_live) return;
    final planner = widget.planner;
    if (!planner.canPlay(people)) {
      _stop('Name at least 4 different people to practice.');
      return;
    }
    final eligible = planner.eligible(people);
    final person = planner.pickNext(eligible, asked: _asked);
    if (person == null) {
      _finish(); // everyone has been asked
      return;
    }
    _asked.add(person.id);
    setState(() {
      _total ??= eligible.length < widget.turns
          ? eligible.length
          : widget.turns;
      _turn++;
      _person = person;
      _choices = planner.choicesFor(person, eligible);
      _wrong.clear();
      _missed = false;
      _advancing = false;
      _correct = null;
      _said = null;
      _phase = _Phase.reveal;
    });
    if (!_hidden) _startReveal();
  }

  /// With a screen reader on, the reveal waits for [_showChoices], so a
  /// timer never cuts the prompt off mid-sentence.
  bool get _paced => MediaQuery.accessibleNavigationOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A screen reader turned on or off mid-reveal: wait for the button, or
    // start the timer the button was standing in for.
    if (_phase == _Phase.reveal && !_hidden) {
      if (_paced) {
        _timer?.cancel();
      } else if (!(_timer?.isActive ?? false)) {
        _startReveal();
      }
    }
  }

  void _showChoices() {
    if (_live && _phase == _Phase.reveal) {
      setState(() => _phase = _Phase.choose);
    }
  }

  void _startReveal() {
    _timer?.cancel();
    if (_paced) return;
    _timer = Timer(widget.reveal, () {
      if (_live) setState(() => _phase = _Phase.choose);
    });
  }

  void _finish() => setState(() {
    _total = _turn;
    _phase = _Phase.finished;
  });

  void _stop(String reason) => setState(() {
    _phase = _Phase.stopped;
    _stopReason = reason;
  });

  Future<void> _choose(String name) async {
    final person = _person;
    if (_writing || _advancing || _phase != _Phase.choose || person == null) {
      return;
    }
    final right = name == person.field(MemoryField.name).trim();
    if (!right) {
      widget.feedback?.wrong();
      setState(() {
        _wrong.add(name);
        _said = 'Not $name.';
      });
      if (_missed) return; // one reset per turn is enough
      _missed = true;
      await _record(person, correctFirstTry: false);
      return;
    }
    widget.feedback?.right();
    setState(() {
      _advancing = true;
      _correct = name;
      _said = 'Right: $name.';
    });
    final pause = Future<void>.delayed(widget.pauseAfterRight);
    if (!_missed && await _record(person, correctFirstTry: true)) {
      _rightFirstTry++;
    }
    await pause;
    if (_live) await _nextTurn();
  }

  /// Saves the answer; true if it was saved. Failures never stop the game.
  Future<bool> _record(Memory person, {required bool correctFirstTry}) async {
    setState(() => _writing = true);
    try {
      await widget.repository.recordAnswer(
        person.id,
        correctFirstTry: correctFirstTry,
        at: widget.clock(),
      );
      return true;
    } catch (_) {
      return false; // gone or unwritable: no point, carry on
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_turn == 0 ? 'Practice faces' : 'Turn $_turn of $_turns'),
        leading: IconButton(
          tooltip: 'Stop practice',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: const [HomeButton()],
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    switch (_phase) {
      case _Phase.loading:
        return const Center(child: CircularProgressIndicator());
      case _Phase.finished:
        return _message(
          context,
          'Done: $_rightFirstTry of $_turns right first try.',
        );
      case _Phase.stopped:
        return _message(context, _stopReason);
      case _Phase.reveal || _Phase.choose:
        break;
    }
    final person = _person!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _hidden
                ? const Center(child: Icon(Icons.visibility_off, size: 64))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      widget.repository.photoFile(person),
                      fit: BoxFit.cover,
                      semanticLabel:
                          'The face to name. This game needs sight; '
                          'Practice details works with a screen reader.',
                      errorBuilder: (_, _, _) =>
                          const Center(child: Icon(Icons.person, size: 96)),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (_phase == _Phase.reveal) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  'Who is this?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
            if (_paced)
              FilledButton(
                onPressed: _showChoices,
                child: const Text('Show names'),
              ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _said ?? 'Who is this?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            for (final name in _choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton.tonal(
                  style: name == _correct ? _rightStyle : null,
                  onPressed: _wrong.contains(name) || _writing || _advancing
                      ? null
                      : () => _choose(name),
                  child: Text(name),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// The right answer, green even while the buttons are disabled.
  static final _rightStyle = FilledButton.styleFrom(
    disabledBackgroundColor: Colors.green.shade600,
    disabledForegroundColor: Colors.white,
  );

  Widget _message(BuildContext context, String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Back to list'),
          ),
        ],
      ),
    ),
  );
}
