import 'package:flutter/material.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';
import 'insight_ui.dart';

/// Admin Growth: facts from our database, with names so the team can act.
/// Tabs: Overview, Sign-up, Workout, Revenue, Retention. Same calls as the app.
class GrowthPage extends StatefulWidget {
  const GrowthPage({super.key});

  @override
  State<GrowthPage> createState() => _GrowthPageState();
}

class _GrowthPageState extends State<GrowthPage> {
  int _days = 30;
  int _tick = 0;

  static const _tabs = [
    ('Overview', '/admin/growth/overview'),
    ('Sign-up', '/admin/growth/signup'),
    ('Workout', '/admin/growth/workout'),
    ('Revenue', '/admin/growth/revenue'),
    ('Retention', '/admin/growth/retention'),
  ];

  List<Widget> Function(Map<String, dynamic>) _builderFor(int i) => switch (i) {
        0 => _overview,
        1 => _signup,
        2 => _workout,
        3 => _revenue,
        _ => _retention,
      };

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          title: 'Growth',
          sub: 'Exact numbers from our own records, with names so the team can act. '
              'Pick how many days to look back.',
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => setState(() => _tick++),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: insightPills<int>(
            options: const [(7, 'Last 7 days'), (30, 'Last 30 days'), (90, 'Last 90 days')],
            selected: _days,
            onTap: (d) => setState(() => _days = d),
          ),
        ),
        Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: PT.line))),
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: PT.ink,
            unselectedLabelColor: PT.sage,
            indicatorColor: PT.green,
            dividerColor: Colors.transparent,
            labelStyle: PT.t(13.5, w: FontWeight.w600),
            unselectedLabelStyle: PT.t(13.5),
            tabs: [for (final t in _tabs) Tab(text: t.$1)],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: TabBarView(children: [
            for (var i = 0; i < _tabs.length; i++)
              _GrowthTab(
                key: ValueKey('${_tabs[i].$2}-$_days-$_tick'),
                path: _tabs[i].$2,
                days: _days,
                builder: _builderFor(i),
              ),
          ]),
        ),
      ]),
    );
  }

  // Overview
  List<Widget> _overview(Map<String, dynamic> d) {
    final k = iMap(d['kpis']);
    return [
      kpiGrid([
        Kpi('New sign-ups', iN(k['signups']), change: k['signupsChange']),
        Kpi('Trial to paid', iN(k['trialToPaid'], suffix: '%'), sub: '${iN(k['trialsStarted'])} trials'),
        Kpi('Active paid women', iN(k['activePaid'])),
        Kpi('Revenue (PKR)', iMoney(k['revenue']),
            change: k['revenueChange'], sub: k['revenueSource'] == 'approved_slips' ? 'from approved slips' : null),
        Kpi('Renewal rate', k['renewalRate'] == null ? '–' : '${k['renewalRate']}%', sub: 'from Oct 2026'),
        Kpi('Active this week', iN(k['activeThisWeekPct'], suffix: '%'), sub: 'of paid women'),
      ], minTile: 180),
      InsightSection(
        title: 'Today: act on these',
        note: 'Click a list to see the women on it and contact them.',
        child: Column(
          children: iList(d['lists']).map((l) {
            final c = l['count'];
            final has = c is num && c > 0;
            return InsightRow(
              title: '${l['title']}',
              sub: '${l['hint'] ?? ''}',
              value: c == null ? '–' : (has ? '$c  ›' : '$c'),
              valueColor: has ? PT.red : PT.sage,
              onTap: has ? () => showGrowthList(context, '${l['key']}', '${l['title']}') : null,
            );
          }).toList(),
        ),
      ),
    ];
  }

  // Sign-up
  List<Widget> _signup(Map<String, dynamic> d) {
    Widget table(String title, dynamic rows) => InsightSection(
          title: title,
          child: iList(rows).isEmpty
              ? Text('Nothing yet', style: PT.t(12.5, c: PT.sage))
              : Column(
                  children: iList(rows)
                      .map((s) => InsightRow(
                          title: '${s['name']}', sub: '${s['signups']} sign-ups', value: '${s['paidPct']}% paid'))
                      .toList(),
                ),
        );
    return [
      InsightSection(
        title: 'From account to paid',
        child: Column(
          children: iList(d['funnel'])
              .map((f) => InsightBar('${f['step']}', '${f['count']}  ·  ${f['pct']}%', iNum(f['pct']) / 100))
              .toList(),
        ),
      ),
      insightColumns([table('By source', d['bySource']), table('By method', d['byMethod'])]),
    ];
  }

  // Workout
  List<Widget> _workout(Map<String, dynamic> d) {
    final k = iMap(d['kpis']);
    final days = iList(d['byWeekday']);
    num maxDay = 1;
    for (final e in days) {
      if (iNum(e['attended']) > maxDay) maxDay = iNum(e['attended']);
    }
    return [
      kpiGrid([
        Kpi('Classes held', iN(k['classesHeld']),
            sub: '${iN(k['cancelled'])} cancelled · ${iN(k['autoCancelled'])} auto-cancelled'),
        Kpi('Stayed 10+ min', iN(k['stayedPct'], suffix: '%'), sub: 'of women who joined'),
        Kpi('Average time in class', iN(k['avgMinutes'], suffix: ' min')),
        Kpi('Women attended', iN(k['womenAttended']), sub: '${iN(k['avgWomenPerClass'])} per class'),
      ], minTile: 220),
      insightColumns([
        InsightSection(
          title: 'Attended by weekday',
          child: SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((e) {
                final v = iNum(e['attended']);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('$v', style: PT.t(11.5, c: PT.sage)),
                      const SizedBox(height: 3),
                      Container(
                        height: 100 * (v / maxDay).toDouble() + 2,
                        decoration: BoxDecoration(color: PT.green, borderRadius: BorderRadius.circular(5)),
                      ),
                      const SizedBox(height: 6),
                      Text('${e['day']}', style: PT.t(11.5, c: PT.sage)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        InsightSection(
          title: 'Time slots',
          child: iList(d['slots']).isEmpty
              ? Text('No classes in this period', style: PT.t(12.5, c: PT.sage))
              : Column(
                  children: iList(d['slots']).map((s) {
                    final trainer = '${s['trainer'] ?? ''}';
                    return InsightRow(
                      title: '${s['label']}${trainer.isNotEmpty ? ' · $trainer' : ''}',
                      sub: '${iN(s['avgWomen'])} women · ${iN(s['avgMinutes'], suffix: ' min')} · '
                          '${s['rating'] == null ? 'no rating' : '★ ${s['rating']}'}',
                      value: '${s['stayedPct']}% stayed',
                    );
                  }).toList(),
                ),
        ),
      ]),
      InsightSection(
        title: 'Trainer scorecard',
        note: d['diarySince'] == null
            ? 'Punctuality fills in from the class diary (started Oct 2026).'
            : 'Punctuality since ${d['diarySince']}',
        child: _trainerTable(iList(d['trainers'])),
      ),
    ];
  }

  Widget _trainerTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return Text('No trainers in this period', style: PT.t(12.5, c: PT.sage));
    DataCell cell(String s) => DataCell(Text(s, style: PT.t(12.5)));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 38,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 52,
        columnSpacing: 22,
        headingTextStyle: PT.t(11.5, w: FontWeight.w700, c: PT.sage),
        columns: const [
          DataColumn(label: Text('Trainer')),
          DataColumn(label: Text('On time')),
          DataColumn(label: Text('Classes'), numeric: true),
          DataColumn(label: Text('Women per class'), numeric: true),
          DataColumn(label: Text('Rating')),
          DataColumn(label: Text('Late (avg)')),
          DataColumn(label: Text('Auto-cancelled'), numeric: true),
          DataColumn(label: Text('Cancelled'), numeric: true),
          DataColumn(label: Text('Forgot to end'), numeric: true),
          DataColumn(label: Text('Used other link'), numeric: true),
          DataColumn(label: Text('Top issue')),
        ],
        rows: rows.map((t) {
          final onTime = t['onTimePct'] is num ? t['onTimePct'] as num : null;
          final color = onTime == null ? PT.sage : (onTime >= 90 ? PT.greenDark : (onTime >= 75 ? PT.amber : PT.red));
          return DataRow(cells: [
            DataCell(Text('${t['name']}', style: PT.t(13, w: FontWeight.w600))),
            DataCell(StatusChip(onTime == null ? '–' : '$onTime%', color: color)),
            cell(iN(t['classesHeld'])),
            cell(iN(t['avgWomen'])),
            cell(t['rating'] == null ? 'no rating' : '★ ${t['rating']}'),
            cell(t['avgLateMinutes'] == null ? '–' : '${t['avgLateMinutes']} min'),
            cell(iN(t['autoCancelled'])),
            cell(iN(t['cancelled'])),
            cell(iN(t['forgotToEnd'])),
            cell(iN(t['usedOtherLink'])),
            cell(t['topIssue'] == null ? '–' : '${t['topIssue']}'),
          ]);
        }).toList(),
      ),
    );
  }

  // Revenue
  List<Widget> _revenue(Map<String, dynamic> d) {
    final kinds = iMap(d['kinds']);
    Map<String, dynamic> k(String n) => iMap(kinds[n]);
    final total = iMap(d['total']);
    final pay = iMap(d['payments']);
    final types = iMap(d['activeByType']);
    num typeTotal = 0;
    for (final v in types.values) {
      typeTotal += iNum(v);
    }
    final methods = iMap(pay['methods']);
    return [
      if (d['source'] == 'approved_slips')
        const InsightNote('Purchase history starts Oct 2026. Until then the total comes from approved slips, '
            'and new / renewal / upgrade are not split yet.'),
      kpiGrid([
        Kpi('Total (PKR)', iMoney(total['amount']), sub: '${iN(total['count'])} payments'),
        Kpi('New purchases', iN(k('new')['count']), sub: 'PKR ${iMoney(k('new')['amount'])}'),
        Kpi('Renewals', iN(k('renewal')['count']), sub: 'PKR ${iMoney(k('renewal')['amount'])}'),
        Kpi('Upgrades', iN(k('upgrade')['count']), sub: 'PKR ${iMoney(k('upgrade')['amount'])}'),
        Kpi('Average lifetime value', iMoney(d['avgLifetimeValue']), sub: 'PKR per woman'),
        Kpi('Slips waiting', iN(pay['pending'])),
      ], minTile: 180),
      insightColumns([
        InsightSection(
          title: 'Active plans by type',
          child: Column(
            children: ['combined', 'workout', 'diet']
                .map((t) => InsightBar(
                      t[0].toUpperCase() + t.substring(1),
                      '${types[t] ?? 0}',
                      typeTotal == 0 ? 0 : iNum(types[t]) / typeTotal,
                    ))
                .toList(),
          ),
        ),
        InsightSection(
          title: 'Payments',
          child: Column(children: [
            InsightRow(title: 'Approved', value: iN(pay['approved'])),
            InsightRow(
                title: 'Rejected', value: iN(pay['rejected']), valueColor: iNum(pay['rejected']) > 0 ? PT.red : PT.ink),
            InsightRow(title: 'DirectPay opened', value: iN(pay['directPayOpened'])),
            if (methods.isNotEmpty)
              InsightRow(title: 'Methods', value: methods.entries.map((e) => '${e.key} ${e.value}').join('  ·  ')),
          ]),
        ),
        InsightSection(
          title: 'Upgrade paths',
          child: iList(d['upgradePaths']).isEmpty
              ? Text('None yet', style: PT.t(12.5, c: PT.sage))
              : Column(
                  children: iList(d['upgradePaths'])
                      .map((p) => InsightRow(title: '${p['path']}', value: '${p['count']}'))
                      .toList(),
                ),
        ),
      ]),
    ];
  }

  // Retention
  List<Widget> _retention(Map<String, dynamic> d) {
    Widget head(String s, int flex) => Expanded(flex: flex, child: Text(s, style: PT.t(11.5, c: PT.sage, w: FontWeight.w700)));
    final cohorts = iList(d['cohorts']);
    return [
      insightColumns([
        InsightSection(
          title: 'By month of first payment',
          child: cohorts.isEmpty
              ? Text('No payments yet', style: PT.t(12.5, c: PT.sage))
              : Column(children: [
                  Row(children: [head('Month', 3), head('Women', 2), head('Renewed', 2), head('Active now', 2)]),
                  const SizedBox(height: 6),
                  ...cohorts.map((c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Expanded(flex: 3, child: Text('${c['month']}', style: PT.t(13))),
                          Expanded(flex: 2, child: Text('${c['women']}', style: PT.t(13))),
                          Expanded(flex: 2, child: _heat(c['renewedPct'])),
                          Expanded(flex: 2, child: _heat(c['activeNowPct'])),
                        ]),
                      )),
                ]),
        ),
        InsightSection(
          title: 'What keeps women (renewed)',
          child: iList(d['whatKeeps']).isEmpty
              ? Text('Not enough data yet', style: PT.t(12.5, c: PT.sage))
              : Column(
                  children: iList(d['whatKeeps'])
                      .map((w) => InsightRow(
                          title: '${w['group']}', sub: '${w['women']} women', value: '${w['renewedPct']}% renew'))
                      .toList(),
                ),
        ),
        InsightSection(
          title: 'Slipping away',
          note: 'Used to come often, now quiet. Contact them before they leave.',
          child: iList(d['slipping']).isEmpty
              ? Text('Nobody right now', style: PT.t(12.5, c: PT.sage))
              : Column(children: iList(d['slipping']).map((p) => PersonRow(p)).toList()),
        ),
        InsightSection(
          title: 'Why they cancelled',
          child: iList(d['cancelReasons']).isEmpty
              ? Text('No cancellations', style: PT.t(12.5, c: PT.sage))
              : Column(
                  children: iList(d['cancelReasons'])
                      .map((r) => InsightRow(title: '${r['reason']}', value: '${r['count']}'))
                      .toList(),
                ),
        ),
      ]),
    ];
  }

  Widget _heat(dynamic v) {
    final p = iNum(v).toDouble();
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.lerp(const Color(0xFFF0F3EC), PT.green, (p / 100).clamp(0, 1).toDouble()),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('${p.round()}%', style: PT.t(12, w: FontWeight.w600)),
    );
  }
}

/// One tab: loads its path with ?days= and shows the cards.
class _GrowthTab extends StatefulWidget {
  const _GrowthTab({super.key, required this.path, required this.days, required this.builder});
  final String path;
  final int days;
  final List<Widget> Function(Map<String, dynamic>) builder;

  @override
  State<_GrowthTab> createState() => _GrowthTabState();
}

class _GrowthTabState extends State<_GrowthTab> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

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
    final b = await insightGet(widget.path, query: {'days': '${widget.days}'});
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (PortalApi.ok(b) && b['data'] is Map) {
        _d = Map<String, dynamic>.from(b['data']);
      } else {
        _d = null;
        _error = PortalApi.msg(b, "Couldn't load. Check your internet.");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    final d = _d;
    if (d == null) {
      return PortalEmpty(
        icon: Icons.cloud_off_outlined,
        title: "Couldn't load these numbers",
        sub: _error,
        action: TextButton(onPressed: _load, child: const Text('Try again')),
      );
    }
    final items = widget.builder(d);
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) => items[i],
    );
  }
}

/// Drill-down: the women on one "act on these" list, with WhatsApp / call.
Future<void> showGrowthList(BuildContext context, String listKey, String title) => showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
          child: GrowthListView(listKey: listKey, title: title),
        ),
      ),
    );

class GrowthListView extends StatefulWidget {
  const GrowthListView({super.key, required this.listKey, required this.title});
  final String listKey;
  final String title;

  @override
  State<GrowthListView> createState() => _GrowthListViewState();
}

class _GrowthListViewState extends State<GrowthListView> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true;
  String _q = '';

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
    final b = await insightGet('/admin/growth/list/${widget.listKey}');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (PortalApi.ok(b) && b['data'] is Map) {
        _d = Map<String, dynamic>.from(b['data']);
      } else {
        _d = null;
        _error = PortalApi.msg(b, "Couldn't load the list.");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = iList(_d?['people']);
    final q = _q.trim().toLowerCase();
    final people = q.isEmpty
        ? all
        : all
            .where((p) => '${p['name'] ?? ''} ${p['phone'] ?? ''} ${p['detail'] ?? ''}'.toLowerCase().contains(q))
            .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 12, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(widget.title, style: PT.t(18, w: FontWeight.w700))),
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ]),
        if (_d?['hint'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: InsightNote('${_d!['hint']}  ·  ${all.length} women'),
          ),
        if (all.length > 8)
          Padding(
            padding: const EdgeInsets.only(top: 10, right: 10),
            child: TextField(
              key: const ValueKey('growth_list_search'),
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Flexible(
          child: _loading
              ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              : _d == null
                  ? PortalEmpty(
                      icon: Icons.cloud_off_outlined,
                      title: "Couldn't load the list",
                      sub: _error,
                      action: TextButton(onPressed: _load, child: const Text('Try again')),
                    )
                  : people.isEmpty
                      ? PortalEmpty(
                          icon: Icons.task_alt_rounded,
                          title: q.isEmpty ? 'Nobody on this list right now' : 'No match',
                        )
                      : ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(right: 10),
                          children: people.map((p) => PersonRow(p)).toList(),
                        ),
        ),
      ]),
    );
  }
}
