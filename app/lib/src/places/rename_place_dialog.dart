import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// Asks for a place's new name. Warns when the name is already another
/// place's (the two will merge) and says how many people it touches.
/// Where place notifications exist, also asks whether this place notifies.
class RenamePlaceDialog extends StatefulWidget {
  const RenamePlaceDialog({
    super.key,
    required this.group,
    required this.otherNames,
    required this.peopleAffected,
    this.alertSettings,
  });

  final PlaceGroup group;
  final List<String> otherNames;
  final int peopleAffected;

  /// The place-notification choices; null hides the checkbox.
  final AppSettings? alertSettings;

  static const notifyLabel = 'Notify me when I arrive here';

  /// The trimmed new name and the checkbox, or null if cancelled.
  static Future<({String name, bool notify})?> show(
    BuildContext context, {
    required PlaceGroup group,
    required List<String> otherNames,
    required int peopleAffected,
    AppSettings? alertSettings,
  }) => showDialog<({String name, bool notify})>(
    context: context,
    builder: (_) => RenamePlaceDialog(
      group: group,
      otherNames: otherNames,
      peopleAffected: peopleAffected,
      alertSettings: alertSettings,
    ),
  );

  @override
  State<RenamePlaceDialog> createState() => _RenamePlaceDialogState();
}

class _RenamePlaceDialogState extends State<RenamePlaceDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.group.name ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _trimmed => _name.text.trim();

  /// Fred's tick, once he has touched the box. Until then the box shows
  /// the place's own choice if he made one (a rename carries it), or else
  /// what the typed name gets by default (so typing "Home" unticks it).
  bool? _notify;

  bool get _notifyShown {
    final settings = widget.alertSettings;
    if (_notify case final notify?) return notify;
    if (settings == null) return false;
    final current = widget.group.name;
    final keepsChoice =
        current != null &&
        (MeetingFinder.samePlace(current, _trimmed) ||
            settings.placeAlertChoices.containsKey(current.trim()));
    return settings.alertsFor(keepsChoice ? current : _trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final mergesWith = widget.otherNames.any(
      (n) => MeetingFinder.samePlace(n, _trimmed),
    );
    final count = widget.peopleAffected;
    return AlertDialog(
      title: Text(
        widget.group.name == null ? 'Name this place' : 'Rename place',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Place name',
              errorText: _trimmed.isEmpty ? 'Enter a name' : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(count == 1 ? 'Changes 1 person.' : 'Changes $count people.'),
          if (mergesWith)
            Text(
              '"$_trimmed" already exists; the two places will become one.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (widget.alertSettings != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(RenamePlaceDialog.notifyLabel),
              value: _notifyShown,
              onChanged: (v) => setState(() => _notify = v ?? false),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _trimmed.isEmpty
              ? null
              : () =>
                    Navigator.of(context)
                        .pop((name: _trimmed, notify: _notifyShown)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
