import 'dart:async';

import 'package:rememberem/src/reminders/reminder_scheduler.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// Records what the app asks of the notification system, and lets a test
/// tap reminders and notices.
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.granted = true, PracticeGame? launch})
    : launch = launch?.wireId;

  bool granted;

  /// When set, a permission request grants it from then on.
  bool grantOnRequest = false;

  /// The payload of the notification that launched the app.
  String? launch;
  final List<String> calls = [];
  (int, int)? scheduled;

  /// The days with an anniversary notice, and what each says.
  List<LocalDay> notices = [];
  Map<LocalDay, String> noticeTexts = {};

  /// Notifications shown at once (debug controls).
  final List<({int id, String title, String body, String payload})> shown = [];
  final _taps = StreamController<String?>.broadcast();

  void emitTap(PracticeGame? game) => _taps.add(game?.wireId);

  void emitPayload(String? payload) => _taps.add(payload);

  @override
  Stream<String?> get taps => _taps.stream;

  @override
  Future<String?> launchPayload() async {
    final payload = launch;
    launch = null;
    return payload;
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

  @override
  Future<void> scheduleAnniversaries(Map<LocalDay, String> notices) async {
    this.notices = notices.keys.toList();
    noticeTexts = Map.of(notices);
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async => shown.add((id: id, title: title, body: body, payload: payload));
}
