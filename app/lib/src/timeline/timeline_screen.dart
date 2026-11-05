import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import '../app/empty_state.dart';
import '../app/home_button.dart';
import '../app/rememberem_theme.dart';
import '../app/section_header.dart';
import '../memories/memory_tile.dart';
import '../memories/person_card_route.dart';
import 'timeline_miniature.dart';

/// Timeline mode: each day people were met, newest first, grouped by
/// place and meeting; the "Details" switch adds the days of their happenings,
/// dated tags and latest anniversaries. Tapping a date shows just that
/// day. Read-only.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({
    super.key,
    required this.services,
    required this.routeObserver,
    this.day,
    this.onMeetSomeone,
  });

  final AppServices services;
  final RouteObserver<ModalRoute<void>> routeObserver;

  /// Show only this day, or every day if null.
  final LocalDay? day;

  /// What "Meet someone" does on an empty timeline; null leaves the
  /// button out.
  final VoidCallback? onMeetSomeone;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> with RouteAware {
  List<TimelineDay>? _days;
  Object? _error;
  int _reloadGen = 0;

  @override
  void initState() {
    super.initState();
    widget.services.timelineDetails.addListener(_reload);
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
    widget.services.timelineDetails.removeListener(_reload);
    widget.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => _reload();

  Future<void> _reload() async {
    final gen = ++_reloadGen;
    try {
      final people = await widget.services.repository.all();
      final days = const TimelineBuilder().build(
        people,
        only: widget.day,
        details: widget.services.timelineDetails.value,
      );
      if (mounted && gen == _reloadGen) {
        setState(() {
          _days = days;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && gen == _reloadGen) setState(() => _error = error);
    }
  }

  void _openDay(LocalDay day) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TimelineScreen(
        services: widget.services,
        routeObserver: widget.routeObserver,
        day: day,
        onMeetSomeone: widget.onMeetSomeone,
      ),
    ),
  );

  void _openPerson(Memory memory) =>
      Navigator.of(context)
          .push(PersonCardRoute(services: widget.services, memory: memory));

  String _dayLabel(LocalDay day) =>
      MaterialLocalizations.of(context).formatFullDate(day.toDate());

  /// The people on a day, each once.
  static int _peopleOn(TimelineDay day) => {
    for (final group in day.groups)
      for (final memory in group.people) memory.id,
  }.length;

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final shown = _days;
    final Widget title;
    if (day == null) {
      title = const Text('Timeline');
    } else if (shown == null || shown.isEmpty) {
      title = Text(_dayLabel(day));
    } else {
      final count = _peopleOn(shown.first);
      title = RememberemTheme.titleWithSuffix(
        context,
        _dayLabel(day),
        count == 1 ? '1 person' : '$count people',
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: title,
        actions: [
          // The switch is on the whole timeline; a day's page follows it.
          if (day == null) _detailsToggle(),
          const HomeButton(),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return EmptyState(
        title: 'Could not load the timeline.',
        actionLabel: 'Retry',
        onAction: _reload,
      );
    }
    final days = _days;
    if (days == null) {
      return const LinearProgressIndicator(
        minHeight: 3,
        semanticsLabel: 'Loading',
      );
    }
    if (days.isEmpty) {
      return EmptyState(
        title: 'No one yet.',
        actionLabel: widget.onMeetSomeone == null ? null : 'Meet someone',
        onAction: widget.onMeetSomeone,
      );
    }
    return ListView.builder(
      itemCount: days.length,
      itemBuilder: (context, index) => _dayTile(context, days[index]),
    );
  }

  Widget _dayTile(BuildContext context, TimelineDay day) {
    final theme = Theme.of(context);
    final opens = widget.day == null;
    final header = SectionHeader(
      title: _dayLabel(day.day),
      tinted: false,
      trailing: opens
          ? const Padding(
              padding: EdgeInsets.only(right: RememberemTheme.gutter),
              child: Icon(Icons.chevron_right_rounded, size: 20),
            )
          : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        opens
            ? Semantics(
                container: true,
                button: true,
                onTap: () => _openDay(day.day),
                child: InkWell(
                  onTap: () => _openDay(day.day),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: RememberemTheme.tapTarget,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: header,
                    ),
                  ),
                ),
              )
            : header,
        for (final group in day.groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RememberemTheme.gutter,
              6,
              RememberemTheme.gutter,
              4,
            ),
            child: Text(
              _groupLabel(group),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RememberemTheme.gutter,
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final memory in group.people)
                  TimelineMiniature(
                    memory: memory,
                    photo: widget.services.repository.photoFile(memory),
                    onOpen: () => _openPerson(memory),
                  ),
              ],
            ),
          ),
          // What put each person here, in the detail's own words.
          for (final memory in group.people)
            for (final detail in group.details[memory.id] ?? const <Detail>[])
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RememberemTheme.gutter,
                  4,
                  RememberemTheme.gutter,
                  0,
                ),
                child: Text(
                  '${MemoryTile.nameOf(memory)} – ${detailLine(detail)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          const SizedBox(height: 8),
        ],
        Divider(height: 1, thickness: 1, color: RememberemTheme.rule(theme)),
      ],
    );
  }

  /// An app bar switch: an icon and the word "Details". Its label stays
  /// "Details"; a screen reader hears whether it is on.
  Widget _detailsToggle() => ValueListenableBuilder<bool>(
    valueListenable: widget.services.timelineDetails,
    builder: (context, on, _) {
      void toggle() => widget.services.timelineDetails.value = !on;
      final color = IconTheme.of(context).color;
      return Semantics(
        toggled: on,
        label: 'Details',
        onTap: toggle,
        excludeSemantics: true,
        child: InkWell(
          onTap: toggle,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: RememberemTheme.tapTarget,
              minHeight: RememberemTheme.tapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    on
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 22,
                    color: color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  /// How a detail that put someone on a day reads: "Happening: picnic",
  /// "Tag · Book club", "Anniversary · Wedding: big party".
  static String detailLine(Detail detail) {
    final label = detail.label?.trim() ?? '';
    final head = [
      detail.kind.label,
      if (label.isNotEmpty) label[0].toUpperCase() + label.substring(1),
    ].join(' · ');
    final text = detail.text.trim();
    return text.isEmpty ? head : '$head: $text';
  }

  String _groupLabel(TimelineGroup group) {
    if (group.isUnknownPlace) return 'Unknown place';
    return [group.place, group.meeting].where((s) => s.isNotEmpty).join(' · ');
  }
}
