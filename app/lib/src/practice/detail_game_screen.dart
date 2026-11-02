import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../memories/memory_tile.dart';
import 'game_feedback.dart';

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
  });

  final MemoryRepository repository;
  final DetailQuizPlanner planner;
  final DateTime Function() clock;
  final Duration reveal;
  final int turns;
  final GameFeedback? feedback;

  /// How long a right answer shows before the next question.
  final Duration pauseAfterRight;

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
  int _rightFirstTry = 0;
  DetailPair? _pair;
  List<Memory> _choices = [];
  final Set<String> _wrong = {};
  bool _missed = false;
  bool _writing = false;

  /// Set from a right pick until the next turn shows, so a second tap
  /// cannot score again or skip a turn.
  bool _advancing = false;

  /// How the current detail reads (its kind, extra data and text).
  DetailPrompt? _prompt;

  /// The person just picked rightly, shown green during the pause.
  String? _correctId;
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
        // Keep the detail off the app switcher and out of sight.
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
      _advancing = false;
      _correctId = null;
      _prompt = DetailQuizPlanner.promptFor(people)(pair.detail);
      _phase = _Phase.reveal;
    });
    if (!_hidden) _startReveal();
  }

  void _startReveal() {
    _timer?.cancel();
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

  Future<void> _choose(Memory picked) async {
    final pair = _pair;
    if (_writing || _advancing || _phase != _Phase.choose || pair == null) {
      return;
    }
    if (picked.id != pair.person.id) {
      widget.feedback?.wrong();
      setState(() => _wrong.add(picked.id));
      if (_missed) return; // one reset per turn is enough
      _missed = true;
      await _record(pair, correctFirstTry: false);
      return;
    }
    widget.feedback?.right();
    setState(() {
      _advancing = true;
      _correctId = picked.id;
    });
    final pause = Future<void>.delayed(widget.pauseAfterRight);
    if (!_missed && await _record(pair, correctFirstTry: true)) {
      _rightFirstTry++;
    }
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
      case _Phase.reveal:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _hidden
                ? const Icon(Icons.visibility_off, size: 64)
                : _promptView(theme, theme.textTheme.headlineSmall),
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
          Text('Who is this about?', style: theme.textTheme.bodyMedium),
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
      label: name,
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
