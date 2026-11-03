import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_session.dart';
import '../../portal_theme.dart';
import '../../shell/portal_nav.dart';
import '../../widgets/portal_ui.dart';
import 'd_ui.dart';

/// Dietitian home: this week's consultations, plans she owes, quick links
/// (alerts, clients, slots), flagged reviews, drafts and all bookings.
class DietitianHomePage extends StatefulWidget {
  const DietitianHomePage({super.key});

  @override
  State<DietitianHomePage> createState() => _DietitianHomePageState();
}

class _DietitianHomePageState extends State<DietitianHomePage> {
  List<Map<String, dynamic>>? _appts;
  List<Map<String, dynamic>>? _clients;
  String? _apptError;
  String? _clientError;
  int? _flagged;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.wait([_loadAppts(), _loadClients(), _loadFlagged()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadAppts() async {
    final b = await dLoadAppointments();
    if (!mounted) return;
    final d = b['data'];
    setState(() {
      if (PortalApi.ok(b) && d is Map && d['appointments'] is List) {
        _appts = dMaps(d['appointments']).where((a) => dApptDate(a) != null).toList();
        _apptError = null;
      } else {
        _apptError = PortalApi.msg(b, 'Could not load consultations. Please try again.');
      }
    });
  }

  Future<void> _loadClients() async {
    final b = await dLoadClients();
    if (!mounted) return;
    final d = b['data'];
    setState(() {
      if (PortalApi.ok(b) && d is Map && d['cliets'] is List) {
        _clients = dMaps(d['cliets']);
        _clientError = null;
      } else {
        _clientError = PortalApi.msg(b, 'Could not load your clients. Please try again.');
      }
    });
  }

  Future<void> _loadFlagged() async {
    // Best effort, like the app: a failure just counts as nothing flagged.
    final b = await PortalApi.get(Constants.adminDay7Reviews,
        query: {'limit': '100', 'offset': '0', 'flagged': 'true'});
    if (!mounted) return;
    final d = b['data'];
    setState(() => _flagged = (PortalApi.ok(b) && d is Map && d['reviews'] is List) ? (d['reviews'] as List).length : 0);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Stat tiles ──────────────────────────────────────────────────────
  Widget _stats() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekEnd = todayStart.add(const Duration(days: 7));
    final appts = _appts ?? const <Map<String, dynamic>>[];
    final week = appts.where((a) {
      final d = dApptDate(a)!;
      final s = '${a['status'] ?? ''}';
      return !d.isBefore(todayStart) && d.isBefore(weekEnd) && s != 'canceled' && s != 'canceledByUser';
    }).toList()
      ..sort((a, b) => dApptDate(a)!.compareTo(dApptDate(b)!));
    final todayCount = week.where((a) => _sameDay(dApptDate(a)!, now)).length;

    final clients = _clients ?? const <Map<String, dynamic>>[];
    final hasPipeline = clients.any((c) => c['planPipeline'] is Map);
    bool pp(Map<String, dynamic> c, String k) => dMap(c['planPipeline'])[k] == true;
    final plansDue = hasPipeline
        ? clients.where((c) => pp(c, 'owed')).toList()
        : clients.where((c) => c['status'] == 'PLAN_OVERDUE' || c['status'] == 'AWAITING_PLAN').toList();
    final overdue = hasPipeline
        ? clients.where((c) => pp(c, 'overdue')).length
        : clients.where((c) => c['status'] == 'PLAN_OVERDUE').length;

    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    String consultSub;
    if (_appts == null) {
      consultSub = _apptError ?? 'Loading…';
    } else if (week.isEmpty) {
      consultSub = 'Nothing booked this week';
    } else {
      final next = week.first;
      final nd = dApptDate(next)!;
      final day = _sameDay(nd, now) ? 'Today' : wd[nd.weekday - 1];
      final start = dSlotTime(dMap(next['SlotDiet'])['start']);
      consultSub = 'Next: ${dFirstName(next)}, $day $start${todayCount > 0 ? ' · $todayCount today' : ''}';
    }
    final plansSub = _clients == null
        ? (_clientError ?? 'Loading…')
        : plansDue.isEmpty
            ? 'Nothing owed right now'
            : overdue > 0
                ? '$overdue overdue'
                : 'Due within 2 days';

    return LayoutBuilder(builder: (context, c) {
      final tiles = [
        _StatTile(
          icon: Icons.event_available_outlined,
          accent: PT.green,
          accentBg: const Color(0xFFEAF7E4),
          count: _appts == null ? '–' : '${week.length}',
          label: 'Consultations this week',
          sub: consultSub,
          onTap: () => portalGo('d_today'),
        ),
        _StatTile(
          icon: Icons.assignment_late_outlined,
          accent: overdue > 0 ? PT.red : PT.amber,
          accentBg: overdue > 0 ? const Color(0xFFFBEAEA) : const Color(0xFFFBEBD8),
          count: _clients == null ? '–' : '${plansDue.length}',
          label: 'Plans to deliver',
          sub: plansSub,
          onTap: () => portalGo('d_deliver'),
        ),
      ];
      if (c.maxWidth < 420) {
        return Column(children: [tiles[0], const SizedBox(height: 10), tiles[1]]);
      }
      return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: tiles[0]),
          const SizedBox(width: 10),
          Expanded(child: tiles[1]),
        ]),
      );
    });
  }

  // ── Messages: the live preview reads the chat app directly; on the
  // portal it opens Chat.
  Widget _messages() => Container(
        decoration: PT.card(),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFFEAF7E4), shape: BoxShape.circle),
            child: const Icon(Icons.chat_bubble_outline_rounded, size: 17, color: PT.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Messages', style: PT.t(13.5, w: FontWeight.w700)),
              Text('Read and reply to your clients', style: PT.t(12, c: PT.sage), overflow: TextOverflow.ellipsis),
            ]),
          ),
          TextButton(
            onPressed: () => portalGo('chat'),
            child: Text('See all', style: PT.t(12.5, w: FontWeight.w600, c: PT.green)),
          ),
        ]),
      );

  Widget _quick(IconData icon, String label, String key) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => portalGo(key),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            decoration: PT.card(),
            child: Column(children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFFEAF7E4), shape: BoxShape.circle),
                child: Icon(icon, color: PT.green, size: 20),
              ),
              const SizedBox(height: 8),
              Text(label, style: PT.t(12.5, w: FontWeight.w600), overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      );

  Widget _quickActions() => Row(children: [
        // Alerts = missed sessions, plan delays, medical worries about HER clients.
        _quick(Icons.notification_important_outlined, 'Alerts', 'd_alerts'),
        const SizedBox(width: 10),
        _quick(Icons.group_outlined, 'Clients', 'd_clients'),
        const SizedBox(width: 10),
        _quick(Icons.edit_calendar_outlined, 'Slots', 'd_slots'),
      ]);

  Widget _feature({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color border,
    required String title,
    required String sub,
    String? badge,
    required VoidCallback onTap,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.white,
          child: ListTile(
            onTap: onTap,
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor),
            ),
            title: Text(title, style: PT.t(14, w: FontWeight.w700)),
            subtitle: Text(sub, style: PT.t(12, c: PT.sage)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: PT.red, borderRadius: BorderRadius.circular(12)),
                  child: Text(badge, style: PT.t(12, w: FontWeight.w700, c: Colors.white)),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AB09A)),
            ]),
          ),
        ),
      );

  Widget _features() {
    final f = _flagged;
    return Column(children: [
      _feature(
        icon: Icons.flag_outlined,
        iconColor: PT.red,
        iconBg: const Color(0xFFFBEAEA),
        border: (f ?? 0) > 0 ? PT.red : PT.line,
        title: 'Flagged reviews',
        sub: f == null
            ? 'Checking for check-ins that need attention…'
            : f == 0
                ? 'Nothing flagged right now'
                : 'Client check-ins that tripped a safety threshold',
        badge: (f != null && f > 0) ? '$f' : null,
        onTap: () => portalGo('d_flagged'),
      ),
      const SizedBox(height: 10),
      _feature(
        icon: Icons.assignment_outlined,
        iconColor: PT.green,
        iconBg: const Color(0xFFEAF7E4),
        border: PT.line,
        title: 'Drafts to review',
        sub: 'AI-generated diet plans pending your review',
        onTap: () => portalGo('d_drafts'),
      ),
    ]);
  }

  // ── Appointments list ───────────────────────────────────────────────
  Widget _apptCard(Map<String, dynamic> a) {
    final status = '${a['status'] ?? ''}';
    final follow = a['kind'] == 'followup';
    final msg = '${a['message'] ?? ''}'.trim();
    final hasMsg = msg.isNotEmpty && msg.toUpperCase() != 'N/A' && msg != 'null';
    final range = dTimeRange(a);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // Her profile lives under Clients on the portal.
        onTap: () => portalGo('d_clients'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: PT.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(dClientName(a), style: PT.t(14.5, w: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(follow ? 'Follow-up consultation' : 'Initial consultation',
                      style: PT.t(11.5, w: FontWeight.w500, c: PT.sage)),
                ]),
              ),
              const SizedBox(width: 8),
              DStatusPill(status),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AB09A)),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 12, runSpacing: 4, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_today_rounded, size: 13, color: PT.sage),
                const SizedBox(width: 5),
                Text(DateFormat('d MMM yyyy').format(dApptDate(a)!), style: PT.t(12.5, w: FontWeight.w500)),
              ]),
              if (range.isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.access_time_rounded, size: 13, color: PT.sage),
                  const SizedBox(width: 5),
                  Text(range, style: PT.t(12.5, w: FontWeight.w500)),
                ]),
            ]),
            if (hasMsg) ...[
              const SizedBox(height: 8),
              Text('"$msg"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PT.t(12, c: PT.sage).copyWith(fontStyle: FontStyle.italic)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _appointments() {
    final head = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text('Your appointments', style: PT.t(15, w: FontWeight.w700)),
    );
    Widget body;
    if (_appts == null && _apptError == null) {
      body = const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    } else if (_appts == null) {
      body = Container(
        decoration: PT.card(),
        child: PortalEmpty(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't load consultations",
          sub: _apptError,
          action: TextButton(onPressed: _loadAppts, child: const Text('Try again')),
        ),
      );
    } else if (_appts!.isEmpty) {
      body = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: PT.card(),
        child: Column(children: [
          const Icon(Icons.event_available_outlined, color: PT.sage, size: 28),
          const SizedBox(height: 8),
          Text('No appointments right now', style: PT.t(14, w: FontWeight.w600)),
        ]),
      );
    } else {
      body = Column(children: [
        for (final a in _appts!) Padding(padding: const EdgeInsets.only(bottom: 10), child: _apptCard(a)),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, body]);
  }

  Widget _greet() {
    final first = '${Get.find<PortalSession>().user.value?['firstName'] ?? ''}'.trim();
    return Row(children: [
      Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Color(0xFFEAF7E4), shape: BoxShape.circle),
        child: const Icon(Icons.eco_outlined, color: PT.green),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$_greeting${first.isEmpty ? '' : ', $first'}', style: PT.t(18, w: FontWeight.w700)),
          const SizedBox(height: 2),
          Text("Here's what needs you today", style: PT.t(13, c: PT.sage)),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[
      _greet(),
      const SizedBox(height: 20),
      _stats(),
      const SizedBox(height: 10),
      _messages(),
      const SizedBox(height: 20),
      _quickActions(),
      const SizedBox(height: 16),
      _features(),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'My dashboard',
        sub: 'Your consultations, plans you owe and anything that needs a look.',
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      if (_loading) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
      const SizedBox(height: 8),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 960) {
            return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              ...left,
              const SizedBox(height: 24),
              _appointments(),
            ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 5,
              child: ListView(padding: const EdgeInsets.only(bottom: 24), children: left),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 6,
              child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [_appointments()]),
            ),
          ]);
        }),
      ),
    ]);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.accent,
    required this.accentBg,
    required this.count,
    required this.label,
    required this.sub,
    required this.onTap,
  });
  final IconData icon;
  final Color accent;
  final Color accentBg;
  final String count;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: PT.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: accentBg, shape: BoxShape.circle),
                  child: Icon(icon, size: 16, color: accent),
                ),
                const SizedBox(width: 8),
                Text(count, style: PT.t(20, w: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              Text(label, style: PT.t(12.5, w: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: PT.t(11, c: PT.sage)),
            ]),
          ),
        ),
      );
}
