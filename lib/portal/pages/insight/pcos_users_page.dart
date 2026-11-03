import 'package:flutter/material.dart';

import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';
import 'insight_ui.dart';

/// Women who took the BMI / PCOS check (GET /admin/getGuest).
class PcosUsersPage extends StatefulWidget {
  const PcosUsersPage({super.key});

  @override
  State<PcosUsersPage> createState() => _PcosUsersPageState();
}

class _PcosUsersPageState extends State<PcosUsersPage> {
  List<Map<String, dynamic>>? _items;
  bool _loading = true;
  String? _error;
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
    final b = await PortalApi.get(Constants.getGuestUsers);
    List<Map<String, dynamic>>? list;
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map && d['data'] is List) {
      list = iList(d['data']);
      list.sort((a, c) => '${c['createdAt'] ?? ''}'.compareTo('${a['createdAt'] ?? ''}'));
    } else {
      _error = PortalApi.msg(b, "Couldn't load the results.");
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (list != null) {
        _items = list;
      } else if (_items != null) {
        portalToast("Couldn't refresh", sub: _error, error: true);
      }
    });
  }

  static String _s(dynamic v) => v == null || '$v' == 'null' ? '' : '$v';

  static String _name(Map<String, dynamic> u) => '${_s(u['firstName'])} ${_s(u['lastName'])}'.trim();

  @override
  Widget build(BuildContext context) {
    final all = _items ?? const <Map<String, dynamic>>[];
    final q = _q.trim().toLowerCase();
    final items = q.isEmpty
        ? all
        : all
            .where((u) => '${_name(u)} ${_s(u['email'])} ${_s(u['phone'])} ${_s(u['bmiResult'])}'.toLowerCase().contains(q))
            .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'PCOS assessment users',
        sub: 'Everyone who took the BMI / PCOS check in the app, newest first, with her result.',
        actions: [
          if (_items != null)
            Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: StatusChip('${all.length} women')),
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      if (_items != null && all.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: insightSearch('pcos_users_search', 'Search name, email, phone or result', (v) => setState(() => _q = v)),
          ),
        ),
      Expanded(
        child: _loading && _items == null
            ? const Center(child: CircularProgressIndicator())
            : _items == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load the results",
                    sub: _error,
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : all.isEmpty
                    ? const PortalEmpty(icon: Icons.biotech_outlined, title: 'No results yet', sub: 'Women who take the check show up here.')
                    : items.isEmpty
                        ? const PortalEmpty(icon: Icons.search_off_rounded, title: 'No match', sub: 'Try a different search.')
                        : InsightTable(
                            columns: const ['Name', 'Email', 'Phone', 'Result', 'Date', 'Contact'],
                            rows: items.map((u) {
                              final phone = _s(u['phone']);
                              return <Widget>[
                                Text(_name(u).isEmpty ? '—' : _name(u), style: PT.t(13, w: FontWeight.w600)),
                                SelectableText(_s(u['email']).isEmpty ? '—' : _s(u['email']), style: PT.t(13)),
                                SelectableText(phone.isEmpty ? '—' : phone, style: PT.t(13)),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 320),
                                  child: Text(_s(u['bmiResult']).isEmpty ? 'N/A' : _s(u['bmiResult']),
                                      maxLines: 3, overflow: TextOverflow.ellipsis, style: PT.t(13)),
                                ),
                                Text(iDate(u['createdAt']), style: PT.t(13)),
                                Row(mainAxisSize: MainAxisSize.min, children: contactButtons(phone)),
                              ];
                            }).toList(),
                          ),
      ),
    ]);
  }
}
