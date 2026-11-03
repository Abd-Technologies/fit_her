import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/api_provider/api_provider.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../values/constants.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

/// Class feedback for staff (fitHer Flows › Class feedback).
///   Trainer: her average + what clients loved / want improved. No names.
///   Admin:   every trainer's average + low ratings (1–3★) with names.

const _ink = Color(0xFF1F2A1E);
const _soft = Color(0xFF66705F);
const _deep = Color(0xFF4C6A4B);
const _lime = Color(0xFF8AD167);
const _limeBg = Color(0xFFEEF7E6);
const _line = Color(0xFFE3E8DE);
const _page = Color(0xFFF7F9F5);
const _star = Color(0xFFF5B83D);
const _redBar = Color(0xFFEBA19E);
const _red = Color(0xFFD9534F);
const _redBg = Color(0xFFFDF0EF);

TextStyle _t(double size, {FontWeight w = FontWeight.w400, Color c = _ink, double? h}) =>
    TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: w, color: c, height: h);

Future<Map<String, dynamic>?> _fetch(String url, {Map<String, dynamic>? query}) async {
  try {
    final token = Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
    final r = await Get.find<ApiProvider>().getData(url, query: query, headers: {'accessToken': token});
    if (r.body is Map && r.body['status'] == '1' && r.body['data'] is Map) {
      return Map<String, dynamic>.from(r.body['data']);
    }
  } catch (_) {}
  return null;
}

List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

String _avg(dynamic v) => v == null ? '–' : (v is num ? v.toStringAsFixed(1) : '$v');

// ───────────────────────── shared pieces ─────────────────────────

class _Box extends StatelessWidget {
  const _Box({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: _t(11, w: FontWeight.w600, c: _soft).copyWith(letterSpacing: .6)),
          const SizedBox(height: 8),
          child,
        ]),
      );
}

class _Bar extends StatelessWidget {
  const _Bar(this.label, this.value, this.max, {this.bad = false, this.right});
  final String label;
  final num value;
  final num max;
  final bool bad;
  final String? right;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: 120, child: Text(label, style: _t(12.5), overflow: TextOverflow.ellipsis)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: max <= 0 ? 0 : (value / max).clamp(0, 1).toDouble(),
                minHeight: 7,
                backgroundColor: const Color(0xFFEDF0EA),
                valueColor: AlwaysStoppedAnimation(bad ? _redBar : _lime),
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(right ?? '$value', textAlign: TextAlign.right, style: _t(12, c: _soft)),
          ),
        ]),
      );
}

Widget _tagBars(List<Map<String, dynamic>> tags, {bool bad = false}) {
  if (tags.isEmpty) return Text('Nothing yet', style: _t(12.5, c: _soft));
  final max = tags.map((e) => (e['count'] as num?) ?? 0).fold<num>(0, (a, b) => a > b ? a : b);
  return Column(
    children: tags.take(6).map((e) => _Bar('${e['tag']}', (e['count'] as num?) ?? 0, max, bad: bad)).toList(),
  );
}

class _DaysPicker extends StatelessWidget {
  const _DaysPicker(this.days, this.onPick);
  final int days;
  final ValueChanged<int> onPick;
  @override
  Widget build(BuildContext context) => Row(
        children: [7, 30, 90].map((d) {
          final sel = d == days;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onPick(d),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? _limeBg : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? _lime : _line),
                ),
                child: Text('$d days', style: _t(12, w: sel ? FontWeight.w600 : FontWeight.w400, c: sel ? _deep : _ink)),
              ),
            ),
          );
        }).toList(),
      );
}

PreferredSizeWidget _bar(String title) => AppBar(
      backgroundColor: _page,
      elevation: 0,
      foregroundColor: _ink,
      title: Text(title, style: _t(17, w: FontWeight.w700)),
    );

Widget _bigAverage(Map<String, dynamic> d, int days) => Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(_avg(d['average']), style: _t(40, w: FontWeight.w700, h: 1)),
        const SizedBox(width: 6),
        const Padding(padding: EdgeInsets.only(bottom: 6), child: Icon(Icons.star_rounded, color: _star, size: 26)),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('from ${d['count'] ?? 0} ratings · last $days days', style: _t(12, c: _soft)),
          ),
        ),
      ],
    );

// ───────────────────────── trainer ─────────────────────────

/// Small tile for the trainer home: "My ratings 4.7★" → full screen.
class TrainerRatingsTile extends StatefulWidget {
  const TrainerRatingsTile({super.key});
  @override
  State<TrainerRatingsTile> createState() => _TrainerRatingsTileState();
}

class _TrainerRatingsTileState extends State<TrainerRatingsTile> {
  Map<String, dynamic>? _d;
  @override
  void initState() {
    super.initState();
    _fetch(Constants.classFeedbackTrainer, query: {'days': '30'}).then((d) {
      if (mounted) setState(() => _d = d);
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Get.to(() => const TrainerRatingsScreen()),
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: _limeBg, shape: BoxShape.circle),
              child: const Icon(Icons.star_rounded, color: _deep, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('My ratings', style: _t(14, w: FontWeight.w600)),
                Text(
                    _d == null
                        ? 'What clients say about your classes'
                        : '${_avg(_d!['average'])}★ from ${_d!['count'] ?? 0} ratings · last 30 days',
                    style: _t(12, c: _soft)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: _soft),
          ]),
        ),
      );
}

class TrainerRatingsScreen extends StatefulWidget {
  const TrainerRatingsScreen({super.key});
  @override
  State<TrainerRatingsScreen> createState() => _TrainerRatingsScreenState();
}

class _TrainerRatingsScreenState extends State<TrainerRatingsScreen> {
  int _days = 30;
  Map<String, dynamic>? _d;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await _fetch(Constants.classFeedbackTrainer, query: {'days': '$_days'});
    if (mounted) {
      setState(() {
        _d = d;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      backgroundColor: _page,
      appBar: _bar('My ratings'),
      body: _loading
          ? const Center(child: FhLoader())
          : d == null
              ? Center(child: Text("Couldn't load your ratings.", style: _t(13, c: _soft)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                    _DaysPicker(_days, (v) {
                      _days = v;
                      _load();
                    }),
                    const SizedBox(height: 14),
                    _bigAverage(d, _days),
                    _Box(
                      title: 'Stars',
                      child: Builder(builder: (_) {
                        final stars = _list(d['stars']);
                        final max = stars.map((e) => (e['count'] as num?) ?? 0).fold<num>(0, (a, b) => a > b ? a : b);
                        return Column(
                          children: stars
                              .map((e) => _Bar('${e['stars']} ★', (e['count'] as num?) ?? 0, max,
                                  bad: ((e['stars'] as num?) ?? 5) <= 3))
                              .toList(),
                        );
                      }),
                    ),
                    _Box(title: 'What they loved', child: _tagBars(_list(d['loved']))),
                    _Box(title: 'To improve', child: _tagBars(_list(d['improve']), bad: true)),
                    const SizedBox(height: 12),
                    Text('Ratings are anonymous so clients can be honest.',
                        textAlign: TextAlign.center, style: _t(11.5, c: _soft)),
                  ]),
                ),
    );
  }
}

// ───────────────────────── dietitian (Nov 2026) ─────────────────────────
// Her CONSULTATION ratings, same look as the trainer's. GET /appointment/ratings/me

const String _dietRatings = '/appointment/ratings/me';

/// Tile for the dietitian home: "My ratings 4.7★" → full screen.
class DietitianRatingsTile extends StatefulWidget {
  const DietitianRatingsTile({super.key});
  @override
  State<DietitianRatingsTile> createState() => _DietitianRatingsTileState();
}

class _DietitianRatingsTileState extends State<DietitianRatingsTile> {
  Map<String, dynamic>? _d;
  @override
  void initState() {
    super.initState();
    _fetch(_dietRatings, query: {'days': '30'}).then((d) {
      if (mounted) setState(() => _d = d);
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Get.to(() => const DietitianRatingsScreen()),
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: _limeBg, shape: BoxShape.circle),
              child: const Icon(Icons.star_rounded, color: _deep, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('My ratings', style: _t(14, w: FontWeight.w600)),
                Text(
                    _d == null || (_d!['count'] ?? 0) == 0
                        ? 'What clients say about your consultations'
                        : '${_avg(_d!['average'])}★ from ${_d!['count'] ?? 0} ratings · last 30 days',
                    style: _t(12, c: _soft)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: _soft),
          ]),
        ),
      );
}

class DietitianRatingsScreen extends StatefulWidget {
  const DietitianRatingsScreen({super.key});
  @override
  State<DietitianRatingsScreen> createState() => _DietitianRatingsScreenState();
}

class _DietitianRatingsScreenState extends State<DietitianRatingsScreen> {
  int _days = 30;
  Map<String, dynamic>? _d;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await _fetch(_dietRatings, query: {'days': '$_days'});
    if (mounted) {
      setState(() {
        _d = d;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      backgroundColor: _page,
      appBar: _bar('My ratings'),
      body: _loading
          ? const Center(child: FhLoader())
          : d == null
              ? Center(child: Text("Couldn't load your ratings.", style: _t(13, c: _soft)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                    _DaysPicker(_days, (v) {
                      _days = v;
                      _load();
                    }),
                    const SizedBox(height: 14),
                    _bigAverage(d, _days),
                    _Box(
                      title: 'Stars',
                      child: Builder(builder: (_) {
                        final stars = _list(d['stars']);
                        final max = stars.map((e) => (e['count'] as num?) ?? 0).fold<num>(0, (a, b) => a > b ? a : b);
                        return Column(
                          children: stars
                              .map((e) => _Bar('${e['stars']} ★', (e['count'] as num?) ?? 0, max,
                                  bad: ((e['stars'] as num?) ?? 5) <= 3))
                              .toList(),
                        );
                      }),
                    ),
                    _Box(title: 'What they loved', child: _tagBars(_list(d['loved']))),
                    _Box(title: 'To improve', child: _tagBars(_list(d['improve']), bad: true)),
                    _Box(
                      title: 'Latest notes',
                      child: _list(d['notes']).isEmpty
                          ? Text('No written notes yet.', style: _t(12.5, c: _soft))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _list(d['notes'])
                                  .map((n) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 5),
                                        child: Text('${n['rating']}★  "${n['note']}"', style: _t(12.5)),
                                      ))
                                  .toList(),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text('Ratings are anonymous so clients can be honest.',
                        textAlign: TextAlign.center, style: _t(11.5, c: _soft)),
                  ]),
                ),
    );
  }
}

// ───────────────────────── admin ─────────────────────────

class AdminClassFeedbackScreen extends StatefulWidget {
  const AdminClassFeedbackScreen({super.key});
  @override
  State<AdminClassFeedbackScreen> createState() => _AdminClassFeedbackScreenState();
}

class _AdminClassFeedbackScreenState extends State<AdminClassFeedbackScreen> {
  int _days = 30;
  Map<String, dynamic>? _d;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await _fetch(Constants.adminClassFeedback, query: {'days': '$_days'});
    if (mounted) {
      setState(() {
        _d = d;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      backgroundColor: _page,
      appBar: _bar('Class feedback'),
      body: _loading
          ? const Center(child: FhLoader())
          : d == null
              ? Center(child: Text("Couldn't load feedback.", style: _t(13, c: _soft)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                    _DaysPicker(_days, (v) {
                      _days = v;
                      _load();
                    }),
                    const SizedBox(height: 14),
                    _bigAverage(Map<String, dynamic>.from(d['overall'] ?? {}), _days),
                    _Box(
                      title: 'Trainers',
                      child: _list(d['trainers']).isEmpty
                          ? Text('No ratings yet', style: _t(12.5, c: _soft))
                          : Column(
                              children: _list(d['trainers'])
                                  .map((t) => _Bar(
                                        '${t['name']} (${t['count']})',
                                        (t['average'] as num?) ?? 0,
                                        5,
                                        bad: ((t['average'] as num?) ?? 5) < 4,
                                        right: _avg(t['average']),
                                      ))
                                  .toList(),
                            ),
                    ),
                    _Box(
                        title: 'Most common issues',
                        child: _tagBars(_list((d['overall'] as Map?)?['improve']), bad: true)),
                    const SizedBox(height: 16),
                    Text('Low ratings (1–3★)', style: _t(14, w: FontWeight.w700)),
                    if (_list(d['low']).isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('None 🎉', style: _t(12.5, c: _soft)),
                      ),
                    ..._list(d['low']).map(_lowCard),
                  ]),
                ),
    );
  }

  Widget _lowCard(Map<String, dynamic> r) {
    final tags = (r['tags'] is List) ? List<String>.from(r['tags']) : const <String>[];
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _redBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0C9C7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${r['rating']}★ · ${r['className'] ?? 'Class'} with ${r['trainer'] ?? '—'}',
            style: _t(13, w: FontWeight.w700, c: _red)),
        const SizedBox(height: 2),
        Text('${r['client'] ?? 'Client'} · ${r['classDate']} · ${r['minutesAttended'] ?? '?'} min in class',
            style: _t(12, c: _ink)),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF0C9C7))),
                      child: Text(t, style: _t(11, c: _red)),
                    ))
                .toList(),
          ),
        ],
        if ((r['comment'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('"${r['comment']}"', style: _t(12, c: _soft).copyWith(fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }
}
