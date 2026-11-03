import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/api_provider/api_provider.dart';
import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_session.dart';
import '../../portal_theme.dart';

/// Shared bits for the dietitian Home / Sessions / Slots pages.

List<Map<String, dynamic>> dMaps(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

Map<String, dynamic> dMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

int dInt(dynamic v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);

/// Logged-in dietitian's id as text ('' if missing).
String dMyId() => '${Get.find<PortalSession>().userId ?? ''}';

/// PUT with the portal token (PortalApi only has GET / POST). Never throws.
Future<Map<String, dynamic>> dPut(String path, Map<String, dynamic> body) async {
  try {
    final s = Get.find<PortalSession>();
    s.touch();
    final r = await Get.find<ApiProvider>().putData(path, body: body, headers: s.headers);
    final b = r.body;
    return b is Map ? Map<String, dynamic>.from(b) : {'status': '0', 'message': "Couldn't reach the server."};
  } catch (_) {
    return {'status': '0', 'message': "Couldn't reach the server."};
  }
}

/// Slot time as the app shows it: "9:00 AM" stays, an old epoch-ms value
/// is turned into "09:00 AM" (same rule as the app's SlotDiet model).
String dSlotTime(dynamic raw) {
  final s = '${raw ?? ''}'.trim();
  if (s.isEmpty || s == 'null') return '';
  if (s == 'Start Time' || s == 'End Time') return s;
  if (s.contains('AM') || s.contains('PM')) return s;
  final ms = int.tryParse(s);
  if (ms == null) return s;
  return DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(ms));
}

/// Parse "9:00 AM" into a TimeOfDay (null if it can't).
TimeOfDay? dParseTime(String s) {
  try {
    final t = DateFormat('h:mm a').parse(s.trim());
    return TimeOfDay(hour: t.hour, minute: t.minute);
  } catch (_) {
    return null;
  }
}

/// Always "h:mm AM/PM" — the format the backend checks for.
String dFormatTime(TimeOfDay t) {
  final now = DateTime.now();
  return DateFormat('h:mm a').format(DateTime(now.year, now.month, now.day, t.hour, t.minute));
}

/// Appointment date exactly as the app reads it (DateTime.parse, no toLocal).
DateTime? dApptDate(Map<String, dynamic> a) => DateTime.tryParse('${a['date'] ?? ''}');

String dClientName(Map<String, dynamic> a, {String fallback = 'Client'}) {
  final u = dMap(a['ClientUser']);
  final n = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
  return n.isEmpty ? fallback : n;
}

String dFirstName(Map<String, dynamic> a) {
  final f = '${dMap(a['ClientUser'])['firstName'] ?? ''}'.trim();
  return f.isEmpty ? 'Client' : f;
}

String dTimeRange(Map<String, dynamic> a) {
  final s = a['SlotDiet'];
  if (s is! Map) return '';
  final st = dSlotTime(s['start']);
  final en = dSlotTime(s['end']);
  if (st.isEmpty && en.isEmpty) return '';
  return '${st.isEmpty ? '?' : st} – ${en.isEmpty ? '?' : en}';
}

/// The link to open: this booking's own snapshot, else the slot's link.
String? dMeetLink(Map<String, dynamic> a) {
  final own = '${a['meetLink'] ?? ''}'.trim();
  if (own.isNotEmpty && own != 'null') return own;
  final slot = '${dMap(a['SlotDiet'])['dietitionLink'] ?? ''}'.trim();
  if (slot.isNotEmpty && slot != 'null') return slot;
  return null;
}

/// Opens a meeting link in a new browser tab (cleans "meet.google.com/..").
Future<bool> dOpenLink(String? raw) async {
  var link = (raw ?? '').trim();
  if (link.isEmpty) return false;
  link = link.replaceAll(RegExp(r'\s+'), '');
  link = link.replaceAll(RegExp(r'[.,;]+$'), '');
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(link)) link = 'https://$link';
  final uri = Uri.tryParse(link);
  if (uri == null || uri.host.isEmpty) return false;
  try {
    return await launchUrl(uri, webOnlyWindowName: '_blank');
  } catch (_) {
    return false;
  }
}

/// Coloured status pill used for appointments (LIVE for "In Progress").
class DStatusPill extends StatelessWidget {
  const DStatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final live = s == 'In Progress';
    final Color c = live
        ? const Color(0xFF2F8A3A)
        : s == 'confirmed'
            ? PT.green
            : s == 'completed'
                ? PT.sage
                : (s == 'canceled' || s == 'canceledByUser')
                    ? PT.red
                    : const Color(0xFFC08A25);
    final label = live
        ? '● LIVE'
        : s.isEmpty
            ? '—'
            : (s == 'canceledByUser' ? 'CANCELED' : s.toUpperCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: PT.t(10.5, w: FontWeight.w700, c: c)),
    );
  }
}

/// Loads the dietitian's bookings (pending / confirmed / live).
/// [recentDays] > 0 also returns finished / cancelled bookings of the last
/// N days (Nov 2026: "Did she join?" cards and join/leave times).
Future<Map<String, dynamic>> dLoadAppointments({int recentDays = 0}) => PortalApi.get(
    '${Constants.getAppointments}/${dMyId()}',
    query: recentDays > 0 ? {'recentDays': '$recentDays'} : null);

/// Loads her clients (with planPipeline).
Future<Map<String, dynamic>> dLoadClients() => PortalApi.get('${Constants.getClients}/${dMyId()}');
