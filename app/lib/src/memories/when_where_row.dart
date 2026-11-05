import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import '../maps/location_choice.dart';
import '../maps/location_picker_screen.dart';

/// When and where a picture was taken on one line, each with a button to
/// change it: a clock for the date and time, a map pin for the location (or
/// Remote). The line wraps rather than clipping. [trailing] goes at the
/// end.
class WhenWhereRow extends StatelessWidget {
  const WhenWhereRow({
    super.key,
    required this.encounter,
    required this.services,
    required this.onTimeChanged,
    required this.onLocationChosen,
    this.trailing,
  });

  final Widget? trailing;

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

  Future<void> _pickLocation(BuildContext context) =>
      pickLocation(context, services, encounter, onLocationChosen);

  /// Opens the location picker at [encounter]'s spot; [onChosen] hears the
  /// choice, if Fred makes one.
  static Future<void> pickLocation(
    BuildContext context,
    AppServices services,
    Encounter encounter,
    ValueChanged<LocationChoice> onChosen,
  ) async {
    final choice = await Navigator.of(context).push<LocationChoice>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          services: services,
          initial: encounter.location,
        ),
      ),
    );
    if (choice != null) onChosen(choice);
  }

  /// Where [encounter] was: its coordinates, Remote, or "No location".
  static String whereOf(Encounter encounter) {
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
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final local = encounter.capturedAt.toLocal();
    final small = theme.textTheme.bodySmall?.copyWith(
      fontSize: 13,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        IconButton(
          tooltip: 'Change date and time',
          icon: const Icon(Icons.schedule_rounded, size: 20),
          onPressed: () => _pickTime(context),
        ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                '${localizations.formatMediumDate(local)}, '
                '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
                style: small,
              ),
              Text('·', style: small),
              Text(whereOf(encounter), style: small),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Change location',
          icon: const Icon(Icons.location_on_outlined, size: 20),
          onPressed: () => _pickLocation(context),
        ),
        ?trailing,
      ],
    );
  }
}
