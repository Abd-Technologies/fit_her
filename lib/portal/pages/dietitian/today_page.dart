import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../shell/portal_nav.dart';
import '../../widgets/portal_ui.dart';
import 'd_ui.dart';
import 'client_detail.dart';
import 'emergency_day_dialog.dart';

/// "Your consultations": every upcoming booking, grouped by day. Start a
/// confirmed session (the client's Join button turns green and the Meet
/// link opens in a new tab), rejoin a live one, mark it completed, report
/// that the client didn't join, or cancel it.
class TodaySessionsPage extends StatefulWidget {
  const TodaySessionsPage({super.key});

  @override
  State<TodaySessionsPage> createState() => _TodaySessionsPageState();
}

class _TodaySessionsPageState extends State<TodaySessionsPage> {
  List<Map<String, dynamic>>? _items;
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // Quiet refresh every 30 s (Oct 2026), so "Client is waiting" shows
    // without her pressing refresh.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_loading && _busy.isEmpty) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final b = await dLoadAppointments(recentDays: 2);
    List<Map<String, dynamic>>? list;
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map && d['appointments'] is List) {
      list = dMaps(d['appointments']).where((a) => dApptDate(a) != null).toList();
    } else {
      _error = PortalApi.msg(b, 'Could not load consultations. Please try again.');
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (list != null) {
        _items = list;
      } else if (_items != null && !quiet) {
        portalToast("Couldn't refresh", sub: _error, error: true);
      }
    });
  }

  List<Map<String, dynamic>> get _upcoming {
    final l = (_items ?? const <Map<String, dynamic>>[]).where((a) {
      final s = '${a['status'] ?? ''}';
      return s != 'canceled' && s != 'canceledByUser' && s != 'completed';
    }).toList();
    l.sort((a, b) => dApptDate(a)!.compareTo(dApptDate(b)!));
    return l;
  }

  /// Oct 2026: finished calls (last 2 days) where the client never tapped
  /// Join in the app and no attendance answer exists yet. Google-checked
  /// calls are left out (Google already knows).
  List<Map<String, dynamic>> get _toConfirm {
    final since = DateTime.now().subtract(const Duration(days: 2));
    return (_items ?? const <Map<String, dynamic>>[]).where((a) {
      if ('${a['status'] ?? ''}' != 'completed') return false;
      final d = dApptDate(a);
      if (d == null || d.isBefore(since)) return false;
      if (a['clientJoinTapAt'] != null || a['clientNoShowAt'] != null) return false;
      if ('${a['attendanceFlag'] ?? ''}' == 'dietitian_confirmed') return false;
      if ('${a['attendanceSource'] ?? ''}' == 'google') return false;
      return !_answered.contains(dInt(a['id']));
    }).toList();
  }

  final Set<int> _answered = {};

  Future<void> _confirmJoined(Map<String, dynamic> a, {int? minutes}) async {
    final id = dInt(a['id']);
    setState(() => _busy.add(id));
    final b = await PortalApi.post('/appointment/$id/client-joined', <String, dynamic>{
      if (minutes != null) 'minutes': minutes,
    });
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (!PortalApi.ok(b)) {
      portalToast('Could not update', sub: PortalApi.msg(b, 'Please try again.'), error: true);
      return;
    }
    setState(() => _answered.add(id));
    portalToast('Thanks, noted 💚');
  }

  Widget _confirmCard(Map<String, dynamic> a) {
    final id = dInt(a['id']);
    final name = dClientName(a);
    final first = name.trim().split(' ').first;
    final d = dApptDate(a)!;
    final when = '${DateFormat('EEE d MMM').format(d)} · ${dTimeRange(a)}';
    final busy = _busy.contains(id);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1DDB0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Did $first join your call?', style: PT.t(14, w: FontWeight.w700)),
        const SizedBox(height: 2),
        Text("$when · she didn't tap Join in the app", style: PT.t(12, c: PT.sage)),
        const SizedBox(height: 10),
        if (busy)
          const Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2.4))
        else
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Nov 2026: "Yes" with about how long, so we have her time.
            Text('Yes, for about:', style: PT.t(12, c: PT.sage)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in const [10, 20, 30, 45])
                ElevatedButton(
                  style: portalPrimary(),
                  onPressed: () => _confirmJoined(a, minutes: m),
                  child: Text('$m min'),
                ),
            ]),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await _noShow(a);
              },
              child: const Text("No, she didn't join"),
            ),
          ]),
      ]),
    );
  }

  void _setStatus(int id, String status) {
    final a = (_items ?? const <Map<String, dynamic>>[]).where((e) => dInt(e['id']) == id).firstOrNull;
    if (a != null) a['status'] = status;
  }

  // ── Times (same rules as the app; the server checks them too) ───────
  static DateTime? _slotAt(Map<String, dynamic> a, String key) {
    final raw = dSlotTime(dMap(a['SlotDiet'])[key]);
    if (raw.isEmpty) return null;
    try {
      final d = dApptDate(a)!.toUtc(); // the day is stored as UTC midnight
      final t = DateFormat('h:mm a').parse(raw);
      return DateTime(d.year, d.month, d.day, t.hour, t.minute);
    } catch (_) {
      return null;
    }
  }

  static DateTime _startAt(Map<String, dynamic> a) => _slotAt(a, 'start') ?? dApptDate(a)!.toLocal();

  // ── Actions ─────────────────────────────────────────────────────────
  Future<void> _start(Map<String, dynamic> a) async {
    final id = dInt(a['id']);
    final ends = _slotAt(a, 'end');
    final opens = _startAt(a).subtract(const Duration(minutes: 10));
    if (ends != null && DateTime.now().isAfter(ends)) {
      portalToast("This session's time has passed", sub: "It can't be started. If the client didn't join, use the ⋯ menu.", error: true);
      return;
    }
    if (DateTime.now().isBefore(opens)) {
      portalToast('Too early to start', sub: 'You can start this session from ${DateFormat('h:mm a').format(opens)} (10 minutes before).', error: true);
      return;
    }
    setState(() => _busy.add(id));
    final b = await PortalApi.post('/appointment/$id/start', <String, dynamic>{});
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (!PortalApi.ok(b)) {
      portalToast('Could not start the session', sub: PortalApi.msg(b), error: true);
      return;
    }
    setState(() => _setStatus(id, 'In Progress'));
    portalToast(PortalApi.msg(b, 'Session started'));
    final link = dMeetLink(a);
    if (link == null) {
      portalToast('No Meet link on this slot', sub: 'Session started, but add a Meet link in your slots so the client can join.', error: true);
    } else if (!await dOpenLink(link)) {
      portalToast("Couldn't open the meeting link", sub: 'Check the Meet link saved on this slot.', error: true);
    }
  }

  Future<void> _rejoin(Map<String, dynamic> a) async {
    final link = dMeetLink(a);
    if (link == null) {
      portalToast('No meeting link has been set for this slot yet.', error: true);
      return;
    }
    if (!await dOpenLink(link)) {
      portalToast("Couldn't open the meeting link", sub: 'Check the Meet link saved on this slot.', error: true);
    }
  }

  Future<bool> _changeStatus(Map<String, dynamic> a, String status) async {
    final id = dInt(a['id']);
    setState(() => _busy.add(id));
    final b = await dPut('/appointment/$id', {'status': status});
    if (!mounted) return false;
    setState(() => _busy.remove(id));
    if (!PortalApi.ok(b)) {
      portalToast('Could not update the consultation', sub: PortalApi.msg(b), error: true);
      return false;
    }
    setState(() => _setStatus(id, status));
    portalToast(PortalApi.msg(b, status == 'completed' ? 'Marked as completed' : 'Consultation canceled'));
    return true;
  }

  Future<void> _complete(Map<String, dynamic> a) async {
    if (!await _changeStatus(a, 'completed')) return;
    if (!mounted) return;
    final go = await portalConfirm(
      context,
      title: 'Consultation completed',
      body: 'Her plan is now due within 2 working days. Want to create it now?',
      yes: 'Create plan',
    );
    if (go) portalGo('d_deliver');
  }

  Future<void> _cancel(Map<String, dynamic> a) async {
    final yes = await portalConfirm(
      context,
      title: 'Cancel this consultation?',
      body: "This cancels the session for the client. They'll need to book a new time if they still want one.",
      yes: 'Cancel it',
      danger: true,
    );
    if (yes) await _changeStatus(a, 'canceled');
  }

  Future<void> _noShow(Map<String, dynamic> a) async {
    final yes = await portalConfirm(
      context,
      title: "Client didn't join?",
      body: "We'll cancel this session without using up her consultation and ask her to book a new time. "
          'You can do this 10 minutes after the start time.',
      yes: "Yes, she didn't join",
      danger: true,
    );
    if (!yes) return;
    final id = dInt(a['id']);
    setState(() => _busy.add(id));
    final b = await PortalApi.post('/appointment/$id/client-no-show', <String, dynamic>{});
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (!PortalApi.ok(b)) {
      portalToast('Could not update', sub: PortalApi.msg(b, 'Please try again.'), error: true);
      return;
    }
    setState(() => _setStatus(id, 'canceled'));
    portalToast(PortalApi.msg(b, "Marked as missed. She's been asked to rebook."));
  }

  // Nov 2026: open THIS client's details right here (it used to jump to the
  // Clients list, where she had to find her). [tab] 0 = profile (header +
  // meal logging), 1 = health form & notes.
  Future<void> _openClientPanel(Map<String, dynamic> a, {int tab = 0}) async {
    final u = dMap(a['ClientUser']);
    final uid = dInt(a['userId']) != 0 ? dInt(a['userId']) : dInt(u['id']);
    if (uid == 0) {
      portalToast('Client details missing', error: true);
      return;
    }
    // Her row from the Clients list (status, plan dates): best effort.
    Map<String, dynamic>? row;
    try {
      final b = await dLoadClients();
      final d = b['data'];
      if (PortalApi.ok(b) && d is Map && d['cliets'] is List) {
        for (final c in dMaps(d['cliets'])) {
          if (dInt(dMap(c['User'])['id']) == uid) {
            row = c;
            break;
          }
        }
      }
    } catch (_) {}
    if (!mounted) return;
    final name = dClientName(a);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          backgroundColor: PT.wash,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1000, maxHeight: size.height * 0.88),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
                child: Row(children: [
                  Expanded(
                    child: Text('$name · ${dTimeRange(a)}',
                        style: PT.t(15, w: FontWeight.w700), overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: ClientDetailPanel(
                    key: ValueKey('today_client_${uid}_$tab'),
                    userId: uid,
                    name: name,
                    email: u['email']?.toString(),
                    phone: u['phone']?.toString(),
                    client: row,
                    userPlanId: row != null ? dInt(row['id']) : (a['planId'] == null ? null : dInt(a['planId'])),
                    initialTab: tab,
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────
  static String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
  }

  Widget _card(Map<String, dynamic> a) {
    final id = dInt(a['id']);
    final status = '${a['status'] ?? ''}';
    final confirmed = status == 'confirmed';
    final live = status == 'In Progress';
    final name = dClientName(a);
    final u = dMap(a['ClientUser']);
    final initials = ['${u['firstName'] ?? ''}'.trim(), '${u['lastName'] ?? ''}'.trim()]
        .where((p) => p.isNotEmpty)
        .map((p) => p.substring(0, 1).toUpperCase())
        .join();
    final range = dTimeRange(a);
    final cn = a['consultNumber'] is num ? (a['consultNumber'] as num).toInt() : null;
    final int? n = (cn != null && cn > 0) ? cn : (a['kind'] == 'followup' ? null : 1);
    final label = n == null
        ? 'Follow-up consultation'
        : n == 1
            ? '1st consultation · New client'
            : '${_ordinal(n)} consultation · Follow-up';
    final note = '${a['message'] ?? ''}'.trim();
    final hasNote = note.isNotEmpty && note != 'N/A' && note != 'null';
    final ends = _slotAt(a, 'end');
    final opens = _startAt(a).subtract(const Duration(minutes: 10));
    final tooLate = ends != null && DateTime.now().isAfter(ends);
    final tooEarly = DateTime.now().isBefore(opens);
    final busy = _busy.contains(id);

    Widget secondary(IconData icon, String text, VoidCallback onTap, {Color color = PT.ink}) => OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: const BorderSide(color: PT.line),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: busy ? null : onTap,
          icon: Icon(icon, size: 16),
          label: Text(text, style: PT.t(12.5, w: FontWeight.w600, c: color), overflow: TextOverflow.ellipsis),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => _openClientPanel(a),
            customBorder: const CircleBorder(),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Color(0xFFEAF7E4), shape: BoxShape.circle),
              child: initials.isEmpty
                  ? const Icon(Icons.person_rounded, color: PT.ink, size: 22)
                  : Text(initials, style: PT.t(15, w: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: PT.t(15, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(range.isEmpty ? DateFormat('EEE, MMM d').format(dApptDate(a)!) : range, style: PT.t(12.5, c: PT.sage)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: n == 1 ? PT.green.withValues(alpha: 0.16) : const Color(0xFFEDEFF6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label,
                    style: PT.t(11, w: FontWeight.w600, c: n == 1 ? const Color(0xFF2F7A22) : const Color(0xFF4A5578))),
              ),
            ]),
          ),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            DStatusPill(status),
            if (confirmed || live)
              PopupMenuButton<String>(
                tooltip: 'More',
                enabled: !busy,
                icon: const Icon(Icons.more_horiz_rounded, color: PT.sage),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (v) {
                  if (v == 'completed') _complete(a);
                  if (v == 'noshow') _noShow(a);
                  if (v == 'form') _openClientPanel(a, tab: 1);
                },
                itemBuilder: (_) => [
                  if (confirmed)
                    PopupMenuItem(value: 'completed', child: _menuRow(Icons.done_all_rounded, 'Mark completed', PT.ink)),
                  PopupMenuItem(value: 'noshow', child: _menuRow(Icons.person_off_outlined, "Client didn't join", PT.amber)),
                  PopupMenuItem(value: 'form', child: _menuRow(Icons.assignment_outlined, 'Health form', PT.ink)),
                ],
              ),
          ]),
        ]),
        if (hasNote) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF6F8F5), borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: PT.sage),
              const SizedBox(width: 8),
              Expanded(child: Text('"$note"', style: PT.t(12.5, h: 1.45).copyWith(fontStyle: FontStyle.italic))),
            ]),
          ),
        ],
        if (_attendance(a) != null) ...[
          const SizedBox(height: 10),
          _attendance(a)!,
        ],
        const SizedBox(height: 12),
        if (busy)
          const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2.4)))
        else if (a['paymentHoldAt'] != null && (confirmed || status == 'pending'))
          // Oct 2026: her payment isn't confirmed yet -> can't start.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFFFF4DE), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.pause_circle_outline_rounded, size: 18, color: Color(0xFFB8790A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('On hold: client\'s payment not confirmed yet. Don\'t start this session.',
                    style: PT.t(12.5, c: const Color(0xFF8A5A00), h: 1.4)),
              ),
            ]),
          )
        else if (confirmed)
          ElevatedButton.icon(
            style: (tooEarly || tooLate)
                ? ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEAF7E4),
                    foregroundColor: PT.ink,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    side: const BorderSide(color: PT.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  )
                : portalPrimary(),
            onPressed: () => _start(a),
            icon: Icon(
                tooLate ? Icons.history_rounded : (tooEarly ? Icons.schedule_rounded : Icons.play_arrow_rounded),
                size: 18),
            label: Text(
              tooLate
                  ? 'Session time has passed'
                  : tooEarly
                      ? 'Start opens at ${DateFormat('h:mm a').format(opens)}'
                      : 'Start session & join call',
              overflow: TextOverflow.ellipsis,
            ),
          )
        else if (live)
          ElevatedButton.icon(
            style: portalPrimary(),
            onPressed: () => _rejoin(a),
            icon: const Icon(Icons.videocam_rounded, size: 18),
            label: const Text('Live now · Rejoin call'),
          )
        else
          Text(status == 'pending' ? 'Booked' : status, style: PT.t(12.5, c: PT.sage)),
        if ((confirmed || live) && !busy) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: secondary(Icons.person_outline_rounded, 'Profile', () => _openClientPanel(a))),
            const SizedBox(width: 8),
            Expanded(
              child: live
                  // Nov 2026: this tap is her "ended" time, so say what it does.
                  ? secondary(Icons.call_end_rounded, 'End session', () => _complete(a))
                  : secondary(Icons.assignment_outlined, 'Health form', () => _openClientPanel(a, tab: 1)),
            ),
            const SizedBox(width: 8),
            Expanded(child: secondary(Icons.close_rounded, 'Cancel', () => _cancel(a), color: PT.red)),
          ]),
        ],
      ]),
    );
  }

  /// Attendance (Oct 2026): from app taps for every dietitian, and from
  /// Google for the one whose account is linked.
  Widget? _attendance(Map<String, dynamic> a) {
    String? hm(Object? v) {
      final d = DateTime.tryParse('${v ?? ''}')?.toLocal();
      return d == null ? null : DateFormat('h:mm a').format(d);
    }

    final status = '${a['status'] ?? ''}';
    final started = hm(a['dietitianStartedAt']);
    final tapped = hm(a['clientJoinTapAt']);
    final source = '${a['attendanceSource'] ?? ''}';
    final flag = '${a['attendanceFlag'] ?? ''}';

    (IconData, String, Color, Color)? line;
    if (flag == 'tap_without_google') {
      line = (Icons.warning_amber_rounded, 'Client tapped Join at $tapped but Google didn\'t see her in the call. Admin will check.',
          const Color(0xFF8A5A00), const Color(0xFFFFF4DE));
    } else if (status == 'confirmed' && tapped != null) {
      line = (Icons.person_pin_circle_rounded, 'Client is waiting · tapped Join at $tapped',
          const Color(0xFF8A5A00), const Color(0xFFFFF4DE));
    } else if (source == 'google' && a['meetDietitianAttended'] == true && a['meetClientAttended'] == true) {
      line = (Icons.verified_rounded, 'Checked with Google · you and the client were both in the call',
          PT.ink, const Color(0xFFEAF7E4));
    } else if (status == 'confirmed') {
      // Oct 2026: joining from the app is how we know she came.
      line = (Icons.tips_and_updates_outlined, 'Tip: ask her to join from the Fit Her app (not a shared link), so her attendance is recorded.',
          PT.sage, const Color(0xFFF6F8F5));
    } else if (status == 'In Progress' || status == 'completed' || source == 'taps') {
      // Nov 2026: close-to-real times from the app (helper/consultAttendance.js).
      final at = a['attendance'] is Map ? Map<String, dynamic>.from(a['attendance'] as Map) : const <String, dynamic>{};
      final c = at['client'] is Map ? Map<String, dynamic>.from(at['client'] as Map) : const <String, dynamic>{};
      final dt = at['dietitian'] is Map ? Map<String, dynamic>.from(at['dietitian'] as Map) : const <String, dynamic>{};
      final cJoin = hm(c['joinedAt']);
      final cLeft = hm(c['leftAt']);
      final cMin = c['minutes'];
      final joins = c['joins'] is num ? (c['joins'] as num).toInt() : 0;
      final dStart = hm(dt['startedAt']) ?? started;
      final dEnd = hm(dt['endedAt']);
      final you = [
        if (dStart != null) 'You: started $dStart',
        if (dEnd != null) 'ended $dEnd${dt['endedHow'] == 'auto' ? ' (auto, at the slot end)' : ''}',
      ].join(' · ');
      String client;
      if (cJoin != null) {
        client = 'Client: joined $cJoin';
        if (joins > 1) client += ' (joined $joins times)';
        if (cLeft != null) client += ' · left ${c['leftHow'] == 'app' ? 'about' : 'by'} $cLeft';
        if (cMin is num) client += ' · about ${cMin.toInt()} min';
      } else if (c['minutesFrom'] == 'dietitian' && cMin is num) {
        client = 'Client: about ${cMin.toInt()} min (your answer)';
      } else {
        client = "Client: hasn't tapped Join in the app";
      }
      final text = [if (you.isNotEmpty) you, client].join('\n') +
          (source == 'google' ? '' : '\nTimes from the app, close but not exact.');
      line = (Icons.schedule_rounded, text, PT.ink, const Color(0xFFF6F8F5));
    }
    if (line == null) return null;
    final (icon, text, fg, bg) = line;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, size: 16, color: fg),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: PT.t(12.5, c: fg, h: 1.4))),
      ]),
    );
  }

  static Widget _menuRow(IconData icon, String text, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(text, style: PT.t(13, w: FontWeight.w500, c: color)),
      ]);

  Widget _dayHeader(String label, int count, bool today, bool first) => Padding(
        padding: EdgeInsets.only(top: first ? 0 : 18, bottom: 10),
        child: Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: today ? PT.green : PT.sage, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: PT.t(14, w: FontWeight.w700, c: today ? PT.ink : PT.greenDark))),
          const SizedBox(width: 8),
          StatusChip('$count', color: today ? PT.green : PT.sage),
        ]),
      );

  Widget _list() {
    final ups = _upcoming;
    final ask = _toConfirm;
    if (ups.isEmpty && ask.isEmpty) {
      return const PortalEmpty(icon: Icons.event_available_outlined, title: 'No upcoming consultations yet.');
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Group by calendar day (the date the app shows).
    final groups = <DateTime, List<Map<String, dynamic>>>{};
    for (final a in ups) {
      final d = dApptDate(a)!;
      groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(a);
    }
    final children = <Widget>[];
    // Oct 2026: "Did she join?" for finished calls with no Join tap.
    if (ask.isNotEmpty) {
      children.add(_dayHeader('Please confirm', ask.length, false, true));
      children.add(LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / 380).floor().clamp(1, 3);
        final w = (c.maxWidth - (cols - 1) * 14) / cols;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [for (final a in ask) SizedBox(width: w, child: _confirmCard(a))],
        );
      }));
    }
    for (final e in groups.entries) {
      final diff = e.key.difference(today).inDays;
      final pretty = DateFormat('EEE, MMM d').format(e.key);
      final label = diff == 0 ? 'Today · $pretty' : (diff == 1 ? 'Tomorrow · $pretty' : pretty);
      children.add(_dayHeader(label, e.value.length, diff == 0, children.isEmpty));
      children.add(LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / 380).floor().clamp(1, 3);
        final w = (c.maxWidth - (cols - 1) * 14) / cols;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [for (final a in e.value) SizedBox(width: w, child: _card(a))],
        );
      }));
    }
    return ListView(padding: const EdgeInsets.only(bottom: 20), children: children);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Your consultations',
        sub: "Start any confirmed session when it's time. The client's Join Meeting button turns green "
            'as soon as you do, and the Meet link opens in a new tab.',
        actions: [
          if (_items != null)
            Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: StatusChip('${_upcoming.length} upcoming')),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: PT.red),
              onPressed: () async {
                if (await showEmergencyDayDialog(context)) _load();
              },
              icon: const Icon(Icons.event_busy_outlined, size: 18),
              label: const Text('Emergency: cancel my day'),
            ),
          ),
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Expanded(
        child: _loading && _items == null
            ? const Center(child: CircularProgressIndicator())
            : _items == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load consultations",
                    sub: _error,
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : Stack(fit: StackFit.expand, children: [
                    _list(),
                    if (_loading) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
                  ]),
      ),
    ]);
  }
}
