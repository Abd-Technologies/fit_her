import 'package:flutter/material.dart';

import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/admin_alerts_bar.dart';
import '../../widgets/portal_ui.dart';
import 'charts.dart';
import 'growth_page.dart' show showGrowthList;
import 'insight_ui.dart';
import 'metrics_page.dart' show metricTriggerLabels;

/// Admin Dashboard: growth, classes, money, retention and the diet team in
/// one place. Each tab loads only when opened and is kept per days value.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

/// One endpoint. [days] = takes ?days=.
class _Src {
  const _Src(this.path, {this.days = true});
  final String path;
  final bool days;
}

const _ov = _Src('/admin/growth/overview');
const _su = _Src('/admin/growth/signup');
const _wo = _Src('/admin/growth/workout');
const _rv = _Src('/admin/growth/revenue');
const _rt = _Src('/admin/growth/retention', days: false);
const _tr = _Src('/admin/growth/trends');
const _mt = _Src(Constants.adminMetricsOverview, days: false);

class _Load {
  const _Load({this.data, this.error, this.loading = false, this.at});
  final Map<String, dynamic>? data;
  final String? error;
  final bool loading;
  final DateTime? at;
}

class _DashboardPageState extends State<DashboardPage> {
  int _days = 30;
  int _tab = 0;
  bool _byMethod = false;
  final Map<String, _Load> _cache = {};
  final Stream<int> _ticker = Stream<int>.periodic(const Duration(seconds: 30), (i) => i);

  static const _tabNames = ['Overview', 'Classes', 'Money', 'Keeping women', 'Diet team'];

  List<_Src> _srcFor(int t) => switch (t) {
        0 => const [_ov, _tr, _su],
        1 => const [_wo, _tr],
        2 => const [_rv, _tr],
        3 => const [_rt],
        _ => const [_mt],
      };

  String _key(_Src s) => s.days ? '${s.path}|$_days' : s.path;

  // 1 = "Today" (server counts from Pakistan midnight).
  String get _span => _days == 1 ? 'today' : 'last $_days days';
  _Load? _get(_Src s) => _cache[_key(s)];
  Map<String, dynamic>? _data(_Src s) => _get(s)?.data;

  @override
  void initState() {
    super.initState();
    _ensure();
  }

  /// Starts loading what the open tab needs (cached ones are skipped).
  void _ensure({bool force = false}) {
    for (final s in _srcFor(_tab)) {
      _fetch(s, force: force);
    }
  }

  Future<void> _fetch(_Src s, {bool force = false}) async {
    final key = _key(s);
    final days = _days;
    final cur = _cache[key];
    if (cur != null && cur.loading) return;
    if (!force && cur != null && cur.data != null) return;
    _cache[key] = _Load(loading: true, data: cur?.data, at: cur?.at);
    Map<String, dynamic> b;
    try {
      b = await insightGet(s.path, query: s.days ? {'days': '$days'} : null);
    } catch (_) {
      b = {'status': '0', 'message': 'Could not reach the server.'};
    }
    if (!mounted) return;
    setState(() {
      if (PortalApi.ok(b) && b['data'] is Map) {
        _cache[key] = _Load(data: Map<String, dynamic>.from(b['data'] as Map), at: DateTime.now());
      } else {
        final msg = PortalApi.msg(b, "Couldn't load. Check your internet.");
        _cache[key] = _Load(data: cur?.data, at: cur?.at, error: msg);
        if (cur?.data != null) portalToast("Couldn't refresh", sub: msg, error: true);
      }
    });
  }

  void _retry(_Src s) {
    _fetch(s, force: true);
    setState(() {});
  }

  void _setTab(int i) {
    setState(() => _tab = i);
    _ensure();
  }

  void _setDays(int d) {
    setState(() => _days = d);
    _ensure();
  }

  void _refresh() {
    _ensure(force: true);
    setState(() {});
  }

  // ── small helpers ──────────────────────────────────────────────────

  num? _numOrNull(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');

  String _pct(dynamic v) => v is num ? '${fmtNum(v)}%' : '–';

  List<num> _series(Map<String, dynamic>? t, String k) {
    final v = t?[k];
    return v is List ? v.map<num>((e) => iNum(e)).toList() : <num>[];
  }

  List<String> _dates(Map<String, dynamic>? t) {
    final v = t?['dates'];
    return v is List ? v.map((e) => '$e').toList() : <String>[];
  }

  List<num>? _spark(Map<String, dynamic>? t, String k) {
    final s = _series(t, k);
    return s.length < 2 ? null : s;
  }

  String _updatedText() {
    final srcs = _srcFor(_tab);
    if (srcs.any((s) => _get(s)?.loading == true)) return 'Loading…';
    DateTime? oldest;
    for (final s in srcs) {
      final at = _get(s)?.at;
      if (at != null && (oldest == null || at.isBefore(oldest))) oldest = at;
    }
    if (oldest == null) return '';
    final m = DateTime.now().difference(oldest).inMinutes;
    if (m < 1) return 'Updated just now';
    if (m < 60) return 'Updated $m min ago';
    return 'Updated ${m ~/ 60} h ago';
  }

  // ── layout pieces ──────────────────────────────────────────────────

  Widget _pair(Widget a, Widget b, {int fa = 1, int fb = 1}) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 1000) return Column(children: [a, const SizedBox(height: 14), b]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: fa, child: a),
          const SizedBox(width: 14),
          Expanded(flex: fb, child: b),
        ]);
      });

  Widget _loadingCard(String title, {double height = 220}) => DashCard(
        title: title,
        child: SizedBox(
          height: height,
          child: const Center(
            child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ),
        ),
      );

  Widget _errorCard(String title, _Src s, String? error) => DashCard(
        title: title,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            const Icon(Icons.cloud_off_outlined, color: DC.bad, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Couldn't load this part", style: PT.t(13.5, w: FontWeight.w600)),
                if (error != null && error.isNotEmpty) Text(error, style: PT.t(12, c: PT.sage)),
              ]),
            ),
            TextButton(onPressed: () => _retry(s), child: const Text('Try again')),
          ]),
        ),
      );

  /// Card that waits for [s]; shows a spinner, an error with Try again, or [build].
  Widget _card(_Src s, String title, Widget Function(Map<String, dynamic> d) build, {double height = 220}) {
    final l = _get(s);
    final d = l?.data;
    if (d != null) return build(d);
    if (l == null || l.loading) return _loadingCard(title, height: height);
    return _errorCard(title, s, l.error);
  }

  Widget _kpis(_Src s, List<Widget> Function(Map<String, dynamic> d) tiles, {int count = 6}) {
    final l = _get(s);
    final d = l?.data;
    if (d != null) return KpiGrid(tiles: tiles(d));
    if (l == null || l.loading) return KpiGrid(tiles: [for (var i = 0; i < count; i++) const KpiSkeleton()]);
    return _errorCard('Key numbers', s, l.error);
  }

  List<Widget> _gap(List<Widget> items) => [
        for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 14), items[i]],
      ];

  Widget _plain(String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(s, style: PT.t(12.5, c: PT.sage)),
      );

  Widget _noteLine(String s) => Text(s, style: PT.t(12, c: PT.sage));

  // ── page ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(title: 'Dashboard', sub: 'How Fit Her is doing, and who to contact today.'),
      const AdminAlertsBar(),
      _filters(),
      const SizedBox(height: 16),
      Expanded(
        child: ListView(
          key: PageStorageKey<String>('dash_tab_$_tab'),
          padding: const EdgeInsets.only(bottom: 32),
          children: _gap(switch (_tab) {
            0 => _overview(),
            1 => _classes(),
            2 => _money(),
            3 => _keeping(),
            _ => _diet(),
          }),
        ),
      ),
    ]);
  }

  Widget _filters() {
    final tabs = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PT.line),
      ),
      child: Wrap(spacing: 4, runSpacing: 4, children: [
        for (var i = 0; i < _tabNames.length; i++)
          Material(
            color: i == _tab ? PT.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => _setTab(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Text(
                  _tabNames[i],
                  style: PT.t(13, w: i == _tab ? FontWeight.w600 : FontWeight.w400, c: i == _tab ? Colors.white : PT.sage),
                ),
              ),
            ),
          ),
      ]),
    );
    final seg = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PT.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final d in const [1, 7, 30, 90])
          Material(
            color: d == _days ? DC.wash2 : Colors.white,
            child: InkWell(
              onTap: () => _setDays(d),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Text(d == 1 ? 'Today' : '$d days',
                    style: PT.t(12.5, w: d == _days ? FontWeight.w600 : FontWeight.w400, c: d == _days ? PT.ink : PT.sage)),
              ),
            ),
          ),
      ]),
    );
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        tabs,
        Row(mainAxisSize: MainAxisSize.min, children: [
          seg,
          const SizedBox(width: 12),
          StreamBuilder<int>(
            stream: _ticker,
            builder: (_, __) => Text(_updatedText(), style: PT.t(12, c: PT.sage)),
          ),
          const SizedBox(width: 4),
          IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh_rounded, size: 20)),
        ]),
      ],
    );
  }

  // ── Overview ───────────────────────────────────────────────────────

  List<Widget> _overview() {
    final t = _data(_tr);
    return [
      _kpis(_ov, (d) {
        final k = iMap(d['kpis']);
        final cmp = _days == 1 ? 'vs all of yesterday' : 'vs previous $_days days';
        return [
          KpiTile(
            label: 'New sign-ups',
            value: fmtNum(k['signups']),
            showChange: true,
            change: _numOrNull(k['signupsChange']),
            changeNote: cmp,
            spark: _spark(t, 'signups'),
          ),
          KpiTile(
            label: 'Trial → paid',
            value: _pct(k['trialToPaid']),
            sub: 'of ${fmtNum(k['trialsStarted'])} trials',
            spark: _spark(t, 'becamePaid'),
            sparkColor: DC.s2,
          ),
          KpiTile(label: 'Active paid women', value: fmtNum(k['activePaid']), sub: 'paid plan right now'),
          KpiTile(
            label: 'Revenue (PKR)',
            value: fmtPkr(k['revenue']),
            showChange: true,
            change: _numOrNull(k['revenueChange']),
            changeNote: cmp,
            spark: _spark(t, 'revenue'),
          ),
          KpiTile(label: 'Renewal rate', value: _pct(k['renewalRate']), sub: 'ended plans that renewed'),
          KpiTile(label: 'Active this week', value: _pct(k['activeThisWeekPct']), sub: 'of paid women'),
        ];
      }),
      _pair(
        _card(_tr, 'Sign-ups and new paid women', (d) {
          return DashCard(
            title: 'Sign-ups and new paid women',
            note: 'per day',
            trailing: const ChartLegend([('Sign-ups', DC.s1), ('Became paid', DC.s2)]),
            child: LineTrendChart(dates: _dates(d), series: [
              ChartSeries('Sign-ups', _series(d, 'signups'), DC.s1, area: true),
              ChartSeries('Became paid', _series(d, 'becamePaid'), DC.s2),
            ]),
          );
        }, height: 240),
        _card(_tr, 'Revenue', (d) {
          final dates = _dates(d);
          return DashCard(
            title: 'Revenue',
            note: d['revenueSource'] == 'approved_slips' ? 'PKR per day, approved slips' : 'PKR per day',
            child: BarTrendChart(
              labels: [for (final x in dates) shortDate(x)],
              tipLabels: [for (final x in dates) longDate(x)],
              values: _series(d, 'revenue'),
              name: 'Revenue',
              money: true,
            ),
          );
        }, height: 240),
        fa: 16,
        fb: 10,
      ),
      _pair(
        _card(_su, 'From sign-up to paid', (d) {
          final f = iList(d['funnel']);
          return DashCard(
            title: 'From sign-up to paid',
            note: _days == 1 ? 'women who signed up today' : 'women who signed up in the last $_days days',
            child: HBarList(
              drops: true,
              rows: [for (final s in f) HBar('${s['step']}', iNum(s['count']), note: _pct(s['pct']))],
            ),
          );
        }),
        _card(_su, 'Where they come from', _sources),
      ),
      _card(_ov, 'Act on these today', (d) => _acts(iList(d['lists'])), height: 120),
    ];
  }

  Widget _sources(Map<String, dynamic> d) {
    final hasMethod = iList(d['byMethod']).isNotEmpty;
    final useMethod = _byMethod && hasMethod;
    final all = iList(d[useMethod ? 'byMethod' : 'bySource']);
    final rows = all.take(8).toList();
    num maxPct = 1;
    for (final r in rows) {
      if (iNum(r['paidPct']) > maxPct) maxPct = iNum(r['paidPct']);
    }
    Widget toggle(String label, bool on, VoidCallback tap) => InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: tap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: on ? DC.wash2 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: PT.line),
            ),
            child: Text(label, style: PT.t(12, w: on ? FontWeight.w600 : FontWeight.w400, c: on ? PT.ink : PT.sage)),
          ),
        );
    return DashCard(
      title: 'Where they come from',
      note: 'sign-ups · % who paid',
      trailing: hasMethod
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              toggle('Source', !useMethod, () => setState(() => _byMethod = false)),
              const SizedBox(width: 6),
              toggle('Sign-up method', useMethod, () => setState(() => _byMethod = true)),
            ])
          : null,
      child: rows.isEmpty
          ? const ChartEmpty(height: 140)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DashTable(
                columns: [
                  DashCol(useMethod ? 'Method' : 'Source', flex: 2),
                  const DashCol('Sign-ups', numeric: true, width: 84),
                  const DashCol('Paid', flex: 2),
                ],
                rows: [
                  for (final r in rows)
                    [
                      Text('${r['name']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: PT.t(12.5)),
                      cellText(fmtNum(r['signups'])),
                      Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              height: 10,
                              color: PT.wash,
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: (iNum(r['paidPct']) / maxPct).clamp(0, 1).toDouble(),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: DC.s1,
                                    borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 64,
                          child: Text(
                            '${fmtNum(r['paid'])} · ${_pct(r['paidPct'])}',
                            textAlign: TextAlign.right,
                            style: tStyle(12),
                          ),
                        ),
                      ]),
                    ],
                ],
              ),
              if (all.length > rows.length)
                Padding(padding: const EdgeInsets.only(top: 8), child: _noteLine('+ ${all.length - rows.length} more')),
            ]),
    );
  }

  /// 2 = high (red), 1 = medium (amber), 0 = low (green).
  int _sev(String key) {
    const high = {'trial_offer_open', 'inactive_paid', 'low_ratings', 'slipping'};
    const med = {'ending_soon', 'signup_unfinished', 'no_trial_class'};
    if (high.contains(key) || key.startsWith('trial') || key.startsWith('inactive')) return 2;
    if (med.contains(key)) return 1;
    return 0;
  }

  Widget _acts(List<Map<String, dynamic>> lists) {
    final items = [...lists]..sort((a, b) {
        final ca = iNum(a['count']) > 0 ? 1 : 0;
        final cb = iNum(b['count']) > 0 ? 1 : 0;
        if (ca != cb) return cb - ca;
        final s = _sev('${b['key']}') - _sev('${a['key']}');
        if (s != 0) return s;
        return iNum(b['count']).compareTo(iNum(a['count']));
      });
    return DashCard(
      title: 'Act on these today',
      note: 'click a box to see the women and WhatsApp / call them',
      child: items.isEmpty
          ? _plain('Nothing to act on right now.')
          : LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 760 ? 3 : (c.maxWidth >= 480 ? 2 : 1);
              final rows = <Widget>[];
              for (var i = 0; i < items.length; i += cols) {
                rows.add(IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (var j = 0; j < cols; j++) ...[
                      if (j > 0) const SizedBox(width: 10),
                      Expanded(child: i + j < items.length ? _actBox(items[i + j]) : const SizedBox()),
                    ],
                  ]),
                ));
              }
              return Column(children: [
                for (var r = 0; r < rows.length; r++) ...[if (r > 0) const SizedBox(height: 10), rows[r]],
              ]);
            }),
    );
  }

  Widget _actBox(Map<String, dynamic> l) {
    final count = l['count'];
    final has = count is num && count > 0;
    final sev = _sev('${l['key']}');
    final bg = !has ? const Color(0xFFF2F4F0) : (sev == 2 ? DC.badBg : (sev == 1 ? DC.warnBg : DC.wash2));
    final fg = !has ? PT.sage : (sev == 2 ? DC.bad : (sev == 1 ? DC.warn : DC.good));
    final title = '${l['title'] ?? ''}';
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: PT.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        hoverColor: PT.wash,
        onTap: has ? () => showGrowthList(context, '${l['key']}', title) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              constraints: const BoxConstraints(minWidth: 42),
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Text(count == null ? '–' : fmtNum(count), style: tStyle(16, w: FontWeight.w700, c: fg)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: PT.t(13, w: FontWeight.w600)),
                if ('${l['hint'] ?? ''}'.isNotEmpty)
                  Text('${l['hint']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: PT.t(11.5, c: PT.sage)),
              ]),
            ),
            if (has) const Icon(Icons.chevron_right_rounded, size: 18, color: PT.sage),
          ]),
        ),
      ),
    );
  }

  // ── Classes ────────────────────────────────────────────────────────

  List<Widget> _classes() {
    final t = _data(_tr);
    return [
      _kpis(_wo, (d) {
        final k = iMap(d['kpis']);
        num rSum = 0;
        num rN = 0;
        for (final tr in iList(d['trainers'])) {
          final r = tr['rating'];
          final n = iNum(tr['ratings']);
          if (r is num && n > 0) {
            rSum += r * n;
            rN += n;
          }
        }
        return [
          KpiTile(
            label: 'Classes held',
            value: fmtNum(k['classesHeld']),
            sub: '${fmtNum(k['cancelled'])} cancelled · ${fmtNum(k['autoCancelled'])} auto',
          ),
          KpiTile(
            label: 'Women attended',
            value: fmtNum(k['womenAttended']),
            sub: 'different women, 5+ min',
            spark: _spark(t, 'attended'),
          ),
          KpiTile(label: 'Avg women per class', value: fmtNum(k['avgWomenPerClass'])),
          KpiTile(label: 'Stayed 5+ min', value: _pct(k['stayedPct']), sub: 'of women who joined'),
          KpiTile(label: 'Avg time in class', value: k['avgMinutes'] is num ? '${fmtNum(k['avgMinutes'])} min' : '–'),
          KpiTile(
            label: 'Average rating',
            value: rN > 0 ? '★ ${(rSum / rN).toStringAsFixed(1)}' : '–',
            sub: '${fmtNum(rN)} ratings',
          ),
        ];
      }),
      _card(_wo, 'Class diary', _classDiary),
      _pair(
        _card(_tr, 'Women in class', (d) {
          return DashCard(
            title: 'Women in class',
            note: 'per day, stayed 5+ min',
            child: LineTrendChart(
              dates: _dates(d),
              series: [ChartSeries('Women in class', _series(d, 'attended'), DC.s1, area: true)],
            ),
          );
        }, height: 240),
        _card(_wo, 'Busiest days', (d) {
          final days = iList(d['byWeekday']);
          return DashCard(
            title: 'Busiest days',
            note: 'women in class, by weekday',
            child: BarTrendChart(
              labels: [for (final x in days) '${x['day']}'],
              values: [for (final x in days) iNum(x['attended'])],
              name: 'Women in class',
            ),
          );
        }, height: 240),
        fa: 16,
        fb: 10,
      ),
      _card(_wo, 'Time slots', (d) {
        final slots = iList(d['slots']);
        return DashCard(
          title: 'Time slots',
          note: 'busiest first',
          child: slots.isEmpty
              ? _plain('No classes in this period')
              : DashTable(
                  minWidth: 720,
                  columns: const [
                    DashCol('Slot', flex: 2),
                    DashCol('Trainer', flex: 2),
                    DashCol('Women / class', numeric: true, flex: 1.2),
                    DashCol('Avg time', numeric: true),
                    DashCol('Stayed 5+ min', numeric: true, flex: 1.2),
                    DashCol('Rating', numeric: true),
                  ],
                  rows: [
                    for (final s in slots)
                      [
                        Text('${s['label']}', style: PT.t(12.5, w: FontWeight.w600)),
                        Text('${s['trainer'] ?? ''}'.isEmpty ? '—' : '${s['trainer']}', style: PT.t(12.5)),
                        cellText(fmtNum(s['avgWomen'])),
                        cellText(s['avgMinutes'] is num ? '${fmtNum(s['avgMinutes'])} min' : '–'),
                        cellText(_pct(s['stayedPct'])),
                        cellText(s['rating'] is num ? '★ ${s['rating']}' : 'no rating',
                            c: s['rating'] is num ? PT.ink : PT.sage),
                      ],
                  ],
                ),
        );
      }),
      _card(_wo, 'Trainer scorecard', (d) {
        final rows = iList(d['trainers']);
        return DashCard(
          title: 'Trainer scorecard',
          note: d['diarySince'] == null
              ? '$_span · on time fills in from the class diary'
              : '$_span · on time since ${iDate(d['diarySince'])}',
          child: rows.isEmpty
              ? _plain('No trainers in this period')
              : DashTable(
                  minWidth: 1080,
                  columns: const [
                    DashCol('Trainer', flex: 1.6),
                    DashCol('Classes', numeric: true),
                    DashCol('Women / class', numeric: true, flex: 1.2),
                    DashCol('Rating', numeric: true, flex: 1.2),
                    DashCol('On time', flex: 1.1),
                    DashCol('Late (avg)', numeric: true),
                    DashCol('Cancelled', numeric: true),
                    DashCol('Auto-cancelled', numeric: true, flex: 1.2),
                    DashCol('Forgot to end', numeric: true, flex: 1.1),
                    DashCol('Other link', numeric: true),
                    DashCol('Watch', flex: 1.8),
                  ],
                  rows: [
                    for (final t in rows)
                      [
                        Text('${t['name']}', style: PT.t(12.5, w: FontWeight.w700)),
                        cellText(fmtNum(t['classesHeld'])),
                        cellText(fmtNum(t['avgWomen'])),
                        cellText(
                          t['rating'] is num ? '★ ${t['rating']} (${fmtNum(t['ratings'])})' : 'no rating',
                          c: t['rating'] is num ? PT.ink : PT.sage,
                        ),
                        _onTime(t['onTimePct']),
                        cellText(t['avgLateMinutes'] is num ? '${t['avgLateMinutes']} min' : '–'),
                        _warnNum(t['cancelled']),
                        _warnNum(t['autoCancelled']),
                        _warnNum(t['forgotToEnd']),
                        _warnNum(t['usedOtherLink']),
                        Text(t['topIssue'] == null ? '—' : '${t['topIssue']}', style: PT.t(12.5, c: PT.sage)),
                      ],
                  ],
                ),
        );
      }),
    ];
  }

  Widget _warnNum(dynamic v) => cellText(fmtNum(v), c: iNum(v) > 0 ? DC.warn : PT.ink);

  Widget _onTime(dynamic v) {
    if (v is! num) return Text('—', style: PT.t(12.5, c: PT.sage));
    final kind = v >= 90 ? 0 : (v >= 80 ? 1 : 2);
    final bg = kind == 0 ? DC.goodBg : (kind == 1 ? DC.warnBg : DC.badBg);
    final fg = kind == 0 ? DC.good : (kind == 1 ? DC.warn : DC.bad);
    final mark = kind == 0 ? '✓' : (kind == 1 ? '!' : '✕');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text('$mark ${fmtNum(v)}%', style: tStyle(11.5, w: FontWeight.w600, c: fg)),
    );
  }

  // ── Money ──────────────────────────────────────────────────────────

  List<Widget> _money() {
    final t = _data(_tr);
    final rv = _data(_rv);
    return [
      if (rv != null && rv['source'] == 'approved_slips')
        const InsightNote('Purchase history starts Oct 2026. Until then the total comes from approved slips, '
            'and new / renewal / upgrade are not split yet.'),
      _kpis(_rv, (d) {
        final kinds = iMap(d['kinds']);
        Map<String, dynamic> k(String n) => iMap(kinds[n]);
        final total = iMap(d['total']);
        final pay = iMap(d['payments']);
        final pending = iNum(pay['pending']);
        return [
          KpiTile(
            label: 'Total (PKR)',
            value: fmtPkr(total['amount']),
            sub: '${fmtNum(total['count'])} payments',
            spark: _spark(t, 'revenue'),
          ),
          KpiTile(
            label: 'New purchases',
            value: fmtNum(k('new')['count']),
            sub: 'PKR ${fmtPkr(k('new')['amount'])}',
            spark: _spark(t, 'becamePaid'),
            sparkColor: DC.s2,
          ),
          KpiTile(label: 'Renewals', value: fmtNum(k('renewal')['count']), sub: 'PKR ${fmtPkr(k('renewal')['amount'])}'),
          KpiTile(label: 'Upgrades', value: fmtNum(k('upgrade')['count']), sub: 'PKR ${fmtPkr(k('upgrade')['amount'])}'),
          KpiTile(label: 'Avg lifetime value (PKR)', value: fmtPkr(d['avgLifetimeValue']), sub: 'per woman'),
          KpiTile(
            label: 'Pending slips',
            value: fmtNum(pay['pending']),
            sub: pending > 0 ? 'waiting for you' : 'all done',
            subColor: pending > 0 ? DC.warn : null,
          ),
        ];
      }),
      _pair(
        _card(_tr, 'Revenue by kind', (d) {
          final weeks = iList(d['revenueByWeek']);
          return DashCard(
            title: 'Revenue by kind',
            note: 'PKR per week',
            trailing: const ChartLegend([('New', DC.s1), ('Renewal', DC.s2), ('Upgrade', DC.s3)]),
            child: StackedWeekBars(
              weeks: [for (final w in weeks) '${w['week']}'],
              data: [
                for (final w in weeks) [iNum(w['new']), iNum(w['renewal']), iNum(w['upgrade'])],
              ],
            ),
          );
        }, height: 240),
        _card(_rv, 'Payments', (d) {
          final pay = iMap(d['payments']);
          return DashCard(
            title: 'Payments',
            note: '$_span · slips waiting is right now',
            child: HBarList(rows: [
              HBar('Approved', iNum(pay['approved']), color: DC.good),
              HBar('Rejected', iNum(pay['rejected']), color: DC.bad),
              HBar('DirectPay opened', iNum(pay['directPayOpened']), color: DC.s2),
              HBar('Slips waiting', iNum(pay['pending']), color: DC.warn),
            ]),
          );
        }),
        fa: 16,
        fb: 10,
      ),
      _pair(
        _card(_rv, 'Active plans by type', (d) {
          final types = iMap(d['activeByType']);
          num total = 0;
          for (final v in types.values) {
            total += iNum(v);
          }
          String share(dynamic v) => total == 0 ? '' : '${(iNum(v) / total * 100).round()}%';
          return DashCard(
            title: 'Active plans by type',
            note: 'right now',
            child: HBarList(
              emptyText: 'No active plans',
              rows: [
                for (final p in const ['combined', 'workout', 'diet'])
                  HBar(p[0].toUpperCase() + p.substring(1), iNum(types[p]), note: share(types[p])),
              ],
            ),
          );
        }),
        _card(_rv, 'Payment methods', (d) {
          final methods = iMap(iMap(d['payments'])['methods']).entries.toList()
            ..sort((a, b) => iNum(b.value).compareTo(iNum(a.value)));
          return DashCard(
            title: 'Payment methods',
            note: 'payment attempts, $_span',
            child: HBarList(
              emptyText: 'No payment attempts in this period',
              rows: [for (final e in methods) HBar(e.key == '?' ? 'Unknown' : e.key, iNum(e.value), color: DC.s2)],
            ),
          );
        }),
      ),
      _card(_rv, 'Upgrade paths', (d) {
        final paths = iList(d['upgradePaths'])..sort((a, b) => iNum(b['count']).compareTo(iNum(a['count'])));
        return DashCard(
          title: 'Upgrade paths',
          note: 'from plan → to plan',
          child: HBarList(
            emptyText: 'No upgrades yet',
            rows: [for (final p in paths) HBar('${p['path']}', iNum(p['count']), color: DC.s3)],
          ),
        );
      }, height: 120),
    ];
  }

  // ── Keeping women ──────────────────────────────────────────────────

  List<Widget> _keeping() {
    return [
      _noteLine("These numbers don't depend on the days picked above."),
      _pair(
        _card(_rt, 'Do women stay?', _cohorts),
        _card(_rt, 'Why plans were cancelled', (d) {
          final r = iList(d['cancelReasons']);
          return DashCard(
            title: 'Why plans were cancelled',
            note: 'all time',
            child: HBarList(
              emptyText: 'No cancellations',
              rows: [for (final x in r.take(10)) HBar('${x['reason']}', iNum(x['count']), color: DC.s3)],
            ),
          );
        }),
        fa: 16,
        fb: 10,
      ),
      _pair(
        _card(_rt, 'What keeps them', (d) {
          final w = iList(d['whatKeeps']);
          return DashCard(
            title: 'What keeps them',
            note: 'classes in her first month → % who renewed',
            child: HBarList(
              max: 100,
              emptyText: 'Not enough data yet',
              rows: [
                for (final x in w)
                  HBar('${x['group']} (${fmtNum(x['women'])} women)', iNum(x['renewedPct']),
                      text: _pct(x['renewedPct'])),
              ],
            ),
          );
        }),
        _card(_rt, 'Slipping away', (d) {
          final s = iList(d['slipping']);
          return DashCard(
            title: 'Slipping away',
            note: 'used to come often, now quiet',
            child: s.isEmpty
                ? _plain('Nobody right now')
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: SingleChildScrollView(child: Column(children: [for (final p in s) PersonRow(p)])),
                  ),
          );
        }),
      ),
      _card(_rt, 'Plans on pause', (d) {
        final f = iList(d['frozen']);
        return DashCard(
          title: 'Plans on pause',
          note: f.isEmpty ? 'frozen plans right now' : '${f.length} frozen right now · soonest back first',
          child: f.isEmpty
              ? _plain('No frozen plans right now')
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: SingleChildScrollView(child: Column(children: [for (final p in f) PersonRow(p)])),
                ),
        );
      }),
    ];
  }

  // Class diary: every class in the period, how the trainer ran it and
  // how many women came. "Today" also lists classes not started yet.
  Widget _classDiary(Map<String, dynamic> d) {
    final rows = iList(d['diary']);
    final mins = d['attendMinutes'] ?? 5;
    String status(String st) => switch (st) {
          'live' => '● Live',
          'completed' => 'Done',
          'cancelled' => 'Cancelled',
          'auto_cancelled' => 'Auto-cancelled',
          'upcoming' => 'Upcoming',
          _ => st,
        };
    Color statusColor(String st) => switch (st) {
          'live' => const Color(0xFFD9443B),
          'completed' => PT.green,
          'cancelled' || 'auto_cancelled' => const Color(0xFFB7791F),
          _ => PT.sage,
        };
    String started(Map x) {
      final at = x['startedAt'];
      if (at == null) return '—';
      final lm = x['lateMinutes'];
      if (lm is! num || lm.abs() <= 2) return '$at · on time';
      return lm > 0 ? '$at · ${lm}m late' : '$at · ${-lm}m early';
    }
    String ended(Map x) {
      final at = x['endedAt'];
      if (at == null) return x['status'] == 'live' ? 'running' : '—';
      final by = x['endedBy'];
      return by == 'system' ? '$at · forgot to end' : by == 'admin' ? '$at · by admin' : '$at';
    }
    return DashCard(
      title: 'Class diary',
      note: _days == 1
          ? 'today, morning first · women = in class $mins+ min / joined'
          : '$_span, newest first · women = in class $mins+ min / joined',
      child: rows.isEmpty
          ? _plain('No classes in this period')
          : DashTable(
              minWidth: 1100,
              columns: const [
                DashCol('Class', flex: 2.2),
                DashCol('Trainer', flex: 1.4),
                DashCol('Status', flex: 1.1),
                DashCol('Started', flex: 1.5),
                DashCol('Ended', flex: 1.5),
                DashCol('Ran', numeric: true),
                DashCol('Women', numeric: true),
                DashCol('Avg time', numeric: true),
                DashCol('Rating', numeric: true),
              ],
              rows: [
                for (final x in rows)
                  [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('${x['className']}', style: PT.t(12.5, w: FontWeight.w600)),
                      Text(_days == 1 ? '${x['scheduled']}' : '${iDate(x['date'])} · ${x['scheduled']}',
                          style: PT.t(11, c: PT.sage)),
                    ]),
                    Text('${x['trainer'] ?? ''}'.isEmpty ? '—' : '${x['trainer']}', style: PT.t(12.5)),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(status('${x['status']}'),
                          style: PT.t(12, w: FontWeight.w600, c: statusColor('${x['status']}'))),
                      // Trainer's reason when she cancelled (Nov 2026).
                      if (x['cancelReason'] != null && '${x['cancelReason']}'.isNotEmpty)
                        Text('${x['cancelReason']}',
                            style: PT.t(11, c: PT.sage), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ]),
                    Text(started(x), style: PT.t(12)),
                    Text(ended(x), style: PT.t(12, c: x['endedBy'] == 'system' ? const Color(0xFFB7791F) : PT.ink)),
                    cellText(x['ranMinutes'] is num ? '${x['ranMinutes']} min' : '–'),
                    cellText('${x['attended'] ?? 0} / ${x['joined'] ?? 0}'),
                    cellText(x['avgMinutes'] is num ? '${x['avgMinutes']} min' : '–'),
                    cellText(x['rating'] is num ? '★ ${x['rating']} (${x['ratings']})' : '–',
                        c: x['rating'] is num ? PT.ink : PT.sage),
                  ],
              ],
            ),
    );
  }

  Color _heatBg(num p) {
    final t = (p / 100).clamp(0, 1).toDouble();
    return HSLColor.fromAHSL(1, 110, (30 + t * 25) / 100, (96 - t * 46) / 100).toColor();
  }

  Widget _heat(dynamic v, {bool tooEarly = false, bool none = false}) {
    if (none) return Text('—', style: PT.t(12, c: PT.sage));
    if (v is! num || tooEarly) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        child: Text('too early', style: PT.t(12, c: PT.sage)),
      );
    }
    final light = 96 - (v / 100).clamp(0, 1) * 46;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _heatBg(v), borderRadius: BorderRadius.circular(6)),
      child: Text('${fmtNum(v)}%', style: tStyle(12, w: FontWeight.w600, c: light < 62 ? Colors.white : PT.ink)),
    );
  }

  Widget _cohorts(Map<String, dynamic> d) {
    final c = iList(d['cohorts']);
    final latest = c.isEmpty ? null : c.last;
    final rows = c.reversed.toList();
    return DashCard(
      title: 'Do women stay?',
      note: 'by month they first paid',
      child: rows.isEmpty || rows.every((r) => iNum(r['women']) == 0)
          ? const ChartEmpty(height: 160, text: 'No payments yet')
          : DashTable(
              columns: const [
                DashCol('Month', flex: 1.4),
                DashCol('Women', numeric: true),
                DashCol('Renewed', center: true, flex: 1.3),
                DashCol('Still active', center: true, flex: 1.3),
              ],
              rows: [
                for (final r in rows)
                  [
                    Text('${r['month']}', style: PT.t(12.5)),
                    cellText(fmtNum(r['women'])),
                    _heat(
                      r['renewedPct'],
                      none: iNum(r['women']) == 0,
                      tooEarly: identical(r, latest) && iNum(r['renewedPct']) == 0,
                    ),
                    _heat(r['activeNowPct'], none: iNum(r['women']) == 0),
                  ],
              ],
            ),
    );
  }

  // ── Diet team ──────────────────────────────────────────────────────

  Map<String, dynamic>? _sub(Map<String, dynamic> d, String k) =>
      d[k] is Map ? Map<String, dynamic>.from(d[k] as Map) : null;

  int _int(dynamic v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);

  List<Widget> _diet() {
    final md = _data(_mt);
    final pending = md == null ? null : _sub(md, 'plansPendingDelivery');
    final lateCount = _int(pending?['day3Breach']);
    return [
      _noteLine("Today and this week. These numbers don't depend on the days picked above."),
      _kpis(_mt, (d) {
        final pend = _sub(d, 'plansPendingDelivery');
        final log = _sub(d, 'dailyLogComplianceToday');
        final work = _sub(d, 'workoutAttendanceWeek');
        final active = _sub(d, 'activeUsersByPlanType') ?? <String, dynamic>{};
        final activeTotal = active.values.fold<num>(0, (s, v) => s + iNum(v));
        final consult = _sub(d, 'consultations');
        final today = consult == null ? null : _sub(consult, 'today');
        final esc = _sub(d, 'escalationsByTrigger') ?? <String, dynamic>{};
        var open = 0;
        for (final v in esc.values) {
          open += _int(iMap(v)['open']);
        }
        final breach = _int(pend?['day3Breach']);
        return [
          KpiTile(
            label: 'Plans waiting to be sent',
            value: fmtNum(_int(pend?['count'])),
            sub: breach > 0 ? '$breach past Day 3' : 'awaiting PDF',
            subColor: breach > 0 ? DC.bad : null,
          ),
          KpiTile(
            label: 'Daily log today',
            value: '${_int(log?['ratePct'])}%',
            sub: '${fmtNum(log?['loggedToday'] ?? 0)} of ${fmtNum(log?['totalActive'] ?? 0)} logged',
          ),
          KpiTile(
            label: 'Workout attendance',
            value: '${_int(work?['ratePct'])}%',
            sub: '${fmtNum(work?['attendedThisWeek'] ?? 0)} of ${fmtNum(work?['totalActive'] ?? 0)} this week',
          ),
          KpiTile(label: 'Active clients', value: fmtNum(activeTotal), sub: 'all plan types'),
          KpiTile(
            label: 'Consultations today',
            value: fmtNum(_int(today?['booked'])),
            sub: '${_int(today?['completed'])} done · ${_int(today?['no_show'])} no-show',
            subColor: _int(today?['no_show']) > 0 ? DC.bad : null,
          ),
          KpiTile(
            label: 'Open escalations',
            value: fmtNum(open),
            sub: open > 0 ? 'need a look' : 'all clear',
            subColor: open > 0 ? DC.bad : null,
          ),
        ];
      }),
      if (lateCount > 0) InsightNote('$lateCount plan(s) have not been sent and are past Day 3.'),
      _pair(
        _card(_mt, 'Active clients by plan', (d) {
          final map = _sub(d, 'activeUsersByPlanType') ?? <String, dynamic>{};
          final entries = map.entries.toList()..sort((a, b) => iNum(b.value).compareTo(iNum(a.value)));
          final total = entries.fold<num>(0, (s, e) => s + iNum(e.value));
          return DashCard(
            title: 'Active clients by plan',
            note: '${fmtNum(total)} in total',
            child: HBarList(
              emptyText: 'No active clients',
              rows: [
                for (final e in entries)
                  HBar(e.key, iNum(e.value), note: total == 0 ? null : '${(iNum(e.value) / total * 100).round()}%'),
              ],
            ),
          );
        }),
        _card(_mt, 'Consultations', (d) {
          final c = _sub(d, 'consultations');
          return DashCard(
            title: 'Consultations',
            child: LayoutBuilder(builder: (context, box) {
              final a = _consultBox('Today', c == null ? null : _sub(c, 'today'));
              final b = _consultBox('This week', c == null ? null : _sub(c, 'thisWeek'));
              if (box.maxWidth < 360) return Column(children: [a, const SizedBox(height: 10), b]);
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: a),
                const SizedBox(width: 10),
                Expanded(child: b),
              ]);
            }),
          );
        }),
      ),
      _pair(
        _card(_mt, 'Escalations by reason', (d) {
          final map = _sub(d, 'escalationsByTrigger') ?? <String, dynamic>{};
          final rows = map.entries.map((e) {
            final s = iMap(e.value);
            return (e.key, _int(s['open']), _int(s['acknowledged']), _int(s['resolved']));
          }).toList()
            ..sort((a, b) => b.$2.compareTo(a.$2));
          return DashCard(
            title: 'Escalations by reason',
            child: rows.isEmpty
                ? _plain('No escalations')
                : DashTable(
                    columns: const [
                      DashCol('Reason', flex: 2.4),
                      DashCol('Open', numeric: true),
                      DashCol('Seen', numeric: true),
                      DashCol('Resolved', numeric: true),
                    ],
                    rows: [
                      for (final r in rows)
                        [
                          Text(metricTriggerLabels[r.$1] ?? r.$1, style: PT.t(12.5)),
                          cellText('${r.$2}', w: FontWeight.w600, c: r.$2 > 0 ? DC.bad : PT.sage),
                          cellText('${r.$3}', c: r.$3 > 0 ? DC.warn : PT.sage),
                          cellText('${r.$4}', c: PT.sage),
                        ],
                    ],
                  ),
          );
        }),
        _card(_mt, 'Open tickets per dietitian', (d) {
          final list = iList(d['slaBreachPerDietitian'])
            ..sort((a, b) => _int(b['openCount']).compareTo(_int(a['openCount'])));
          return DashCard(
            title: 'Open tickets per dietitian',
            child: HBarList(
              emptyText: 'No open tickets',
              rows: [
                for (final r in list)
                  HBar(r['dietitianName']?.toString() ?? 'Dietitian #${r['dietitianId']}', _int(r['openCount']),
                      color: DC.bad),
              ],
            ),
          );
        }),
      ),
    ];
  }

  Widget _consultBox(String label, Map<String, dynamic>? c) {
    Widget line(String k, int v, {bool warn = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(k, style: PT.t(12.5, c: PT.sage))),
            Text('$v', style: tStyle(13, w: FontWeight.w700, c: warn && v > 0 ? DC.bad : PT.ink)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: PT.t(11, w: FontWeight.w700, c: PT.sage).copyWith(letterSpacing: .4)),
        const SizedBox(height: 6),
        Text('${_int(c?['booked'])}', style: tStyle(26, w: FontWeight.w700)),
        Text('booked', style: PT.t(11.5, c: PT.sage)),
        const SizedBox(height: 8),
        line('Completed', _int(c?['completed'])),
        line('In progress', _int(c?['in_progress'])),
        line('No-show', _int(c?['no_show']), warn: true),
        line('Cancelled', _int(c?['cancelled'])),
      ]),
    );
  }
}
