import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helper/notification_services.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Schedules local notifications for the daily nudge (1 PM) and weekly check-in.
///
/// Works alongside [NotificationServices] which handles FCM push notifications.
/// Uses the same Android channel ('high_importance_channel') for consistency.
class NotificationScheduler {
  NotificationScheduler._();

  static const int morningNudgeId = 1001;
  static const int weeklyCheckinId = 6001;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initializes timezone data and the notifications plugin. Must be
  /// called once at app startup (splash).
  static Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    _timeZoneName = timeZoneName;
    // Oct 2026: the plugin was only set up when the first push arrived
    // while the app was open (NotificationServices.initLocalNotifications),
    // so the morning reminder could be scheduled before it was ready.
    // Set it up here too. A later initLocalNotifications call still adds
    // its own tap handling on top.
    // One shared setup (tap routing, Android channel):
    // NotificationServices.ensureLocalNotifications.
    await NotificationServices.ensureLocalNotifications();
    _initialized = true;
    debugPrint('🔔 NotificationScheduler initialized, timezone: $timeZoneName');
  }

  /// Daily nudge time (Oct 2026): the middle of the day, 1:00 PM in her
  /// own time zone (the phone's zone, see [initialize]). Was 8:00 AM.
  static const int dailyNudgeHour = 13;
  static const int dailyNudgeMinute = 0;

  /// What is scheduled now: "13:00|Asia/Karachi". Used so an app open
  /// does not schedule it again; it is only redone when the time or her
  /// time zone changes, or it is missing.
  static const String _kDailyNudgeKey = 'daily_nudge_scheduled';
  static String _timeZoneName = '';

  /// Schedules the daily nudge: once a day at [dailyNudgeHour] in her time
  /// zone, repeating every day by itself (she doesn't need to open the
  /// app). Opening the app doesn't move or reset it.
  ///
  /// Lock screen safe — no cycle/health data in title or body.
  /// If [enabled] is false, cancels the existing notification.
  static Future<void> scheduleMorningNudge({
    required bool enabled,
  }) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    if (!enabled) {
      await _plugin.cancel(morningNudgeId);
      await prefs?.remove(_kDailyNudgeKey);
      return;
    }

    final want = '$dailyNudgeHour:$dailyNudgeMinute|$_timeZoneName';
    try {
      final pending = await _plugin.pendingNotificationRequests();
      final alreadySet = pending.any((p) => p.id == morningNudgeId);
      if (alreadySet && prefs?.getString(_kDailyNudgeKey) == want) {
        debugPrint('🔔 Daily nudge already set ($want)');
        return;
      }
    } catch (_) {
      // Can't read what is scheduled: schedule it again (same id, so it
      // replaces the old one; never two).
    }

    final scheduledDate = nextOccurrence(dailyNudgeHour, dailyNudgeMinute);

    try {
      debugPrint('🔔 Scheduling daily nudge, first: $scheduledDate');
      await _plugin.zonedSchedule(
        morningNudgeId,
        'Your daily insight is ready',
        'Open FitHer to see today\'s recommendations',
        scheduledDate,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        // Repeat every day at this time.
        matchDateTimeComponents: DateTimeComponents.time,
      );
      await prefs?.setString(_kDailyNudgeKey, want);
      debugPrint('🔔 Daily nudge scheduled');
    } catch (e) {
      debugPrint('🔔 ERROR scheduling daily nudge: $e');
    }
  }

  /// Schedules the weekly check-in reminder for Sunday at 7:00 PM.
  ///
  /// Suppressed if user already completed weekly check-in this week.
  /// If [enabled] is false or [alreadyDoneThisWeek] is true, cancels it.
  static Future<void> scheduleWeeklyCheckin({
    required bool enabled,
    required bool alreadyDoneThisWeek,
  }) async {
    if (!enabled || alreadyDoneThisWeek) {
      await _plugin.cancel(weeklyCheckinId);
      return;
    }

    final scheduledDate = nextDayOfWeek(DateTime.sunday, 19, 0);

    await _plugin.zonedSchedule(
      weeklyCheckinId,
      'Weekly check-in time',
      '1 minute to update your trends. Your report gets better with every check-in.',
      scheduledDate,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Returns true if [now] (defaults to the current local time) falls
  /// within quiet hours.
  ///
  /// Handles midnight crossing correctly (e.g. 22:00 to 07:00). [now] is
  /// injectable so this can be tested deterministically — see
  /// test/notifications/notification_scheduler_test.dart.
  static bool isQuietHours(String quietStart, String quietEnd, [DateTime? now]) {
    final effectiveNow = now ?? DateTime.now();
    final currentMinutes = effectiveNow.hour * 60 + effectiveNow.minute;

    final startParts = quietStart.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);

    final endParts = quietEnd.split(':');
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

    if (startMinutes > endMinutes) {
      // Spans midnight: e.g. 22:00 to 07:00
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    } else {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
  }

  /// Reschedules all notifications based on current preferences.
  ///
  /// Called on every app open to ensure notifications reflect current state.
  /// [prefs] should contain keys: morningNudge, weeklyCheckin, quietStart, quietEnd.
  static Future<void> rescheduleAll({
    required Map<String, dynamic> prefs,
    required bool weeklyCheckinDone,
  }) async {
    await initialize();

    final morningEnabled = prefs['morningNudge'] == 1;
    final weeklyEnabled = prefs['weeklyCheckin'] == 1;

    await scheduleMorningNudge(enabled: morningEnabled);
    await scheduleWeeklyCheckin(
      enabled: weeklyEnabled,
      alreadyDoneThisWeek: weeklyCheckinDone,
    );
  }

  /// Cancels all scheduled notifications managed by this scheduler.
  static Future<void> cancelAll() async {
    await _plugin.cancel(morningNudgeId);
    await _plugin.cancel(weeklyCheckinId);
  }

  /// Cancels a single notification by ID.
  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  // ── Pure date math (public for testability) ──────────────
  //
  // Previously private (_nextOccurrence/_nextDayOfWeek). Made public and
  // given an injectable [now] so they can be tested deterministically
  // without depending on the wall clock at test-run time — see
  // test/notifications/notification_scheduler_test.dart. Behavior for
  // existing callers (scheduleMorningNudge/scheduleWeeklyCheckin) is
  // unchanged since they don't pass [now] and get the same
  // tz.TZDateTime.now(tz.local) default as before.

  /// Returns the next occurrence of the given hour:minute in local timezone.
  /// If the time has already passed today, returns tomorrow.
  static tz.TZDateTime nextOccurrence(int hour, int minute, [tz.TZDateTime? now]) {
    final effectiveNow = now ?? tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, effectiveNow.year, effectiveNow.month, effectiveNow.day, hour, minute);
    if (scheduled.isBefore(effectiveNow)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Returns the next occurrence of a specific day of week at hour:minute.
  /// If that day/time has already passed this week, returns next week.
  static tz.TZDateTime nextDayOfWeek(int weekday, int hour, int minute, [tz.TZDateTime? now]) {
    final effectiveNow = now ?? tz.TZDateTime.now(tz.local);
    var daysUntil = weekday - effectiveNow.weekday;
    if (daysUntil < 0) daysUntil += 7;

    var scheduled = tz.TZDateTime(
      tz.local, effectiveNow.year, effectiveNow.month, effectiveNow.day + daysUntil, hour, minute,
    );
    if (scheduled.isBefore(effectiveNow)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }

  /// Notification details using the existing high_importance_channel.
  static NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}
