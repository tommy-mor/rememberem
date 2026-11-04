import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../places/place_notice_consent.dart';
import '../places/location_ask.dart';
import '../places/place_notice_keeper.dart';
import 'reminder_coordinator.dart';

/// Turn the daily practice reminder on or off and choose its time, and
/// turn anniversary notices on or off. Part of the Settings page.
class RemindersSection extends StatefulWidget {
  const RemindersSection({
    super.key,
    required this.coordinator,
    this.placeNotices,
  });

  final ReminderCoordinator coordinator;

  /// Place notices; null hides their switch.
  final PlaceNoticeKeeper? placeNotices;

  @override
  State<RemindersSection> createState() => _RemindersSectionState();
}

class _RemindersSectionState extends State<RemindersSection> {
  ReminderSettings? _settings;

  /// The last switch turned on was refused notification permission.
  bool _denied = false;

  /// How the last turning on of place notices went, if it did not.
  LocationAsk? _placesAsk;
  bool _busy = false;

  /// Back from the phone's settings: finish any turning on, then show it.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () async {
      try {
        await widget.placeNotices?.sync();
      } catch (_) {
        // The switch shows what is stored.
      }
      if (mounted) await _load();
    },
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // created now, so it listens from the start
    _load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
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

  /// On: first the page saying what location in the background is for,
  /// then the permissions. Off at once.
  Future<void> _setPlaces(PlaceNoticeKeeper keeper, bool on) async {
    if (on && !await PlaceNoticeConsent.show(context)) return;
    setState(() => _busy = true);
    LocationAsk? ask;
    try {
      if (on) {
        final result = await keeper.enable();
        ask = result == LocationAsk.granted ? null : result;
      } else {
        await keeper.disable();
      }
    } catch (_) {
      // The switch shows what is actually stored.
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _placesAsk = ask;
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
                  'One gentle nudge a day.',
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
                  'A daily reminder of who has an anniversary in the '
                  'coming week.',
                ),
                value: settings.anniversaries,
                onChanged: _busy ? null : _setAnniversaries,
              ),
              if (widget.placeNotices case final keeper?) ...[
                SwitchListTile(
                  title: const Text('Place notices'),
                  subtitle: const Text(
                    'Tell me when I arrive somewhere significant for '
                    'someone I know. ' ,
                  ),
                  value: settings.places,
                  onChanged: _busy ? null : (on) => _setPlaces(keeper, on),
                ),
                if (_placesAsk case final ask?)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      ask == LocationAsk.inSettings
                          ? 'In the settings page, choose Location, then '
                                '"Allow all the time". Place notices turn on '
                                'when you come back.'
                          : 'Place notices need location "Allow all the '
                                'time" and notifications. You can allow them '
                                'in Settings.',
                      style: small,
                    ),
                  ),
              ],
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
