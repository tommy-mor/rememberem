import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/home_button.dart';
import '../memories/memory_tile.dart';
import '../settings/app_settings_controller.dart';
import 'countdown_button.dart';
import 'game_feedback.dart';
import 'mute_button.dart';
import 'quiz_result.dart';
import 'quiz_results_view.dart';

enum _Phase { loading, reveal, choose, finished, stopped }

/// Details practice: up to [turns] turns (no detail twice), each showing
/// a detail Fred wrote for a moment, then four people's photos with names. A first-try right pick
/// earns that detail a point; any miss resets the detail's points.
class DetailGameScreen extends StatefulWidget {
  const DetailGameScreen({
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
  final DetailQuizPlanner planner;
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
  State<DetailGameScreen> createState() => _DetailGameScreenState();
}

class _DetailGameScreenState extends State<DetailGameScreen>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.loading;
  int _turn = 0;

  /// Fixed when the first question is picked: [DetailGameScreen.turns], or
  /// fewer when there are fewer details.
  int? _total;
  final Set<String> _asked = {};
  DetailPair? _pair;
  List<Memory> _choices = [];
  final Set<String> _wrong = {};
  bool _missed = false;

  /// Whether this turn's miss was saved (it reset the points).
  bool _missSaved = false;
  bool _writing = false;

  /// One per finished turn, for the results.
  final List<QuizResult> _results = [];

  /// Set from a right pick until the next turn shows, so a second tap
  /// cannot score again or skip a turn.
  bool _advancing = false;

  /// How the current detail reads (its kind, extra data and text).
  DetailPrompt? _prompt;

  /// The person just picked rightly, shown green during the pause.
  String? _correctId;

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
        // Keep the detail off the app switcher and out of sight.
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
      _stop('Add a detail and have 4 people to practice.');
      return;
    }
    final eligible = planner.eligible(people);
    final pair = planner.pickNext(eligible, asked: _asked);
    if (pair == null) {
      _finish(); // every detail has been asked
      return;
    }
    _asked.add(pair.detail.id);
    setState(() {
      _total ??= eligible.length < widget.turns
          ? eligible.length
          : widget.turns;
      _turn++;
      _pair = pair;
      _choices = planner.choicesFor(pair.person, people);
      _wrong.clear();
      _missed = false;
      _missSaved = false;
      _advancing = false;
      _correctId = null;
      _said = null;
      _prompt = DetailQuizPlanner.promptFor(people)(pair.detail);
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

  Future<void> _choose(Memory picked) async {
    final pair = _pair;
    if (_writing || _advancing || _phase != _Phase.choose || pair == null) {
      return;
    }
    if (picked.id != pair.person.id) {
      widget.feedback?.wrong();
      setState(() {
        _wrong.add(picked.id);
        _said = 'Not ${MemoryTile.nameOf(picked)}.';
      });
      if (_missed) return; // one reset per turn is enough
      _missed = true;
      _missSaved = await _record(pair, correctFirstTry: false);
      return;
    }
    widget.feedback?.right();
    setState(() {
      _advancing = true;
      _correctId = picked.id;
      _said = 'Right: ${MemoryTile.nameOf(picked)}.';
    });
    final pause = Future<void>.delayed(widget.pauseAfterRight);
    final saved = _missed
        ? _missSaved
        : await _record(pair, correctFirstTry: true);
    _results.add(
      QuizResult.answered(
        person: pair.person,
        detail: pair.detail,
        detailText: _prompt?.full,
        rightFirstTry: !_missed,
        saved: saved,
      ),
    );
    await pause;
    if (_live) await _nextTurn();
  }

  /// Saves the answer; true if it was saved. Failures never stop the game.
  Future<bool> _record(DetailPair pair, {required bool correctFirstTry}) async {
    setState(() => _writing = true);
    try {
      await widget.repository.recordDetailAnswer(
        pair.person.id,
        pair.detail.id,
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
        title: Text(_turn == 0 ? 'Practice details' : 'Turn $_turn of $_turns'),
        leading: IconButton(
          tooltip: 'Stop practice',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (widget.settings case final settings?) MuteButton(settings),
          const HomeButton(),
        ],
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
      case _Phase.reveal:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _hidden
                ? const Icon(Icons.visibility_off, size: 64)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: _promptView(
                          theme,
                          theme.textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 24),
                      CountdownButton(
                        key: ValueKey(_turn),
                        label: 'Show people',
                        duration: widget.reveal,
                        running: !_hidden,
                        onPressed: _showChoices,
                      ),
                    ],
                  ),
          ),
        );
      case _Phase.choose:
        break;
    }
    if (_hidden) {
      return const Center(child: Icon(Icons.visibility_off, size: 64));
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _promptView(theme, theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              _said ?? 'Who is this about?',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
              children: [for (final m in _choices) _card(context, m)],
            ),
          ),
        ],
      ),
    );
  }

  /// The detail as it reads: its kind small above, then the words.
  Widget _promptView(ThemeData theme, TextStyle? style) {
    final prompt = _prompt!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(prompt.caption, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(prompt.full, textAlign: TextAlign.center, style: style),
      ],
    );
  }

  Widget _card(BuildContext context, Memory person) {
    final disabled = _wrong.contains(person.id) || _writing || _advancing;
    final name = MemoryTile.nameOf(person);
    return Semantics(
      button: true,
      enabled: !disabled,
      label: person.id == _correctId
          ? '$name, right'
          : _wrong.contains(person.id)
          ? '$name, not this one'
          : name,
      onTap: disabled ? null : () => _choose(person),
      excludeSemantics: true,
      child: Opacity(
        opacity: _wrong.contains(person.id) ? 0.35 : 1,
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: person.id == _correctId
              ? RoundedRectangleBorder(
                  side: BorderSide(color: Colors.green.shade600, width: 4),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: InkWell(
            onTap: disabled ? null : () => _choose(person),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Image.file(
                    widget.repository.photoFile(person),
                    fit: BoxFit.cover,
                    cacheWidth: 500,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.person, size: 48)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
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
