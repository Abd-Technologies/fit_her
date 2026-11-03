import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Emergency days to approve (Oct 2026). Same calls as the app's admin
/// screen: GET /emergency-day/awaiting, POST /emergency-day/:id/decide.
/// A dietitian's 3rd+ emergency day in a month waits here.
class EmergencyDaysPage extends StatefulWidget {
  const EmergencyDaysPage({super.key});

  @override
  State<EmergencyDaysPage> createState() => _EmergencyDaysPageState();
}

class _EmergencyDaysPageState extends State<EmergencyDaysPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  final Set<int> _busy = {};

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
    final b = await PortalApi.get('/emergency-day/awaiting');
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map && d['items'] is List) {
      _items = (d['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      _error = PortalApi.msg(b, "Couldn't load emergency days.");
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _decide(Map<String, dynamic> it, bool approve) async {
    final id = (it['id'] as num).toInt();
    final yes = await portalConfirm(
      context,
      title: approve ? 'Approve this emergency day?' : 'Reject this emergency day?',
      body: approve
          ? "Her ${it['sessions']} session(s) that day are cancelled. Clients get free days and are asked to rebook."
          : 'Her sessions stay as booked and she is told.',
      yes: approve ? 'Approve' : 'Reject',
      danger: !approve,
    );
    if (!yes) return;
    setState(() => _busy.add(id));
    final b = await PortalApi.post('/emergency-day/$id/decide', {'approve': approve});
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (PortalApi.ok(b)) {
      portalToast(PortalApi.msg(b, approve ? 'Approved' : 'Rejected'));
      _load();
    } else {
      portalToast("Couldn't save", sub: PortalApi.msg(b), error: true);
    }
  }

  Widget _card(Map<String, dynamic> it) {
    final id = (it['id'] as num).toInt();
    final day = DateTime.tryParse('${it['day']}');
    final busy = _busy.contains(id);
    final note = '${it['note'] ?? ''}'.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('${it['dietitian']}', style: PT.t(15, w: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('${day != null ? DateFormat('EEE d MMM').format(day) : it['day']} · '
            "${it['sessions']} session(s) · ${it['reason']}",
            style: PT.t(13)),
        if (note.isNotEmpty && note != 'null') ...[
          const SizedBox(height: 4),
          Text('"$note"', style: PT.t(12.5, c: PT.sage).copyWith(fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 6),
        Text("Emergency day ${it['monthCount']} this month", style: PT.t(12, w: FontWeight.w600, c: PT.red)),
        if (it['requestedAt'] != null)
          Text('Asked ${portalAgo(it['requestedAt'])}', style: PT.t(11.5, c: PT.sage)),
        const SizedBox(height: 12),
        if (busy)
          const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
        else
          Row(children: [
            Expanded(
              child: OutlinedButton(style: portalDanger(), onPressed: () => _decide(it, false), child: const Text('Reject')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(style: portalPrimary(), onPressed: () => _decide(it, true), child: const Text('Approve')),
            ),
          ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Emergency days',
        sub: 'A dietitian gets 2 emergency days a month on her own. Later ones wait here. '
            'Approve: her sessions that day are cancelled, clients get free days and rebook. '
            'Reject: sessions stay as booked.',
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? PortalEmpty(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load",
                    sub: _error,
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : _items.isEmpty
                    ? const PortalEmpty(icon: Icons.event_available_outlined, title: 'Nothing waiting.')
                    : LayoutBuilder(builder: (context, c) {
                        final cols = (c.maxWidth / 380).floor().clamp(1, 3);
                        final w = (c.maxWidth - (cols - 1) * 14) / cols;
                        return ListView(padding: const EdgeInsets.only(bottom: 20), children: [
                          Wrap(spacing: 14, runSpacing: 14, children: [
                            for (final it in _items) SizedBox(width: w, child: _card(it)),
                          ]),
                        ]);
                      }),
      ),
    ]);
  }
}
