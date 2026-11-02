import 'dart:async';

import 'package:rememberem/src/reminders/reminder_scheduler.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// Records what the app asks of the notification system, and lets a test
/// tap reminders.
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.granted = true, this.launch});

  bool granted;

  /// When set, a permission request grants it from then on.
  bool grantOnRequest = false;
  PracticeGame? launch;
  final List<String> calls = [];
  (int, int)? scheduled;
  final _taps = StreamController<PracticeGame?>.broadcast();

  void emitTap(PracticeGame? game) => _taps.add(game);

  @override
  Stream<PracticeGame?> get taps => _taps.stream;

  @override
  Future<PracticeGame?> launchGame() async {
    final game = launch;
    launch = null;
    return game;
  }

  @override
  Future<bool> requestPermission() async {
    calls.add('request');
    if (grantOnRequest) granted = true;
    return granted;
  }

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<void> scheduleDaily(int hour, int minute) async {
    calls.add('schedule $hour:$minute');
    scheduled = (hour, minute);
  }

  @override
  Future<void> cancel() async {
    calls.add('cancel');
    scheduled = null;
  }
}
