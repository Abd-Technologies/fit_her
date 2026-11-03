import 'package:flutter/material.dart';

import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Trainer: her class ratings (app: TrainerRatingsScreen).
/// Average, stars, what clients loved and what to improve. No names.
class TrainerRatingsPage extends StatefulWidget {
  const TrainerRatingsPage({super.key});

  @override
  State<TrainerRatingsPage> createState() => _TrainerRatingsPageState();
}

class _TrainerRatingsPageState extends State<TrainerRatingsPage> {
  static const _star = Color(0xFFF5B83D);
  static const _redBar = Color(0xFFEBA19E);

  int _days = 30;
  Map<String, dynamic>? _d;
  bool _loading = true;
  String? _error;

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
    final b = await PortalApi.get(Constants.classFeedbackTrainer, query: {'days': '$_days'});
    if (!mounted) return;
    setState(() {
      if (PortalApi.ok(b) && b['data'] is Map) {
        _d = Map<String, dynamic>.from(b['data']);
      } else {
        _d = null;
        _error = PortalApi.msg(b, "Couldn't load your ratings.");
      }
      _loading = false;
    });
  }

  static List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

  static String _avg(dynamic v) => v == null ? '–' : (v is num ? v.toStringAsFixed(1) : '$v');

  static num _n(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

  Widget _box(String title, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: PT.card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: PT.t(11, w: FontWeight.w600, c: PT.sage).copyWith(letterSpacing: .6)),
          const SizedBox(height: 10),
          child,
        ]),
      );

  Widget _bar(String label, num value, num max, {bool bad = false, double labelW = 140}) => Padding(
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
          SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.right, style: PT.t(12, c: PT.sage))),
        ]),
      );

  Widget _tagBars(List<Map<String, dynamic>> tags, {bool bad = false}) {
    if (tags.isEmpty) return Text('Nothing yet', style: PT.t(12.5, c: PT.sage));
    final max = tags.map((e) => _n(e['count'])).fold<num>(0, (a, b) => a > b ? a : b);
    return Column(children: tags.take(6).map((e) => _bar('${e['tag']}', _n(e['count']), max, bad: bad)).toList());
  }

  Widget _daysPicker() => Wrap(
        spacing: 8,
        runSpacing: 8,
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

  Widget _overall(Map<String, dynamic> d) {
    final stars = _list(d['stars']);
    final max = stars.map((e) => _n(e['count'])).fold<num>(0, (a, b) => a > b ? a : b);
    return _box(
      'Your average',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_avg(d['average']), style: PT.t(40, w: FontWeight.w700, h: 1)),
          const SizedBox(width: 6),
          const Padding(padding: EdgeInsets.only(bottom: 6), child: Icon(Icons.star_rounded, color: _star, size: 26)),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('from ${d['count'] ?? 0} ratings · last $_days days', style: PT.t(12, c: PT.sage)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (stars.isEmpty) Text('No ratings in this time.', style: PT.t(12.5, c: PT.sage)),
        ...stars.map((e) => _bar('${e['stars']} ★', _n(e['count']), max, bad: _n(e['stars']) <= 3, labelW: 44)),
      ]),
    );
  }

  Widget _content(Map<String, dynamic> d) => SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _daysPicker(),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (c, box) {
            final loved = _box('What they loved', _tagBars(_list(d['loved'])));
            final improve = _box('To improve', _tagBars(_list(d['improve']), bad: true));
            if (box.maxWidth >= 900) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _overall(d)),
                const SizedBox(width: 16),
                Expanded(child: Column(children: [loved, const SizedBox(height: 16), improve])),
              ]);
            }
            return Column(children: [
              _overall(d),
              const SizedBox(height: 16),
              loved,
              const SizedBox(height: 16),
              improve,
            ]);
          }),
          const SizedBox(height: 16),
          // "Why did you leave early?" (Nov 2026), no names.
          _box(
            'Why women left early',
            _list(d['leftEarly']).isEmpty
                ? Text('No one left early with a reason yet.', style: PT.t(12.5, c: PT.sage))
                : _tagBars(_list(d['leftEarly']), bad: true),
          ),
          const SizedBox(height: 16),
          Text('Ratings are anonymous so clients can be honest.',
              textAlign: TextAlign.center, style: PT.t(11.5, c: PT.sage)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'My ratings',
        sub: 'What clients say about your classes after they join. Names are hidden.',
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
                    title: "Couldn't load your ratings",
                    sub: _error,
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : _content(d),
      ),
    ]);
  }
}
