import 'package:rememberem_core/rememberem_core.dart';

/// The phone's notification system, as far as reminders need it.
abstract interface class ReminderScheduler {
  /// Asks Fred for permission to notify; true if granted.
  Future<bool> requestPermission();

  Future<bool> hasPermission();

  /// One reminder a day at local [hour]:[minute], replacing any earlier.
  Future<void> scheduleDaily(int hour, int minute);

  Future<void> cancel();

  /// The game a tapped reminder asked for if it launched the app; given
  /// once only.
  Future<PracticeGame?> launchGame();

  /// Reminders tapped while the app runs; null for an unreadable payload.
  Stream<PracticeGame?> get taps;
}
