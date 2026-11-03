import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// "Report an issue" tickets (Oct 2026). Admin reads each issue, sees who
/// she is and her plan, replies (she gets a push + sees it in the app) and
/// moves it Received → In review → Resolved. Backend: /admin/support-tickets.
/// Promise to her: an answer within 3 working days (dueAt); late = Overdue.
class SupportTicketsPage extends StatefulWidget {
  const SupportTicketsPage({super.key});

  @override
  State<SupportTicketsPage> createState() => _SupportTicketsPageState();
}

class _SupportTicketsPageState extends State<SupportTicketsPage> {
  static const _filters = [
    ('open', 'Open'),
    ('overdue', 'Overdue'),
    ('received', 'New'),
    ('in_review', 'In review'),
    ('resolved', 'Resolved'),
    ('all', 'All'),
  ];
  static const _categories = {
    'APP_ISSUE': 'App problem',
    'CLASS': 'Class',
    'PAYMENT': 'Payment',
    'PLAN': 'Plan',
    'ACCOUNT': 'Account',
    'OTHER': 'Other',
    'MEDICAL': 'Medical',
  };

  String _filter = 'open';
  final _search = TextEditingController();
  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic> _counts = {};
  bool _loading = true;

  int? _openId;
  Map<String, dynamic>? _ticket;
  bool _ticketLoading = false;
  final _reply = TextEditingController();
  String _replyStatus = 'keep';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final q = _search.text.trim();
    final b = await PortalApi.get('/admin/support-tickets', query: {
      'status': _filter,
      if (q.isNotEmpty) 'q': q,
      'limit': '100',
    });
    if (!mounted) return;
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map) {
      setState(() {
        _tickets = ((d['tickets'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _counts = d['counts'] is Map ? Map<String, dynamic>.from(d['counts']) : {};
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      portalToast("Couldn't load tickets", sub: PortalApi.msg(b), error: true);
    }
  }

  Future<void> _open(int id, {bool narrow = false}) async {
    setState(() {
      _openId = id;
      _ticket = null;
      _ticketLoading = true;
      _reply.clear();
      _replyStatus = 'keep';
    });
    final b = await PortalApi.get('/admin/support-tickets/$id');
    if (!mounted || _openId != id) return;
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map && d['ticket'] is Map) {
      setState(() {
        _ticket = Map<String, dynamic>.from(d['ticket']);
        _ticketLoading = false;
        // Opening it marks it read.
        for (final t in _tickets) {
          if (t['id'] == id) t['adminUnread'] = false;
        }
      });
      if (narrow) _showNarrow();
    } else {
      setState(() => _ticketLoading = false);
      portalToast("Couldn't open ticket", sub: PortalApi.msg(b), error: true);
    }
  }

  void _showNarrow() {
    showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 640,
          height: MediaQuery.of(c).size.height * 0.88,
          child: StatefulBuilder(builder: (c, set) => _detail(onChanged: () => set(() {}))),
        ),
      ),
    );
  }

  Future<void> _send({VoidCallback? onChanged}) async {
    final t = _ticket;
    if (t == null) return;
    final msg = _reply.text.trim();
    final status = _replyStatus == 'keep' ? null : _replyStatus;
    if (msg.isEmpty && status == null) {
      portalToast('Write a reply or pick a status', error: true);
      return;
    }
    setState(() => _sending = true);
    onChanged?.call();
    final b = await PortalApi.post('/admin/support-tickets/${t['id']}/reply', {
      if (msg.isNotEmpty) 'message': msg,
      if (status != null) 'status': status,
    });
    if (!mounted) return;
    setState(() => _sending = false);
    if (PortalApi.ok(b)) {
      portalToast(msg.isNotEmpty ? 'Reply sent' : 'Status updated',
          sub: msg.isNotEmpty ? 'She gets a notification and sees it in the app.' : null);
      _reply.clear();
      _replyStatus = 'keep';
      await _open(t['id'] as int);
      onChanged?.call();
      _load();
    } else {
      onChanged?.call();
      portalToast("Couldn't send", sub: PortalApi.msg(b), error: true);
    }
  }

  Future<void> _setStatus(String status, {VoidCallback? onChanged}) async {
    final t = _ticket;
    if (t == null) return;
    setState(() => _sending = true);
    onChanged?.call();
    final b = await PortalApi.post('/admin/support-tickets/${t['id']}/status', {'status': status});
    if (!mounted) return;
    setState(() => _sending = false);
    if (PortalApi.ok(b)) {
      portalToast(status == 'resolved' ? 'Marked resolved' : 'Marked in review');
      await _open(t['id'] as int);
      onChanged?.call();
      _load();
    } else {
      onChanged?.call();
      portalToast("Couldn't update", sub: PortalApi.msg(b), error: true);
    }
  }

  // ── helpers ──
  static DateTime? _dt(dynamic v) => DateTime.tryParse('${v ?? ''}')?.toLocal();
  static String _ago(dynamic v) {
    final t = _dt(v);
    if (t == null) return '';
    final m = DateTime.now().difference(t).inMinutes;
    if (m < 1) return 'just now';
    if (m < 60) return '$m min ago';
    final h = m ~/ 60;
    if (h < 24) return '$h h ago';
    final d = h ~/ 24;
    return d == 1 ? 'yesterday' : '$d days ago';
  }

  static (String, Color) _statusLook(Map<String, dynamic> t) {
    if (t['overdue'] == true) return ('Overdue', PT.red);
    switch ('${t['status']}') {
      case 'received':
        return ('New', PT.amber);
      case 'in_review':
        return ('In review', const Color(0xFF3F7FBF));
      case 'resolved':
        return ('Resolved', PT.green);
    }
    return ('${t['status']}', PT.sage);
  }

  String _cat(dynamic c) => _categories['${c ?? ''}'.toUpperCase()] ?? '${c ?? 'Other'}';

  // ── list ──
  Widget _filterBar() {
    int? countFor(String k) {
      final v = _counts[k];
      return v is num ? v.toInt() : null;
    }

    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final (k, label) in _filters)
        ChoiceChip(
          label: Text(countFor(k) != null ? '$label · ${countFor(k)}' : label),
          selected: _filter == k,
          onSelected: (_) {
            setState(() => _filter = k);
            _load();
          },
          selectedColor: PT.green.withValues(alpha: 0.18),
          labelStyle: PT.t(12.5,
              w: _filter == k ? FontWeight.w600 : FontWeight.w400,
              c: k == 'overdue' && (countFor(k) ?? 0) > 0 ? PT.red : PT.ink),
        ),
    ]);
  }

  Widget _row(Map<String, dynamic> t, {required bool narrow}) {
    final id = (t['id'] as num).toInt();
    final client = t['client'] is Map ? Map<String, dynamic>.from(t['client']) : const {};
    final name = '${client['name'] ?? 'Client ${t['userId'] ?? ''}'}';
    final (label, color) = _statusLook(t);
    final unread = t['adminUnread'] == true;
    final selected = _openId == id;
    final msg = '${t['message'] ?? ''}'.trim();
    return InkWell(
      onTap: () => _open(id, narrow: narrow),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? PT.wash : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? PT.green : PT.line, width: selected ? 1.5 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(color: PT.red, shape: BoxShape.circle),
              ),
            Expanded(
              child: Text(name,
                  style: PT.t(13.5, w: unread ? FontWeight.w700 : FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
            StatusChip(label, color: color),
          ]),
          const SizedBox(height: 3),
          Text('#$id · ${_cat(t['category'])} · ${_ago(t['createdAt'])}', style: PT.t(11.5, c: PT.sage)),
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(msg, maxLines: 2, overflow: TextOverflow.ellipsis, style: PT.t(12.5, h: 1.4)),
          ],
        ]),
      ),
    );
  }

  Widget _list({required bool narrow}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _filterBar(),
      const SizedBox(height: 10),
      TextField(
        controller: _search,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search_rounded, size: 18),
          hintText: 'Search name, phone, email or ticket #',
        ),
        onSubmitted: (_) => _load(),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _tickets.isEmpty
                ? const PortalEmpty(
                    icon: Icons.mark_email_read_outlined,
                    title: 'Nothing here',
                    sub: 'No tickets in this list.',
                  )
                : ListView(children: [for (final t in _tickets) _row(t, narrow: narrow)]),
      ),
    ]);
  }

  // ── detail ──
  Widget _bubble({
    required bool fromHer,
    required String who,
    required String body,
    String? image,
    dynamic at,
  }) {
    final img = (image ?? '').trim();
    return Align(
      alignment: fromHer ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: fromHer ? Colors.white : const Color(0xFFEAF7E4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PT.line),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$who · ${_ago(at)}', style: PT.t(11, c: PT.sage, w: FontWeight.w500)),
            if (body.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText(body, style: PT.t(13.5, h: 1.45)),
            ],
            if (img.isNotEmpty && img != 'null') ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (c) => Dialog(
                    child: InteractiveViewer(child: Image.network(PortalApi.privateFile(img))),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    PortalApi.privateFile(img),
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Text('Screenshot could not load', style: PT.t(12, c: PT.sage)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _detail({VoidCallback? onChanged}) {
    if (_ticketLoading) return const Center(child: CircularProgressIndicator());
    final t = _ticket;
    if (t == null) {
      return const PortalEmpty(
        icon: Icons.support_agent_outlined,
        title: 'Pick a ticket',
        sub: 'Open one from the list to read it and reply.',
      );
    }
    final client = t['client'] is Map ? Map<String, dynamic>.from(t['client']) : const {};
    final plan = t['plan'] is Map ? Map<String, dynamic>.from(t['plan']) : null;
    final (label, color) = _statusLook(t);
    final due = _dt(t['dueAt']);
    final resolved = t['status'] == 'resolved';
    final messages = ((t['messages'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final firstMsg = '${t['message'] ?? ''}'.trim();
    final firstImg = '${t['imageUrl'] ?? ''}';
    // The thread may already repeat her first message; don't show it twice.
    final dupFirst = messages.isNotEmpty &&
        messages.first['sender'] == 'user' &&
        '${messages.first['body'] ?? ''}'.trim() == firstMsg;

    String whoOf(Map<String, dynamic> m) {
      switch ('${m['sender']}') {
        case 'user':
          return '${client['name'] ?? 'She'}';
        case 'crm':
          return '${m['senderName'] ?? 'Support team (CRM)'}';
        default:
          return '${m['senderName'] ?? 'FitHer Support'}';
      }
    }

    return Container(
      decoration: PT.card(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text('#${t['id']} · ${_cat(t['category'])}', style: PT.t(16, w: FontWeight.w700)),
          ),
          StatusChip(label, color: color),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 18, runSpacing: 6, children: [
          _info(Icons.person_outline, '${client['name'] ?? '—'} (ID ${client['id'] ?? t['userId'] ?? ''})'),
          if (client['phone'] != null) _info(Icons.phone_outlined, '${client['phone']}'),
          if (client['email'] != null) _info(Icons.mail_outline, '${client['email']}'),
          _info(Icons.inventory_2_outlined,
              plan == null ? 'No plan' : '${plan['title'] ?? 'Plan'} · ${plan['status'] ?? ''}${plan['expires'] != null ? ' · ends ${plan['expires']}' : ''}'),
          if (!resolved && due != null)
            _info(Icons.schedule_rounded, 'Answer by ${DateFormat('EEE d MMM').format(due)}',
                color: t['overdue'] == true ? PT.red : PT.sage),
          if (t['feedback'] != null) _info(Icons.star_outline_rounded, 'Her feedback: ${t['feedback']}'),
        ]),
        if ('${t['category']}'.toUpperCase() == 'MEDICAL')
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFDEEEE), borderRadius: BorderRadius.circular(10)),
            child: Text('Medical: don\'t give medical advice here. Pass it to her dietitian or ask her to see a doctor.',
                style: PT.t(12.5, c: PT.red)),
          ),
        const Divider(height: 24, color: PT.line),
        Expanded(
          child: ListView(children: [
            if (!dupFirst)
              _bubble(
                fromHer: true,
                who: '${client['name'] ?? 'She'}',
                body: firstMsg,
                image: firstImg,
                at: t['createdAt'],
              ),
            for (final m in messages)
              _bubble(
                fromHer: m['sender'] == 'user',
                who: whoOf(m),
                body: '${m['body'] ?? ''}',
                image: m['imageUrl'] as String?,
                at: m['createdAt'],
              ),
          ]),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reply,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Write your reply to her…'),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DropdownButton<String>(
            value: _replyStatus,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'keep', child: Text('Keep status')),
              DropdownMenuItem(value: 'in_review', child: Text('…and mark In review')),
              DropdownMenuItem(value: 'resolved', child: Text('…and mark Resolved')),
            ],
            onChanged: _sending
                ? null
                : (v) {
                    setState(() => _replyStatus = v ?? 'keep');
                    onChanged?.call();
                  },
          ),
          ElevatedButton.icon(
            style: portalPrimary(),
            onPressed: _sending ? null : () => _send(onChanged: onChanged),
            icon: _sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 16),
            label: const Text('Send reply'),
          ),
          if (t['status'] == 'received')
            OutlinedButton(
              onPressed: _sending ? null : () => _setStatus('in_review', onChanged: onChanged),
              child: const Text('Mark in review'),
            ),
          if (!resolved)
            OutlinedButton(
              onPressed: _sending ? null : () => _setStatus('resolved', onChanged: onChanged),
              child: const Text('Mark resolved'),
            )
          else
            OutlinedButton(
              onPressed: _sending ? null : () => _setStatus('in_review', onChanged: onChanged),
              child: const Text('Reopen'),
            ),
        ]),
      ]),
    );
  }

  Widget _info(IconData icon, String text, {Color color = PT.sage}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          SelectableText(text, style: PT.t(12.5, c: color)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Support tickets',
        sub: 'Issues women sent from "Report an issue". Reply here: she gets a notification and sees it in the app. '
            'Promise: an answer within 3 working days.',
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Expanded(
        child: LayoutBuilder(builder: (c, box) {
          final narrow = box.maxWidth < 900;
          if (narrow) return _list(narrow: true);
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: 380, child: _list(narrow: false)),
            const SizedBox(width: 16),
            Expanded(child: _detail()),
          ]);
        }),
      ),
    ]);
  }
}
