import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import 'memory_tile.dart';
import 'person_card_route.dart';

/// Matching mode: filter everyone by place, meeting, day and detail text,
/// then open a match. Nothing here is saved, not even the filters.
class MatchingScreen extends StatefulWidget {
  const MatchingScreen({
    super.key,
    required this.services,
    required this.routeObserver,
  });

  final AppServices services;
  final RouteObserver<ModalRoute<void>> routeObserver;

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> with RouteAware {
  List<Memory>? _people;
  Object? _error;
  int _reloadGen = 0;
  MemoryFilter _filter = const MemoryFilter();

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

  /// Back from a person's card: show their edits, trash or merge.
  @override
  void didPopNext() => _reload();

  Future<void> _reload() async {
    final gen = ++_reloadGen;
    try {
      final people = await widget.services.repository.all();
      if (mounted && gen == _reloadGen) {
        setState(() {
          _people = people;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && gen == _reloadGen) setState(() => _error = error);
    }
  }

  void _setFilter({
    String? place,
    String? meeting,
    DateTime? day,
    String? detailsContains,
    bool clearPlace = false,
    bool clearMeeting = false,
    bool clearDay = false,
  }) {
    setState(() {
      _filter = MemoryFilter(
        place: clearPlace ? null : place ?? _filter.place,
        meeting: clearMeeting ? null : meeting ?? _filter.meeting,
        day: clearDay ? null : day ?? _filter.day,
        detailsContains: detailsContains ?? _filter.detailsContains,
      );
    });
  }

  Future<void> _pickDay() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _filter.day ?? DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(2100, 12, 31),
    );
    if (day != null && mounted) _setFilter(day: day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Match people')),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load people.'),
            TextButton(onPressed: _reload, child: const Text('Retry')),
          ],
        ),
      );
    }
    final people = _people;
    if (people == null) return const Center(child: CircularProgressIndicator());
    final matches = _filter.apply(people);
    final localizations = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _picker(
                label: 'Place',
                value: _filter.place,
                options: MemoryFilter.places(people),
                onChanged: (v) => v == null
                    ? _setFilter(clearPlace: true)
                    : _setFilter(place: v),
              ),
              _picker(
                label: 'Meeting',
                value: _filter.meeting,
                options: MemoryFilter.meetings(people),
                onChanged: (v) => v == null
                    ? _setFilter(clearMeeting: true)
                    : _setFilter(meeting: v),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _pickDay,
                      icon: const Icon(Icons.event),
                      label: Text(
                        _filter.day == null
                            ? 'Any date'
                            : localizations.formatFullDate(_filter.day!),
                      ),
                    ),
                  ),
                  if (_filter.day != null)
                    IconButton(
                      tooltip: 'Clear date',
                      icon: const Icon(Icons.clear),
                      onPressed: () => _setFilter(clearDay: true),
                    ),
                ],
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Details contain',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (text) => _setFilter(detailsContains: text),
              ),
              const SizedBox(height: 8),
              Text(
                matches.length == 1 ? '1 person' : '${matches.length} people',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: matches.isEmpty
              ? const Center(child: Text('No one matches.'))
              : ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, index) => MemoryTile(
                    memory: matches[index],
                    photo: widget.services.repository.photoFile(matches[index]),
                    onTap: () => Navigator.of(context).push(
                      PersonCardRoute(
                        services: widget.services,
                        memory: matches[index],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  /// A dropdown of known names plus "Any". A chosen name that has since
  /// disappeared is still offered, so the filter keeps working.
  Widget _picker({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final items = [
      ...options,
      if (value != null && !options.contains(value)) value,
    ];
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String?>(child: Text('Any')),
        for (final item in items)
          DropdownMenuItem<String?>(value: item, child: Text(item)),
      ],
      onChanged: onChanged,
    );
  }
}
