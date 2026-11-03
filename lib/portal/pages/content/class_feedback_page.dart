import 'package:flutter/material.dart';

import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Class ratings from clients (app: Class Feedback / AdminClassFeedbackScreen).
/// Every trainer average, most common issues, and low ratings with names.
class ClassFeedbackPage extends StatefulWidget {
  const ClassFeedbackPage({super.key});

  @override
  State<ClassFeedbackPage> createState() => _ClassFeedbackPageState();
}

class _ClassFeedbackPageState extends State<ClassFeedbackPage> {
  static const _star = Color(0xFFF5B83D);
  static const _redBar = Color(0xFFEBA19E);
  static const _redBg = Color(0xFFFDF0EF);
  static const _redLine = Color(0xFFF0C9C7);

  int _days = 30;
  Map<String, dynamic>? _d;
  bool _loading = true;
  String? _trainer; // filter for the low ratings list (trainer name)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final b = await PortalApi.get(Constants.adminClassFeedback, query: {'days': '$_days'});
    Map<String, dynamic>? d;
    if (PortalApi.ok(b) && b['data'] is Map) {
      d = Map<String, dynamic>.from(b['data']);
    } else {
      portalToast("Couldn't load feedback", sub: PortalApi.msg(b), error: true);
    }
    if (!mounted) return;
    setState(() {
      _d = d ?? _d;
      _loading = false;
      if (d != null && _trainer != null && !_list(d['trainers']).any((t) => '${t['name']}' == _trainer)) {
        _trainer = null;
      }
    });
  }

  static List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

  static String _avg(dynamic v) => v == null ? '–' : (v is num ? v.toStringAsFixed(1) : '$v');

  static num _n(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

  // ---------- small pieces ----------

  Widget _box(String title, Widget child, {Widget? trailing}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: PT.card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(title.toUpperCase(),
                  style: PT.t(11, w: FontWeight.w600, c: PT.sage).copyWith(letterSpacing: .6)),
            ),
            if (trailing != null) trailing,
          ]),
          const SizedBox(height: 10),
          child,
        ]),
      );

  Widget _bar(String label, num value, num max, {bool bad = false, String? right, double labelW = 140}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: labelW, child: Text(label, style: PT.t(12.5), overflow: TextOverflow.ellipsis)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: max <= 0 ? 0 : (value / max).clamp(0, 1).toDouble(),
                minHeight: 8,
                backgroundColor: const Color(0xFFEDF0EA),
                valueColor: AlwaysStoppedAnimation(bad ? _redBar : PT.green),
              ),
            ),
          ),
          SizedBox(width: 40, child: Text(right ?? '$value', textAlign: TextAlign.right, style: PT.t(12, c: PT.sage))),
        ]),
      );

  Widget _tagBars(List<Map<String, dynamic>> tags, {bool bad = false}) {
    if (tags.isEmpty) return Text('Nothing yet', style: PT.t(12.5, c: PT.sage));
    final max = tags.map((e) => _n(e['count'])).fold<num>(0, (a, b) => a > b ? a : b);
    return Column(children: tags.take(8).map((e) => _bar('${e['tag']}', _n(e['count']), max, bad: bad)).toList());
  }

  Widget _daysPicker() => Wrap(
        spacing: 8,
        children: [7, 30, 90].map((d) {
          final sel = d == _days;
          return ChoiceChip(
            label: Text('Last $d days'),
            selected: sel,
            showCheckmark: false,
            labelStyle: PT.t(12.5, w: sel ? FontWeight.w600 : FontWeight.w400, c: sel ? PT.greenDark : PT.ink),
            selectedColor: const Color(0xFFEAF7E4),
            backgroundColor: Colors.white,
            side: BorderSide(color: sel ? PT.green : PT.line),
            onSelected: _loading
                ? null
                : (_) {
                    if (d == _days) return;
                    setState(() => _days = d);
                    _load();
                  },
          );
        }).toList(),
      );

  Widget _overall(Map<String, dynamic> o) {
    final stars = _list(o['stars']);
    final max = stars.map((e) => _n(e['count'])).fold<num>(0, (a, b) => a > b ? a : b);
    return _box(
      'Overall',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_avg(o['average']), style: PT.t(40, w: FontWeight.w700, h: 1)),
          const SizedBox(width: 6),
          const Padding(padding: EdgeInsets.only(bottom: 6), child: Icon(Icons.star_rounded, color: _star, size: 26)),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('from ${o['count'] ?? 0} ratings · last $_days days', style: PT.t(12, c: PT.sage)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        ...stars.map((e) => _bar('${e['stars']} ★', _n(e['count']), max, bad: _n(e['stars']) <= 3, labelW: 44)),
      ]),
    );
  }

  Widget _trainers(List<Map<String, dynamic>> list) => _box(
        'Trainers',
        list.isEmpty
            ? Text('No ratings yet', style: PT.t(12.5, c: PT.sage))
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('Click a trainer to see only her low ratings.', style: PT.t(11.5, c: PT.sage)),
                ),
                ...list.map((t) {
                  final name = '${t['name']}';
                  final sel = name == _trainer;
                  final avg = t['average'] == null ? null : _n(t['average']);
                  return Material(
                    color: sel ? const Color(0xFFEAF7E4) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _trainer = sel ? null : name),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _bar('$name (${t['count'] ?? 0})', avg ?? 0, 5,
                            bad: (avg ?? 5) < 4, right: _avg(t['average'])),
                      ),
                    ),
                  );
                }),
              ]),
      );

  Widget _lowCard(Map<String, dynamic> r) {
    final tags = r['tags'] is List ? (r['tags'] as List).map((e) => '$e').toList() : const <String>[];
    final comment = '${r['comment'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _redBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _redLine),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${r['rating']}★ · ${r['className'] ?? 'Class'} with ${r['trainer'] ?? '—'}',
            style: PT.t(13.5, w: FontWeight.w700, c: PT.red)),
        const SizedBox(height: 2),
        SelectableText('${r['client'] ?? 'Client'} · ${r['classDate'] ?? ''} · ${r['minutesAttended'] ?? '?'} min in class',
            style: PT.t(12.5)),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _redLine)),
                      child: Text(t, style: PT.t(11.5, c: PT.red)),
                    ))
                .toList(),
          ),
        ],
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText('"$comment"', style: PT.t(12.5, c: PT.sage).copyWith(fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }

  Widget _low(List<Map<String, dynamic>> all) {
    final list = _trainer == null ? all : all.where((r) => '${r['trainer']}' == _trainer).toList();
    return _box(
      _trainer == null ? 'Low ratings (1–3★)' : 'Low ratings (1–3★) · $_trainer',
      list.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('None. Well done!', style: PT.t(12.5, c: PT.sage)),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: list.map(_lowCard).toList()),
      trailing: _trainer == null
          ? StatusChip('${list.length}', color: list.isEmpty ? PT.green : PT.red)
          : TextButton(onPressed: () => setState(() => _trainer = null), child: const Text('Show all trainers')),
    );
  }

  /// "Why did you leave early?" (Nov 2026): reasons + latest answers.
  Widget _leftEarly(Map<String, dynamic> d) {
    final le = d['leftEarly'] is Map ? Map<String, dynamic>.from(d['leftEarly']) : <String, dynamic>{};
    final reasons = _list(le['reasons']);
    final recent = _list(le['recent']);
    return _box(
      'Why women left early',
      reasons.isEmpty
          ? Text('No answers yet. Women who leave after 5+ min but before half the class are asked once, gently.',
              style: PT.t(12.5, c: PT.sage, h: 1.4))
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _tagBars(reasons.map((r) => {'tag': r['tag'], 'count': r['count']}).toList(), bad: true),
              const SizedBox(height: 10),
              for (final r in recent.take(10))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SelectableText(
                    '${r['client'] ?? 'Client'} · ${r['className'] ?? 'Class'} with ${r['trainer'] ?? '—'} · '
                    '${r['classDate'] ?? ''} · ${r['minutesAttended'] ?? '?'} min · ${r['reason']}'
                    '${(r['comment'] ?? '').toString().isNotEmpty ? ' · "${r['comment']}"' : ''}',
                    style: PT.t(12, c: PT.sage),
                  ),
                ),
            ]),
    );
  }

  Widget _body(Map<String, dynamic> d) {
    final o = d['overall'] is Map ? Map<String, dynamic>.from(d['overall']) : <String, dynamic>{};
    final trainers = _list(d['trainers']);
    final low = _list(d['low']);
    final issues = _box('Most common issues', _tagBars(_list(o['improve']), bad: true));
    final loved = _box('What clients loved', _tagBars(_list(o['loved'])));
    return LayoutBuilder(builder: (c, box) {
      final wide = box.maxWidth >= 900;
      return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _overall(o)),
              const SizedBox(width: 16),
              Expanded(child: issues),
              const SizedBox(width: 16),
              Expanded(child: loved),
            ])
          else ...[
            _overall(o),
            const SizedBox(height: 16),
            issues,
            const SizedBox(height: 16),
            loved,
          ],
          const SizedBox(height: 16),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: _trainers(trainers)),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: _low(low)),
            ])
          else ...[
            _trainers(trainers),
            const SizedBox(height: 16),
            _low(low),
          ],
          const SizedBox(height: 16),
          _leftEarly(d),
          const SizedBox(height: 8),
        ]),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Class feedback',
        sub: 'How clients rate the classes. Trainers see only their own ratings without names; here you see everything.',
        actions: [
          if (_loading && d != null)
            const Padding(
                padding: EdgeInsets.only(top: 12, right: 8),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Padding(padding: const EdgeInsets.only(bottom: 14), child: _daysPicker()),
      Expanded(
        child: _loading && d == null
            ? const Center(child: CircularProgressIndicator())
            : d == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load feedback",
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : _n((d['overall'] is Map ? d['overall']['count'] : 0)) == 0
                    ? PortalEmpty(
                        icon: Icons.star_outline_rounded,
                        title: 'No ratings yet',
                        sub: 'No class ratings in the last $_days days.',
                      )
                    : _body(d),
      ),
    ]);
  }
}
