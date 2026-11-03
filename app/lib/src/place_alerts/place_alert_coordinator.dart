import 'dart:async';

import 'package:rememberem_core/rememberem_core.dart';

import '../settings/app_settings_controller.dart';
import 'place_alert_access.dart';
import 'place_fencer.dart';

/// Keeps the places the phone watches in step with Fred's settings, his
/// places and what the phone allows. Every change runs one at a time.
class PlaceAlertCoordinator {
  PlaceAlertCoordinator({
    required this.fencer,
    required this.settings,
    required this.repository,
  });

  final PlaceFencer fencer;
  final AppSettingsController settings;
  final MemoryRepository repository;

  Future<void> _tail = Future.value();

  /// Fred turned the switch on but was sent to the phone's Settings to
  /// allow location all the time: the next sync finishes the job if he
  /// did. In memory only, so it never turns on by surprise days later.
  bool _wanted = false;

  /// True after the phone refused to watch places (no location service,
  /// location turned off).
  bool unavailable = false;

  Future<T> _serial<T>(Future<T> Function() step) {
    final result = _tail.then((_) => step());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Brings the watched places up to date; run on every app open.
  Future<void> sync() => _serial(_sync);

  /// Completes once every change already started has finished.
  Future<void> settled() => _serial(() async {});

  Future<void> _sync() async {
    if (!settings.value.placeAlerts && !_wanted) {
      unavailable = false;
      await fencer.replace(const []);
      return;
    }
    final access = await fencer.access();
    if (access == null) return; // can't tell: leave everything as it is
    if (access != PlaceAlertAccess.granted) {
      // Taken away in the phone's Settings: switch off, never re-ask.
      if (settings.value.placeAlerts) {
        await settings.update(settings.value.copyWith(placeAlerts: false));
      }
      unavailable = false;
      await fencer.replace(const []);
      return;
    }
    if (_wanted) {
      _wanted = false;
      await settings.update(settings.value.copyWith(placeAlerts: true));
    }
    final List<Memory> people;
    try {
      people = await repository.all();
    } catch (_) {
      return; // can't tell: leave whatever is watched
    }
    // Read the settings after the wait: they may have changed.
    final fences = PlaceFencePlanner.plan(people, settings.value);
    unavailable = !await fencer.replace(fences);
  }

  /// Turns place notifications on (asking for what is missing) or off.
  /// Says what is still missing, or [PlaceAlertAccess.granted].
  Future<PlaceAlertAccess> setEnabled(bool on) => _serial(() async {
    if (!on) {
      _wanted = false;
      await settings.update(settings.value.copyWith(placeAlerts: false));
      await _sync();
      return PlaceAlertAccess.granted;
    }
    final access = await fencer.requestAccess();
    if (access != PlaceAlertAccess.granted) {
      _wanted = true;
      return access;
    }
    _wanted = false;
    await settings.update(settings.value.copyWith(placeAlerts: true));
    await _sync();
    return PlaceAlertAccess.granted;
  });

  /// Turns notifications for one place on or off.
  Future<void> setPlace(String place, bool on) => _serial(() async {
    await settings.update(settings.value.withPlaceAlert(place, on));
    await _sync();
  });

  /// A place was renamed (or named): its choice moves to [to].
  Future<void> renamed(String from, String to, bool on) => _serial(() async {
    await settings.update(settings.value.renamePlaceAlert(from, to, on));
    await _sync();
  });
}
