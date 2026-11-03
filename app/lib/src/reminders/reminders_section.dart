import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'reminder_coordinator.dart';

/// Turn the daily practice reminder on or off and choose its time, and
/// turn anniversary notices on or off. Part of the Settings page.
class RemindersSection extends StatefulWidget {
  const RemindersSection({super.key, required this.coordinator});

  final ReminderCoordinator coordinator;

  @override
  State<RemindersSection> createState() => _RemindersSectionState();
}

class _RemindersSectionState extends State<RemindersSection> {
  ReminderSettings? _settings;

  /// The last switch turned on was refused notification permission.
  bool _denied = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    ReminderSettings settings;
    try {
      settings = await widget.coordinator.settings();
    } catch (_) {
      // Unreadable just now: show the last known state, or off.
      settings = _settings ?? const ReminderSettings.off();
    }
    if (mounted) setState(() => _settings = settings);
  }

  Future<void> _setEnabled(bool enabled) async {
    setState(() => _busy = true);
    var denied = false;
    try {
      denied =
          await widget.coordinator.setEnabled(enabled) == EnableResult.denied;
    } catch (_) {
      // Could not save; the switch shows what is actually stored.
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _denied = denied;
        });
      }
    }
    await _load();
  }

  Future<void> _setAnniversaries(bool enabled) async {
    setState(() => _busy = true);
    var denied = false;
    try {
      denied =
          await widget.coordinator.setAnniversaries(enabled) ==
          EnableResult.denied;
    } catch (_) {
      // Could not save; the switch shows what is actually stored.
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _denied = denied;
        });
      }
    }
    await _load();
  }

  Future<void> _pickTime() async {
    final settings = _settings!;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
    );
    if (time == null || !mounted) return;
    await widget.coordinator.setTime(time.hour, time.minute);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final small = Theme.of(context).textTheme.bodySmall;
    return settings == null
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                title: const Text('Daily practice reminder'),
                subtitle: const Text(
                  'One gentle nudge a day. It never names anyone.',
                ),
                value: settings.enabled,
                onChanged: _busy ? null : _setEnabled,
              ),
              if (settings.enabled)
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(
                    'Around ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay(hour: settings.hour, minute: settings.minute))}',
                  ),
                  subtitle: const Text('Tap to change'),
                  onTap: _pickTime,
                ),
              if (settings.enabled && widget.coordinator.waitingForPeople)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Reminders start once there are enough people to '
                    'practice with.',
                    style: small,
                  ),
                ),
              SwitchListTile(
                title: const Text('Anniversary notices'),
                subtitle: const Text(
                  'A morning note on days when someone has an anniversary '
                  'in the coming week. It never names anyone.',
                ),
                value: settings.anniversaries,
                onChanged: _busy ? null : _setAnniversaries,
              ),
              if (_denied)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Notifications are turned off for Rememberem. To get '
                    'reminders, allow notifications for it in Settings.',
                    style: small,
                  ),
                ),
            ],
          );
  }
}
