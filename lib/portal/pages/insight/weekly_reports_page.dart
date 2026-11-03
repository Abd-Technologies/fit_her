import 'package:flutter/material.dart';

import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';
import 'insight_ui.dart';

/// Body measurements every client sends (GET /admin/userReports).
/// One row per report, with search by name, email or phone.
class WeeklyReportsPage extends StatefulWidget {
  const WeeklyReportsPage({super.key});

  @override
  State<WeeklyReportsPage> createState() => _WeeklyReportsPageState();
}

class _WeeklyReportsPageState extends State<WeeklyReportsPage> {
  List<Map<String, dynamic>>? _rows;
  bool _loading = true;
  String? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _s(dynamic v) => v == null || '$v' == 'null' ? '' : '$v';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final b = await PortalApi.get(Constants.getReports);
    List<Map<String, dynamic>>? rows;
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map && d['reports'] is List) {
      rows = [];
      for (final u in iList(d['reports'])) {
        final name = '${_s(u['firstName'])} ${_s(u['lastName'])}'.trim();
        for (final r in iList(u['Reports'])) {
          rows.add({
            ...r,
            '_name': name.isEmpty ? 'Client #${u['id']}' : name,
            '_email': _s(u['email']),
            '_phone': _s(u['phone']),
          });
        }
      }
      rows.sort((a, c) => '${c['updatedAt'] ?? ''}'.compareTo('${a['updatedAt'] ?? ''}'));
    } else {
      _error = PortalApi.msg(b, "Couldn't load the reports.");
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (rows != null) {
        _rows = rows;
      } else if (_rows != null) {
        portalToast("Couldn't refresh", sub: _error, error: true);
      }
    });
  }

  String _dash(dynamic v) => _s(v).isEmpty ? '—' : _s(v);

  Widget _weight(Map<String, dynamic> r) {
    final a = num.tryParse(_s(r['weight']));
    final b = num.tryParse(_s(r['currentWeight']));
    final txt = Text(_dash(r['currentWeight']), style: PT.t(13, w: FontWeight.w600));
    if (a == null || b == null || a == b) return txt;
    final diff = b - a;
    final down = diff < 0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      txt,
      const SizedBox(width: 6),
      Text('${down ? '▼' : '▲'} ${diff.abs().toStringAsFixed(diff.abs() % 1 == 0 ? 0 : 1)}',
          style: PT.t(11.5, w: FontWeight.w600, c: down ? PT.greenDark : PT.amber)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final all = _rows ?? const <Map<String, dynamic>>[];
    final q = _q.trim().toLowerCase();
    final rows = q.isEmpty
        ? all
        : all.where((r) => '${r['_name']} ${r['_email']} ${r['_phone']}'.toLowerCase().contains(q)).toList();
    final women = all.map((r) => r['_name']).toSet().length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Weekly reports',
        sub: 'Weight and body measurements the women send each week. Search to see one woman’s progress.',
        actions: [
          if (_rows != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: StatusChip('${all.length} reports · $women women'),
            ),
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      if (_rows != null && all.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: insightSearch('weekly_reports_search', 'Search name, email or phone', (v) => setState(() => _q = v)),
          ),
        ),
      Expanded(
        child: _loading && _rows == null
            ? const Center(child: CircularProgressIndicator())
            : _rows == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load the reports",
                    sub: _error,
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : all.isEmpty
                    ? const PortalEmpty(icon: Icons.straighten_outlined, title: 'No reports yet', sub: 'Reports show up here when women send them.')
                    : rows.isEmpty
                        ? const PortalEmpty(icon: Icons.search_off_rounded, title: 'No match', sub: 'Try a different search.')
                        : InsightTable(
                            columns: const [
                              'Name',
                              'Start date',
                              'End date',
                              '1st day weight',
                              'Current weight',
                              'Waist',
                              'Shoulder',
                              'Arms',
                              'Chest',
                              'Abdomen',
                              'Hips',
                              'Thighs',
                            ],
                            rows: rows
                                .map((r) => <Widget>[
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${r['_name']}', style: PT.t(13, w: FontWeight.w600)),
                                          if (_s(r['_phone']).isNotEmpty) Text(_s(r['_phone']), style: PT.t(11.5, c: PT.sage)),
                                        ],
                                      ),
                                      Text(iDate(r['istDayDate'])),
                                      Text(r['currentDate'] == null ? '—' : iDate(r['currentDate'])),
                                      Text(_dash(r['weight'])),
                                      _weight(r),
                                      Text(_dash(r['weist'])),
                                      Text(_dash(r['shoulder'])),
                                      Text(_dash(r['arms'])),
                                      Text(_dash(r['chest'])),
                                      Text(_dash(r['abdoman'])),
                                      Text(_dash(r['hips'])),
                                      Text(_dash(r['thighs'])),
                                    ])
                                .toList(),
                          ),
      ),
    ]);
  }
}
