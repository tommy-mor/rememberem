import 'dart:io';

import 'package:rememberem_core/rememberem_core.dart';

import '../reminders/notice_channel.dart';
import '../reminders/reminder_coordinator.dart';
import '../settings/app_settings_controller.dart';
import 'background_location.dart';
import 'place_fences.dart';

/// Keeps the phone watching exactly the named places, while place notices
/// are on and allowed; otherwise watching nothing. Run on every open,
/// resume and return to the list, and after places change.
class PlaceNoticeKeeper {
  PlaceNoticeKeeper({
    required this.fences,
    required this.location,
    required this.reminders,
    required this.repository,
    required this.settings,
    int? most,
  }) : most = most ?? (Platform.isIOS ? 18 : 90);

  final PlaceFences fences;
  final BackgroundLocation location;
  final ReminderCoordinator reminders;
  final MemoryRepository repository;
  final AppSettingsController settings;

  /// How many places to watch: iOS watches at most 20 regions an app.
  final int most;

  Future<void> _tail = Future.value();

  /// Fred went to the phone's settings for "Allow all the time"; on his
  /// return, place notices turn on if he chose it.
  bool _awaitingSettings = false;

  /// Enable, disable and sync run one at a time, so two syncs never work
  /// from the same stale list of fences.
  Future<T> _serial<T>(Future<T> Function() step) {
    final result = _tail.then((_) => step());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Turns place notices on, after Fred has read what they do: asks for
  /// notifications and location all the time. [LocationAsk.inSettings]
  /// means it finishes when he comes back from the phone's settings.
  Future<LocationAsk> enable() => _serial(() async {
    if (!await reminders.scheduler.requestPermission()) {
      await _disable();
      return LocationAsk.refused;
    }
    final ask = await location.request();
    if (ask != LocationAsk.granted) {
      await _disable();
      _awaitingSettings = ask == LocationAsk.inSettings;
      return ask;
    }
    return await _turnOn() ? LocationAsk.granted : LocationAsk.refused;
  });

  Future<bool> _turnOn() async {
    await reminders.setPlaces(true);
    try {
      await _sync();
    } catch (_) {
      // The phone would not watch the places (approximate location only,
      // say): off, so the switch never claims what is not happening.
      await _disable();
      return false;
    }
    return true;
  }

  Future<void> disable() => _serial(_disable);

  Future<void> _disable() async {
    await reminders.setPlaces(false);
    await fences.clear();
  }

  Future<void> sync() => _serial(_sync);

  Future<void> _sync() async {
    if (_awaitingSettings) {
      // Back from the phone's settings: on, if he chose all the time.
      _awaitingSettings = false;
      try {
        if (await location.granted()) {
          await _turnOn();
          return;
        }
      } catch (_) {
        // Could not say: stays off.
      }
    }
    final on = (await reminders.settings()).places;
    if (!on) {
      await fences.clear();
      return;
    }
    final bool allowed;
    try {
      allowed =
          await location.granted() && await reminders.scheduler.hasPermission();
    } catch (_) {
      return; // the phone could not say: leave things as they are
    }
    if (!allowed) {
      // Taken away in the phone's settings: off, never asked again.
      await _disable();
      return;
    }
    final groups = PlaceBook.from(
      await repository.all(),
      spots: settings.value.placeSpots,
    ).groups;
    await fences.sync(
      PlaceFence.select(groups, settings.value.radiusFor, most: most),
    );
  }

  /// The named places, for the debug controls.
  Future<List<String>> places() async => [
    for (final g in PlaceBook.from(
      await repository.all(),
      spots: settings.value.placeSpots,
    ).groups)
      ?g.name,
  ];

  /// Debug controls: [place]'s notice, shown now, as an arrival would.
  Future<void> showNow(String place) async {
    final text =
        PlaceNotice.textFor(await repository.all(), place) ??
        'No one met here yet.';
    await reminders.scheduler.showNow(
      id: debugId,
      title: PlaceNotice.title(place),
      body: text,
      payload: PlaceNotice.wireId(PlaceNotice.fenceId(place)),
      channel: NoticeChannel.places,
    );
  }

  static const debugId = 902;
}
