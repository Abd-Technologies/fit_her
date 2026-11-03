import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_session.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';
import 'insight_ui.dart';
import 'metrics_page.dart' show metricTriggerLabels;

/// Escalation tickets: filter by status and reason, read the details,
/// resolve with a note, or unlock booking for a locked client.
class EscalationsPage extends StatefulWidget {
  const EscalationsPage({super.key, this.title = 'Escalations', this.sub});

  /// Same page for admin (all tickets) and a dietitian (the server only
  /// returns tickets about her own clients); only the heading differs.
  final String title;
  final String? sub;

  @override
  State<EscalationsPage> createState() => _EscalationsPageState();
}

class _EscalationsPageState extends State<EscalationsPage> {
  List<Map<String, dynamic>>? _items;
  bool _loading = true;
  String? _error;
  String _status = 'open';
  String? _trigger;
  int? _selId;
  final Set<int> _busy = {};

  static const _statusOptions = [
    ('open', 'Open'),
    ('acknowledged', 'Seen'),
    ('resolved', 'Resolved'),
  ];

  static const _triggerOptions = <(String?, String)>[
    (null, 'All reasons'),
    ('PLAN_DELAYED', 'Plan delayed'),
    ('CONSULT_NO_SHOW', 'Dietitian no-show'),
    ('CONSULT_CLIENT_NO_SHOW', 'Client missed session'),
    ('INACTIVITY', 'Inactivity'),
    ('MEDICAL', 'Medical'),
    ('REVIEW_FLAG', 'Review flag'),
    ('BOOKING_REMINDER_5X', 'Booking reminder 5 times'),
    ('SYSTEM_ISSUE', 'System issue'),
    ('DIET_CHECKIN_HELP', 'Needs help with diet plan'),
    ('DIETITIAN_EMERGENCY_DAY', 'Emergency day'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  static Map<String, dynamic>? _json(dynamic x) {
    if (x is Map) return Map<String, dynamic>.from(x);
    if (x is String && x.isNotEmpty) {
      try {
        final v = jsonDecode(x);
        if (v is Map) return Map<String, dynamic>.from(v);
      } catch (_) {}
    }
    return null;
  }

  static int _id(Map<String, dynamic> t) => t['id'] is num ? (t['id'] as num).toInt() : 0;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final b = await PortalApi.get(Constants.adminEscalations, query: {
      'limit': '200',
      'offset': '0',
      'status': _status,
      if (_trigger != null) 'trigger': _trigger!,
    });
    List<Map<String, dynamic>>? list;
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map && d['tickets'] is List) {
      list = iList(d['tickets']).map((t) {
        t['payload'] = _json(t['payload']);
        t['attendance'] = _json(t['attendance']);
        return t;
      }).toList();
    } else {
      _error = PortalApi.msg(b, "Couldn't load tickets.");
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (list != null) {
        _items = list;
        if (!list.any((e) => _id(e) == _selId)) _selId = list.isEmpty ? null : _id(list.first);
      } else if (_items != null) {
        portalToast("Couldn't load tickets", sub: _error, error: true);
      }
    });
  }

  Future<bool> _resolveCall(int id, String? note) async {
    final b = await PortalApi.post('${Constants.adminEscalations}/$id/resolve', {
      if (note != null) 'resolutionNote': note,
    });
    if (!PortalApi.ok(b)) portalToast('Could not resolve', sub: PortalApi.msg(b), error: true);
    return PortalApi.ok(b);
  }

  Future<void> _resolve(Map<String, dynamic> t) async {
    final note = await _askNote();
    if (note == null) return;
    final id = _id(t);
    setState(() => _busy.add(id));
    final ok = await _resolveCall(id, note.isEmpty ? null : note);
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (ok) {
      portalToast('Ticket resolved', sub: '#$id');
      _load();
    }
  }

  Future<void> _unlock(Map<String, dynamic> t) async {
    final planId = int.tryParse('${t['payload']?['userPlanId'] ?? ''}');
    if (planId == null) return;
    final yes = await portalConfirm(
      context,
      title: 'Unlock booking?',
      body: 'She will be able to book her own sessions again, and her one free '
          'late change on this package is given back. The ticket is closed too.',
      yes: 'Unlock',
    );
    if (!yes) return;
    final id = _id(t);
    setState(() => _busy.add(id));
    final b = await PortalApi.post('/admin/diet-plan/user-plan/$planId/reset-booking-pass', <String, dynamic>{});
    if (!PortalApi.ok(b)) {
      if (mounted) setState(() => _busy.remove(id));
      portalToast('Could not unlock booking', sub: PortalApi.msg(b), error: true);
      return;
    }
    await _resolveCall(id, 'Booking unlocked by ${Get.find<PortalSession>().name}.');
    if (!mounted) return;
    setState(() => _busy.remove(id));
    portalToast('Booking unlocked', sub: _client(t));
    _load();
  }

  Future<String?> _askNote() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Resolve ticket', style: PT.t(17, w: FontWeight.w700)),
        content: SizedBox(
          width: 420,
          child: TextField(
            key: const ValueKey('escalation_resolve_note'),
            controller: ctrl,
            maxLines: 3,
            maxLength: 500,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'What was done? (optional)', counterText: ''),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, null), child: Text('Cancel', style: PT.t(13.5, c: PT.sage))),
          ElevatedButton(
            style: portalPrimary(),
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return res;
  }

  static String _person(dynamic u, String fallback) {
    if (u is Map) {
      final n = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
      if (n.isNotEmpty) return n;
    }
    return fallback;
  }

  static String _client(Map<String, dynamic> t) => _person(t['client'], 'Client #${t['userId'] ?? '?'}');

  static String _reason(Map<String, dynamic> t) {
    final k = '${t['trigger'] ?? ''}';
    return metricTriggerLabels[k] ?? (k.isEmpty ? '—' : k);
  }

  static Color _sevColor(String s) => s == 'high' ? PT.red : (s == 'low' ? PT.sage : PT.amber);

  static String _statusLabel(String s) => switch (s) {
        'acknowledged' => 'Seen',
        'resolved' => 'Resolved',
        _ => 'Open',
      };

  bool _canUnlock(Map<String, dynamic> t) {
    final p = t['payload'] is Map ? t['payload'] as Map : const {};
    return t['status'] != 'resolved' &&
        t['trigger'] == 'CONSULT_CLIENT_NO_SHOW' &&
        p['bookingLocked'] == true &&
        p['userPlanId'] != null;
  }

  Widget _tile(Map<String, dynamic> t) {
    final sel = _id(t) == _selId;
    final sev = '${t['severity'] ?? 'medium'}';
    return Material(
      color: sel ? const Color(0xFFEAF7E4) : Colors.white,
      child: InkWell(
        onTap: () => setState(() => _selId = _id(t)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: const BorderSide(color: PT.line),
              left: BorderSide(color: sev == 'high' ? PT.red : Colors.transparent, width: 3),
            ),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_client(t), style: PT.t(13.5, w: FontWeight.w600), overflow: TextOverflow.ellipsis),
                Text('${_reason(t)}  ·  #${t['id']}', style: PT.t(12, c: PT.sage), overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              StatusChip(sev.toUpperCase(), color: _sevColor(sev)),
              const SizedBox(height: 3),
              Text(portalAgo(t['openedAt']), style: PT.t(11, c: PT.sage)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _info(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(k, style: PT.t(12.5, c: PT.sage))),
          Expanded(child: SelectableText(v.isEmpty ? '—' : v, style: PT.t(13))),
        ]),
      );

  Widget _attendance(Map<String, dynamic> a) {
    String who(String label, dynamic v) =>
        v == true ? '$label joined' : (v == false ? "$label didn't join" : '$label: unknown');
    final checked = a['checked'] == true;
    final people = iList(a['participants']).map((p) => '${p['name'] ?? '?'}').toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFEAF7E4), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a['source'] == 'google' ? 'Attendance · Google Meet' : 'Attendance',
            style: PT.t(13, w: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          checked
              ? '${who('Dietitian', a['dietitianJoined'])}  ·  ${who('Client', a['clientJoined'])}'
              : 'Not checked yet (no Meet link, or the check has not run).',
          style: PT.t(12.5),
        ),
        // Oct 2026: how it was decided (Google or app taps), with times.
        if ('${a['summary'] ?? ''}'.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('${a['summary']}', style: PT.t(12.5, c: const Color(0xFF3E8E36))),
          ),
        if (people.isNotEmpty) Text('In the call: ${people.join(', ')}', style: PT.t(12, c: PT.sage)),
      ]),
    );
  }

  Widget _detail(Map<String, dynamic> t) {
    final id = _id(t);
    final sev = '${t['severity'] ?? 'medium'}';
    final status = '${t['status'] ?? 'open'}';
    final payload = t['payload'] is Map ? Map<String, dynamic>.from(t['payload']) : <String, dynamic>{};
    final att = t['attendance'] is Map ? Map<String, dynamic>.from(t['attendance']) : null;
    final client = t['client'] is Map ? t['client'] as Map : const {};
    final diet = t['dietitian'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(_reason(t), style: PT.t(19, w: FontWeight.w700)),
          StatusChip(sev.toUpperCase(), color: _sevColor(sev)),
          StatusChip(_statusLabel(status), color: status == 'resolved' ? PT.green : PT.amber),
        ]),
        Text('Ticket #${t['id']}  ·  opened ${iDate(t['openedAt'], time: true)}', style: PT.t(12, c: PT.sage)),
        const SizedBox(height: 14),
        _info('Client', _client(t)),
        _info('Client email', '${client['email'] ?? ''}'),
        _info('Dietitian', t['dietitianId'] == null ? '' : _person(diet, 'Dietitian #${t['dietitianId']}')),
        _info('Told', '${t['notifiedDietitian'] == true ? 'Dietitian' : ''}'
            '${t['notifiedDietitian'] == true && t['notifiedAdmin'] == true ? ' and ' : ''}'
            '${t['notifiedAdmin'] == true ? 'Admin' : ''}'),
        if (t['resolvedAt'] != null) _info('Resolved', iDate(t['resolvedAt'], time: true)),
        if (payload.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Details', style: PT.t(13.5, w: FontWeight.w700)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(12), border: Border.all(color: PT.line)),
            child: SelectableText(
              payload.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: PT.ink, height: 1.5),
            ),
          ),
        ],
        if (att != null) ...[const SizedBox(height: 10), _attendance(att)],
        if (t['resolutionNote'] != null) ...[
          const SizedBox(height: 10),
          Text('Resolution: ${t['resolutionNote']}', style: PT.t(12.5, c: PT.sage).copyWith(fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 18),
        if (_busy.contains(id))
          const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2.4))
        else if (status != 'resolved')
          Wrap(spacing: 10, runSpacing: 10, children: [
            ElevatedButton.icon(
              style: portalPrimary(),
              onPressed: () => _resolve(t),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Resolve'),
            ),
            if (_canUnlock(t))
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: PT.ink,
                  side: const BorderSide(color: PT.green),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _unlock(t),
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('Unlock booking'),
              ),
          ]),
      ]),
    );
  }

  Widget _filters() => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Wrap(spacing: 14, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          insightPills<String>(
            options: _statusOptions,
            selected: _status,
            onTap: (v) {
              setState(() => _status = v);
              _load();
            },
          ),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String?>(
              key: const ValueKey('escalation_trigger_filter'),
              value: _trigger,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: [
                for (final o in _triggerOptions) DropdownMenuItem<String?>(value: o.$1, child: Text(o.$2)),
              ],
              onChanged: (v) {
                setState(() => _trigger = v);
                _load();
              },
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final items = _items ?? const <Map<String, dynamic>>[];
    final sel = items.where((e) => _id(e) == _selId).firstOrNull;
    final wide = MediaQuery.of(context).size.width >= 1100;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: widget.title,
        sub: widget.sub ??
            'Problems the system flagged: late plans, missed sessions, medical worries and more. '
                'Open a ticket, sort it out, then resolve it.',
        actions: [
          if (_items != null)
            Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: StatusChip('${items.length} shown')),
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      _filters(),
      Expanded(
        child: _loading && _items == null
            ? const Center(child: CircularProgressIndicator())
            : _items == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load tickets",
                    sub: _error,
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : Stack(fit: StackFit.expand, children: [
                    items.isEmpty
                        ? const PortalEmpty(icon: Icons.task_alt_rounded, title: 'No tickets here', sub: 'Try another filter.')
                        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              width: wide ? 340 : 270,
                              decoration: PT.card(),
                              clipBehavior: Clip.antiAlias,
                              child: ListView(children: items.map(_tile).toList()),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: sel == null ? const SizedBox() : SingleChildScrollView(child: _detail(sel)),
                            ),
                          ]),
                    if (_loading) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
                  ]),
      ),
    ]);
  }
}
