import 'dart:async';

import 'package:rememberem_core/rememberem_core.dart';

import 'reminder_scheduler.dart';
import 'reminder_settings_store.dart';

/// What happened when Fred turned reminders on.
enum EnableResult { enabled, denied }

/// Keeps the daily reminder in step with Fred's setting and with whether
/// there is anything to practise. Every change runs one at a time.
class ReminderCoordinator {
  ReminderCoordinator({
    required this.scheduler,
    required this.store,
    required this.repository,
  });

  final ReminderScheduler scheduler;
  final ReminderSettingsStore store;
  final MemoryRepository repository;

  Future<void> _tail = Future.value();

  /// True after a sync found nothing to practise, so no reminder is set
  /// even though the switch is on.
  bool waitingForPeople = false;

  Future<T> _serial<T>(Future<T> Function() step) {
    final result = _tail.then((_) => step());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<ReminderSettings> settings() => store.load();

  /// Brings the schedule up to date; run on every app open.
  Future<void> sync() => _serial(_sync);

  Future<void> _sync() async {
    var settings = await store.load();
    if (!settings.enabled) {
      await scheduler.cancel();
      return;
    }
    if (!await scheduler.hasPermission()) {
      // Permission was taken away in Settings: switch off, never re-ask.
      // Before the first ask (see [askOnce]) there is nothing to take away.
      if (await store.hasSaved()) {
        await store.save(settings.copyWith(enabled: false));
      }
      await scheduler.cancel();
      return;
    }
    final List<Memory> people;
    try {
      people = await repository.all();
    } catch (_) {
      return; // can't tell: leave whatever is scheduled
    }
    // The switch may have changed while we read.
    settings = await store.load();
    if (!settings.enabled) {
      await scheduler.cancel();
      return;
    }
    if (ReminderTarget.resolve(people, null) == null) {
      waitingForPeople = true;
      await scheduler.cancel();
      return;
    }
    waitingForPeople = false;
    await scheduler.scheduleDaily(settings.hour, settings.minute);
  }

  /// Reminders start on, but the permission is asked for only here, once,
  /// at a calm moment the list chooses. The answer is saved either way, so
  /// Fred is never asked twice.
  Future<void> askOnce() => _serial(() async {
    if (await store.hasSaved()) return;
    final settings = await store.load();
    final granted =
        await scheduler.hasPermission() || await scheduler.requestPermission();
    await store.save(settings.copyWith(enabled: settings.enabled && granted));
    await _sync();
  });

  /// Turns reminders on (asking permission) or off.
  Future<EnableResult> setEnabled(bool enabled) => _serial(() async {
    final settings = await store.load();
    if (enabled && !await scheduler.requestPermission()) {
      await store.save(settings.copyWith(enabled: false));
      return EnableResult.denied;
    }
    await store.save(settings.copyWith(enabled: enabled));
    await _sync();
    return EnableResult.enabled;
  });

  Future<void> setTime(int hour, int minute) => _serial(() async {
    final settings = await store.load();
    await store.save(settings.copyWith(hour: hour, minute: minute));
    await _sync();
  });
}
