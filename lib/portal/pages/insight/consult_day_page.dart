import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Admin: one day of consultations (Nov 2026). GET /appointment/admin/day
/// Booked that day, scheduled / done / live / missed, plans delivered, per
/// dietitian, and every session: when the dietitian started and ended,
/// when the client joined and left, and her rating.
class ConsultDayPage extends StatefulWidget {
  const ConsultDayPage({super.key});

  @override
  State<ConsultDayPage> createState() => _ConsultDayPageState();
}

class _ConsultDayPageState extends State<ConsultDayPage> {
  static const _star = Color(0xFFF5B83D);

  DateTime _day = DateTime.now();
  Map<String, dynamic>? _d;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _dayStr => DateFormat('yyyy-MM-dd').format(_day);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final b = await PortalApi.get('/appointment/admin/day', query: {'date': _dayStr});
    if (!mounted) return;
    setState(() {
      if (PortalApi.ok(b) && b['data'] is Map) {
        _d = Map<String, dynamic>.from(b['data']);
      } else {
        _d = null;
        _error = PortalApi.msg(b, "Couldn't load this day.");
      }
      _loading = false;
    });
  }

  void _shift(int days) {
    setState(() => _day = _day.add(Duration(days: days)));
    _load();
  }

  Future<void> _pick() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (p == null) return;
    setState(() => _day = p);
    _load();
  }

  // ── helpers ─────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  static Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  static String? _hm(dynamic v) {
    final d = DateTime.tryParse('${v ?? ''}')?.toLocal();
    return d == null ? null : DateFormat('h:mm a').format(d);
  }

  static String _num(dynamic v) => v == null ? '–' : '$v';

  Widget _box(String title, Widget child, {String? sub}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: PT.card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: PT.t(11, w: FontWeight.w600, c: PT.sage).copyWith(letterSpacing: .6)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub, style: PT.t(11.5, c: PT.sage)),
          ],
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _kpi(String label, String value, {Color? color, IconData? icon}) => Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: PT.card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, size: 16, color: color ?? PT.sage), const SizedBox(width: 6)],
            Expanded(child: Text(label, style: PT.t(11.5, c: PT.sage), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 6),
          Text(value, style: PT.t(24, w: FontWeight.w700, c: color ?? PT.ink, h: 1)),
        ]),
      );

  Widget _status(String s) {
    final (String label, Color c) = switch (s) {
      'completed' => ('Done', PT.green),
      'In Progress' => ('Live', PT.green),
      'confirmed' => ('Booked', PT.sage),
      'pending' => ('Pending', PT.amber),
      'canceledByUser' => ('Cancelled by client', PT.red),
      'canceled' => ('Cancelled', PT.red),
      _ => (s, PT.sage),
    };
    return StatusChip(label, color: c);
  }

  // ── sections ────────────────────────────────────────────────────────
  Widget _header() {
    final now = DateTime.now();
    final isToday = _day.year == now.year && _day.month == now.month && _day.day == now.day;
    return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      IconButton(tooltip: 'Previous day', onPressed: _loading ? null : () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
      OutlinedButton.icon(
        onPressed: _loading ? null : _pick,
        icon: const Icon(Icons.calendar_today_rounded, size: 16),
        label: Text(isToday ? 'Today · ${DateFormat('EEE d MMM').format(_day)}' : DateFormat('EEE d MMM yyyy').format(_day)),
      ),
      IconButton(tooltip: 'Next day', onPressed: _loading ? null : () => _shift(1), icon: const Icon(Icons.chevron_right_rounded)),
      if (!isToday)
        TextButton(
          onPressed: _loading
              ? null
              : () {
                  setState(() => _day = DateTime.now());
                  _load();
                },
          child: const Text('Back to today'),
        ),
    ]);
  }

  Widget _kpis(Map<String, dynamic> t) => Wrap(spacing: 12, runSpacing: 12, children: [
        _kpi('Booked today', _num(t['bookedToday']), icon: Icons.event_available_rounded),
        _kpi('Sessions today', _num(t['scheduled']), icon: Icons.video_call_outlined),
        _kpi('Done', _num(t['done']), color: PT.green, icon: Icons.check_circle_outline),
        _kpi('Live / upcoming', '${t['live'] ?? 0} / ${t['upcoming'] ?? 0}', icon: Icons.schedule_rounded),
        _kpi('Client missed', _num(t['missedByClient']), color: (t['missedByClient'] ?? 0) > 0 ? PT.amber : null, icon: Icons.person_off_outlined),
        _kpi('Dietitian no-show', _num(t['dietitianNoShow']), color: (t['dietitianNoShow'] ?? 0) > 0 ? PT.red : null, icon: Icons.report_outlined),
        _kpi('Plans delivered', _num(t['plansDelivered']), color: PT.green, icon: Icons.assignment_turned_in_outlined),
        _kpi('Rating', t['ratingAvg'] == null ? '–' : '${t['ratingAvg']}★ (${t['ratingCount']})', color: t['ratingAvg'] == null ? null : _star, icon: Icons.star_outline_rounded),
      ]);

  Widget _dietitians(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return Text('No dietitian had sessions, bookings or plans on this day.', style: PT.t(12.5, c: PT.sage));
    const cols = ['Dietitian', 'Sessions', 'Done', 'Upcoming', 'Client missed', 'No-show', 'Late starts', 'Booked today', 'Plans', 'Rating'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: PT.t(12, w: FontWeight.w700, c: PT.sage),
        dataTextStyle: PT.t(13),
        columnSpacing: 22,
        columns: [for (final c in cols) DataColumn(label: Text(c))],
        rows: [
          for (final r in rows)
            DataRow(cells: [
              DataCell(Text('${r['name']}', style: PT.t(13, w: FontWeight.w600))),
              DataCell(Text(_num(r['scheduled']))),
              DataCell(Text(_num(r['done']), style: PT.t(13, c: PT.green, w: FontWeight.w600))),
              DataCell(Text('${(r['upcoming'] ?? 0) + (r['live'] ?? 0)}')),
              DataCell(Text(_num(r['missedByClient']), style: PT.t(13, c: (r['missedByClient'] ?? 0) > 0 ? PT.amber : PT.ink))),
              DataCell(Text(_num(r['dietitianNoShow']), style: PT.t(13, c: (r['dietitianNoShow'] ?? 0) > 0 ? PT.red : PT.ink))),
              DataCell(Text(_num(r['lateStarts']), style: PT.t(13, c: (r['lateStarts'] ?? 0) > 0 ? PT.amber : PT.ink))),
              DataCell(Text(_num(r['bookedToday']))),
              DataCell(Text(_num(r['plansDelivered']))),
              DataCell(Text(r['ratingAvg'] == null ? '–' : '${r['ratingAvg']}★ (${r['ratingCount']})')),
            ]),
        ],
      ),
    );
  }

  Widget _session(Map<String, dynamic> s) {
    final c = _map(s['client']);
    final d = _map(s['dietitian']);
    final att = _map(s['attendance']);
    final ac = _map(att['client']);
    final ad = _map(att['dietitian']);
    final rating = _map(s['rating']);
    final google = att['source'] == 'google';

    final dStart = _hm(ad['startedAt']);
    final dEnd = _hm(ad['endedAt']);
    final dietLine = dStart == null
        ? (s['status'] == 'confirmed' || s['status'] == 'pending' ? 'Not started yet' : "Didn't start the session")
        : 'Started $dStart${dEnd != null ? ' · ended $dEnd${ad['endedHow'] == 'auto' ? ' (auto, slot end)' : ''}' : ''}'
            '${ad['minutes'] is num ? ' · ${ad['minutes']} min' : ''}';

    final cJoin = _hm(ac['joinedAt']);
    final cLeft = _hm(ac['leftAt']);
    String clientLine;
    if (s['clientNoShow'] == true) {
      clientLine = "Didn't join";
    } else if (cJoin != null) {
      clientLine = 'Joined $cJoin${(ac['joins'] ?? 0) > 1 ? ' (${ac['joins']} times)' : ''}'
          '${cLeft != null ? ' · left ${ac['leftHow'] == 'app' ? 'about' : 'by'} $cLeft' : ''}'
          '${ac['minutes'] is num ? ' · about ${ac['minutes']} min' : ''}';
    } else if (ac['minutesFrom'] == 'dietitian' && ac['minutes'] is num) {
      clientLine = 'About ${ac['minutes']} min (dietitian said she joined)';
    } else {
      clientLine = (s['status'] == 'confirmed' || s['status'] == 'pending') ? 'Not joined yet' : "No Join tap in the app";
    }

    Widget line(IconData icon, String who, String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 15, color: PT.sage),
            const SizedBox(width: 6),
            SizedBox(width: 70, child: Text(who, style: PT.t(12, w: FontWeight.w600, c: PT.sage))),
            Expanded(child: Text(text, style: PT.t(12.5, h: 1.4))),
          ]),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: PT.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 92,
            child: Text('${s['start'] ?? '?'}\n${s['end'] ?? ''}', style: PT.t(13, w: FontWeight.w700, h: 1.35)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c['name'] ?? 'Client'}  ·  with ${d['name'] ?? '—'}', style: PT.t(13.5, w: FontWeight.w700)),
              Text(
                  [
                    if ('${c['phone'] ?? ''}'.isNotEmpty && '${c['phone']}' != 'null') '${c['phone']}',
                    if ('${c['email'] ?? ''}'.isNotEmpty && '${c['email']}' != 'null') '${c['email']}',
                    if (s['kind'] == 'followup') 'Follow-up' else 'Initial consultation',
                  ].join(' · '),
                  style: PT.t(11.5, c: PT.sage)),
            ]),
          ),
          _status('${s['status']}'),
        ]),
        line(Icons.medical_services_outlined, 'Dietitian', dietLine),
        line(Icons.person_outline_rounded, 'Client', clientLine),
        if (s['canceledBy'] != null) line(Icons.info_outline_rounded, 'Cancelled', '${s['canceledBy']}'),
        if (rating.isNotEmpty)
          line(Icons.star_rounded, 'Rating',
              '${rating['stars']}★${'${rating['comment'] ?? ''}'.trim().isNotEmpty ? '  "${rating['comment']}"' : ''}'),
        if (!google && (cJoin != null || dStart != null))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Times from the app, close but not exact.', style: PT.t(10.5, c: PT.sage)),
          ),
      ]),
    );
  }

  Widget _booked(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return Text('No bookings were made on this day.', style: PT.t(12.5, c: PT.sage));
    return Column(
      children: rows.map((b) {
        final c = _map(b['client']);
        final d = _map(b['dietitian']);
        final when = DateTime.tryParse('${b['date'] ?? ''}');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(width: 80, child: Text(_hm(b['bookedAt']) ?? '', style: PT.t(12.5, c: PT.sage))),
            Expanded(child: Text('${c['name'] ?? 'Client'} → ${d['name'] ?? '—'}', style: PT.t(13, w: FontWeight.w600))),
            Text('for ${when == null ? '' : DateFormat('EEE d MMM').format(when)} · ${b['start'] ?? ''}', style: PT.t(12.5)),
            const SizedBox(width: 10),
            _status('${b['status']}'),
          ]),
        );
      }).toList(),
    );
  }

  Widget _plans(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return Text('No diet plans were delivered on this day.', style: PT.t(12.5, c: PT.sage));
    return Column(
      children: rows.map((p) {
        final c = _map(p['client']);
        final d = _map(p['dietitian']);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(width: 80, child: Text(_hm(p['deliveredAt']) ?? '', style: PT.t(12.5, c: PT.sage))),
            Expanded(child: Text('${c['name'] ?? 'Client'}', style: PT.t(13, w: FontWeight.w600))),
            Text('by ${d['name'] ?? '—'}', style: PT.t(12.5, c: PT.sage)),
          ]),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Consultations by day',
        sub: 'Bookings, sessions, plans delivered and ratings for each dietitian, with when each side joined and left.',
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Expanded(
        child: _loading && d == null
            ? const Center(child: CircularProgressIndicator())
            : d == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load this day",
                    sub: _error,
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                      _header(),
                      const SizedBox(height: 12),
                      _kpis(_map(d['totals'])),
                      const SizedBox(height: 16),
                      _box('By dietitian', _dietitians(_list(d['dietitians']))),
                      const SizedBox(height: 16),
                      _box(
                        'Sessions on this day',
                        _list(d['sessions']).isEmpty
                            ? Text('No sessions on this day.', style: PT.t(12.5, c: PT.sage))
                            : Column(children: _list(d['sessions']).map(_session).toList()),
                        sub: 'Dietitian: Start and End taps. Client: Join tap and when she came back to the app.',
                      ),
                      const SizedBox(height: 16),
                      _box('Bookings made on this day', _booked(_list(d['booked']))),
                      const SizedBox(height: 16),
                      _box('Diet plans delivered on this day', _plans(_list(d['plans']))),
                    ]),
                  ),
      ),
    ]);
  }
}
