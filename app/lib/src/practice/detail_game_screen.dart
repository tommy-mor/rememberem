import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/home_button.dart';
import '../app/rememberem_theme.dart';
import '../memories/memory_tile.dart';
import '../settings/app_settings_controller.dart';
import 'countdown_button.dart';
import 'detail_prompt_block.dart';
import 'game_feedback.dart';
import 'mute_button.dart';
import 'quiz_progress_bar.dart';
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
        title: Text(_turn == 0 ? 'Practice details' : 'Turn $_turn of $_turns'),
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
      case _Phase.reveal:
        if (_hidden) {
          return const Center(
            child: Icon(Icons.visibility_off_rounded, size: 64),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            RememberemTheme.gutter,
            24,
            RememberemTheme.gutter,
            RememberemTheme.gutter,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DetailPromptBlock(
                prompt: _prompt!,
                question: 'Who is this about?',
                announce: true,
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
        );
      case _Phase.choose:
        break;
    }
    if (_hidden) {
      return const Center(child: Icon(Icons.visibility_off_rounded, size: 64));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Each photo takes what is left once the prompt and the two name
        // strips have their room: 120 to 188 dp. When even 120 does not
        // fit (large text, a phone on its side) the whole page scrolls.
        final scaler = MediaQuery.textScalerOf(context);
        final prompt = scaler.scale(14) * 1.4 + 8 + scaler.scale(21) * 1.25 * 3;
        final strip = _stripHeight(context);
        const gap = 10.0;
        final space =
            (constraints.maxHeight -
                    2 * RememberemTheme.gutter -
                    prompt -
                    16 -
                    gap) /
                2 -
            strip;
        final photo = space.clamp(120.0, 188.0);
        final width =
            (constraints.maxWidth - 2 * RememberemTheme.gutter - gap) / 2;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(RememberemTheme.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DetailPromptBlock(
                prompt: _prompt!,
                question: _said ?? 'Who is this about?',
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _choices.length; i += 2) ...[
                if (i > 0) const SizedBox(height: gap),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _card(context, _choices[i], width, photo, strip),
                    const SizedBox(width: gap),
                    if (i + 1 < _choices.length)
                      _card(context, _choices[i + 1], width, photo, strip)
                    else
                      SizedBox(width: width),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// The strip under a photo: two lines of name, 48 dp at the least.
  double _stripHeight(BuildContext context) =>
      math.max(48.0, MediaQuery.textScalerOf(context).scale(14) * 1.3 * 2 + 16);

  Widget _card(
    BuildContext context,
    Memory person,
    double width,
    double photoHeight,
    double stripHeight,
  ) {
    final disabled = _wrong.contains(person.id) || _writing || _advancing;
    final right = person.id == _correctId;
    final wrong = _wrong.contains(person.id);
    final name = MemoryTile.nameOf(person);
    return SizedBox(
      width: width,
      child: Semantics(
        container: true,
        button: true,
        enabled: !disabled || right,
        selected: right,
        label: right
            ? '$name, right'
            : wrong
            ? '$name, not this one'
            : name,
        onTap: disabled ? null : () => _choose(person),
        excludeSemantics: true,
        child: Opacity(
          opacity: wrong ? 0.35 : 1,
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              side: right
                  ? const BorderSide(
                      color: RememberemTheme.rememberedGreen,
                      width: 3,
                    )
                  : BorderSide(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.2),
                    ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: disabled ? null : () => _choose(person),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: photoHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          widget.repository.photoFile(person),
                          fit: BoxFit.cover,
                          cacheWidth: 500,
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.person_rounded, size: 48),
                          ),
                        ),
                        if (right)
                          const Positioned(
                            top: 6,
                            right: 6,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: RememberemTheme.rememberedGreen,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: stripHeight,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
