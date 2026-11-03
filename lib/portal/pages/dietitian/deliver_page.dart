import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_session.dart';
import '../../portal_theme.dart';
import '../../shell/portal_nav.dart';
import '../../widgets/portal_ui.dart';
import 'generate_page.dart';
import 'plan_editor.dart';
import 'client_detail.dart';

/// Optional hook for "Review form": the shell / clients page can set this to
/// open the client's consultation form. Gets the client row from
/// /dietTimes/getClients. When not set, the page sends her to Clients.
void Function(Map<String, dynamic> client)? deliverOpenForm;

/// Every client who has had her consultation but hasn't got her plan yet,
/// most urgent first (app: PlansToDeliverScreen). Steps: 1 review form,
/// 2 generate AI plan, 3 review and deliver. Due 48 h after the consultation.
class DietDeliverPage extends StatefulWidget {
  const DietDeliverPage({super.key});

  @override
  State<DietDeliverPage> createState() => _DietDeliverPageState();
}

class _DietDeliverPageState extends State<DietDeliverPage> {
  List<Map<String, dynamic>>? _owed;
  bool _loading = true;
  String? _error;

  int? _openPlanId;
  String? _openName;

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
    final me = Get.find<PortalSession>().userId ?? 0;
    final b = await PortalApi.get('${Constants.getClients}/$me');
    if (!mounted) return;
    final ok = PortalApi.ok(b);
    // "No Plan assigned to you yet" = she has no clients at all.
    final none = !ok && PortalApi.msg(b).toLowerCase().contains('no plan assigned');
    if (ok || none) {
      final list = ok
          ? dpList(dpMap(b['data'])['cliets']).where((c) => dpMap(c['planPipeline'])['owed'] == true).toList()
          : <Map<String, dynamic>>[];
      list.sort((a, b) => (dpInt(dpMap(a['planPipeline'])['hoursLeft']) ?? 0)
          .compareTo(dpInt(dpMap(b['planPipeline'])['hoursLeft']) ?? 0));
      setState(() {
        _owed = list;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _error = PortalApi.msg(b, 'Could not load your clients. Please try again.');
      });
      if (_owed != null) portalToast("Couldn't refresh", sub: _error, error: true);
    }
  }

  static String _fmtHours(int h) {
    if (h < 1) return 'under 1h';
    if (h < 24) return '${h}h';
    final d = h ~/ 24;
    final r = h % 24;
    return r == 0 ? '${d}d' : '${d}d ${r}h';
  }

  void _toGenerate(Map<String, dynamic> c) {
    generateForClient.value = Map<String, dynamic>.from(c);
    portalGo('d_generate');
  }

  void _toForm(Map<String, dynamic> c, String name) {
    final hook = deliverOpenForm;
    if (hook != null) {
      hook(c);
      return;
    }
    // Nov 2026: open HER health form right here (it used to send the
    // dietitian to the Clients list to find her).
    final u = dpMap(c['User']);
    final uid = dpInt(u['id']);
    if (uid == null) {
      portalToast('Client details missing', error: true);
      return;
    }
    showClientPanelDialog(
      context,
      userId: uid,
      name: name,
      title: '$name · health form',
      email: u['email']?.toString(),
      phone: u['phone']?.toString(),
      client: c,
      userPlanId: dpInt(c['id']),
      initialTab: 1,
    ).then((_) {
      if (mounted) _load(); // "form reviewed" may have changed
    });
  }

  Widget _step(String n, String label, bool done) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? PT.green : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: done ? PT.green : PT.line, width: 1.5),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : Text(n, style: PT.t(11.5, w: FontWeight.w700, c: PT.sage)),
        ),
        const SizedBox(height: 4),
        Text(label, style: PT.t(11, w: FontWeight.w600, c: done ? PT.ink : PT.sage)),
      ]);

  Widget _line(bool done) => Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
          color: done ? PT.green : PT.line,
        ),
      );

  Widget _card(Map<String, dynamic> c) {
    final p = dpMap(c['planPipeline']);
    final name = dpUserName(c['User']);
    final draftId = dpInt(p['draftPlanId']);
    final hasDraft = draftId != null;
    final overdue = p['overdue'] == true;
    final hoursLeft = dpInt(p['hoursLeft']) ?? 0;
    final formReviewed = p['formReviewed'] == true;
    final hasForm = p['hasForm'] == true;

    final Color timeColor = overdue ? PT.red : (hoursLeft <= 12 ? PT.amber : PT.green);
    final String timeLabel = overdue ? 'Overdue by ${_fmtHours(-hoursLeft)}' : 'Due in ${_fmtHours(hoursLeft)}';

    late final String cta;
    late final VoidCallback onCta;
    if (hasDraft) {
      cta = 'Review and deliver';
      onCta = () => setState(() {
            _openPlanId = draftId;
            _openName = name;
          });
    } else if (!formReviewed) {
      cta = 'Review form';
      onCta = () => _toForm(c, name);
    } else {
      cta = 'Generate AI plan';
      onCta = () => _toGenerate(c);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: overdue ? PT.red.withValues(alpha: 0.35) : PT.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: Text(name, style: PT.t(15, w: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          StatusChip(timeLabel, color: timeColor),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _step('1', 'Form', formReviewed),
          _line(formReviewed),
          _step('2', 'AI plan', hasDraft),
          _line(hasDraft),
          _step('3', 'Deliver', false),
        ]),
        if (!hasForm) ...[
          const SizedBox(height: 10),
          Text("She hasn't filled her form. Fill it with her before generating.",
              style: PT.t(12, c: PT.amber, h: 1.4)),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              style: portalPrimary().copyWith(
                backgroundColor: WidgetStatePropertyAll(overdue ? PT.red : PT.green),
              ),
              onPressed: onCta,
              child: Text(cta, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          // Skip straight to generating if the form was fine as it is.
          if (!hasDraft && !formReviewed) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _toGenerate(c),
              child: Text('Skip to plan', style: PT.t(12.5, w: FontWeight.w600)),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _body() {
    if (_loading && _owed == null) return const Center(child: CircularProgressIndicator(color: PT.green));
    if (_owed == null) {
      return PortalEmpty(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load your clients",
        sub: _error,
        action: ElevatedButton(style: portalPrimary(), onPressed: _load, child: const Text('Try again')),
      );
    }
    final owed = _owed!;
    if (owed.isEmpty) {
      return const PortalEmpty(
        icon: Icons.task_alt_rounded,
        title: "You're all caught up",
        sub: 'No plans owed right now.',
      );
    }
    return LayoutBuilder(builder: (context, box) {
      const gap = 14.0;
      final int cols = (box.maxWidth / 380).floor().clamp(1, 3).toInt();
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return SingleChildScrollView(
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: owed.map((c) => SizedBox(width: w, child: _card(c))).toList(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_openPlanId != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader(
          title: 'Review and deliver',
          sub: 'Check each day, tap a meal to change it, then activate the plan to send it to her.',
        ),
        Expanded(
          child: DietPlanEditor(
            key: ValueKey('dp_deliver_$_openPlanId'),
            planId: _openPlanId!,
            clientName: _openName,
            backLabel: 'Back to plans to deliver',
            onBack: () {
              setState(() => _openPlanId = null);
              _load();
            },
            onChanged: () {
              setState(() => _openPlanId = null);
              _load();
            },
          ),
        ),
      ]);
    }
    final n = _owed?.length ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Plans to deliver',
        sub: 'Clients who had their consultation and are waiting for their plan, most urgent first. '
            "Every plan is due within 2 working days of the consultation (weekends don't count).",
        actions: [
          if (n > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 4),
              child: StatusChip('$n owed', color: PT.amber),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: PT.green))
                : const Icon(Icons.refresh_rounded, color: PT.sage),
          ),
        ],
      ),
      Expanded(child: _body()),
    ]);
  }
}
