import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../reminders/reminder_coordinator.dart';
import '../settings/settings_section.dart';

/// Buttons that fire notifications now, for trying them out. Shown on
/// About in debug builds only (see [AboutScreen]); release builds never
/// build it.
class DebugSection extends StatelessWidget {
  const DebugSection({super.key, required this.reminders});

  final ReminderCoordinator reminders;

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

  @override
  Widget build(BuildContext context) {
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
      ],
    );
  }
}
