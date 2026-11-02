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
/// the device: the time zone data is bundled, and the reminder names no one.
class LocalNotificationsScheduler implements ReminderScheduler {
  static const _id = 1;

  /// Fixed, generic text: never a name, place or detail (lock screens).
  static const title = 'Time to practice';
  static const body = 'A minute to practice remembering people';

  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<PracticeGame?>.broadcast();
  Future<void>? _ready;
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
          _taps.add(PracticeGame.fromWireId(response.payload)),
    );
  }

  @override
  Stream<PracticeGame?> get taps => _taps.stream;

  @override
  Future<PracticeGame?> launchGame() async {
    try {
      await _init();
      if (_launchTaken) return null;
      _launchTaken = true;
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return PracticeGame.fromWireId(details.notificationResponse?.payload);
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
      debugPrint('Rememberem: scheduling the reminder failed: $error');
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
