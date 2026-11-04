import 'package:rememberem_core/rememberem_core.dart';

import '../reminders/notice_channel.dart';
import '../reminders/reminder_scheduler.dart';
import '../reminders/reminder_settings_store.dart';
import '../settings/settings_store.dart';
import 'place_notice_log.dart';

/// What happens on arriving at a watched place: if place notices are on,
/// and the place is known and due, a notice says who Fred has met there.
/// Reads everything afresh, since it may run with the app closed.
class PlaceArrival {
  PlaceArrival({
    required this.repository,
    required this.reminders,
    required this.settings,
    required this.log,
    required this.scheduler,
    this.clock = DateTime.now,
  });

  final MemoryRepository repository;
  final ReminderSettingsStore reminders;
  final SettingsStore settings;
  final PlaceNoticeLog log;
  final ReminderScheduler scheduler;
  final DateTime Function() clock;

  /// The notification id; a newer arrival replaces an older notice.
  static const noticeId = 950;

  /// Shows the notice for the first of [fenceIds] that is due and that
  /// Fred wants notices for; true if one showed. One that could not show
  /// leaves the place due.
  Future<bool> handle(List<String> fenceIds) async {
    if (!(await reminders.load()).places) return false;
    final people = await repository.all();
    final chosen = await settings.load();
    final places = [
      for (final g in PlaceBook.from(people, spots: chosen.placeSpots).groups)
        ?g.name,
    ];
    final now = clock();
    for (final id in fenceIds) {
      final place = PlaceNotice.placeFor(id, places);
      // A fence left from before Fred unticked the place says nothing.
      if (place == null || !chosen.notifies(place)) continue;
      if (!PlaceNotice.due(await log.lastShown(id), now)) continue;
      final text = PlaceNotice.textFor(people, place);
      if (text == null) continue;
      final shown = await scheduler.showNow(
        id: noticeId,
        title: PlaceNotice.title(place),
        body: text,
        payload: PlaceNotice.wireId(id),
        channel: NoticeChannel.places,
      );
      if (!shown) return false;
      await log.record(id, now);
      return true;
    }
    return false;
  }
}
