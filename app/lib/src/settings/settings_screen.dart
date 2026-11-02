import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../reminders/reminder_coordinator.dart';
import '../reminders/reminders_section.dart';
import 'app_settings_controller.dart';
import 'setting_stepper.dart';
import 'settings_heading.dart';

/// Fred's choices: reminders, how matching and practice behave, and
/// whether maps fetch streets. Every change applies at once.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings, this.reminders});

  final AppSettingsController settings;
  final ReminderCoordinator? reminders;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ValueListenableBuilder<AppSettings>(
        valueListenable: settings,
        builder: (context, s, _) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (reminders case final reminders?) ...[
              const SettingsHeading('Reminders'),
              RemindersSection(coordinator: reminders),
            ],
            const SettingsHeading('Matching'),
            SettingStepper(
              label: 'Same place within',
              value: s.placeRadiusFeet,
              range: AppSettings.placeRadiusRange,
              step: 50,
              format: (v) => '$v ft',
              onChanged: (v) => settings.update(s.copyWith(placeRadiusFeet: v)),
            ),
            SettingStepper(
              label: 'Same meeting within',
              value: s.meetingWindowMinutes,
              range: AppSettings.meetingWindowRange,
              step: 15,
              format: _minutes,
              onChanged: (v) =>
                  settings.update(s.copyWith(meetingWindowMinutes: v)),
            ),
            const SettingsHeading('Practice'),
            SettingStepper(
              label: 'Questions per game',
              value: s.gameTurns,
              range: AppSettings.gameTurnsRange,
              onChanged: (v) => settings.update(s.copyWith(gameTurns: v)),
            ),
            SettingStepper(
              label: 'Time to look before choosing',
              value: s.revealSeconds,
              range: AppSettings.revealSecondsRange,
              format: (v) => '$v s',
              onChanged: (v) => settings.update(s.copyWith(revealSeconds: v)),
            ),
            SettingStepper(
              label: 'Remembered after right answers',
              value: s.rememberedThreshold,
              range: AppSettings.rememberedThresholdRange,
              onChanged: (v) =>
                  settings.update(s.copyWith(rememberedThreshold: v)),
            ),
            SwitchListTile(
              title: const Text('Sounds'),
              value: s.sounds,
              onChanged: (v) => settings.update(s.copyWith(sounds: v)),
            ),
            SwitchListTile(
              title: const Text('Vibration'),
              value: s.vibration,
              onChanged: (v) => settings.update(s.copyWith(vibration: v)),
            ),
            const SettingsHeading('Maps'),
            SwitchListTile(
              title: const Text('Street maps'),
              subtitle: const Text(
                'Fetches map pictures from OpenStreetMap, which sees the area '
                'you are looking at. Off shows places on a blank map.',
              ),
              value: s.streetMaps,
              onChanged: (v) => settings.update(s.copyWith(streetMaps: v)),
            ),
          ],
        ),
      ),
    );
  }

  static String _minutes(int v) {
    final hours = v ~/ 60;
    final minutes = v % 60;
    if (hours == 0) return '$minutes min';
    return minutes == 0 ? '$hours h' : '$hours h $minutes min';
  }
}
