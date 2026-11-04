import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import '../app/home_button.dart';
import '../memories/memory_tile.dart';
import '../memories/person_card_route.dart';
import 'timeline_miniature.dart';

/// Timeline mode: each day people were met, newest first, grouped by
/// place and meeting; "Show details" adds the days of their happenings,
/// dated tags and latest anniversaries. Tapping a date shows just that
/// day. Read-only.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({
    super.key,
    required this.services,
    required this.routeObserver,
    this.day,
  });

  final AppServices services;
  final RouteObserver<ModalRoute<void>> routeObserver;

  /// Show only this day, or every day if null.
  final LocalDay? day;

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
      ),
    ),
  );

  void _openPerson(Memory memory) =>
      Navigator.of(context)
          .push(PersonCardRoute(services: widget.services, memory: memory));

  String _dayLabel(LocalDay day) =>
      MaterialLocalizations.of(context).formatFullDate(day.toDate());

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    return Scaffold(
      appBar: AppBar(
        title: Text(day == null ? 'Timeline' : _dayLabel(day)),
        actions: const [HomeButton()],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load the timeline.'),
            TextButton(onPressed: _reload, child: const Text('Retry')),
          ],
        ),
      );
    }
    final days = _days;
    if (days == null) return const Center(child: CircularProgressIndicator());
    if (days.isEmpty) return const Center(child: Text('No one yet.'));
    // The checkbox is on the whole timeline; a day's page follows it.
    final toggle = widget.day == null;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: days.length + (toggle ? 1 : 0),
      itemBuilder: (context, index) {
        if (toggle && index == 0) return _detailsToggle();
        return _dayTile(context, days[index - (toggle ? 1 : 0)]);
      },
    );
  }

  Widget _dayTile(BuildContext context, TimelineDay day) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: widget.day == null ? () => _openDay(day.day) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _dayLabel(day.day),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          // Everything under a date is indented beneath it.
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final group in day.groups) ...[
                  Text(_groupLabel(group), style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final memory in group.people)
                        TimelineMiniature(
                          memory: memory,
                          photo: widget.services.repository.photoFile(memory),
                          onOpen: () => _openPerson(memory),
                        ),
                    ],
                  ),
                  // What put each person here, in the detail's own words.
                  for (final memory in group.people)
                    for (final detail
                        in group.details[memory.id] ?? const <Detail>[])
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${MemoryTile.nameOf(memory)} – '
                          '${detailLine(detail)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _detailsToggle() => ValueListenableBuilder<bool>(
    valueListenable: widget.services.timelineDetails,
    builder: (context, on, _) => CheckboxListTile(
      // The box just before its label.
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text('Show details'),
      value: on,
      onChanged: (v) => widget.services.timelineDetails.value = v ?? false,
    ),
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
    return [group.place, group.meeting].where((s) => s.isNotEmpty).join(' - ');
  }
}
