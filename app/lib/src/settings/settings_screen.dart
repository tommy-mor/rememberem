import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../about/about_screen.dart';
import '../about/link_opener.dart';
import '../app/home_button.dart';
import '../places/place_notice_keeper.dart';
import '../reminders/reminder_coordinator.dart';
import '../reminders/reminders_section.dart';
import 'app_settings_controller.dart';
import 'colour_choice.dart';
import 'setting_stepper.dart';
import 'settings_section.dart';
import 'units.dart';

/// Fred's choices: reminders, how matching and practice behave, and
/// whether maps fetch streets. Every change applies at once.
class SettingsScreen extends StatelessWidget {
  static const _metersPerFoot = 0.3048;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.links,
    this.reminders,
    this.placeNotices,
  });

  final AppSettingsController settings;
  final LinkOpener links;
  final ReminderCoordinator? reminders;
  final PlaceNoticeKeeper? placeNotices;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: const [HomeButton()],
      ),
      body: ValueListenableBuilder<AppSettings>(
        valueListenable: settings,
        builder: (context, s, _) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (reminders case final reminders?)
              SettingsSection(
                title: 'Reminders',
                children: [
                  RemindersSection(
                    coordinator: reminders,
                    placeNotices: placeNotices,
                  ),
                ],
              ),
            SettingsSection(
              title: 'Display',
              children: [
                SwitchListTile(
                  title: const Text('Dark mode'),
                  subtitle: const Text(
                    'A dark background below makes the pages dark too.',
                  ),
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
                  onChanged: (v) =>
                      settings.update(s.copyWith(backgroundColor: v)),
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
              ],
            ),
            SettingsSection(
              title: 'Matching',
              children: [
                SettingStepper(
                  label: 'Same place within',
                  value: s.placeRadiusFeet,
                  range: AppSettings.placeRadiusRange,
                  step: 50,
                  format: (v) => Units.distance(s, v * _metersPerFoot),
                  onChanged: (v) =>
                      settings.update(s.copyWith(placeRadiusFeet: v)),
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
              ],
            ),
            SettingsSection(
              title: 'Practice',
              children: [
                SettingStepper(
                  label: 'Questions per game',
                  value: s.gameTurns,
                  range: AppSettings.gameTurnsRange,
                  onChanged: (v) => settings.update(s.copyWith(gameTurns: v)),
                ),
                SwitchListTile(
                  title: const Text('Wait before showing choices'),
                  subtitle: const Text(
                    'Time to recall before the choices appear. Off: at once.',
                  ),
                  value: s.revealDelay,
                  onChanged: (v) => settings.update(s.copyWith(revealDelay: v)),
                ),
                if (s.revealDelay)
                  SettingStepper(
                    label: 'Time to look before choosing',
                    value: s.revealSeconds,
                    range: AppSettings.revealSecondsRange,
                    format: (v) => '$v s',
                    onChanged: (v) =>
                        settings.update(s.copyWith(revealSeconds: v)),
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
              ],
            ),
            SettingsSection(
              title: 'Maps',
              children: [
                SwitchListTile(
                  title: const Text('Street maps'),
                  subtitle: const Text(
                    'Fetches map pictures from OpenStreetMap, which sees the area '
                    'you are looking at. Off shows places on a blank map.',
                  ),
                  value: s.streetMaps,
                  onChanged: (v) => settings.update(s.copyWith(streetMaps: v)),
                ),
                SwitchListTile(
                  title: const Text('Metric units (m, km)'),
                  subtitle: const Text(
                    "Off shows feet and miles. Starts from your phone's region.",
                  ),
                  value: Units.metric(s),
                  onChanged: (v) => settings.update(s.copyWith(metricUnits: v)),
                ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About Rememberem'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AboutScreen(
                    links: links,
                    reminders: reminders,
                    placeNotices: placeNotices,
                  ),
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
