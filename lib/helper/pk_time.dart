import 'package:intl/intl.dart';

/// Consultation times (Nov 2026).
///
/// Dietitians set their slots in Pakistan time ("6:00 PM" = 6 PM in
/// Pakistan). A client abroad must see HER time, or a woman in Dubai joins
/// an hour late. Pakistan has no daylight saving, so it is always UTC+5.
///
/// The models convert once when they read the server's answer; the
/// original Pakistan date is kept for anything sent back to the server.
class PkTime {
  static const Duration pkOffset = Duration(hours: 5);

  /// Minutes after midnight and whether the time had AM/PM.
  /// "6:00 PM" → (1080, true), "18:00" → (1080, false).
  static (int, bool)? _clock(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'^\s*(\d{1,2}):(\d{2})(?::\d{2})?\s*([AaPp][Mm])?\s*$').firstMatch(raw);
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final ap = m.group(3)?.toUpperCase();
    if (ap == 'PM' && h < 12) h += 12;
    if (ap == 'AM' && h == 12) h = 0;
    if (h > 23 || min > 59) return null;
    return (h * 60 + min, ap != null);
  }

  /// "2026-11-03" + "6:00 PM" (Pakistan) → that moment on this phone.
  /// Old 24-hour slot times ("18:00") are UTC on the server, kept that way.
  static DateTime? toLocal(String? ymd, String? time) {
    final d = DateTime.tryParse(ymd ?? '');
    final c = _clock(time);
    if (d == null || c == null) return null;
    final (mins, ampm) = c;
    var utc = DateTime.utc(d.year, d.month, d.day, mins ~/ 60, mins % 60);
    if (ampm) utc = utc.subtract(pkOffset);
    return utc.toLocal();
  }

  static String ymd(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  static String clock(DateTime t) => DateFormat('h:mm a').format(t);

  /// True when this phone is on Pakistan time.
  static bool get phoneInPakistan => DateTime.now().timeZoneOffset == pkOffset;
}
