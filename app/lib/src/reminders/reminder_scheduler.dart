import 'package:rememberem_core/rememberem_core.dart';

import 'notice_channel.dart';

/// The phone's notification system, as far as reminders need it.
abstract interface class ReminderScheduler {
  /// The practice reminder's words: fixed, never a name, place or detail.
  static const practiceTitle = 'Time to practice';
  static const practiceBody = 'A minute to practice remembering people';

  /// Asks Fred for permission to notify; true if granted.
  Future<bool> requestPermission();

  Future<bool> hasPermission();

  /// One practice reminder a day at local [hour]:[minute], replacing any
  /// earlier.
  Future<void> scheduleDaily(int hour, int minute);

  /// Cancels the practice reminder only; anniversary notices stay.
  Future<void> cancel();

  /// One anniversary notice on each day of [notices], saying its text,
  /// at [AnniversaryNotice.hour], replacing every earlier notice. Days
  /// already past that hour are skipped; none cancels them all.
  Future<void> scheduleAnniversaries(Map<LocalDay, String> notices);

  /// Shows a named notice at once, on [channel]: a place notice, or the
  /// debug controls on About. True if it was shown.
  Future<bool> showNow({
    required int id,
    required String title,
    required String body,
    required String payload,
    NoticeChannel channel = NoticeChannel.anniversaries,
  });

  /// The payload of the notification that launched the app, if one did;
  /// given once only.
  Future<String?> launchPayload();

  /// Payloads of notifications tapped while the app runs. Untrusted: the
  /// app decodes them.
  Stream<String?> get taps;
}
