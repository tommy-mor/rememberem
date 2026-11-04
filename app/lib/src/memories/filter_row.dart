import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'filter_kind.dart';

/// One filter on the list: its kind as the label, a way to fill it
/// in, and a remove button. Reports each change as a new condition. A
/// filter just added ([openNow]) goes straight to filling it in: a text
/// filter takes the keyboard, a choice opens its list, a date range its
/// calendar. Cancelling that first choice removes the filter again.
class FilterRow extends StatefulWidget {
  const FilterRow({
    super.key,
    required this.condition,
    required this.places,
    required this.meetings,
    required this.tags,
    required this.onChanged,
    required this.onRemove,
    this.openNow = false,
    this.onOpened,
  });

  final FilterCondition condition;

  /// The known place, meeting and tag names to choose from.
  final List<String> places;
  final List<String> meetings;
  final List<String> tags;
  final ValueChanged<FilterCondition> onChanged;
  final VoidCallback onRemove;

  /// Fill it in as soon as it shows (it was just added).
  final bool openNow;

  /// Told once [openNow] has been acted on, so it is not done again.
  final VoidCallback? onOpened;

  /// Shown in a choice list with nothing to choose.
  static const noneYet = 'None yet';

  @override
  State<FilterRow> createState() => _FilterRowState();
}

class _FilterRowState extends State<FilterRow> {
  FilterCondition get _condition => widget.condition;

  @override
  void initState() {
    super.initState();
    if (!widget.openNow) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onOpened?.call();
      if (mounted) _openFirst();
    });
  }

  /// The first choice; cancelled, the blank filter goes. The removal
  /// needs no context, so it happens even if the list has gone.
  Future<void> _openFirst() async {
    final remove = widget.onRemove;
    final chosen = switch (_condition) {
      PlaceFilter() || MeetingFilter() || TagFilter() => await _choose(),
      DateRangeFilter() || AnniversaryFilter() => await _pickRange(),
      _ => true, // a text filter has the keyboard already
    };
    if (!chosen) remove();
  }

  @override
  Widget build(BuildContext context) {
    final kind = FilterKind.of(_condition);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: _input(context, kind)),
          IconButton(
            tooltip: 'Remove ${kind.label} filter',
            icon: const Icon(Icons.close),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }

  Widget _input(BuildContext context, FilterKind kind) {
    final decoration = InputDecoration(labelText: kind.label);
    return switch (_condition) {
      PlaceFilter(:final name) ||
      MeetingFilter(:final name) ||
      TagFilter(
        :final name,
      ) => _tappable(decoration, name ?? 'Choose', _choose),
      NameFilter(:final text) => TextFormField(
        initialValue: text,
        autofocus: widget.openNow,
        decoration: decoration,
        onChanged: (v) => widget.onChanged(NameFilter(v)),
      ),
      DetailsFilter(:final text) => TextFormField(
        initialValue: text,
        autofocus: widget.openNow,
        decoration: decoration,
        onChanged: (v) => widget.onChanged(DetailsFilter(v)),
      ),
      DateRangeFilter(:final from, :final to) ||
      AnniversaryFilter(
        :final from,
        :final to,
      ) => _tappable(decoration, _rangeText(context, from, to), _pickRange),
      _ => const SizedBox.shrink(),
    };
  }

  /// A field that opens a chooser when tapped.
  Widget _tappable(
    InputDecoration decoration,
    String text,
    Future<bool> Function() open,
  ) => Semantics(
    button: true,
    child: InkWell(
      onTap: open,
      child: InputDecorator(decoration: decoration, child: Text(text)),
    ),
  );

  /// The known names for this filter, plus a chosen one that has since
  /// disappeared, so the filter keeps working.
  List<String> get _options {
    final (options, value) = switch (_condition) {
      PlaceFilter(:final name) => (widget.places, name),
      MeetingFilter(:final name) => (widget.meetings, name),
      TagFilter(:final name) => (widget.tags, name),
      _ => (const <String>[], null),
    };
    return [...options, if (value != null && !options.contains(value)) value];
  }

  FilterCondition _with(String name) => switch (_condition) {
    PlaceFilter() => PlaceFilter(name),
    MeetingFilter() => MeetingFilter(name),
    _ => TagFilter(name),
  };

  String? get _chosenName => switch (_condition) {
    PlaceFilter(:final name) => name,
    MeetingFilter(:final name) => name,
    TagFilter(:final name) => name,
    _ => null,
  };

  /// Lists the names in a sheet; true if one was chosen.
  Future<bool> _choose() async {
    final options = _options;
    final current = _chosenName;
    final kind = FilterKind.of(_condition);
    final name = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                kind.label,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
            if (options.isEmpty) const ListTile(title: Text(FilterRow.noneYet)),
            // Each in its own box, close together.
            for (final option in options)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                child: ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: Theme.of(sheet).colorScheme.outlineVariant,
                    ),
                  ),
                  title: Text(option),
                  selected: option == current,
                  trailing: option == current
                      ? const Icon(Icons.check, semanticLabel: 'Chosen')
                      : null,
                  onTap: () => Navigator.of(sheet).pop(option),
                ),
              ),
          ],
        ),
      ),
    );
    if (name == null) return false;
    widget.onChanged(_with(name));
    return true;
  }

  String _rangeText(BuildContext context, DateTime? from, DateTime? to) {
    if (from == null || to == null) return 'Choose dates';
    final l = MaterialLocalizations.of(context);
    return '${l.formatShortDate(from)} – ${l.formatShortDate(to)}';
  }

  /// Opens the date range picker; true if a range was chosen.
  Future<bool> _pickRange() async {
    final (from, to) = switch (_condition) {
      DateRangeFilter(:final from, :final to) => (from, to),
      AnniversaryFilter(:final from, :final to) => (from, to),
      _ => (null, null),
    };
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: from == null || to == null
          ? null
          : DateTimeRange(start: from, end: to),
      firstDate: DateTime(1970),
      lastDate: DateTime(2100, 12, 31),
    );
    if (range == null) return false;
    widget.onChanged(switch (_condition) {
      AnniversaryFilter() => AnniversaryFilter(range.start, range.end),
      _ => DateRangeFilter(range.start, range.end),
    });
    return true;
  }
}
