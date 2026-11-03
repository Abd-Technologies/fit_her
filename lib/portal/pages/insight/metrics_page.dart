import 'package:flutter/material.dart';

import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';
import 'insight_ui.dart';

/// Admin metrics: active users, consultations, plans waiting, compliance,
/// escalations and late tickets per dietitian (GET /admin/metrics/overview).
class MetricsPage extends StatefulWidget {
  const MetricsPage({super.key});

  @override
  State<MetricsPage> createState() => _MetricsPageState();
}

const metricTriggerLabels = {
  'PLAN_DELAYED': 'Plan delayed',
  'CONSULT_NO_SHOW': 'Dietitian no-show',
  'CONSULT_CLIENT_NO_SHOW': 'Client missed session',
  'INACTIVITY': 'Inactivity',
  'MEDICAL': 'Medical',
  'REVIEW_FLAG': 'Review flag',
  'BOOKING_REMINDER_5X': 'Booking reminder sent 5 times',
  'SYSTEM_ISSUE': 'System issue',
  'DIET_CHECKIN_HELP': 'Needs help with diet plan',
  'DIETITIAN_EMERGENCY_DAY': 'Emergency day',
};

class _MetricsPageState extends State<MetricsPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final b = await PortalApi.get(Constants.adminMetricsOverview);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (PortalApi.ok(b) && b['data'] is Map) {
        _data = Map<String, dynamic>.from(b['data']);
      } else {
        _error = PortalApi.msg(b, "Couldn't load metrics.");
        if (_data != null) portalToast("Couldn't refresh metrics", sub: _error, error: true);
      }
    });
  }

  Map<String, dynamic>? _m(String k) => _data?[k] is Map ? Map<String, dynamic>.from(_data![k]) : null;

  int _int(dynamic v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);

  Widget _empty(String s) => Text(s, style: PT.t(13, c: PT.sage));

  Widget _activeUsers() {
    final map = _m('activeUsersByPlanType');
    if (map == null || map.isEmpty) return InsightSection(title: 'Active users by plan', child: _empty('—'));
    final entries = map.entries.toList()..sort((a, b) => iNum(b.value).compareTo(iNum(a.value)));
    final total = entries.fold<num>(0, (s, e) => s + iNum(e.value));
    return InsightSection(
      title: 'Active users by plan',
      trailing: Text('$total in total', style: PT.t(12, w: FontWeight.w600, c: PT.greenDark)),
      child: Column(
        children: entries
            .map((e) => InsightBar(e.key, '${e.value}', total == 0 ? 0 : iNum(e.value) / total))
            .toList(),
      ),
    );
  }

  Widget _consultBox(String label, Map<String, dynamic>? c) {
    Widget line(String k, int v, {bool warn = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(k, style: PT.t(12.5, c: PT.sage))),
            Text('$v', style: PT.t(13, w: FontWeight.w700, c: warn && v > 0 ? PT.red : PT.ink)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: PT.t(11, w: FontWeight.w700, c: PT.sage).copyWith(letterSpacing: .4)),
        const SizedBox(height: 6),
        Text('${_int(c?['booked'])}', style: PT.t(28, w: FontWeight.w800)),
        Text('booked', style: PT.t(11.5, c: PT.sage)),
        const SizedBox(height: 8),
        line('Completed', _int(c?['completed'])),
        line('In progress', _int(c?['in_progress'])),
        line('No-show', _int(c?['no_show']), warn: true),
        line('Cancelled', _int(c?['cancelled'])),
      ]),
    );
  }

  Widget _consultations() {
    final c = _m('consultations');
    final today = c?['today'] is Map ? Map<String, dynamic>.from(c!['today']) : null;
    final week = c?['thisWeek'] is Map ? Map<String, dynamic>.from(c!['thisWeek']) : null;
    return InsightSection(
      title: 'Consultations',
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _consultBox('Today', today)),
        const SizedBox(width: 12),
        Expanded(child: _consultBox('This week', week)),
      ]),
    );
  }

  Widget _escalations() {
    final map = _m('escalationsByTrigger');
    if (map == null || map.isEmpty) return InsightSection(title: 'Escalations by reason', child: _empty('—'));
    final rows = map.entries.map((e) {
      final s = iMap(e.value);
      return (e.key, _int(s['open']), _int(s['acknowledged']), _int(s['resolved']));
    }).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return InsightSection(
      title: 'Escalations by reason',
      child: Column(
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Expanded(child: Text(metricTriggerLabels[r.$1] ?? r.$1, style: PT.t(13))),
                    Flexible(
                      child: Wrap(alignment: WrapAlignment.end, spacing: 6, runSpacing: 4, children: [
                        StatusChip('${r.$2} open', color: r.$2 > 0 ? PT.red : PT.sage),
                        if (r.$3 > 0) StatusChip('${r.$3} seen', color: PT.amber),
                        StatusChip('${r.$4} resolved', color: PT.sage),
                      ]),
                    ),
                  ]),
                ))
            .toList(),
      ),
    );
  }

  Widget _sla() {
    final list = iList(_data?['slaBreachPerDietitian'])..sort((a, b) => _int(b['openCount']).compareTo(_int(a['openCount'])));
    return InsightSection(
      title: 'Open tickets per dietitian',
      child: list.isEmpty
          ? _empty('No open tickets')
          : Column(
              children: list
                  .map((r) => InsightRow(
                        title: r['dietitianName']?.toString() ?? 'Dietitian #${r['dietitianId']}',
                        value: '${_int(r['openCount'])}',
                        valueColor: PT.red,
                      ))
                  .toList(),
            ),
    );
  }

  List<Widget> _body() {
    final pend = _m('plansPendingDelivery');
    final log = _m('dailyLogComplianceToday');
    final work = _m('workoutAttendanceWeek');
    final breach = _int(pend?['day3Breach']);
    return [
      kpiGrid([
        Kpi('Plans waiting to be sent', '${_int(pend?['count'])}',
            sub: breach > 0 ? '$breach past Day 3' : 'awaiting PDF'),
        Kpi('Daily log today', '${_int(log?['ratePct'])}%',
            sub: '${log?['loggedToday'] ?? 0} of ${log?['totalActive'] ?? 0} logged'),
        Kpi('Workout attendance this week', '${_int(work?['ratePct'])}%',
            sub: '${work?['attendedThisWeek'] ?? 0} of ${work?['totalActive'] ?? 0} attended'),
      ], minTile: 240),
      if (breach > 0) InsightNote('$breach plan(s) have not been sent and are past Day 3.'),
      insightColumns([_activeUsers(), _consultations(), _escalations(), _sla()]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Metrics',
        sub: 'Today and this week at a glance: active clients, consultations, plans waiting and escalations.',
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Expanded(
        child: _loading && _data == null
            ? const Center(child: CircularProgressIndicator())
            : _data == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load metrics",
                    sub: _error,
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : Builder(builder: (_) {
                    final items = _body();
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (_, i) => items[i],
                    );
                  }),
      ),
    ]);
  }
}
