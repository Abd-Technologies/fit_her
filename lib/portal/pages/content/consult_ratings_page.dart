import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Admin: consultation ratings for every dietitian (Nov 2026).
/// Each dietitian's average, and every 1–2 star rating WITH the client's
/// name so the team can check in with her. GET /appointment/ratings/all
class ConsultRatingsPage extends StatefulWidget {
  const ConsultRatingsPage({super.key});

  @override
  State<ConsultRatingsPage> createState() => _ConsultRatingsPageState();
}

class _ConsultRatingsPageState extends State<ConsultRatingsPage> {
  static const _star = Color(0xFFF5B83D);

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
    final b = await PortalApi.get('/appointment/ratings/all', query: {'days': '$_days'});
    if (!mounted) return;
    setState(() {
      if (PortalApi.ok(b) && b['data'] is Map) {
        _d = Map<String, dynamic>.from(b['data']);
      } else {
        _d = null;
        _error = PortalApi.msg(b, "Couldn't load the ratings.");
      }
      _loading = false;
    });
  }

  static List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  static String _avg(dynamic v) => v == null ? '–' : (v is num ? v.toStringAsFixed(1) : '$v');

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

  Widget _dietitians(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return Text('No ratings in this time.', style: PT.t(12.5, c: PT.sage));
    return Column(
      children: rows.map((r) {
        final improve = _list(r['improve']).map((e) => '${e['tag']} (${e['count']})').join(' · ');
        final low = r['low'] is num ? (r['low'] as num).toInt() : 0;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: PT.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r['name']}', style: PT.t(13.5, w: FontWeight.w600)),
                if (improve.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('To improve: $improve', style: PT.t(11.5, c: PT.sage)),
                  ),
              ]),
            ),
            Text(_avg(r['average']), style: PT.t(16, w: FontWeight.w700)),
            const Icon(Icons.star_rounded, color: _star, size: 18),
            const SizedBox(width: 10),
            SizedBox(width: 70, child: Text('${r['count']} ratings', style: PT.t(12, c: PT.sage))),
            if (low > 0) StatusChip('$low low', color: PT.red),
          ]),
        );
      }).toList(),
    );
  }

  Widget _low(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return Text('No low ratings. 🎉', style: PT.t(12.5, c: PT.sage));
    return Column(
      children: rows.map((r) {
        final at = DateTime.tryParse('${r['at'] ?? ''}')?.toLocal();
        final tags = (r['tags'] is List ? (r['tags'] as List).join(', ') : '');
        final client = r['client'] is Map ? '${(r['client'] as Map)['name']}' : 'A client';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF3D2CF)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${r['rating']} ★', style: PT.t(13, w: FontWeight.w700, c: PT.red)),
              const SizedBox(width: 8),
              Expanded(child: Text('$client · with ${r['dietitian']}', style: PT.t(13, w: FontWeight.w600))),
              if (at != null) Text(DateFormat('d MMM, h:mm a').format(at), style: PT.t(11.5, c: PT.sage)),
            ]),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(tags, style: PT.t(12, c: PT.sage)),
            ],
            if ((r['note'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('"${r['note']}"', style: PT.t(12.5, h: 1.45)),
            ],
          ]),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final overall = d == null ? null : (d['overall'] is Map ? Map<String, dynamic>.from(d['overall']) : null);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Consultation ratings',
        sub: "How clients rate their dietitian sessions. Low ratings show the client's name so you can check in.",
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
                    title: "Couldn't load the ratings",
                    sub: _error,
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _daysPicker(),
                      const SizedBox(height: 16),
                      _box(
                        'All dietitians',
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(_avg(overall?['average']), style: PT.t(36, w: FontWeight.w700, h: 1)),
                          const Padding(
                              padding: EdgeInsets.only(bottom: 4, left: 4),
                              child: Icon(Icons.star_rounded, color: _star, size: 24)),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('from ${overall?['count'] ?? 0} ratings · last $_days days',
                                style: PT.t(12, c: PT.sage)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      _box('By dietitian (lowest first)', _dietitians(_list(d['dietitians']))),
                      const SizedBox(height: 16),
                      _box('Low ratings (1–2 stars)', _low(_list(d['low']))),
                    ]),
                  ),
      ),
    ]);
  }
}
