import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/api_provider/api_provider.dart';
import '../../portal_api.dart';
import '../../portal_session.dart';
import '../../portal_theme.dart';
import '../../shell/portal_nav.dart';
import '../../widgets/portal_ui.dart';

/// The client the dietitian chose before opening "Generate AI plan".
/// Shape: {userId: int, userPlanId: int?, name: String}. The generate page
/// may read it to preselect her (and set it back to null when used).
final ValueNotifier<Map<String, dynamic>?> dietitianSelectedClient = ValueNotifier<Map<String, dynamic>?>(null);

// ── Small shared helpers (also used by clients_page / flagged_page) ──────

int? dtInt(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

double? dtNum(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

String dtHuman(dynamic s) {
  final t = '${s ?? ''}'.trim();
  if (t.isEmpty) return '';
  return t.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
}

String dtDate(dynamic iso, [String fmt = 'd MMM yyyy']) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  return d == null ? '' : DateFormat(fmt).format(d);
}

List<Map<String, dynamic>> dtMaps(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

List<dynamic> dtList(dynamic v) {
  if (v is List) return v;
  if (v is String && v.trim().isNotEmpty) {
    try {
      final d = jsonDecode(v);
      if (d is List) return d;
    } catch (_) {}
  }
  return const [];
}

Map<String, dynamic>? dtMap(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is String && v.trim().isNotEmpty) {
    try {
      final d = jsonDecode(v);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
  }
  return null;
}

String dtUserName(dynamic u, [String fallback = 'Client']) {
  if (u is! Map) return fallback;
  final n = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
  return n.isEmpty ? fallback : n;
}

String dtInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
  final s = parts.map((p) => p[0].toUpperCase()).join();
  return s.isEmpty ? '?' : s;
}

/// PATCH with the portal token (PortalApi has GET/POST only). Never throws.
Future<Map<String, dynamic>> dtPatch(String path, Map<String, dynamic> body) async {
  try {
    final ses = Get.find<PortalSession>();
    ses.touch();
    final r = await Get.find<ApiProvider>().patchData(path, body: body, headers: ses.headers);
    final b = r.body;
    if (b is Map) return Map<String, dynamic>.from(b);
  } catch (_) {}
  return {'status': '0', 'message': "Couldn't reach the server."};
}

class DtStatus {
  const DtStatus(this.label, this.fg, this.bg);
  final String label;
  final Color fg;
  final Color bg;
}

/// Same labels and colours as the app's Clients list.
const Map<String, DtStatus> dtStatusStyles = {
  'FLAGGED': DtStatus('Needs attention', Color(0xFFC24B4B), Color(0xFFFBEAEA)),
  'CONSULTATION_TODAY': DtStatus('Consultation today', Color(0xFF3D8F4F), Color(0xFFE3F3E3)),
  'PLAN_OVERDUE': DtStatus('Plan overdue', Color(0xFFC77B2B), Color(0xFFFBEBD8)),
  'AWAITING_PLAN': DtStatus('Plan due soon', Color(0xFF3B6FA0), Color(0xFFE3EEF7)),
  'ON_TRACK': DtStatus('On track', Color(0xFF4E9F3D), Color(0xFFE4F3DE)),
  'NEW': DtStatus('No consultation yet', Color(0xFF6F8B7A), Color(0xFFEFF3EF)),
  'PLAN_ENDED': DtStatus('Plan ended', Color(0xFF8A8F87), Color(0xFFEDEFEA)),
};

DtStatus dtStatusFor(dynamic s) => dtStatusStyles['${s ?? ''}'] ?? dtStatusStyles['ON_TRACK']!;

Widget dtPill(DtStatus s) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(999)),
      child: Text(s.label, style: PT.t(11.5, w: FontWeight.w600, c: s.fg)),
    );

/// White card with a title row and optional actions.
Widget dtCard({required String title, String? sub, List<Widget> actions = const [], required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: PT.t(15, w: FontWeight.w700)),
              if (sub != null) Text(sub, style: PT.t(12, c: PT.sage)),
            ]),
          ),
          ...actions,
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );

Widget dtLoading() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
    );

Widget dtMessage(String text, {VoidCallback? retry}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(children: [
        Text(text, textAlign: TextAlign.center, style: PT.t(13, c: PT.sage, h: 1.45)),
        if (retry != null) TextButton(onPressed: retry, child: const Text('Try again')),
      ]),
    );

Widget dtRefresh(VoidCallback? onTap) => IconButton(
      tooltip: 'Refresh',
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: const Icon(Icons.refresh_rounded, size: 20),
    );

Widget dtField(String label, String value, {bool warn = false}) => Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: Text(label, style: PT.t(12.5, c: PT.sage))),
        Expanded(child: SelectableText(value, style: PT.t(13, w: FontWeight.w600, c: warn ? PT.red : PT.ink))),
      ]),
    );

Widget dtTag(String text, {Color color = PT.red}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: PT.t(11, w: FontWeight.w700, c: color)),
    );

/// One Day 7 review (used here and on the Flagged reviews page).
Widget dtReviewCard(Map<String, dynamic> r, {bool showClient = false}) {
  final flagged = r['flagged'] == true;
  final resolved = r['flagResolvedAt'] != null;
  final reasons = dtList(r['flagReasons']);
  final struggled = dtList(r['mealsStruggled']);
  final effects = dtList(r['sideEffects']);
  final plan = r['UserPlan'] is Map && r['UserPlan']['Plan'] is Map ? '${r['UserPlan']['Plan']['title'] ?? ''}' : '';
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: flagged && !resolved ? PT.red : PT.line, width: flagged && !resolved ? 1.4 : 1),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(
            [
              if (showClient) dtUserName(r['User']),
              'Cycle ${r['cycle'] ?? '?'}',
              '${r['planType'] ?? 'plan'}'.toUpperCase(),
              if (plan.isNotEmpty) plan,
            ].join(' · '),
            style: PT.t(13.5, w: FontWeight.w700),
          ),
        ),
        if (flagged) dtTag(resolved ? 'FLAG RESOLVED' : 'FLAGGED', color: resolved ? PT.sage : PT.red),
      ]),
      const SizedBox(height: 6),
      if (r['adherencePct'] != null) dtField('Adherence', '${r['adherencePct']}%', warn: (dtInt(r['adherencePct']) ?? 100) < 40),
      if (r['hungerLevel'] != null) dtField('Hunger', dtHuman(r['hungerLevel'])),
      if (r['difficultyLevel'] != null) dtField('Difficulty', dtHuman(r['difficultyLevel'])),
      if (r['satisfaction'] != null) dtField('Satisfaction', '${r['satisfaction']}/5', warn: (dtInt(r['satisfaction']) ?? 5) < 2),
      if (r['painReported'] == true)
        dtField('Pain reported', r['painLocation'] == null ? 'Yes' : 'Yes — ${r['painLocation']}', warn: true),
      if (r['severeSideEffectsReported'] == true) dtField('Severe side effects', 'Yes', warn: true),
      if (effects.isNotEmpty) dtField('Side effects', effects.map(dtHuman).join(', ')),
      if (struggled.isNotEmpty) dtField('Meals she found hard', struggled.map(dtHuman).join(', ')),
      if (r['sessionTimingIssues'] == true) dtField('Session timing', 'Had trouble with session times'),
      if (flagged && reasons.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: reasons.map((x) => dtTag('$x')).toList()),
      ],
      if (r['createdAt'] != null) ...[
        const SizedBox(height: 8),
        Text('Sent ${dtDate(r['createdAt'])}', style: PT.t(11.5, c: PT.sage)),
      ],
    ]),
  );
}

// ── The client panel ─────────────────────────────────────────────────────

/// Everything the dietitian sees about one client: who she is, plan status,
/// quick actions, meal logging, health form + private notes, Day 7 reviews,
/// progress check-ins and her diet plans. Not scrollable itself — put it in
/// a scroll view. Give it a key per client so it resets.
/// Nov 2026: a client's details in a large window over the current page
/// ([initialTab] 1 = her health form). Used where a button should open
/// THIS client instead of sending the dietitian to the Clients list.
Future<void> showClientPanelDialog(
  BuildContext context, {
  required int userId,
  required String name,
  String? title,
  String? email,
  String? phone,
  Map<String, dynamic>? client,
  int? userPlanId,
  int initialTab = 0,
}) {
  return showDialog<void>(
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
                  child: Text(title ?? name, style: PT.t(15, w: FontWeight.w700), overflow: TextOverflow.ellipsis),
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
                  key: ValueKey('client_dialog_${userId}_$initialTab'),
                  userId: userId,
                  name: name,
                  email: email,
                  phone: phone,
                  client: client,
                  userPlanId: userPlanId,
                  initialTab: initialTab,
                ),
              ),
            ),
          ]),
        ),
      );
    },
  );
}

class ClientDetailPanel extends StatefulWidget {
  const ClientDetailPanel({
    super.key,
    required this.userId,
    required this.name,
    this.email,
    this.phone,
    this.client,
    this.userPlanId,
    this.initialTab = 0,
  });

  final int userId;
  final String name;
  final String? email;
  final String? phone;

  /// The row from the Clients list (status, plan dates, plan pipeline).
  final Map<String, dynamic>? client;

  /// Her plan purchase id (needed to generate a plan).
  final int? userPlanId;
  final int initialTab;

  @override
  State<ClientDetailPanel> createState() => _ClientDetailPanelState();
}

class _ClientDetailPanelState extends State<ClientDetailPanel> {
  static const _tabs = ['Meal logging', 'Health form & notes', 'Day 7 reviews', 'Progress', 'Plans'];
  static const _icons = [
    Icons.restaurant_outlined,
    Icons.assignment_outlined,
    Icons.rate_review_outlined,
    Icons.monitor_weight_outlined,
    Icons.history_rounded,
  ];

  late int _tab;
  final Set<int> _seen = {};

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, _tabs.length - 1);
    _seen.add(_tab);
  }

  int? get _planId => widget.userPlanId ?? dtInt(widget.client?['id']);

  void _generate() {
    dietitianSelectedClient.value = {'userId': widget.userId, 'userPlanId': _planId, 'name': widget.name};
    portalGo('d_generate');
  }

  void _message() {
    portalToast('Opening chat', sub: 'Pick ${widget.name} in your chat list.');
    portalGo('chat');
  }

  Widget _header() {
    final c = widget.client;
    final status = c == null ? null : dtStatusFor(c['status']);
    final detail = '${c?['statusDetail'] ?? ''}'.trim();
    final start = dtDate(c?['buyingDate'], 'd MMM yyyy');
    final end = dtDate(c?['expireDate'], 'd MMM yyyy');
    final ended = c?['status'] == 'PLAN_ENDED' ||
        (DateTime.tryParse('${c?['expireDate'] ?? ''}')?.isBefore(DateTime.now()) ?? false);
    final todayAt = c?['hasConsultationToday'] == true ? dtDate(c?['consultationTodayAt'], 'h:mm a') : '';
    final pipe = dtMap(c?['planPipeline']);
    final email = (widget.email ?? '').trim();
    final phone = (widget.phone ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7E4),
              shape: BoxShape.circle,
              border: Border.all(color: PT.green.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Text(dtInitials(widget.name), style: PT.t(19, w: FontWeight.w800)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.name, style: PT.t(18, w: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (email.isNotEmpty) SelectableText(email, style: PT.t(12.5, c: PT.sage)),
              if (phone.isNotEmpty) SelectableText(phone, style: PT.t(12.5, c: PT.sage)),
              if (status != null) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  dtPill(status),
                  if (detail.isNotEmpty) Text(detail, style: PT.t(12, c: PT.sage)),
                ]),
              ],
            ]),
          ),
        ]),
        if (start.isNotEmpty || end.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.event_note_outlined, size: 17, color: ended ? PT.sage : PT.green),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Plan: $start – $end${ended ? '  (ended)' : ''}',
                  style: PT.t(12.5, c: ended ? PT.sage : PT.ink)),
            ),
          ]),
        ],
        if (ended && c != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFEDEFEA), borderRadius: BorderRadius.circular(10)),
            child: Text("Her plan has ended. She still sees her meal plan, but she can't book new sessions.",
                style: PT.t(12.5, c: const Color(0xFF5E645B), h: 1.4)),
          ),
        ],
        if (todayAt.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.today_outlined, size: 17, color: Color(0xFF3D8F4F)),
            const SizedBox(width: 6),
            Expanded(child: Text('Consultation today at $todayAt', style: PT.t(12.5, w: FontWeight.w600))),
            TextButton(onPressed: () => portalGo('d_today'), child: const Text("Today's sessions")),
          ]),
        ],
        if (pipe != null && pipe['owed'] == true) ...[
          const SizedBox(height: 10),
          _pipeline(pipe),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (_planId != null)
            ElevatedButton.icon(
              style: portalPrimary(),
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Generate plan'),
            ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: PT.ink,
              side: const BorderSide(color: PT.line),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _message,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Message'),
          ),
        ]),
      ]),
    );
  }

  Widget _pipeline(Map<String, dynamic> p) {
    final hours = dtInt(p['hoursLeft']) ?? 0;
    final overdue = p['overdue'] == true;
    final color = overdue ? PT.red : PT.amber;
    Widget step(bool done, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 16, color: done ? PT.green : PT.sage),
          const SizedBox(width: 5),
          Text(label, style: PT.t(12.5)),
        ]);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          overdue
              ? 'Her plan is overdue by ${hours.abs()} h'
              : 'Her plan is due in $hours h${p['dueAt'] == null ? '' : ' (${dtDate(p['dueAt'], 'EEE d MMM, h:mm a')})'}',
          style: PT.t(13, w: FontWeight.w700, c: color),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 16, runSpacing: 6, children: [
          step(p['hasForm'] == true, 'Health form filled'),
          step(p['formReviewed'] == true, 'Form reviewed by you'),
          step(p['draftPlanId'] != null, 'Draft plan ready'),
        ]),
        const SizedBox(height: 4),
        Wrap(spacing: 4, children: [
          if (p['draftPlanId'] != null)
            TextButton(onPressed: () => portalGo('d_drafts'), child: const Text('Review the draft')),
          TextButton(onPressed: () => portalGo('d_deliver'), child: const Text('Plans to deliver')),
        ]),
      ]),
    );
  }

  Widget _tabBar() => Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < _tabs.length; i++)
          Material(
            color: i == _tab ? PT.ink : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: i == _tab ? PT.ink : PT.line),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() {
                _tab = i;
                _seen.add(i);
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_icons[i], size: 16, color: i == _tab ? Colors.white : PT.green),
                  const SizedBox(width: 6),
                  Text(_tabs[i], style: PT.t(12.5, w: FontWeight.w600, c: i == _tab ? Colors.white : PT.ink)),
                ]),
              ),
            ),
          ),
      ]);

  Widget _tabBody(int i) {
    switch (i) {
      case 0:
        return _MealActivityCard(userId: widget.userId);
      case 1:
        return _ProfileTab(userId: widget.userId, name: widget.name);
      case 2:
        return _ReviewsTab(userId: widget.userId);
      case 3:
        return _ProgressTab(userId: widget.userId);
      default:
        return _PlansTab(userId: widget.userId, name: widget.name, onGenerate: _planId == null ? null : _generate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seen = _seen.toList()..sort();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      _header(),
      const SizedBox(height: 14),
      _tabBar(),
      const SizedBox(height: 12),
      for (final i in seen) Offstage(offstage: i != _tab, child: _tabBody(i)),
    ]);
  }
}

// ── Meal logging, last 7 days ────────────────────────────────────────────

const Color _kFollowed = Color(0xFF3F9E3A);
const Color _kSwapped = Color(0xFF4C7BD9);
const Color _kSkipped = Color(0xFFD9605F);
const Color _kNotLogged = Color(0xFFEEF2EC);

enum _DotKind { followed, swapped, skipped, notLogged }

class _MealActivityCard extends StatefulWidget {
  const _MealActivityCard({required this.userId});
  final int userId;

  @override
  State<_MealActivityCard> createState() => _MealActivityCardState();
}

class _MealActivityCardState extends State<_MealActivityCard> {
  List<Map<String, dynamic>>? _days;
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
    final b = await PortalApi.get('/admin/diet-plan/user/${widget.userId}/meal-activity', query: {'days': '7'});
    if (!mounted) return;
    final d = b['data'];
    setState(() {
      _loading = false;
      if (PortalApi.ok(b) && d is Map && d['days'] is List) {
        _days = dtMaps(d['days']);
      } else {
        _days = null;
        _error = PortalApi.msg(b, "Couldn't load her meal logs.");
      }
    });
  }

  static int _n(dynamic v) => dtInt(v) ?? 0;

  @override
  Widget build(BuildContext context) {
    return dtCard(
      title: 'Meal logging · last 7 days',
      sub: 'How actively she logged the meals on her plan.',
      actions: [dtRefresh(_loading ? null : _load)],
      child: _loading
          ? dtLoading()
          : _error != null
              ? dtMessage(_error!, retry: _load)
              : _content(),
    );
  }

  Widget _content() {
    final days = _days ?? const <Map<String, dynamic>>[];
    final planned = days.fold<int>(0, (s, d) => s + _n(d['planned']));
    final followed = days.fold<int>(0, (s, d) => s + _n(d['followed']));
    final swapped = days.fold<int>(0, (s, d) => s + _n(d['alternative']));
    final skipped = days.fold<int>(0, (s, d) => s + _n(d['skipped']));
    final logged = followed + swapped + skipped;
    final activeDays = days.where((d) => _n(d['logged']) > 0).length;
    final planDays = days.where((d) => _n(d['planned']) > 0).length;

    if (planned == 0 && logged == 0) {
      return dtMessage('No meal plan was active this week, so there is nothing to log yet. '
          'Logging starts once her plan is delivered.');
    }
    final int? pct = planned == 0 ? null : (logged * 100 / planned).round().clamp(0, 100);
    final pctColor = pct == null
        ? PT.sage
        : pct >= 70
            ? _kFollowed
            : pct >= 40
                ? const Color(0xFFB7791F)
                : _kSkipped;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('$logged', style: PT.t(30, w: FontWeight.w800, h: 1.0)),
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 3),
          child: Text(planned > 0 ? 'of $planned meals logged' : 'meals logged', style: PT.t(13, c: PT.sage)),
        ),
        const Spacer(),
        if (pct != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: pctColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text('$pct%', style: PT.t(13, w: FontWeight.w800)),
          ),
      ]),
      const SizedBox(height: 4),
      Text(planDays > 0 ? 'Logged on $activeDays of $planDays plan days' : 'Logged on $activeDays days',
          style: PT.t(12, c: PT.sage)),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final d in days) Expanded(child: _dayColumn(d)),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 14, runSpacing: 6, children: [
        _legend(_DotKind.followed, 'Followed $followed'),
        _legend(_DotKind.swapped, 'Swapped $swapped'),
        _legend(_DotKind.skipped, 'Skipped $skipped'),
        _legend(_DotKind.notLogged, 'Not logged'),
      ]),
    ]);
  }

  Widget _dayColumn(Map<String, dynamic> day) {
    final date = DateTime.tryParse('${day['date']}');
    final now = DateTime.now();
    final isToday = date != null && date.year == now.year && date.month == now.month && date.day == now.day;
    final planned = _n(day['planned']);
    final f = _n(day['followed']);
    final a = _n(day['alternative']);
    final s = _n(day['skipped']);
    final logged = f + a + s;
    final slots = planned > logged ? planned : logged;
    final dots = <_DotKind>[
      for (var i = 0; i < f; i++) _DotKind.followed,
      for (var i = 0; i < a; i++) _DotKind.swapped,
      for (var i = 0; i < s; i++) _DotKind.skipped,
      for (var i = logged; i < slots; i++) _DotKind.notLogged,
    ];
    return Column(children: [
      Text(date == null ? '' : DateFormat('EEE').format(date),
          style: PT.t(11.5, w: isToday ? FontWeight.w800 : FontWeight.w600, c: isToday ? PT.green : PT.sage)),
      if (date != null) Text('${date.day}', style: PT.t(10.5, c: PT.sage)),
      const SizedBox(height: 6),
      if (dots.isEmpty)
        Text('–', style: PT.t(12, c: PT.sage))
      else
        for (final k in dots) Padding(padding: const EdgeInsets.only(bottom: 4), child: _dot(k)),
    ]);
  }

  static Widget _legend(_DotKind k, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        _dot(k),
        const SizedBox(width: 5),
        Text(label, style: PT.t(11.5)),
      ]);

  static Widget _dot(_DotKind kind) {
    Widget circle({required Color fill, Color? border, IconData? icon, Color? iconColor}) => Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: border == null ? null : Border.all(color: border, width: 1.5),
          ),
          child: icon == null ? null : Icon(icon, size: 11, color: iconColor),
        );
    switch (kind) {
      case _DotKind.followed:
        return circle(fill: _kFollowed, icon: Icons.check_rounded, iconColor: Colors.white);
      case _DotKind.swapped:
        return circle(fill: _kSwapped, icon: Icons.swap_horiz_rounded, iconColor: Colors.white);
      case _DotKind.skipped:
        return circle(fill: Colors.white, border: _kSkipped, icon: Icons.close_rounded, iconColor: _kSkipped);
      case _DotKind.notLogged:
        return circle(fill: _kNotLogged, border: const Color(0xFFD8EDD4));
    }
  }
}

// ── Health form + private notes ──────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.userId, required this.name});
  final int userId;
  final String name;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _loading = true;
  String? _error;
  bool _notFilled = false;
  Map<String, dynamic>? _raw;
  bool _adding = false;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final b = await PortalApi.get('/admin/pre-consultation/${widget.userId}');
    if (!mounted) return;
    final d = b['data'];
    setState(() {
      _loading = false;
      _notFilled = false;
      if (PortalApi.ok(b) && d is Map && d['profile'] is Map) {
        _raw = Map<String, dynamic>.from(d['profile'] as Map);
      } else if (PortalApi.msg(b).toLowerCase().contains('not found')) {
        _raw = null;
        _notFilled = true;
      } else {
        _raw = null;
        _error = PortalApi.msg(b, "Couldn't load her health form.");
      }
    });
  }

  Future<void> _addNote() async {
    final text = _note.text.trim();
    if (text.isEmpty) return;
    setState(() => _adding = true);
    final b = await PortalApi.post('/admin/pre-consultation/${widget.userId}/comments', {'text': text});
    if (!mounted) return;
    setState(() => _adding = false);
    if (PortalApi.ok(b)) {
      _note.clear();
      portalToast('Note added');
      await _load();
    } else {
      portalToast("Couldn't add the note", sub: PortalApi.msg(b), error: true);
    }
  }

  Future<void> _openEdit() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditFormDialog(userId: widget.userId, name: widget.name, initial: _raw),
    );
    if (saved == true && mounted) await _load();
  }

  Widget _editButton(String label) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: PT.ink,
          side: const BorderSide(color: PT.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        onPressed: _openEdit,
        icon: const Icon(Icons.edit_outlined, size: 16, color: PT.green),
        label: Text(label),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return dtCard(title: 'Health form & notes', child: dtLoading());
    if (_error != null) {
      return dtCard(title: 'Health form & notes', actions: [dtRefresh(_load)], child: dtMessage(_error!, retry: _load));
    }
    final p = _raw;
    if (_notFilled || p == null) {
      return dtCard(
        title: 'Health form & notes',
        actions: [dtRefresh(_load)],
        child: Column(children: [
          dtMessage("She hasn't filled her form yet. You can fill it with her during the consultation."),
          _editButton('Fill form now'),
          const SizedBox(height: 8),
        ]),
      );
    }

    final complete = p['isComplete'] == true || p['isComplete'] == 1;
    final prefs = dtList(p['dietaryPreferences']).map(dtHuman).join(', ');
    final w = dtMap(p['workoutSection']);
    final comments = dtList(p['dietitianComments']).whereType<Map>().toList();
    String v(dynamic x) => '${x ?? ''}'.trim().isEmpty ? '—' : '${x ?? ''}'.trim();

    final sections = <MapEntry<String, String>>[
      MapEntry('Goal', v(dtHuman(p['goals']))),
      MapEntry('Meals per day', v(p['mealsPerDay'])),
      MapEntry('Allergies', v(p['allergies'])),
      MapEntry('Medical conditions', v(p['medicalConditions'])),
      MapEntry('Cycle / reproductive', v(dtHuman(p['pregnancyMenstrualStatus']))),
      MapEntry('Dietary preferences', v(prefs)),
      if ('${p['familyHistory'] ?? ''}'.trim().isNotEmpty) MapEntry('Family history', v(p['familyHistory'])),
      if ('${p['surgeries'] ?? ''}'.trim().isNotEmpty) MapEntry('Surgeries', v(p['surgeries'])),
      if ('${p['currentMedications'] ?? ''}'.trim().isNotEmpty) MapEntry('Medications', v(p['currentMedications'])),
      if ('${p['fastingHabits'] ?? ''}'.trim().isNotEmpty) MapEntry('Fasting habits', v(p['fastingHabits'])),
      if (w != null) MapEntry('Fitness level', v(dtHuman(w['fitnessLevel']))),
      if (w != null && '${w['injuries'] ?? ''}'.trim().isNotEmpty) MapEntry('Injuries / avoid', v(w['injuries'])),
      if (w != null && w['equipment'] is List)
        MapEntry('Equipment', v((w['equipment'] as List).map(dtHuman).join(', '))),
    ];

    final edited = dtDate(p['lastDietitianEdit'], 'd MMM yyyy, h:mm a');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      dtCard(
        title: 'Health form',
        sub: edited.isEmpty ? 'What she told us before the consultation.' : 'Last edited by a dietitian on $edited.',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: StatusChip(complete ? 'Form complete' : 'Form in progress', color: complete ? PT.green : PT.amber),
          ),
          _editButton('Edit form'),
          dtRefresh(_load),
        ],
        child: LayoutBuilder(builder: (c, box) {
          final cols = box.maxWidth >= 640 ? 2 : 1;
          final cw = (box.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final e in sections)
              Container(
                width: cw,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.key.toUpperCase(), style: PT.t(10.5, w: FontWeight.w700, c: PT.sage)),
                  const SizedBox(height: 3),
                  SelectableText(e.value, style: PT.t(13, h: 1.4)),
                ]),
              ),
          ]);
        }),
      ),
      const SizedBox(height: 12),
      _ScreeningCard(userId: widget.userId),
      dtCard(
        title: 'Private notes',
        sub: 'Only dietitians and admins can see these.',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (comments.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('No notes yet.', style: PT.t(13, c: PT.sage)))
          else
            ...comments.map((c) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${c['authorName'] ?? 'Staff'}', style: PT.t(12.5, w: FontWeight.w700))),
                      Text(dtDate(c['timestamp'], 'd MMM, h:mm a'), style: PT.t(11, c: PT.sage)),
                    ]),
                    const SizedBox(height: 4),
                    SelectableText('${c['text'] ?? ''}', style: PT.t(13, h: 1.4)),
                  ]),
                )),
          const SizedBox(height: 8),
          TextField(
            key: ValueKey('dt_note_${widget.userId}'),
            controller: _note,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Add a private note…'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: portalPrimary(),
              onPressed: _adding ? null : _addNote,
              child: _adding
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Add note'),
            ),
          ),
        ]),
      ),
    ]);
  }
}

/// Her in-app symptom checks (latest per condition). Hidden when none.
class _ScreeningCard extends StatefulWidget {
  const _ScreeningCard({required this.userId});
  final int userId;

  @override
  State<_ScreeningCard> createState() => _ScreeningCardState();
}

class _ScreeningCardState extends State<_ScreeningCard> {
  List<Map<String, dynamic>> _rows = [];
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await PortalApi.get('/admin/healthScreening/${widget.userId}');
    final d = b['data'];
    if (!mounted) return;
    if (PortalApi.ok(b) && d is Map && d['results'] is List) setState(() => _rows = dtMaps(d['results']));
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: dtCard(
        title: 'Symptom check (in app)',
        sub: 'Her latest result for each check, highest risk first.',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ..._rows.map((r) {
            final risk = '${r['riskLevel'] ?? 'low'}';
            final color = risk == 'high'
                ? const Color(0xFFC2412D)
                : risk == 'moderate'
                    ? const Color(0xFFB7791F)
                    : PT.greenDark;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text('${r['conditionType'] ?? ''}', style: PT.t(13, w: FontWeight.w600))),
                StatusChip(dtHuman(risk), color: color),
                const SizedBox(width: 10),
                SizedBox(width: 90, child: Text(dtDate(r['takenAt']), textAlign: TextAlign.right, style: PT.t(11.5, c: PT.sage))),
              ]),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _open = !_open),
              child: Text(_open ? 'Hide her answers' : 'Show her answers'),
            ),
          ),
          if (_open)
            ..._rows.where((r) => r['answers'] is Map).map((r) {
              final a = Map<String, dynamic>.from(r['answers'] as Map);
              return Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['conditionType'] ?? ''}', style: PT.t(12.5, w: FontWeight.w700)),
                  ...a.entries.map((e) => Text('Q${(int.tryParse(e.key) ?? 0) + 1}: ${e.value}', style: PT.t(12.5, c: PT.sage))),
                ]),
              );
            }),
        ]),
      ),
    );
  }
}

/// The dietitian edits (or fills) the client's health form. Saving replaces
/// what the client entered; the AI plan is built from this form.
class _EditFormDialog extends StatefulWidget {
  const _EditFormDialog({required this.userId, required this.name, this.initial});
  final int userId;
  final String name;
  final Map<String, dynamic>? initial;

  @override
  State<_EditFormDialog> createState() => _EditFormDialogState();
}

class _EditFormDialogState extends State<_EditFormDialog> {
  static const _goals = [
    ['weight_loss', 'Lose weight'],
    ['weight_gain', 'Gain weight'],
    ['maintain', 'Maintain'],
    ['pcos_management', 'Manage PCOS'],
    ['postpartum', 'Postpartum recovery'],
    ['pregnancy_prep', 'Pregnancy prep'],
    ['general_wellness', 'General wellness'],
  ];
  static const _cycle = [
    ['regular_cycle', 'Regular cycle'],
    ['irregular_cycle', 'Irregular cycle'],
    ['trying_to_conceive', 'Trying for a baby'],
    ['pcos', 'PCOS'],
    ['pregnant', 'Pregnant'],
    ['postpartum', 'Postpartum'],
    ['menopause', 'Menopause'],
    ['prefer_not_to_say', 'Prefer not to say'],
  ];
  static const _diet = [
    ['vegetarian', 'Vegetarian'],
    ['halal', 'Halal'],
    ['lactose_free', 'Lactose-free'],
    ['gluten_free', 'Gluten-free'],
    ['eggs_ok', 'Eggs OK'],
    ['seafood_ok', 'Seafood OK'],
    ['no_restrictions', 'No restrictions'],
  ];

  String? _goal;
  String? _cycleStatus;
  final Set<String> _prefs = {};
  int _meals = 5;
  bool _saving = false;
  final _allergies = TextEditingController();
  final _medical = TextEditingController();
  final _meds = TextEditingController();
  final _fasting = TextEditingController();
  final _surgeries = TextEditingController();
  final _family = TextEditingController();

  @override
  void initState() {
    super.initState();
    final m = widget.initial ?? const <String, dynamic>{};
    _goal = m['goals']?.toString();
    _cycleStatus = m['pregnancyMenstrualStatus']?.toString();
    _prefs.addAll(dtList(m['dietaryPreferences']).map((e) => e.toString()));
    final meals = dtInt(m['mealsPerDay']);
    if (meals != null && meals >= 3 && meals <= 6) _meals = meals;
    _allergies.text = '${m['allergies'] ?? ''}';
    _medical.text = '${m['medicalConditions'] ?? ''}';
    _meds.text = '${m['currentMedications'] ?? ''}';
    _fasting.text = '${m['fastingHabits'] ?? ''}';
    _surgeries.text = '${m['surgeries'] ?? ''}';
    _family.text = '${m['familyHistory'] ?? ''}';
  }

  @override
  void dispose() {
    for (final c in [_allergies, _medical, _meds, _fasting, _surgeries, _family]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final b = await dtPatch('/admin/pre-consultation/${widget.userId}', {
      'goals': _goal,
      'pregnancyMenstrualStatus': _cycleStatus,
      'dietaryPreferences': _prefs.toList(),
      'mealsPerDay': _meals,
      'allergies': _allergies.text.trim(),
      'medicalConditions': _medical.text.trim(),
      'currentMedications': _meds.text.trim(),
      'fastingHabits': _fasting.text.trim(),
      'surgeries': _surgeries.text.trim(),
      'familyHistory': _family.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (PortalApi.ok(b)) {
      portalToast('Form updated', sub: widget.name);
      Navigator.pop(context, true);
    } else {
      portalToast("Couldn't save changes", sub: PortalApi.msg(b), error: true);
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(t, style: PT.t(13, w: FontWeight.w700)),
      );

  Widget _chips(List<List<String>> opts, bool Function(String) isOn, void Function(String) onTap) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: opts.map((o) {
          final on = isOn(o[0]);
          return Material(
            color: on ? PT.ink : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: on ? PT.ink : PT.line),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onTap(o[0]),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(o[1], style: PT.t(12.5, w: FontWeight.w600, c: on ? Colors.white : PT.ink)),
              ),
            ),
          );
        }).toList(),
      );

  Widget _field(String key, TextEditingController c, String hint) => TextField(
        key: ValueKey('dt_form_$key'),
        controller: c,
        minLines: 1,
        maxLines: 4,
        decoration: InputDecoration(hintText: hint),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text("${widget.name}'s health form", style: PT.t(17, w: FontWeight.w700)),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(10)),
              child: Text('Your changes replace what she entered. The AI plan is built from this form.',
                  style: PT.t(12.5, c: PT.greenDark, h: 1.4)),
            ),
            _label('Goal'),
            _chips(_goals, (v) => _goal == v, (v) => setState(() => _goal = v)),
            _label('Cycle / reproductive status'),
            _chips(_cycle, (v) => _cycleStatus == v, (v) => setState(() => _cycleStatus = v)),
            _label('Dietary preferences'),
            _chips(_diet, (v) => _prefs.contains(v), (v) => setState(() {
                  if (!_prefs.remove(v)) _prefs.add(v);
                })),
            _label('Meals per day'),
            _chips(const [
              ['3', '3'],
              ['4', '4'],
              ['5', '5'],
              ['6', '6'],
            ], (v) => '$_meals' == v, (v) => setState(() => _meals = int.parse(v))),
            _label('Allergies'),
            _field('allergies', _allergies, 'e.g. peanuts, shellfish'),
            _label('Medical conditions'),
            _field('medical', _medical, 'e.g. PCOS, hypothyroid, diabetes'),
            _label('Current medications'),
            _field('meds', _meds, 'e.g. Metformin 500mg'),
            _label('Fasting habits'),
            _field('fasting', _fasting, 'e.g. fasts Mondays and Thursdays'),
            _label('Past surgeries'),
            _field('surgeries', _surgeries, 'Optional'),
            _label('Family history'),
            _field('family', _family, 'Optional'),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: Text('Cancel', style: PT.t(13.5, c: PT.sage))),
        ElevatedButton(
          style: portalPrimary(),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save form'),
        ),
      ],
    );
  }
}

// ── Day 7 reviews ────────────────────────────────────────────────────────

class _ReviewsTab extends StatefulWidget {
  const _ReviewsTab({required this.userId});
  final int userId;

  @override
  State<_ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<_ReviewsTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

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
    final b = await PortalApi.get('/admin/day7-reviews', query: {'limit': '50', 'offset': '0', 'userId': '${widget.userId}'});
    if (!mounted) return;
    final d = b['data'];
    setState(() {
      _loading = false;
      if (PortalApi.ok(b) && d is Map && d['reviews'] is List) {
        _items = dtMaps(d['reviews']);
      } else {
        _error = PortalApi.msg(b, "Couldn't load her reviews.");
      }
    });
  }

  @override
  Widget build(BuildContext context) => dtCard(
        title: 'Day 7 reviews',
        sub: 'What she told us after the first week of each plan.',
        actions: [dtRefresh(_loading ? null : _load)],
        child: _loading
            ? dtLoading()
            : _error != null
                ? dtMessage(_error!, retry: _load)
                : _items.isEmpty
                    ? dtMessage('No reviews submitted yet.')
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _items.map((r) => dtReviewCard(r)).toList()),
      );
}

// ── Progress (Day 15 / Day 30 check-ins) ─────────────────────────────────

class _ProgressTab extends StatefulWidget {
  const _ProgressTab({required this.userId});
  final int userId;

  @override
  State<_ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<_ProgressTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

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
    final b = await PortalApi.get('/admin/users/${widget.userId}/progress');
    if (!mounted) return;
    final d = b['data'];
    setState(() {
      _loading = false;
      if (PortalApi.ok(b) && d is Map && d['progressSubmissions'] is List) {
        _items = dtMaps(d['progressSubmissions']);
      } else {
        _error = PortalApi.msg(b, "Couldn't load her progress.");
      }
    });
  }

  static String _cm(dynamic v) => '${dtNum(v)!.toStringAsFixed(1)} cm';

  Widget _card(Map<String, dynamic> s) {
    final notes = '${s['strengthNotes'] ?? ''}'.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: PT.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatusChip('Day ${s['cycle'] ?? '?'}'),
          const Spacer(),
          Text(dtDate(s['submittedAt']), style: PT.t(11.5, c: PT.sage)),
        ]),
        const SizedBox(height: 8),
        if (dtNum(s['weightKg']) != null) dtField('Weight', '${dtNum(s['weightKg'])!.toStringAsFixed(1)} kg'),
        if (dtNum(s['waistCm']) != null) dtField('Waist', _cm(s['waistCm'])),
        if (dtNum(s['hipsCm']) != null) dtField('Hips', _cm(s['hipsCm'])),
        if (dtNum(s['chestCm']) != null) dtField('Chest', _cm(s['chestCm'])),
        if (dtNum(s['armsCm']) != null) dtField('Arms', _cm(s['armsCm'])),
        if (dtNum(s['thighsCm']) != null) dtField('Thighs', _cm(s['thighsCm'])),
        if (s['clothesFit'] != null) dtField('Clothes', dtHuman(s['clothesFit'])),
        if (s['sleepQuality'] != null) dtField('Sleep', '${s['sleepQuality']}/5'),
        if (s['satisfaction'] != null) dtField('Satisfaction', '${s['satisfaction']}/5'),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('STRENGTH NOTES', style: PT.t(10.5, w: FontWeight.w700, c: PT.sage)),
          const SizedBox(height: 3),
          SelectableText(notes, style: PT.t(13, h: 1.4)),
        ],
      ]),
    );
  }

  Widget _trend() {
    // Oldest and newest weigh-ins (list comes newest first).
    final withWeight = _items.where((s) => dtNum(s['weightKg']) != null).toList();
    if (withWeight.length < 2) return const SizedBox.shrink();
    final newest = dtNum(withWeight.first['weightKg'])!;
    final oldest = dtNum(withWeight.last['weightKg'])!;
    final diff = newest - oldest;
    final txt = diff.abs() < 0.05
        ? 'Weight unchanged since her first check-in'
        : 'Weight ${diff < 0 ? 'down' : 'up'} ${diff.abs().toStringAsFixed(1)} kg since her first check-in';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(12), border: Border.all(color: PT.line)),
      child: Row(children: [
        Icon(diff < 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded, color: PT.green, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text('$txt (${oldest.toStringAsFixed(1)} → ${newest.toStringAsFixed(1)} kg).', style: PT.t(13))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => dtCard(
        title: 'Progress check-ins',
        sub: 'Day 15 and Day 30 measurements. Progress photos stay on her phone and are never uploaded.',
        actions: [dtRefresh(_loading ? null : _load)],
        child: _loading
            ? dtLoading()
            : _error != null
                ? dtMessage(_error!, retry: _load)
                : _items.isEmpty
                    ? dtMessage('No progress check-ins yet.')
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _trend(),
                        LayoutBuilder(builder: (c, box) {
                          final cols = box.maxWidth >= 640 ? 2 : 1;
                          final cw = (box.maxWidth - (cols - 1) * 10) / cols;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _items.map((s) => SizedBox(width: cw, child: _card(s))).toList(),
                          );
                        }),
                      ]),
      );
}

// ── Diet plans (history, view, edit meals, activate / cancel) ────────────

const _kMealTypes = [
  ['breakfast', 'Breakfast'],
  ['mid_morning', 'Mid-morning'],
  ['lunch', 'Lunch'],
  ['afternoon_snack', 'Afternoon snack'],
  ['evening_snack', 'Evening snack'],
  ['dinner', 'Dinner'],
];

String _mealLabel(dynamic wire) {
  for (final m in _kMealTypes) {
    if (m[0] == '$wire') return m[1];
  }
  return dtHuman(wire);
}

class _PlansTab extends StatefulWidget {
  const _PlansTab({required this.userId, required this.name, this.onGenerate});
  final int userId;
  final String name;
  final VoidCallback? onGenerate;

  @override
  State<_PlansTab> createState() => _PlansTabState();
}

class _PlansTabState extends State<_PlansTab> {
  static const _filters = [
    [null, 'All'],
    ['draft', 'Drafts'],
    ['active', 'Active'],
    ['completed', 'Completed'],
    ['cancelled', 'Cancelled'],
  ];

  String? _status;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _plans = [];
  final Set<int> _open = {};
  final Set<int> _busy = {};

  String get _first {
    final f = widget.name.trim().split(' ').first;
    return f.isEmpty ? 'this client' : f;
  }

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
    final b = await PortalApi.get('/admin/diet-plan/user/${widget.userId}/list',
        query: _status == null ? null : {'status': _status!});
    if (!mounted) return;
    final d = b['data'];
    setState(() {
      _loading = false;
      if (PortalApi.ok(b) && d is Map) {
        _plans = dtMaps(d['plans']);
      } else {
        _plans = [];
        _error = PortalApi.msg(b, "Couldn't load her plans.");
      }
    });
  }

  List<Map<String, dynamic>> _days(Map<String, dynamic> p) {
    final days = dtMaps(p['DietPlanDays'] ?? p['days']);
    days.sort((a, b) => (dtInt(a['dayNumber']) ?? 0).compareTo(dtInt(b['dayNumber']) ?? 0));
    return days;
  }

  List<Map<String, dynamic>> _meals(Map<String, dynamic> day) {
    final meals = dtMaps(day['DietPlanMeals'] ?? day['meals']);
    meals.sort((a, b) => '${a['time'] ?? ''}'.compareTo('${b['time'] ?? ''}'));
    return meals;
  }

  Future<void> _activate(Map<String, dynamic> p) async {
    final id = dtInt(p['id']) ?? 0;
    final sure = await portalConfirm(context,
        title: 'Send this plan to $_first?',
        body: 'The plan becomes active and she will see it in her app straight away.',
        yes: 'Activate plan');
    if (!sure) return;
    setState(() => _busy.add(id));
    final b = await PortalApi.post('/admin/diet-plan/$id/activate', {});
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (PortalApi.ok(b)) {
      portalToast('Plan activated', sub: 'Your client will see it now.');
      _load();
    } else {
      portalToast("Couldn't activate the plan", sub: PortalApi.msg(b), error: true);
    }
  }

  Future<void> _cancel(Map<String, dynamic> p) async {
    final id = dtInt(p['id']) ?? 0;
    final reason = TextEditingController();
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Cancel this plan?', style: PT.t(17, w: FontWeight.w700)),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("She won't be able to use this plan. You can leave a reason for the record (optional).",
                style: PT.t(13.5, h: 1.45)),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('dt_cancel_reason'),
              controller: reason,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Reason (optional)', counterText: ''),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Keep plan', style: PT.t(13.5, c: PT.sage))),
          OutlinedButton(style: portalDanger(), onPressed: () => Navigator.pop(c, true), child: const Text('Cancel plan')),
        ],
      ),
    );
    final why = reason.text.trim();
    if (sure != true || !mounted) return;
    setState(() => _busy.add(id));
    final b = await PortalApi.post('/admin/diet-plan/$id/cancel', why.isEmpty ? {} : {'reason': why});
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (PortalApi.ok(b)) {
      portalToast('Plan cancelled');
      _load();
    } else {
      portalToast("Couldn't cancel the plan", sub: PortalApi.msg(b), error: true);
    }
  }

  Future<void> _editMeal(Map<String, dynamic> meal) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _MealDialog(meal: meal));
    if (saved == true && mounted) _load();
  }

  Widget _statusPill(String s) {
    switch (s) {
      case 'draft':
        return const StatusChip('DRAFT', color: PT.sage);
      case 'active':
        return const StatusChip('ACTIVE');
      case 'completed':
        return const StatusChip('COMPLETED', color: PT.greenDark);
      case 'cancelled':
        return const StatusChip('CANCELLED', color: PT.red);
      default:
        return StatusChip(s.toUpperCase(), color: PT.sage);
    }
  }

  Widget _chip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(10), border: Border.all(color: PT.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: PT.green),
          const SizedBox(width: 4),
          Text(text, style: PT.t(11.5, w: FontWeight.w600)),
        ]),
      );

  Widget _planCard(Map<String, dynamic> p) {
    final id = dtInt(p['id']) ?? 0;
    final status = '${p['status'] ?? ''}';
    final closed = status == 'completed' || status == 'cancelled';
    final days = _days(p);
    final totals = days.map((d) => dtInt(d['totalCalories']) ?? 0).where((t) => t > 0).toList();
    final avg = totals.isEmpty ? null : (totals.reduce((a, b) => a + b) / totals.length).round();
    final summary = '${p['summary'] ?? ''}'.trim();
    final open = _open.contains(id);
    final busy = _busy.contains(id);
    final when = status == 'active' && p['activatedAt'] != null
        ? 'Activated ${dtDate(p['activatedAt'])}'
        : status == 'cancelled' && p['cancelledAt'] != null
            ? 'Cancelled ${dtDate(p['cancelledAt'])}'
            : status == 'completed' && p['completedAt'] != null
                ? 'Completed ${dtDate(p['completedAt'])}'
                : 'Created ${portalAgo(p['createdAt'])}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: status == 'active' ? PT.green : PT.line, width: status == 'active' ? 1.4 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _statusPill(status),
          const SizedBox(width: 8),
          Expanded(child: Text(when, style: PT.t(11.5, c: PT.sage), overflow: TextOverflow.ellipsis)),
          Text('#$id', style: PT.t(11, c: PT.sage)),
        ]),
        const SizedBox(height: 8),
        Text(summary.isEmpty ? 'AI-generated personalized plan' : summary, style: PT.t(13, h: 1.45)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _chip(Icons.calendar_month_outlined, '${dtInt(p['planDays']) ?? days.length} days'),
          _chip(Icons.restaurant_outlined, '${dtInt(p['mealsPerDay']) ?? 0} meals/day'),
          if (avg != null) _chip(Icons.local_fire_department_outlined, '$avg kcal/day'),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          TextButton.icon(
            onPressed: days.isEmpty ? null : () => setState(() => open ? _open.remove(id) : _open.add(id)),
            icon: Icon(open ? Icons.expand_less : Icons.expand_more, size: 18),
            label: Text(days.isEmpty ? 'No meals in this plan' : (open ? 'Hide meals' : 'Show meals')),
          ),
          if (busy)
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
          else ...[
            if (status == 'draft')
              ElevatedButton.icon(
                style: portalPrimary(),
                onPressed: () => _activate(p),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Activate plan'),
              ),
            if (status == 'draft' || status == 'active')
              OutlinedButton(style: portalDanger(), onPressed: () => _cancel(p), child: const Text('Cancel plan')),
          ],
        ]),
        if (open) ...[
          const SizedBox(height: 6),
          if (closed)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.lock_outline, size: 16, color: PT.sage),
                const SizedBox(width: 8),
                Expanded(child: Text('This plan is $status and cannot be edited.', style: PT.t(12.5, c: PT.sage))),
              ]),
            ),
          for (final d in days) _dayBlock(d, closed),
        ],
      ]),
    );
  }

  Widget _dayBlock(Map<String, dynamic> d, bool closed) {
    final meals = _meals(d);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: PT.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: PT.wash,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Expanded(child: Text('Day ${d['dayNumber'] ?? '?'}', style: PT.t(13, w: FontWeight.w700))),
            Text('${dtInt(d['totalCalories']) ?? 0} kcal', style: PT.t(12, c: PT.sage)),
          ]),
        ),
        for (final m in meals)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: PT.line))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 52, child: Text('${m['time'] ?? ''}', style: PT.t(12.5, w: FontWeight.w600))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_mealLabel(m['mealType']).toUpperCase(), style: PT.t(10.5, w: FontWeight.w700, c: PT.sage)),
                  Text('${m['foodName'] ?? ''}', style: PT.t(13, h: 1.35)),
                  if ('${m['notes'] ?? ''}'.trim().isNotEmpty)
                    Text('↳ ${'${m['notes']}'.trim()}', style: PT.t(11.5, c: PT.sage, h: 1.35)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 8),
                child: Text('${dtInt(m['calories']) ?? 0} kcal', style: PT.t(12, c: PT.sage)),
              ),
              if (!closed && m['id'] != null)
                IconButton(
                  tooltip: 'Edit meal',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _editMeal(m),
                  icon: const Icon(Icons.edit_outlined, size: 17, color: PT.green),
                )
              else
                const SizedBox(width: 8),
            ]),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => dtCard(
        title: "$_first's plans",
        sub: 'Every diet plan made for her. Open one to see the meals; drafts and active plans can be edited.',
        actions: [dtRefresh(_loading ? null : _load)],
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in _filters)
              ChoiceChip(
                label: Text('${f[1]}'),
                selected: _status == f[0],
                onSelected: (_) {
                  setState(() => _status = f[0]);
                  _load();
                },
              ),
          ]),
          const SizedBox(height: 12),
          if (_loading)
            dtLoading()
          else if (_error != null)
            dtMessage(_error!, retry: _load)
          else if (_plans.isEmpty)
            Column(children: [
              dtMessage(_status == null
                  ? 'No plans yet for $_first. Generate her first plan from here.'
                  : 'No ${_filters.firstWhere((f) => f[0] == _status)[1]!.toLowerCase()} plans for $_first.'),
              if (_status == null && widget.onGenerate != null)
                ElevatedButton.icon(
                  style: portalPrimary(),
                  onPressed: widget.onGenerate,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Generate plan'),
                ),
            ])
          else
            ..._plans.map(_planCard),
        ]),
      );
}

/// Edit one meal. Only changed fields are sent.
class _MealDialog extends StatefulWidget {
  const _MealDialog({required this.meal});
  final Map<String, dynamic> meal;

  @override
  State<_MealDialog> createState() => _MealDialogState();
}

class _MealDialogState extends State<_MealDialog> {
  static final _hhmm = RegExp(r'^\d{2}:\d{2}$');
  final _form = GlobalKey<FormState>();
  late final TextEditingController _food;
  late final TextEditingController _cal;
  late final TextEditingController _time;
  late final TextEditingController _notes;
  late String _type;
  bool _saving = false;

  Map<String, dynamic> get _m => widget.meal;

  @override
  void initState() {
    super.initState();
    _food = TextEditingController(text: '${_m['foodName'] ?? ''}');
    _cal = TextEditingController(text: '${dtInt(_m['calories']) ?? 0}');
    _time = TextEditingController(text: '${_m['time'] ?? ''}');
    _notes = TextEditingController(text: '${_m['notes'] ?? ''}');
    final t = '${_m['mealType'] ?? ''}';
    _type = _kMealTypes.any((e) => e[0] == t) ? t : 'breakfast';
  }

  @override
  void dispose() {
    _food.dispose();
    _cal.dispose();
    _time.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final body = <String, dynamic>{};
    final food = _food.text.trim();
    if (food != '${_m['foodName'] ?? ''}') body['foodName'] = food;
    final cal = int.tryParse(_cal.text.trim());
    if (cal != null && cal != dtInt(_m['calories'])) body['calories'] = cal;
    final time = _time.text.trim();
    if (time != '${_m['time'] ?? ''}') body['time'] = time;
    final notes = _notes.text.trim();
    if (notes != '${_m['notes'] ?? ''}'.trim()) body['notes'] = notes;
    if (_type != '${_m['mealType'] ?? ''}') body['mealType'] = _type;
    if (body.isEmpty) {
      Navigator.pop(context, false);
      return;
    }
    setState(() => _saving = true);
    final b = await dtPatch('/admin/diet-plan/meal/${_m['id']}', body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (PortalApi.ok(b)) {
      portalToast('Meal updated');
      Navigator.pop(context, true);
    } else {
      portalToast("Couldn't save the meal", sub: PortalApi.msg(b), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Edit meal', style: PT.t(17, w: FontWeight.w700)),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Meal'),
              items: [for (final t in _kMealTypes) DropdownMenuItem(value: t[0], child: Text(t[1]))],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('dt_meal_food'),
              controller: _food,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Food'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextFormField(
                  key: const ValueKey('dt_meal_cal'),
                  controller: _cal,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Calories'),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    return (n == null || n <= 0) ? 'A number above 0' : null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const ValueKey('dt_meal_time'),
                  controller: _time,
                  decoration: const InputDecoration(labelText: 'Time (HH:MM)', hintText: '08:30'),
                  validator: (v) => (v == null || !_hhmm.hasMatch(v.trim())) ? 'Use HH:MM, e.g. 08:30' : null,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('dt_meal_notes'),
              controller: _notes,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: Text('Cancel', style: PT.t(13.5, c: PT.sage))),
        ElevatedButton(
          style: portalPrimary(),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}
