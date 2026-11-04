import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:rememberem_core/rememberem_core.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_scheduler.dart';

/// [ReminderScheduler] on the phone's own notifications. Nothing leaves
/// the device: the time zone data is bundled. The practice reminder names
/// no one; anniversary notices name people, so they are secret on a
/// locked phone, and their text is never logged.
class LocalNotificationsScheduler implements ReminderScheduler {
  static const _id = 1;

  /// Fixed, generic text: never a name, place or detail (lock screens).
  static const title = ReminderScheduler.practiceTitle;
  static const body = ReminderScheduler.practiceBody;

  /// The notices' channel. A new one, because Android keeps a channel's
  /// lock-screen setting once made: the old one showed text when locked.
  static const noticeChannel = 'anniversaries_named';
  static const _oldNoticeChannel = 'anniversaries';

  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String?>.broadcast();
  Future<void>? _ready;

  /// The last anniversary plan fully carried out, so an unchanged one is
  /// not redone.
  String? _lastNotices;
  bool _launchTaken = false;

  Future<void> _init() => _ready ??= _initialise();

  Future<void> _initialise() async {
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Unknown zone: tz.local stays UTC; the reminder may drift an hour.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _taps.add(response.payload),
    );
    try {
      await _android()?.deleteNotificationChannel(channelId: _oldNoticeChannel);
    } catch (_) {
      // Gone already, or not Android.
    }
  }

  /// How anniversary notices show.
  @visibleForTesting
  static const noticeDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      noticeChannel,
      'Anniversary notices',
      channelDescription: 'Who has an anniversary in the coming week',
      // Names: nothing at all on a locked phone.
      visibility: NotificationVisibility.secret,
      // All of it, not one cut-off line.
      styleInformation: BigTextStyleInformation(''),
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// What a set of notices is, to tell whether it changed: the days, the
  /// slots to clear, and the words (a rename changes them).
  @visibleForTesting
  static String noticeKey(
    ({Map<int, LocalDay> schedule, List<int> cancel}) plan,
    Map<LocalDay, String> notices,
  ) =>
      '${plan.schedule}|${plan.cancel}|'
      '${[for (final day in plan.schedule.values) notices[day]]}';

  @override
  Stream<String?> get taps => _taps.stream;

  @override
  Future<String?> launchPayload() async {
    try {
      await _init();
      if (_launchTaken) return null;
      _launchTaken = true;
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return details.notificationResponse?.payload;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await _init();
      if (Platform.isAndroid) {
        return await _android()?.requestNotificationsPermission() ?? false;
      }
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      await _init();
      if (Platform.isAndroid) {
        return await _android()?.areNotificationsEnabled() ?? false;
      }
      final ios = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return ios?.isEnabled ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> scheduleDaily(int hour, int minute) async {
    try {
      await _init();
      final now = tz.TZDateTime.now(tz.local);
      var next = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
      await _plugin.cancel(id: _id);
      await _plugin.zonedSchedule(
        id: _id,
        scheduledDate: next,
        title: title,
        body: body,
        payload: PracticeGame.faces.wireId,
        matchDateTimeComponents: DateTimeComponents.time,
        // Inexact: no exact-alarm permission; a few minutes late is fine.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'practice',
            'Practice reminders',
            channelDescription: 'A daily nudge to practice names',
            visibility: NotificationVisibility.private,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (error) {
      // Never block the app over a reminder, but leave a trace (no data
      // about anyone is involved here).
      debugPrint(
        'Rememberem: scheduling the reminder failed: ${error.runtimeType}',
      );
    }
  }

  @override
  Future<void> scheduleAnniversaries(Map<LocalDay, String> notices) async {
    try {
      await _init();
      final now = tz.TZDateTime.now(tz.local);
      final plan = AnniversaryNotice.plan(notices.keys.toList(), now);
      final key = noticeKey(plan, notices);
      // Every return to the list syncs; skip the work if nothing changed.
      if (key == _lastNotices) return;
      var done = true;
      // The new set first, then cancel what it no longer uses, so a sync
      // cut short still leaves working notices. One failure never stops
      // the rest.
      for (final MapEntry(key: id, value: day) in plan.schedule.entries) {
        try {
          await _plugin.zonedSchedule(
            id: id,
            scheduledDate: tz.TZDateTime(
              tz.local,
              day.year,
              day.month,
              day.day,
              AnniversaryNotice.hour,
            ),
            title: AnniversaryNotice.title,
            body: notices[day],
            payload: AnniversaryNotice.wireId(day),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            notificationDetails: noticeDetails,
          );
        } catch (error) {
          done = false;
          // Only the kind of error: it may carry the names.
          debugPrint(
            'Rememberem: scheduling a notice failed: ${error.runtimeType}',
          );
        }
      }
      for (final id in plan.cancel) {
        try {
          await _plugin.cancel(id: id);
        } catch (error) {
          done = false;
          debugPrint(
            'Rememberem: cancelling a notice failed: ${error.runtimeType}',
          );
        }
      }
      _lastNotices = done ? key : null;
    } catch (error) {
      debugPrint(
        'Rememberem: scheduling anniversary notices failed: '
        '${error.runtimeType}',
      );
    }
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      await _init();
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: noticeDetails,
      );
    } catch (error) {
      debugPrint('Rememberem: showing a notice failed: ${error.runtimeType}');
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _init();
      await _plugin.cancel(id: _id);
    } catch (_) {}
  }

  AndroidFlutterLocalNotificationsPlugin? _android() => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
}
