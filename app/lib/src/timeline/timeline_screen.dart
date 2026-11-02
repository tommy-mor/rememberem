import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import '../memories/person_card_route.dart';
import 'timeline_miniature.dart';

/// Timeline mode: each day details were recorded, newest first, with the
/// people met grouped by place and meeting. Tapping a date shows just that
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
    try {
      final people = await widget.services.repository.all();
      final days = const TimelineBuilder().build(people, only: widget.day);
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
      appBar: AppBar(title: Text(day == null ? 'Timeline' : _dayLabel(day))),
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: days.length,
      itemBuilder: (context, index) => _dayTile(context, days[index]),
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

  String _groupLabel(TimelineGroup group) {
    if (group.isUnknownPlace) return 'Unknown place';
    return [group.place, group.meeting].where((s) => s.isNotEmpty).join(' - ');
  }
}
