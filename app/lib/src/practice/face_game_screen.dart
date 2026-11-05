import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/home_button.dart';
import '../app/rememberem_theme.dart';
import '../settings/app_settings_controller.dart';
import 'answer_row.dart';
import 'countdown_button.dart';
import 'game_feedback.dart';
import 'mute_button.dart';
import 'quiz_progress_bar.dart';
import 'quiz_result.dart';
import 'quiz_results_view.dart';

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
    this.showDelay = true,
    this.pool,
    this.settings,
  });

  final MemoryRepository repository;
  final FaceQuizPlanner planner;
  final DateTime Function() clock;
  final Duration reveal;
  final int turns;
  final GameFeedback? feedback;

  /// How long a right answer shows before the next question.
  final Duration pauseAfterRight;

  /// Wait [reveal] (or a tap on Show) before the choices; false shows
  /// them at once.
  final bool showDelay;

  /// The ids of the people to play with (a filtered list), fixed when
  /// the game starts; null for everyone.
  final Set<String>? pool;

  /// For the mute button; null hides it (tests).
  final AppSettingsController? settings;

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
  Memory? _person;
  List<String> _choices = [];
  final Set<String> _wrong = {};
  bool _missed = false;

  /// Whether this turn's miss was saved (it reset the points).
  bool _missSaved = false;
  bool _writing = false;

  /// One per finished turn, for the results.
  final List<QuizResult> _results = [];

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nextTurn();
  }

  @override
  void dispose() {
    _ended = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        // Keep the face off the app switcher and out of sight; no scoring.
        // The Show countdown waits while hidden.
        setState(() => _hidden = true);
      case AppLifecycleState.resumed:
        setState(() => _hidden = false);
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _ended = true;
        if (mounted) Navigator.of(context).maybePop();
      case AppLifecycleState.detached:
        break;
    }
  }

  bool get _live => mounted && !_ended;

  List<Memory> _inPool(List<Memory> people) {
    final pool = widget.pool;
    return pool == null
        ? people
        : [
            for (final m in people)
              if (pool.contains(m.id)) m,
          ];
  }

  int get _turns => _total ?? widget.turns;

  Future<void> _nextTurn() async {
    if (_turn >= _turns) {
      _finish();
      return;
    }
    final List<Memory> people;
    try {
      people = _inPool(await widget.repository.all());
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
      _missSaved = false;
      _advancing = false;
      _correct = null;
      _said = null;
      _phase = widget.showDelay ? _Phase.reveal : _Phase.choose;
    });
  }

  void _showChoices() {
    if (_live && _phase == _Phase.reveal) {
      setState(() => _phase = _Phase.choose);
    }
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
      _missSaved = await _record(person, correctFirstTry: false);
      return;
    }
    widget.feedback?.right();
    setState(() {
      _advancing = true;
      _correct = name;
      _said = 'Right: $name.';
    });
    final pause = Future<void>.delayed(widget.pauseAfterRight);
    final saved = _missed
        ? _missSaved
        : await _record(person, correctFirstTry: true);
    _results.add(
      QuizResult.answered(
        person: person,
        rightFirstTry: !_missed,
        saved: saved,
      ),
    );
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

  /// How far through the turns: moving while loading, full at the end.
  double? get _progress => switch (_phase) {
    _Phase.loading => null,
    _Phase.finished => 1,
    _ => _turns == 0 ? 0 : _turn / _turns,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_turn == 0 ? 'Practice faces' : 'Turn $_turn of $_turns'),
        leading: IconButton(
          tooltip: 'Stop practice',
          icon: const Icon(Icons.close_rounded, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (widget.settings case final settings?) MuteButton(settings),
          const HomeButton(),
        ],
        bottom: QuizProgressBar(value: _progress),
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    switch (_phase) {
      case _Phase.loading:
        return const SizedBox.shrink();
      case _Phase.finished:
        return QuizResultsView(
          results: _results,
          threshold:
              widget.settings?.value.rememberedThreshold ??
              RememberedCount.defaultThreshold,
          photoOf: (r) => widget.repository.photoFile(r.person),
          feedback: widget.feedback,
          onDone: () => Navigator.of(context).maybePop(),
        );
      case _Phase.stopped:
        return _message(context, _stopReason);
      case _Phase.reveal || _Phase.choose:
        break;
    }
    final person = _person!;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The photo takes what the page leaves once the question and the
        // four answers have their room, and the same in the reveal as in
        // the choosing, so it never jumps when the names appear. Never
        // under 200 dp: the page scrolls instead.
        final line = MediaQuery.textScalerOf(context).scale(16) * 1.4;
        final double answers = 4 * math.max(54.0, line + 24) + 2;
        final double photo = math.max(
          200.0,
          constraints.maxHeight -
              2 * RememberemTheme.gutter -
              (12 + line + 8 + answers),
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(RememberemTheme.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: photo,
                child: _hidden
                    ? const Center(
                        child: Icon(Icons.visibility_off_rounded, size: 64),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          widget.repository.photoFile(person),
                          fit: BoxFit.cover,
                          semanticLabel:
                              'The face to name. This game needs sight; '
                              'Practice details works with a screen reader.',
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.person_rounded, size: 96),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _phase == _Phase.choose
                      ? (_said ?? 'Who is this?')
                      : 'Who is this?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // The names stay hidden until the countdown ends; their room
              // is kept so nothing moves when they come.
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: answers),
                child: _phase == _Phase.reveal
                    ? Align(
                        alignment: Alignment.topCenter,
                        child: CountdownButton(
                          key: ValueKey(_turn),
                          label: 'Show names',
                          duration: widget.reveal,
                          running: !_hidden,
                          onPressed: _showChoices,
                        ),
                      )
                    : _answers(context),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The four names in one rounded list.
  Widget _answers(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          children: [
            for (final (i, name) in _choices.indexed) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: RememberemTheme.rule(theme),
                ),
              AnswerRow(
                name: name,
                state: name == _correct
                    ? AnswerState.right
                    : _wrong.contains(name)
                    ? AnswerState.wrong
                    : AnswerState.open,
                onTap: _wrong.contains(name) || _writing || _advancing
                    ? null
                    : () => _choose(name),
              ),
            ],
          ],
        ),
      ),
    );
  }

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
