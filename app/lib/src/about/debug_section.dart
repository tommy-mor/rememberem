import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../places/place_notice_keeper.dart';
import '../reminders/reminder_coordinator.dart';
import '../settings/settings_section.dart';

/// Buttons that fire notifications now, for trying them out. Shown on
/// About in debug builds only (see [AboutScreen]); release builds never
/// build it.
class DebugSection extends StatelessWidget {
  const DebugSection({super.key, required this.reminders, this.placeNotices});

  final ReminderCoordinator reminders;
  final PlaceNoticeKeeper? placeNotices;

  Future<void> _anniversary(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Notice for which day?',
    );
    if (picked == null) return;
    await reminders.showAnniversaryNow(LocalDay.of(picked));
  }

  Future<void> _place(BuildContext context, PlaceNoticeKeeper keeper) async {
    final places = await keeper.places();
    if (!context.mounted) return;
    final place = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Notice for which place?'),
        children: [
          if (places.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No named places yet.'),
            ),
          for (final p in places)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(p),
              child: Text(p),
            ),
        ],
      ),
    );
    if (place != null) await keeper.showNow(place);
  }

  @override
  Widget build(BuildContext context) {
    final keeper = placeNotices;
    return SettingsSection(
      title: 'Debug',
      children: [
        ListTile(
          leading: const Icon(Icons.cake_outlined),
          title: const Text('Anniversary notice for…'),
          subtitle: const Text('Pick a day; its notice shows now.'),
          onTap: () => _anniversary(context),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Practice reminder now'),
          subtitle: const Text('Shows nothing if notifications are off.'),
          onTap: reminders.showReminderNow,
        ),
        if (keeper != null)
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: const Text('Place notice for…'),
            subtitle: const Text('Pick a place; its arrival notice shows now.'),
            onTap: () => _place(context, keeper),
          ),
      ],
    );
  }
}
