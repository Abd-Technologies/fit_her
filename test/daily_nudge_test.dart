import 'package:fitness_zone_2/data/services/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
  });
  test('daily nudge is at 1 PM local', () {
    expect(NotificationScheduler.dailyNudgeHour, 13);
    final morning = tz.TZDateTime(tz.local, 2026, 10, 23, 9, 0);
    final r1 = NotificationScheduler.nextOccurrence(13, 0, morning);
    expect([r1.day, r1.hour, r1.location.name], [23, 13, 'Asia/Karachi']);
    final evening = tz.TZDateTime(tz.local, 2026, 10, 23, 18, 0);
    final r2 = NotificationScheduler.nextOccurrence(13, 0, evening);
    expect([r2.day, r2.hour], [24, 13]);
  });
  test('another time zone keeps 1 PM in that zone', () {
    // Her phone is in London: the app sets that as the local zone at start.
    tz.setLocalLocation(tz.getLocation('Europe/London'));
    final now = tz.TZDateTime(tz.local, 2026, 10, 23, 10, 0);
    final r = NotificationScheduler.nextOccurrence(13, 0, now);
    expect([r.hour, r.location.name], [13, 'Europe/London']);
  });
}
