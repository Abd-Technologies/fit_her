import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../portal_api.dart';
import '../../portal_session.dart';
import '../../portal_theme.dart';
import '../../shell/portal_nav.dart';
import '../../widgets/portal_ui.dart';
import 'client_detail.dart';

/// The dietitian's clients (most urgent first, as the server sorts them)
/// with the full client profile beside the list.
class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  List<Map<String, dynamic>>? _items;
  bool _loading = true;
  String? _error;
  int? _selId;
  String _q = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final me = Get.find<PortalSession>().userId;
    final b = await PortalApi.get('/dietTimes/getClients/${me ?? ''}');
    if (!mounted) return;
    final d = b['data'];
    List<Map<String, dynamic>>? list;
    String? err;
    if (PortalApi.ok(b) && d is Map) {
      list = dtMaps(d['cliets']);
    } else if (PortalApi.msg(b).toLowerCase().contains('no plan assigned')) {
      // Server says "No Plan assigned to you yet" when she has no clients.
      list = [];
    } else {
      err = PortalApi.msg(b, "Couldn't load your clients.");
    }
    if (err != null && _items != null) portalToast("Couldn't refresh your clients", sub: err, error: true);
    setState(() {
      _loading = false;
      _error = err;
      if (list != null) {
        _items = list;
        if (!list.any((e) => dtInt(e['id']) == _selId)) _selId = null;
      }
    });
  }

  static String _name(Map<String, dynamic> c) => dtUserName(c['User']);

  List<Map<String, dynamic>> get _filtered {
    final q = _q.trim().toLowerCase();
    final all = _items ?? const <Map<String, dynamic>>[];
    if (q.isEmpty) return all;
    return all.where((c) => _name(c).toLowerCase().contains(q)).toList();
  }

  void _message(Map<String, dynamic> c) {
    portalToast('Opening chat', sub: 'Pick ${_name(c)} in your chat list.');
    portalGo('chat');
  }

  Widget _tile(Map<String, dynamic> c) {
    final id = dtInt(c['id']);
    final sel = id == _selId;
    final st = dtStatusFor(c['status']);
    final urgent = c['status'] == 'FLAGGED' || c['status'] == 'CONSULTATION_TODAY';
    final ended = c['status'] == 'PLAN_ENDED';
    final start = dtDate(c['buyingDate'], 'MMM d');
    final end = dtDate(c['expireDate'], 'MMM d');
    final name = _name(c);
    return Material(
      color: sel ? const Color(0xFFEAF7E4) : Colors.white,
      child: InkWell(
        onTap: () => setState(() => _selId = id),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: const BorderSide(color: PT.line),
              left: BorderSide(color: urgent ? st.fg : Colors.transparent, width: 3),
            ),
          ),
          child: Opacity(
            opacity: ended ? 0.75 : 1,
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: ended ? const Color(0xFFEDEFEA) : const Color(0xFFEAF7E4),
                child: Text(dtInitials(name), style: PT.t(13, w: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: PT.t(13.5, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  dtPill(st),
                  const SizedBox(height: 3),
                  Text('Plan: $start – $end', style: PT.t(11, c: PT.sage), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              IconButton(
                tooltip: 'Message',
                onPressed: () => _message(c),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19, color: PT.sage),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _list(List<Map<String, dynamic>> items) {
    final all = _items ?? const <Map<String, dynamic>>[];
    final needs = all
        .where((c) => c['status'] == 'FLAGGED' || c['status'] == 'CONSULTATION_TODAY' || c['status'] == 'PLAN_OVERDUE')
        .length;
    return Container(
      decoration: PT.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            key: const ValueKey('dt_clients_search'),
            controller: _search,
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'Search clients…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _q.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _search.clear();
                        setState(() => _q = '');
                      },
                    ),
            ),
          ),
        ),
        if (needs > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text(
              '$needs client${needs == 1 ? '' : 's'} need${needs == 1 ? 's' : ''} something from you today',
              style: PT.t(12.5, w: FontWeight.w600, c: PT.amber),
            ),
          ),
        const Divider(height: 1, color: PT.line),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text('No clients found', style: PT.t(13, c: PT.sage)))
              : ListView(children: items.map(_tile).toList()),
        ),
      ]),
    );
  }

  Widget _detail(Map<String, dynamic> c, {VoidCallback? onBack}) {
    final u = c['User'] is Map ? Map<String, dynamic>.from(c['User'] as Map) : <String, dynamic>{};
    final uid = dtInt(u['id']);
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back, size: 18), label: const Text('All clients')),
          ),
        uid == null
            ? const PortalEmpty(icon: Icons.person_off_outlined, title: 'Client details missing')
            : ClientDetailPanel(
                key: ValueKey('client_${c['id']}'),
                userId: uid,
                name: _name(c),
                email: u['email']?.toString(),
                phone: u['phone']?.toString(),
                client: c,
                userPlanId: dtInt(c['id']),
              ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _items ?? const <Map<String, dynamic>>[];
    final items = _filtered;
    final sel = all.where((e) => dtInt(e['id']) == _selId).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Clients',
        sub: 'Your clients, most urgent first. Pick one to see her form, notes, reviews, progress and plans.',
        actions: [
          if (_items != null)
            Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: StatusChip('${all.length} clients')),
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Expanded(
        child: _loading && _items == null
            ? const Center(child: CircularProgressIndicator())
            : _items == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load your clients",
                    sub: _error,
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : all.isEmpty
                    ? const PortalEmpty(
                        icon: Icons.people_outline,
                        title: 'No clients yet',
                        sub: 'Clients assigned to you will show up here.',
                      )
                    : LayoutBuilder(builder: (context, box) {
                        final wide = box.maxWidth >= 900;
                        if (!wide) {
                          return sel == null ? _list(items) : _detail(sel, onBack: () => setState(() => _selId = null));
                        }
                        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          SizedBox(width: box.maxWidth >= 1150 ? 340 : 290, child: _list(items)),
                          const SizedBox(width: 18),
                          Expanded(
                            child: sel == null
                                ? Container(
                                    decoration: PT.card(),
                                    child: const PortalEmpty(
                                      icon: Icons.person_search_outlined,
                                      title: 'Pick a client',
                                      sub: 'Her profile, health form, notes, reviews, progress and plans show here.',
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
