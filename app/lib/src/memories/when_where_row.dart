import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import '../maps/location_choice.dart';
import '../maps/location_picker_screen.dart';

/// When and where a picture was taken, each with a button to change it:
/// a clock for the date and time, a map pin for the location (or Remote).
/// [stacked] puts them on two tight lines, beside the person's photo.
class WhenWhereRow extends StatelessWidget {
  const WhenWhereRow({
    super.key,
    required this.encounter,
    required this.services,
    required this.onTimeChanged,
    required this.onLocationChosen,
    this.stacked = false,
  });

  final bool stacked;

  final Encounter encounter;
  final AppServices services;
  final ValueChanged<DateTime> onTimeChanged;
  final ValueChanged<LocationChoice> onLocationChosen;

  Future<void> _pickTime(BuildContext context) async {
    final local = encounter.capturedAt.toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
    );
    if (time == null || !context.mounted) return;
    onTimeChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _pickLocation(BuildContext context) async {
    final choice = await Navigator.of(context).push<LocationChoice>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          services: services,
          initial: encounter.location,
        ),
      ),
    );
    if (choice != null) onLocationChosen(choice);
  }

  String get _where {
    final at = encounter.location;
    if (at != null) {
      return '${at.latitude.toStringAsFixed(2)}, '
          '${at.longitude.toStringAsFixed(2)}';
    }
    return encounter.place == Encounter.remotePlace
        ? Encounter.remotePlace
        : 'No location';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final local = encounter.capturedAt.toLocal();
    final small = Theme.of(context).textTheme.bodySmall;
    final when = Text(
      '${localizations.formatMediumDate(local)}, '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
      style: small,
    );
    final density = stacked ? VisualDensity.compact : null;
    final clock = IconButton(
      visualDensity: density,
      tooltip: 'Change date and time',
      icon: const Icon(Icons.schedule),
      onPressed: () => _pickTime(context),
    );
    final where = Text(_where, style: small);
    final pin = IconButton(
      visualDensity: density,
      tooltip: 'Change location',
      icon: const Icon(Icons.location_on_outlined),
      onPressed: () => _pickLocation(context),
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(child: when),
              clock,
            ],
          ),
          Row(
            children: [
              Flexible(child: where),
              pin,
            ],
          ),
        ],
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [when, clock, where, pin],
    );
  }
}
