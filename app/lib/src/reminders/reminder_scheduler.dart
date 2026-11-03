import 'package:rememberem_core/rememberem_core.dart';

/// The phone's notification system, as far as reminders need it.
abstract interface class ReminderScheduler {
  /// Asks Fred for permission to notify; true if granted.
  Future<bool> requestPermission();

  Future<bool> hasPermission();

  /// One practice reminder a day at local [hour]:[minute], replacing any
  /// earlier.
  Future<void> scheduleDaily(int hour, int minute);

  /// Cancels the practice reminder only; anniversary notices stay.
  Future<void> cancel();

  /// One anniversary notice on each of [days], at
  /// [AnniversaryNotice.hour], replacing every earlier notice. Days already
  /// past that hour are skipped; an empty list cancels them all.
  Future<void> scheduleAnniversaries(List<LocalDay> days);

  /// The payload of the notification that launched the app, if one did;
  /// given once only.
  Future<String?> launchPayload();

  /// Payloads of notifications tapped while the app runs. Untrusted: the
  /// app decodes them.
  Stream<String?> get taps;
}
