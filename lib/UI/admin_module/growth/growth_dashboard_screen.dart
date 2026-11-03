import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/api_provider/api_provider.dart';
import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../values/constants.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

/// Admin › Growth: exact facts from our database (with names, so the team
/// can act). Behaviour/funnels live in Mixpanel, not here. See growth.md.
/// Tabs: Overview · Sign-up · Workout · Revenue · Retention.

const _ink = Color(0xFF1F2A1E);
const _soft = Color(0xFF66705F);
const _deep = Color(0xFF4C6A4B);
const _lime = Color(0xFF8AD167);
const _limeBg = Color(0xFFEEF7E6);
const _line = Color(0xFFE3E8DF);
const _page = Color(0xFFF7F9F5);
const _red = Color(0xFFC2412D);
const _redBg = Color(0xFFFCEBE7);
const _amber = Color(0xFFB7791F);
const _amberBg = Color(0xFFFDF3DF);

TextStyle _t(double s, {FontWeight w = FontWeight.w400, Color c = _ink, double? h}) =>
    TextStyle(fontFamily: 'Poppins', fontSize: s, fontWeight: w, color: c, height: h);

Future<Map<String, dynamic>?> _get(String path, {Map<String, dynamic>? query}) async {
  try {
    final token = Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
    final r = await Get.find<ApiProvider>()
        .getData(path, query: query, headers: {'accessToken': token}, timeout: const Duration(seconds: 45));
    if (r.body is Map && r.body['status'] == '1' && r.body['data'] is Map) {
      return Map<String, dynamic>.from(r.body['data']);
    }
    if (r.body is Map && r.body['message'] != null) return {'_error': '${r.body['message']}'};
  } catch (_) {}
  return null;
}

List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

String _n(dynamic v, {String suffix = ''}) => v == null ? '–' : '$v$suffix';

String _money(dynamic v) {
  if (v is! num) return '–';
  final n = v.toDouble();
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 100000 ? 0 : 1)}k';
  return n.toStringAsFixed(0);
}

num _num(dynamic v) => v is num ? v : 0;

class GrowthDashboardScreen extends StatefulWidget {
  const GrowthDashboardScreen({super.key});

  @override
  State<GrowthDashboardScreen> createState() => _GrowthDashboardScreenState();
}

class _GrowthDashboardScreenState extends State<GrowthDashboardScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: _page,
        appBar: AppBar(
          backgroundColor: _page,
          elevation: 0,
          foregroundColor: _ink,
          title: Text('Growth', style: _t(18, w: FontWeight.w700)),
          actions: [
            for (final d in [7, 30, 90])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _days = d),
                  child: Container(
                    alignment: Alignment.center,
                    margin: const EdgeInsets.symmetric(vertical: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: d == _days ? _limeBg : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: d == _days ? _lime : _line),
                    ),
                    child: Text('${d}d',
                        style: _t(12,
                            w: d == _days ? FontWeight.w600 : FontWeight.w400, c: d == _days ? _deep : _ink)),
                  ),
                ),
              ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: _ink,
            unselectedLabelColor: _soft,
            indicatorColor: _lime,
            labelStyle: _t(13, w: FontWeight.w600),
            unselectedLabelStyle: _t(13),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Sign-up'),
              Tab(text: 'Workout'),
              Tab(text: 'Revenue'),
              Tab(text: 'Retention'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _Tab(key: ValueKey('o$_days'), path: '/admin/growth/overview', days: _days, builder: _overview),
          _Tab(key: ValueKey('s$_days'), path: '/admin/growth/signup', days: _days, builder: _signup),
          _Tab(key: ValueKey('w$_days'), path: '/admin/growth/workout', days: _days, builder: _workout),
          _Tab(key: ValueKey('r$_days'), path: '/admin/growth/revenue', days: _days, builder: _revenue),
          _Tab(key: ValueKey('t$_days'), path: '/admin/growth/retention', days: _days, builder: _retention),
        ]),
      ),
    );
  }

  // ── Overview ───────────────────────────────────────────────────────
  List<Widget> _overview(Map<String, dynamic> d) {
    final k = Map<String, dynamic>.from(d['kpis'] ?? {});
    return [
      _kpiGrid([
        _Kpi('New sign-ups', _n(k['signups']), change: k['signupsChange']),
        _Kpi('Trial → paid', _n(k['trialToPaid'], suffix: '%'), sub: '${_n(k['trialsStarted'])} trials'),
        _Kpi('Active paid women', _n(k['activePaid'])),
        _Kpi('Revenue (PKR)', _money(k['revenue']),
            change: k['revenueChange'], sub: k['revenueSource'] == 'approved_slips' ? 'from approved slips' : null),
        _Kpi('Renewal rate', k['renewalRate'] == null ? '–' : '${k['renewalRate']}%', sub: 'from Oct 2026'),
        _Kpi('Active this week', _n(k['activeThisWeekPct'], suffix: '%'), sub: 'of paid women'),
      ]),
      _Section(
        title: 'Today: act on these',
        child: Column(
          children: _list(d['lists']).map((l) {
            final c = l['count'];
            final has = c is num && c > 0;
            return _Row(
              title: '${l['title']}',
              sub: '${l['hint']}',
              value: c == null ? '–' : '$c ›',
              valueColor: has ? _red : _soft,
              onTap: has
                  ? () => Get.to(() => GrowthListScreen(listKey: '${l['key']}', title: '${l['title']}'))
                  : null,
            );
          }).toList(),
        ),
      ),
    ];
  }

  // ── Sign-up ────────────────────────────────────────────────────────
  List<Widget> _signup(Map<String, dynamic> d) {
    return [
      _Section(
        title: 'From account to paid',
        child: Column(
          children: _list(d['funnel'])
              .map((f) => _Bar('${f['step']}', '${f['count']} · ${f['pct']}%', _num(f['pct']) / 100))
              .toList(),
        ),
      ),
      _Section(
        title: 'By source',
        child: Column(
          children: _list(d['bySource'])
              .map((s) => _Row(title: '${s['name']}', sub: '${s['signups']} sign-ups', value: '${s['paidPct']}% paid'))
              .toList(),
        ),
      ),
      _Section(
        title: 'By method',
        child: Column(
          children: _list(d['byMethod'])
              .map((s) => _Row(title: '${s['name']}', sub: '${s['signups']} sign-ups', value: '${s['paidPct']}% paid'))
              .toList(),
        ),
      ),
    ];
  }

  // ── Workout ────────────────────────────────────────────────────────
  List<Widget> _workout(Map<String, dynamic> d) {
    final k = Map<String, dynamic>.from(d['kpis'] ?? {});
    final days = _list(d['byWeekday']);
    num maxDay = 1;
    for (final e in days) {
      if (_num(e['attended']) > maxDay) maxDay = _num(e['attended']);
    }
    return [
      _kpiGrid([
        _Kpi('Classes held', _n(k['classesHeld']),
            sub: '${_n(k['cancelled'])} cancelled · ${_n(k['autoCancelled'])} auto'),
        _Kpi('Stayed 5+ min', _n(k['stayedPct'], suffix: '%'), sub: 'of women who joined'),
        _Kpi('Avg time in class', _n(k['avgMinutes'], suffix: ' min')),
        _Kpi('Women attended', _n(k['womenAttended']), sub: '${_n(k['avgWomenPerClass'])} per class'),
      ]),
      _Section(
        title: 'Attended by weekday',
        child: SizedBox(
          height: 100,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days.map((e) {
              final v = _num(e['attended']);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('$v', style: _t(10, c: _soft)),
                    const SizedBox(height: 2),
                    Container(
                      height: 56 * (v / maxDay).toDouble() + 2,
                      decoration: BoxDecoration(color: _lime, borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(height: 4),
                    Text('${e['day']}', style: _t(10, c: _soft)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ),
      _Section(
        title: 'Time slots',
        child: Column(
          children: _list(d['slots']).map((s) {
            final trainer = '${s['trainer'] ?? ''}';
            return _Row(
              title: '${s['label']}${trainer.isNotEmpty ? ' · $trainer' : ''}',
              sub: '${_n(s['avgWomen'])} women · ${_n(s['avgMinutes'], suffix: ' min')} · '
                  '${s['rating'] == null ? 'no rating' : '★${s['rating']}'}',
              value: '${s['stayedPct']}%',
            );
          }).toList(),
        ),
      ),
      _Section(
        title: 'Trainer scorecard',
        note: d['diarySince'] == null
            ? 'Punctuality fills in from the class diary (started Oct 2026).'
            : 'Punctuality since ${d['diarySince']}',
        child: Column(children: _list(d['trainers']).map(_trainerRow).toList()),
      ),
    ];
  }

  Widget _trainerRow(Map<String, dynamic> t) {
    final onTime = t['onTimePct'] is num ? t['onTimePct'] as num : null;
    final color = onTime == null ? _soft : (onTime >= 90 ? _deep : (onTime >= 75 ? _amber : _red));
    final bg = onTime == null
        ? const Color(0xFFF0F3EC)
        : (onTime >= 90 ? _limeBg : (onTime >= 75 ? _amberBg : _redBg));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F3EC)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${t['name']}', style: _t(13.5, w: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Text(onTime == null ? 'On time –' : 'On time $onTime%',
                style: _t(11, w: FontWeight.w600, c: color)),
          ),
        ]),
        const SizedBox(height: 3),
        Text(
          '${t['classesHeld']} classes · ${_n(t['avgWomen'])} women · '
          '${t['rating'] == null ? 'no rating' : '★${t['rating']}'}'
          '${t['avgLateMinutes'] != null ? ' · late avg ${t['avgLateMinutes']}m' : ''}',
          style: _t(11.5, c: _soft),
        ),
        Text(
          'Auto-cancelled ${t['autoCancelled']} · cancelled ${t['cancelled']} · '
          'forgot to end ${t['forgotToEnd']} · other link ${t['usedOtherLink']}'
          '${t['topIssue'] != null ? ' · issue: ${t['topIssue']}' : ''}',
          style: _t(11, c: _soft),
        ),
      ]),
    );
  }

  // ── Revenue ────────────────────────────────────────────────────────
  List<Widget> _revenue(Map<String, dynamic> d) {
    final kinds = Map<String, dynamic>.from(d['kinds'] ?? {});
    Map<String, dynamic> k(String n) => Map<String, dynamic>.from(kinds[n] ?? {});
    final total = Map<String, dynamic>.from(d['total'] ?? {});
    final pay = Map<String, dynamic>.from(d['payments'] ?? {});
    final types = Map<String, dynamic>.from(d['activeByType'] ?? {});
    num typeTotal = 0;
    for (final v in types.values) {
      typeTotal += _num(v);
    }
    final methods = Map<String, dynamic>.from(pay['methods'] ?? {});
    return [
      if (d['source'] == 'approved_slips')
        const _Note('Purchase history starts Oct 2026. Until then the total comes from approved slips, '
            'and new / renewal / upgrade are not split yet.'),
      _kpiGrid([
        _Kpi('Total (PKR)', _money(total['amount']), sub: '${_n(total['count'])} payments'),
        _Kpi('New purchases', _n(k('new')['count']), sub: _money(k('new')['amount'])),
        _Kpi('Renewals', _n(k('renewal')['count']), sub: _money(k('renewal')['amount'])),
        _Kpi('Upgrades', _n(k('upgrade')['count']), sub: _money(k('upgrade')['amount'])),
        _Kpi('Avg lifetime value', _money(d['avgLifetimeValue']), sub: 'PKR per woman'),
        _Kpi('Pending slips', _n(pay['pending'])),
      ]),
      _Section(
        title: 'Upgrade paths',
        child: _list(d['upgradePaths']).isEmpty
            ? Text('None yet', style: _t(12.5, c: _soft))
            : Column(
                children: _list(d['upgradePaths']).map((p) => _Row(title: '${p['path']}', value: '${p['count']}')).toList(),
              ),
      ),
      _Section(
        title: 'Active plans by type',
        child: Column(
          children: ['combined', 'workout', 'diet']
              .map((t) => _Bar(
                    t[0].toUpperCase() + t.substring(1),
                    '${types[t] ?? 0}',
                    typeTotal == 0 ? 0 : _num(types[t]) / typeTotal,
                  ))
              .toList(),
        ),
      ),
      _Section(
        title: 'Payments',
        child: Column(children: [
          _Row(title: 'Approved', value: _n(pay['approved'])),
          _Row(title: 'Rejected', value: _n(pay['rejected']), valueColor: _num(pay['rejected']) > 0 ? _red : _ink),
          _Row(title: 'DirectPay opened', value: _n(pay['directPayOpened'])),
          if (methods.isNotEmpty)
            _Row(title: 'Methods', value: methods.entries.map((e) => '${e.key} ${e.value}').join(' · ')),
        ]),
      ),
    ];
  }

  // ── Retention ──────────────────────────────────────────────────────
  List<Widget> _retention(Map<String, dynamic> d) {
    Widget head(String s, int flex) =>
        Expanded(flex: flex, child: Text(s, style: _t(11, c: _soft, w: FontWeight.w600)));
    return [
      _Section(
        title: 'By month of first payment',
        child: Column(children: [
          Row(children: [head('Month', 3), head('Women', 2), head('Renewed', 2), head('Active now', 2)]),
          const SizedBox(height: 6),
          ..._list(d['cohorts']).map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(flex: 3, child: Text('${c['month']}', style: _t(12.5))),
                  Expanded(flex: 2, child: Text('${c['women']}', style: _t(12.5))),
                  Expanded(flex: 2, child: _heat(c['renewedPct'])),
                  Expanded(flex: 2, child: _heat(c['activeNowPct'])),
                ]),
              )),
        ]),
      ),
      _Section(
        title: 'What keeps women (renewed)',
        child: Column(
          children: _list(d['whatKeeps'])
              .map((w) => _Row(title: '${w['group']}', sub: '${w['women']} women', value: '${w['renewedPct']}% renew'))
              .toList(),
        ),
      ),
      _Section(
        title: 'Slipping away',
        child: _list(d['slipping']).isEmpty
            ? Text('Nobody right now 🎉', style: _t(12.5, c: _soft))
            : Column(children: _list(d['slipping']).map((p) => _PersonRow(p)).toList()),
      ),
      _Section(
        title: 'Why they cancelled',
        child: _list(d['cancelReasons']).isEmpty
            ? Text('No cancellations', style: _t(12.5, c: _soft))
            : Column(
                children:
                    _list(d['cancelReasons']).map((r) => _Row(title: '${r['reason']}', value: '${r['count']}')).toList(),
              ),
      ),
    ];
  }

  Widget _heat(dynamic v) {
    final p = _num(v).toDouble();
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.lerp(const Color(0xFFF0F3EC), _lime, (p / 100).clamp(0, 1)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('${p.round()}%', style: _t(11.5, w: FontWeight.w600)),
    );
  }
}

// ── shared widgets ─────────────────────────────────────────────────────
class _Tab extends StatefulWidget {
  const _Tab({super.key, required this.path, required this.days, required this.builder});
  final String path;
  final int days;
  final List<Widget> Function(Map<String, dynamic>) builder;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _d;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await _get(widget.path, query: {'days': '${widget.days}'});
    if (mounted) {
      setState(() {
        _d = d;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: FhLoader());
    final d = _d;
    if (d == null || d['_error'] != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(d?['_error']?.toString() ?? "Couldn't load. Check your internet.",
                textAlign: TextAlign.center, style: _t(13, c: _soft)),
            TextButton(onPressed: _load, child: Text('Try again', style: _t(13, w: FontWeight.w600, c: _deep))),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: _lime,
      child: ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 28), children: widget.builder(d)),
    );
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, {this.sub, this.change});
  final String label;
  final String value;
  final String? sub;
  final dynamic change;
}

Widget _kpiGrid(List<_Kpi> items) => LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 8) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((k) {
          final ch = k.change is num ? k.change as num : null;
          return Container(
            width: w,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k.label, style: _t(11, c: _soft)),
              const SizedBox(height: 2),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Flexible(child: Text(k.value, style: _t(20, w: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                if (ch != null) ...[
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('${ch >= 0 ? '▲' : '▼'} ${ch.abs()}%',
                        style: _t(10.5, w: FontWeight.w600, c: ch >= 0 ? _deep : _red)),
                  ),
                ],
              ]),
              if (k.sub != null)
                Text(k.sub!, style: _t(10.5, c: _soft), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          );
        }).toList(),
      );
    });

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.note});
  final String title;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: _t(11, w: FontWeight.w600, c: _soft).copyWith(letterSpacing: .6)),
          if (note != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(note!, style: _t(11, c: _soft))),
          const SizedBox(height: 8),
          child,
        ]),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _amberBg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: _t(12, c: const Color(0xFF7A4E0E), h: 1.4)),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.sub, required this.value, this.valueColor = _ink, this.onTap});
  final String title;
  final String? sub;
  final String value;
  final Color valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F3EC)))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: _t(13, w: FontWeight.w500)),
                if (sub != null && sub!.isNotEmpty) Text(sub!, style: _t(11, c: _soft)),
              ]),
            ),
            const SizedBox(width: 8),
            Text(value, style: _t(13, w: FontWeight.w600, c: valueColor)),
          ]),
        ),
      );
}

class _Bar extends StatelessWidget {
  const _Bar(this.label, this.value, this.fraction);
  final String label;
  final String value;
  final num fraction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label, style: _t(12.5))),
            Text(value, style: _t(12.5, w: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1).toDouble(),
              minHeight: 9,
              backgroundColor: const Color(0xFFEDF0EA),
              valueColor: const AlwaysStoppedAnimation(_lime),
            ),
          ),
        ]),
      );
}

class _PersonRow extends StatelessWidget {
  const _PersonRow(this.p);
  final Map<String, dynamic> p;

  String get _phone => '${p['phone'] ?? ''}'.replaceAll(RegExp(r'[^0-9+]'), '');

  String get _wa {
    var n = _phone.replaceAll('+', '');
    if (n.startsWith('0')) n = '92${n.substring(1)}';
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final high = p['level'] == 'high';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F3EC)))),
      child: Row(children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(color: high ? _red : _amber, shape: BoxShape.circle),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p['name']}', style: _t(13, w: FontWeight.w600)),
            Text('${p['detail']}', style: _t(11.5, c: _soft)),
          ]),
        ),
        if (_phone.isNotEmpty) ...[
          IconButton(
            tooltip: 'WhatsApp',
            icon: const Icon(Icons.chat_rounded, color: _deep, size: 20),
            onPressed: () => launchUrl(Uri.parse('https://wa.me/$_wa'), mode: LaunchMode.externalApplication),
          ),
          IconButton(
            tooltip: 'Call',
            icon: const Icon(Icons.call_rounded, color: _deep, size: 20),
            onPressed: () => launchUrl(Uri.parse('tel:$_phone')),
          ),
        ],
      ]),
    );
  }
}

/// One "act on these" list: names + WhatsApp / call buttons.
class GrowthListScreen extends StatefulWidget {
  const GrowthListScreen({super.key, required this.listKey, required this.title});
  final String listKey;
  final String title;

  @override
  State<GrowthListScreen> createState() => _GrowthListScreenState();
}

class _GrowthListScreenState extends State<GrowthListScreen> {
  Map<String, dynamic>? _d;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await _get('/admin/growth/list/${widget.listKey}');
    if (mounted) {
      setState(() {
        _d = d;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = _list(_d?['people']);
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _page,
        elevation: 0,
        foregroundColor: _ink,
        title: Text(widget.title, style: _t(15.5, w: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: FhLoader())
          : RefreshIndicator(
              onRefresh: _load,
              color: _lime,
              child: ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 28), children: [
                if (_d?['hint'] != null) _Note('${_d!['hint']} · ${people.length} women'),
                if (people.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(_d?['_error']?.toString() ?? 'Nobody on this list right now.',
                        textAlign: TextAlign.center, style: _t(13, c: _soft)),
                  ),
                ...people.map((p) => _PersonRow(p)),
              ]),
            ),
    );
  }
}
