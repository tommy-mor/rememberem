import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../about/about_screen.dart';
import '../about/link_opener.dart';
import '../place_alerts/place_alert_coordinator.dart';
import '../place_alerts/place_alerts_section.dart';
import '../reminders/reminder_coordinator.dart';
import '../reminders/reminders_section.dart';
import 'app_settings_controller.dart';
import 'colour_choice.dart';
import 'setting_stepper.dart';
import 'settings_heading.dart';

/// Fred's choices: reminders, how matching and practice behave, and
/// whether maps fetch streets. Every change applies at once.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.links,
    this.reminders,
    this.placeAlerts,
  });

  final AppSettingsController settings;
  final LinkOpener links;
  final ReminderCoordinator? reminders;
  final PlaceAlertCoordinator? placeAlerts;

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
            if (placeAlerts case final placeAlerts?) ...[
              const SettingsHeading('Place notifications'),
              PlaceAlertsSection(coordinator: placeAlerts),
            ],
            const SettingsHeading('Display'),
            SwitchListTile(
              title: const Text('Dark mode'),
              value: s.darkMode,
              onChanged: (v) => settings.update(s.copyWith(darkMode: v)),
            ),
            ColourChoice(
              label: 'Theme colour',
              colours: AppPalette.themeColors,
              value: s.themeColor,
              onChanged: (v) => settings.update(s.copyWith(themeColor: v)),
            ),
            ColourChoice(
              label: 'Background',
              colours: AppPalette.backgrounds,
              value: s.backgroundColor,
              enabled: !s.darkMode,
              onChanged: (v) => settings.update(s.copyWith(backgroundColor: v)),
            ),
            SettingStepper(
              label: 'Detail text size',
              value: s.detailTextPercent,
              range: AppSettings.detailTextPercentRange,
              step: 10,
              format: (v) => '$v %',
              onChanged: (v) =>
                  settings.update(s.copyWith(detailTextPercent: v)),
            ),
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
              subtitle: const Text('Game chimes and the dictation ding'),
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
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About Rememberem'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AboutScreen(links: links),
                ),
              ),
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
