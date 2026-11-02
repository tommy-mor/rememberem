import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'filter_kind.dart';

/// One filter on the Filter List: its kind as the label, a way to fill it
/// in, and a remove button. Reports each change as a new condition.
class FilterRow extends StatelessWidget {
  const FilterRow({
    super.key,
    required this.condition,
    required this.places,
    required this.meetings,
    required this.onChanged,
    required this.onRemove,
    this.autofocus = false,
  });

  final FilterCondition condition;

  /// The known place and meeting names to choose from.
  final List<String> places;
  final List<String> meetings;
  final ValueChanged<FilterCondition> onChanged;
  final VoidCallback onRemove;

  /// Focus a text filter as soon as it is added.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final kind = FilterKind.of(condition);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: _input(context, kind)),
          IconButton(
            tooltip: 'Remove ${kind.label} filter',
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  Widget _input(BuildContext context, FilterKind kind) {
    final decoration = InputDecoration(labelText: kind.label);
    return switch (condition) {
      PlaceFilter(:final name) => _picker(
        decoration,
        name,
        places,
        (v) => onChanged(PlaceFilter(v)),
      ),
      MeetingFilter(:final name) => _picker(
        decoration,
        name,
        meetings,
        (v) => onChanged(MeetingFilter(v)),
      ),
      NameFilter(:final text) => TextFormField(
        initialValue: text,
        autofocus: autofocus,
        decoration: decoration,
        onChanged: (v) => onChanged(NameFilter(v)),
      ),
      DetailsFilter(:final text) => TextFormField(
        initialValue: text,
        autofocus: autofocus,
        decoration: decoration,
        onChanged: (v) => onChanged(DetailsFilter(v)),
      ),
      DateRangeFilter(:final from, :final to) => Semantics(
        button: true,
        child: InkWell(
          onTap: () => _pickRange(context, from, to),
          child: InputDecorator(
            decoration: decoration,
            child: Text(_rangeText(context, from, to)),
          ),
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  /// A dropdown of known names. A chosen name that has since disappeared
  /// is still offered, so the filter keeps working.
  Widget _picker(
    InputDecoration decoration,
    String? value,
    List<String> options,
    ValueChanged<String?> changed,
  ) {
    final items = [
      ...options,
      if (value != null && !options.contains(value)) value,
    ];
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: decoration,
      hint: const Text('Choose'),
      items: [
        for (final item in items)
          DropdownMenuItem<String>(value: item, child: Text(item)),
      ],
      onChanged: changed,
    );
  }

  String _rangeText(BuildContext context, DateTime? from, DateTime? to) {
    if (from == null || to == null) return 'Choose dates';
    final l = MaterialLocalizations.of(context);
    return '${l.formatShortDate(from)} – ${l.formatShortDate(to)}';
  }

  Future<void> _pickRange(
    BuildContext context,
    DateTime? from,
    DateTime? to,
  ) async {
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: from == null || to == null
          ? null
          : DateTimeRange(start: from, end: to),
      firstDate: DateTime(1970),
      lastDate: DateTime(2100, 12, 31),
    );
    if (range != null) onChanged(DateRangeFilter(range.start, range.end));
  }
}
