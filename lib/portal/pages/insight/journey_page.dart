import 'dart:async';

import 'package:flutter/material.dart';

import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';
import 'insight_ui.dart';

/// User journey (GET /admin/growth/journey): every woman who signed up,
/// day by day — how far she got (sign-up form, trial, classes), whether she
/// paid, and where she stopped. Admin only.
class JourneyPage extends StatefulWidget {
  const JourneyPage({super.key});

  @override
  State<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends State<JourneyPage> {
  static const _stageOrder = ['all', 'no_form', 'no_trial', 'trial_no_class', 'trial_active', 'trial_ended', 'paid'];
  static const _stageShort = {
    'all': 'All',
    'no_form': 'Form not finished',
    'no_trial': 'Form done, no trial',
    'trial_no_class': 'Trial, no class',
    'trial_active': 'Trial in progress',
    'trial_ended': 'Trial ended, not paid',
    'paid': 'Paid',
  };

  int _days = 14;
  String _stage = 'all';
  String _q = '';
  String _view = 'people';
  int _page = 1;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _s(dynamic v) => v == null || '$v' == 'null' ? '' : '$v';

  static int _pct(num a, num b) => b == 0 ? 0 : (a * 100 / b).round();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final to = DateTime.now();
    final from = to.subtract(Duration(days: _days - 1));
    final b = await insightGet('/admin/growth/journey', query: {
      'from': _ymd(from),
      'to': _ymd(to),
      'stage': _stage,
      'q': _q,
      'page': '$_page',
    });
    if (!mounted) return;
    setState(() {
      _loading = false;
      if ('${b['status']}' == '1' && b['data'] is Map) {
        _data = iMap(b['data']);
      } else {
        _error = (b['message'] ?? "Couldn't load the journey.").toString();
        if (_data != null) portalToast("Couldn't refresh", sub: _error, error: true);
      }
    });
  }

  void _search(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _q = v;
      _page = 1;
      _load();
    });
  }

  Color _stageColor(String stage) {
    switch (stage) {
      case 'paid':
        return PT.green;
      case 'trial_active':
        return PT.greenDark;
      case 'trial_ended':
        return PT.red;
      default:
        return PT.amber;
    }
  }

  Widget _formCell(Map<String, dynamic> f) {
    if (f['done'] == true) return const StatusChip('Done');
    return StatusChip('Step ${iNum(f['step'])}/${iNum(f['total'])}', color: PT.amber);
  }

  Widget _trialCell(Map<String, dynamic> t) {
    if (t['started'] != true) return Text('Not started', style: PT.t(13, c: PT.sage));
    if (t['ended'] == true) {
      final ends = _s(t['endsAt']);
      return Text(ends.isEmpty ? 'Ended' : 'Ended ${iDate(ends)}', style: PT.t(13));
    }
    return Text('Day ${iNum(t['day'])} of ${iNum(t['days'])}', style: PT.t(13, w: FontWeight.w600, c: PT.greenDark));
  }

  Widget _paidCell(Map<String, dynamic> p) {
    if (p['yes'] != true) return Text('No', style: PT.t(13, c: PT.sage));
    final amount = p['amount'] is num ? '${(p['amount'] as num).round()} PKR' : 'Paid';
    final plan = _s(p['plan']);
    final more = iNum(p['count']) > 1 ? ' · ${iNum(p['count'])} payments' : '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(amount, style: PT.t(13, w: FontWeight.w600, c: PT.greenDark)),
      Text('${plan.isEmpty ? 'Plan' : plan} · ${iDate(p['firstAt'])}$more',
          style: PT.t(11.5, c: PT.sage), maxLines: 1, overflow: TextOverflow.ellipsis),
    ]);
  }

  Widget _peopleTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const PortalEmpty(icon: Icons.search_off_rounded, title: 'Nobody here', sub: 'Try another stage, date range or search.');
    }
    return InsightTable(
      columns: const ['Signed up', 'Name', 'Phone', 'Came from', 'Form', 'Trial', 'Classes', 'Paid', 'Stopped at', 'Contact'],
      numeric: const {6},
      rows: rows.map((r) {
        final name = _s(r['name']);
        final email = _s(r['email']);
        final phone = _s(r['phone']);
        final method = _s(r['method']);
        final source = _s(r['source']);
        final from = [method, source].where((x) => x.isNotEmpty).join(' · ');
        final trial = iMap(r['trial']);
        return <Widget>[
          Text(iDate(r['signedUpAt'], time: true), style: PT.t(13)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(name.isEmpty ? '—' : name, style: PT.t(13, w: FontWeight.w600)),
            if (email.isNotEmpty) Text(email, style: PT.t(11.5, c: PT.sage), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
          SelectableText(phone.isEmpty ? '—' : phone, style: PT.t(13)),
          Text(from.isEmpty ? '—' : from, style: PT.t(13)),
          _formCell(iMap(r['form'])),
          _trialCell(trial),
          Text(trial['started'] == true ? '${iNum(trial['classes'])}/3' : '—', style: PT.t(13)),
          _paidCell(iMap(r['paid'])),
          StatusChip(_s(r['stageLabel']), color: _stageColor(_s(r['stage']))),
          Row(mainAxisSize: MainAxisSize.min, children: contactButtons(phone)),
        ];
      }).toList(),
    );
  }

  Widget _dayTable(List<Map<String, dynamic>> days) {
    if (days.isEmpty) {
      return const PortalEmpty(icon: Icons.event_busy_outlined, title: 'No sign-ups in these days');
    }
    String cell(num n, num of) => of == 0 ? '0' : '$n  (${_pct(n, of)}%)';
    return InsightTable(
      columns: const ['Day', 'Signed up', 'Finished form', 'Started trial', 'Paid'],
      numeric: const {1, 2, 3, 4},
      rows: days.map((d) {
        final n = iNum(d['signedUp']);
        return <Widget>[
          Text(iDate(d['day']), style: PT.t(13, w: FontWeight.w600)),
          Text('$n', style: PT.t(13)),
          Text(cell(iNum(d['formDone']), n), style: PT.t(13)),
          Text(cell(iNum(d['trialStarted']), n), style: PT.t(13)),
          Text(cell(iNum(d['paid']), n), style: PT.t(13, w: FontWeight.w600, c: PT.greenDark)),
        ];
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final counts = iMap(d?['counts']);
    final f = iMap(d?['funnel']);
    final n = iNum(f['signedUp']);
    final page = iNum(d?['page']).toInt();
    final pages = iNum(d?['pages']).toInt();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'User journey',
        sub: 'Every woman who signed up, day by day: how far she got and whether she paid. Pakistan dates.',
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      insightPills<int>(
        options: const [(7, 'Last 7 days'), (14, 'Last 14 days'), (30, 'Last 30 days'), (90, 'Last 90 days')],
        selected: _days,
        onTap: (v) {
          setState(() {
            _days = v;
            _page = 1;
          });
          _load();
        },
      ),
      const SizedBox(height: 14),
      if (d != null) ...[
        kpiGrid([
          Kpi('Signed up', '$n'),
          Kpi('Finished the form', '${iNum(f['formDone'])}', sub: '${_pct(iNum(f['formDone']), n)}% of sign-ups'),
          Kpi('Started trial', '${iNum(f['trialStarted'])}', sub: '${_pct(iNum(f['trialStarted']), n)}% of sign-ups'),
          Kpi('Joined a class', '${iNum(f['attendedClass'])}', sub: '${_pct(iNum(f['attendedClass']), n)}% of sign-ups'),
          Kpi('Paid', '${iNum(f['paid'])}', sub: '${_pct(iNum(f['paid']), n)}% of sign-ups'),
        ], minTile: 170),
        const SizedBox(height: 14),
        insightPills<String>(
          options: [for (final k in _stageOrder) (k, '${_stageShort[k]} (${iNum(counts[k])})')],
          selected: _stage,
          onTap: (v) {
            setState(() {
              _stage = v;
              _page = 1;
            });
            _load();
          },
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          insightPills<String>(
            options: const [('people', 'People'), ('days', 'By day')],
            selected: _view,
            onTap: (v) => setState(() => _view = v),
          ),
          if (_view == 'people') insightSearch('journey_search', 'Search name, email or phone', _search),
        ]),
        const SizedBox(height: 12),
      ],
      Expanded(
        child: _loading && d == null
            ? const Center(child: CircularProgressIndicator())
            : d == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load the journey",
                    sub: _error,
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : _view == 'days'
                    ? _dayTable(iList(d['byDay']))
                    : _peopleTable(iList(d['rows'])),
      ),
      if (d != null && _view == 'people' && pages > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('Page $page of $pages · ${iNum(d['total'])} women', style: PT.t(12.5, c: PT.sage)),
            IconButton(
              tooltip: 'Previous page',
              onPressed: _loading || page <= 1
                  ? null
                  : () {
                      _page = page - 1;
                      _load();
                    },
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: _loading || page >= pages
                  ? null
                  : () {
                      _page = page + 1;
                      _load();
                    },
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ]),
        ),
    ]);
  }
}
