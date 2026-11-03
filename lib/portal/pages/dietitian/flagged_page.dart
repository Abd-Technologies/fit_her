import 'package:flutter/material.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';
import 'client_detail.dart';

/// Day 7 reviews the server flagged (adherence under 40%, pain, severe side
/// effects, or satisfaction under 2). Pick one to see the review and the
/// client's full profile.
class FlaggedPage extends StatefulWidget {
  const FlaggedPage({super.key});

  @override
  State<FlaggedPage> createState() => _FlaggedPageState();
}

class _FlaggedPageState extends State<FlaggedPage> {
  List<Map<String, dynamic>>? _items;
  bool _loading = true;
  String? _error;
  int? _selId;

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
    final b = await PortalApi.get('/admin/day7-reviews', query: {'flagged': 'true', 'limit': '100', 'offset': '0'});
    if (!mounted) return;
    final d = b['data'];
    List<Map<String, dynamic>>? list;
    String? err;
    if (PortalApi.ok(b) && d is Map && d['reviews'] is List) {
      list = dtMaps(d['reviews']);
    } else {
      err = PortalApi.msg(b, "Couldn't load flagged reviews.");
      if (_items != null) portalToast("Couldn't refresh", sub: err, error: true);
    }
    setState(() {
      _loading = false;
      _error = err;
      if (list != null) {
        _items = list;
        if (!list.any((e) => dtInt(e['id']) == _selId)) _selId = null;
      }
    });
  }

  static String _name(Map<String, dynamic> r) {
    final n = dtUserName(r['User'], '');
    return n.isEmpty ? 'Client #${r['userId'] ?? '?'}' : n;
  }

  Widget _tile(Map<String, dynamic> r) {
    final id = dtInt(r['id']);
    final sel = id == _selId;
    final reasons = dtList(r['flagReasons']);
    return Material(
      color: sel ? const Color(0xFFEAF7E4) : Colors.white,
      child: InkWell(
        onTap: () => setState(() => _selId = id),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: PT.line), left: BorderSide(color: PT.red, width: 3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(_name(r), style: PT.t(13.5, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(dtDate(r['createdAt'], 'd MMM'), style: PT.t(11, c: PT.sage)),
            ]),
            Text('Cycle ${r['cycle'] ?? '?'} · ${'${r['planType'] ?? 'plan'}'.toUpperCase()}', style: PT.t(11.5, c: PT.sage)),
            if (reasons.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 5, runSpacing: 5, children: reasons.map((x) => dtTag('$x')).toList()),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _detail(Map<String, dynamic> r, {VoidCallback? onBack}) {
    final u = r['User'] is Map ? Map<String, dynamic>.from(r['User'] as Map) : <String, dynamic>{};
    final uid = dtInt(r['userId']) ?? dtInt(u['id']);
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back, size: 18), label: const Text('All flagged reviews')),
          ),
        dtCard(
          title: 'Flagged review',
          sub: 'Reach out to her, then check her plan. The flag clears when the matching client alert is resolved.',
          child: dtReviewCard(r, showClient: true),
        ),
        const SizedBox(height: 14),
        if (uid == null || uid == 0)
          const PortalEmpty(icon: Icons.person_off_outlined, title: 'Client details missing')
        else
          ClientDetailPanel(
            key: ValueKey('flag_client_${r['id']}'),
            userId: uid,
            name: _name(r),
            email: u['email']?.toString(),
            userPlanId: dtInt(r['userPlanId']),
            initialTab: 1,
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items ?? const <Map<String, dynamic>>[];
    final sel = items.where((e) => dtInt(e['id']) == _selId).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Flagged Day 7 reviews',
        sub: 'Reviews that need you: adherence under 40%, pain, severe side effects or very low satisfaction.',
        actions: [
          if (_items != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: StatusChip('${items.length} flagged', color: items.isEmpty ? PT.green : PT.red),
            ),
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Expanded(
        child: _loading && _items == null
            ? const Center(child: CircularProgressIndicator())
            : _items == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load flagged reviews",
                    sub: _error,
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : items.isEmpty
                    ? const PortalEmpty(icon: Icons.task_alt_rounded, title: 'No flagged reviews', sub: 'Nice — nobody needs extra help right now.')
                    : LayoutBuilder(builder: (context, box) {
                        final wide = box.maxWidth >= 900;
                        final list = Container(
                          decoration: PT.card(),
                          clipBehavior: Clip.antiAlias,
                          child: ListView(children: items.map(_tile).toList()),
                        );
                        if (!wide) {
                          return sel == null ? list : _detail(sel, onBack: () => setState(() => _selId = null));
                        }
                        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          SizedBox(width: box.maxWidth >= 1150 ? 330 : 280, child: list),
                          const SizedBox(width: 18),
                          Expanded(
                            child: sel == null
                                ? Container(
                                    decoration: PT.card(),
                                    child: const PortalEmpty(
                                      icon: Icons.flag_outlined,
                                      title: 'Pick a review',
                                      sub: 'The review and her full profile show here.',
                                    ),
                                  )
                                : _detail(sel),
                          ),
                        ]);
                      }),
      ),
    ]);
  }
}
