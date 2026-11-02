import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'behavior_signal_service.dart';

/// 1NH13 / 1NH15 — local phase + log reminders with quiet hours and caps.
class SmartReminderService extends GetxService {
  static const quietStartKey = 'd1_quiet_start_hour';
  static const quietEndKey = 'd1_quiet_end_hour';
  static const maxPerDayKey = 'd1_reminder_max';
  static const enabledPrefix = 'd1_reminder_enabled_';

  final SharedPreferences prefs;
  final FlutterLocalNotificationsPlugin plugin;

  SmartReminderService({
    required this.prefs,
    required this.plugin,
  });

  int get quietStart => prefs.getInt(quietStartKey) ?? 22;
  int get quietEnd => prefs.getInt(quietEndKey) ?? 7;
  int get maxPerDay => prefs.getInt(maxPerDayKey) ?? 3;

  bool isTypeEnabled(String type) =>
      prefs.getBool('$enabledPrefix$type') ?? true;

  Future<void> setTypeEnabled(String type, bool enabled) async {
    await prefs.setBool('$enabledPrefix$type', enabled);
  }

  Future<void> setQuietHours({required int start, required int end}) async {
    await prefs.setInt(quietStartKey, start);
    await prefs.setInt(quietEndKey, end);
  }

  bool _inQuietHours(DateTime when) {
    final h = when.hour;
    if (quietStart > quietEnd) {
      return h >= quietStart || h < quietEnd;
    }
    return h >= quietStart && h < quietEnd;
  }

  Future<void> scheduleDailyLogReminders() async {
    int hour = 10;
    if (Get.isRegistered<BehaviorSignalService>()) {
      hour = Get.find<BehaviorSignalService>().preferredReminderHour() ?? 10;
    }

    final types = <String, String>{
      'checkin': 'Time for your quick check-in',
      'water': 'Log a glass of water',
      'symptoms': 'Any symptoms to log today?',
      'meal': 'Log a meal when you can',
    };

    var scheduled = 0;
    var id = 7100;
    for (final entry in types.entries) {
      if (scheduled >= maxPerDay) break;
      if (!isTypeEnabled(entry.key)) continue;

      var when = DateTime.now();
      when = DateTime(when.year, when.month, when.day, hour + scheduled, 0);
      if (when.isBefore(DateTime.now())) {
        when = when.add(const Duration(days: 1));
      }
      if (_inQuietHours(when)) {
        when = DateTime(when.year, when.month, when.day, quietEnd, 15);
        if (when.isBefore(DateTime.now())) {
          when = when.add(const Duration(days: 1));
        }
      }

      try {
        await plugin.zonedSchedule(
          id++,
          'FitHer reminder',
          entry.value,
          tz.TZDateTime.from(when, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'd1_smart_reminders',
              'Smart log reminders',
              channelDescription: 'Gentle reminders to log daily habits',
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        scheduled++;
      } catch (_) {}
    }
  }

  /// Rules-based phase nudge (1NH13) — local schedule around predicted phase.
  Future<void> schedulePhaseNudge({
    required String phase,
    required String message,
  }) async {
    if (!isTypeEnabled('phase')) return;
    final when = DateTime.now().add(const Duration(hours: 20));
    if (_inQuietHours(when)) return;
    try {
      await plugin.zonedSchedule(
        7201,
        'Your $phase phase',
        message,
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'd1_phase_nudges',
            'Phase nudges',
            channelDescription: 'Cycle phase reminders',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }
}
