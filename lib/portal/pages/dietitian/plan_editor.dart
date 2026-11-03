import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/api_provider/api_provider.dart';
import '../../portal_api.dart';
import '../../portal_session.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';
import 'client_detail.dart';

// ─── Small shared helpers for the dietitian plan pages ───────────────────

int? dpInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

Map<String, dynamic> dpMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> dpList(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

String dpUserName(dynamic user, [String fallback = 'Client']) {
  final u = dpMap(user);
  final n = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
  return n.isEmpty ? fallback : n;
}

String dpKcal(dynamic n) => NumberFormat.decimalPattern().format(dpInt(n) ?? 0);

/// For calls PortalApi doesn't cover (PATCH, long timeouts). Never throws.
Future<Map<String, dynamic>> dpSend(Future<dynamic> Function(ApiProvider api, Map<String, String> h) fn) async {
  try {
    final r = await fn(Get.find<ApiProvider>(), Get.find<PortalSession>().headers);
    final b = r.body;
    if (b is Map) return Map<String, dynamic>.from(b);
  } catch (_) {}
  return {'status': '0', 'message': "Couldn't reach the server."};
}

/// Meal types the server accepts (wire value → label).
const Map<String, String> dpMealTypes = {
  'breakfast': 'Breakfast',
  'mid_morning': 'Mid-morning',
  'lunch': 'Lunch',
  'afternoon_snack': 'Afternoon snack',
  'evening_snack': 'Evening snack',
  'dinner': 'Dinner',
};

String dpMealLabel(dynamic t) => dpMealTypes['${t ?? ''}'] ?? '${t ?? ''}';

/// Average calories per day over days that have a total.
int dpAvgKcal(Map<String, dynamic> plan) {
  final totals = dpList(plan['DietPlanDays'] ?? plan['days'])
      .map((d) => dpInt(d['totalCalories']) ?? 0)
      .where((c) => c > 0)
      .toList();
  if (totals.isEmpty) return 0;
  return (totals.reduce((a, b) => a + b) / totals.length).round();
}

Widget dpStatusChip(dynamic status) {
  switch ('${status ?? ''}') {
    case 'active':
      return const StatusChip('Active');
    case 'completed':
      return const StatusChip('Completed', color: PT.sage);
    case 'cancelled':
      return const StatusChip('Cancelled', color: PT.red);
    default:
      return const StatusChip('Draft', color: PT.amber);
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: PT.wash,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PT.line),
        ),
        child: Text(text, style: PT.t(12, w: FontWeight.w600)),
      );
}

/// Review one AI diet plan: see every day and meal, edit a meal,
/// activate (send to the client) or cancel. Same as the app's
/// PlanReviewEditScreen. Needs a bounded height.
class DietPlanEditor extends StatefulWidget {
  const DietPlanEditor({
    super.key,
    required this.planId,
    this.clientName,
    this.onBack,
    this.backLabel = 'Back',
    this.onChanged,
  });

  final int planId;
  final String? clientName;
  final VoidCallback? onBack;
  final String backLabel;

  /// Called after the plan was activated or cancelled, so lists can refresh.
  final VoidCallback? onChanged;

  @override
  State<DietPlanEditor> createState() => _DietPlanEditorState();
}

class _DietPlanEditorState extends State<DietPlanEditor> {
  Map<String, dynamic>? _plan;
  List<Map<String, dynamic>> _days = [];
  bool _loading = true;
  String? _error;
  int _dayIdx = 0;
  int? _savingMeal;
  bool _activating = false;
  bool _cancelling = false;
  // Nov 2026: whole-plan view, her health form beside the plan.
  bool _weekView = false;
  Map<String, dynamic>? _health;
  bool _healthMissing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DietPlanEditor old) {
    super.didUpdateWidget(old);
    if (old.planId != widget.planId) {
      _plan = null;
      _days = [];
      _dayIdx = 0;
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  static List<Map<String, dynamic>> _meals(Map<String, dynamic> day) =>
      day['meals'] is List<Map<String, dynamic>> ? day['meals'] as List<Map<String, dynamic>> : <Map<String, dynamic>>[];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final id = widget.planId;
    final b = await PortalApi.get('/admin/diet-plan/$id');
    if (!mounted || id != widget.planId) return;
    final p = dpMap(dpMap(b['data'])['dietPlan']);
    if (PortalApi.ok(b) && p.isNotEmpty) {
      final days = dpList(p['DietPlanDays'] ?? p['days']);
      days.sort((a, b) => (dpInt(a['dayNumber']) ?? 0).compareTo(dpInt(b['dayNumber']) ?? 0));
      for (final d in days) {
        d['meals'] = dpList(d['DietPlanMeals'] ?? d['meals']);
      }
      setState(() {
        _plan = p;
        _days = days;
        _loading = false;
        if (_dayIdx >= days.length) _dayIdx = 0;
      });
      _loadHealth(dpInt(p['userId']));
    } else {
      setState(() {
        _loading = false;
        _error = PortalApi.msg(b, "Couldn't load this plan.");
      });
      if (_plan != null) portalToast("Couldn't refresh the plan", sub: _error, error: true);
    }
  }

  String get _status => '${_plan?['status'] ?? 'draft'}';
  bool get _closed => _status == 'completed' || _status == 'cancelled';

  String get _who {
    final n = (widget.clientName ?? '').trim();
    if (n.isNotEmpty) return n;
    return dpUserName(_plan?['User'], 'Your client');
  }

  // ─── Meal editing ─────────────────────────────────────────────────────

  Future<void> _edit(Map<String, dynamic> meal) async {
    final id = dpInt(meal['id']);
    if (id == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _MealDialog(
        meal: meal,
        onSave: (changes) => _saveMeal(id, changes),
        onDelete: () => _deleteMeal(meal),
        onCopy: _days.length > 1 ? () => _copyMeal(meal) : null,
      ),
    );
  }

  Future<bool> _saveMeal(int mealId, Map<String, dynamic> changes) async {
    setState(() => _savingMeal = mealId);
    final b = await dpSend((api, h) => api.patchData('/admin/diet-plan/meal/$mealId', body: changes, headers: h));
    if (!mounted) return false;
    setState(() => _savingMeal = null);
    if (!PortalApi.ok(b)) {
      portalToast("Couldn't save the meal", sub: PortalApi.msg(b), error: true);
      return false;
    }
    final data = dpMap(b['data']);
    final newMeal = dpMap(data['meal']);
    final newDay = dpMap(data['day']);
    setState(() {
      for (final d in _days) {
        final meals = _meals(d);
        final i = meals.indexWhere((x) => dpInt(x['id']) == mealId);
        if (i < 0) continue;
        meals[i] = newMeal.isEmpty ? {...meals[i], ...changes} : newMeal;
        meals.sort((a, b) => '${a['time'] ?? ''}'.compareTo('${b['time'] ?? ''}'));
        if (newDay['totalCalories'] != null) d['totalCalories'] = newDay['totalCalories'];
      }
    });
    portalToast('Meal saved');
    return true;
  }

  // ─── Nov 2026: health form, add / remove / copy a meal, note ─────────

  Future<void> _loadHealth(int? userId) async {
    if (userId == null || _health != null) return;
    final b = await PortalApi.get('/admin/pre-consultation/$userId');
    if (!mounted) return;
    final d = b['data'];
    setState(() {
      if (PortalApi.ok(b) && d is Map && d['profile'] is Map) {
        _health = Map<String, dynamic>.from(d['profile'] as Map);
      } else {
        _healthMissing = true;
      }
    });
  }

  void _openHealthForm() {
    final uid = dpInt(_plan?['userId']);
    if (uid == null) return;
    showClientPanelDialog(context, userId: uid, name: _who, title: '$_who · health form', initialTab: 1);
  }

  Future<void> _addMeal(Map<String, dynamic> day) async {
    final dayId = dpInt(day['id']);
    if (dayId == null) return;
    final used = _meals(day).map((m) => '${m['mealType']}').toSet();
    final free = dpMealTypes.keys.firstWhere((k) => !used.contains(k), orElse: () => '');
    if (free.isEmpty) {
      portalToast('This day already has every meal', sub: 'Edit one of them instead.', error: true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _MealDialog(
        meal: {'mealType': free, 'time': '', 'foodName': '', 'calories': ''},
        isNew: true,
        onSave: (fields) async {
          final b = await PortalApi.post('/admin/diet-plan/day/$dayId/meal', fields);
          if (!mounted) return false;
          if (!PortalApi.ok(b)) {
            portalToast("Couldn't add the meal", sub: PortalApi.msg(b), error: true);
            return false;
          }
          portalToast('Meal added');
          await _load();
          return true;
        },
      ),
    );
  }

  Future<bool> _deleteMeal(Map<String, dynamic> meal) async {
    final id = dpInt(meal['id']);
    if (id == null) return false;
    final sure = await portalConfirm(
      context,
      title: 'Remove this meal?',
      body: '"${meal['foodName'] ?? ''}" will be taken out of this day.',
      yes: 'Remove meal',
      danger: true,
    );
    if (!sure || !mounted) return false;
    final b = await dpSend((api, h) => api.deleteData('/admin/diet-plan/meal/$id', headers: h));
    if (!mounted) return false;
    if (!PortalApi.ok(b)) {
      portalToast("Couldn't remove the meal", sub: PortalApi.msg(b), error: true);
      return false;
    }
    portalToast('Meal removed');
    await _load();
    return true;
  }

  Future<bool> _copyMeal(Map<String, dynamic> meal) async {
    final id = dpInt(meal['id']);
    if (id == null) return false;
    final fromDay = _days.firstWhere((d) => _meals(d).any((m) => dpInt(m['id']) == id), orElse: () => const {});
    final others = _days.where((d) => dpInt(d['id']) != dpInt(fromDay['id'])).toList();
    if (others.isEmpty) {
      portalToast('There are no other days to copy to', error: true);
      return false;
    }
    final picked = <int>{};
    final label = dpMealLabel(meal['mealType']).toLowerCase();
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Copy this meal to other days', style: PT.t(17, w: FontWeight.w700)),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('"${meal['foodName']}" replaces the $label on the days you pick.',
                  style: PT.t(12.5, c: PT.sage, h: 1.45)),
              const SizedBox(height: 10),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: picked.length == others.length,
                title: Text('All other days', style: PT.t(13.5, w: FontWeight.w600)),
                onChanged: (v) => set(() {
                  picked.clear();
                  if (v == true) picked.addAll(others.map((d) => dpInt(d['id'])!).toList());
                }),
              ),
              const Divider(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(children: [
                    for (final d in others)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: picked.contains(dpInt(d['id'])),
                        title: Text('Day ${dpInt(d['dayNumber']) ?? ''}', style: PT.t(13.5)),
                        onChanged: (v) => set(() {
                          final did = dpInt(d['id'])!;
                          v == true ? picked.add(did) : picked.remove(did);
                        }),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel', style: PT.t(13.5, c: PT.sage))),
            ElevatedButton(
              style: portalPrimary(),
              onPressed: picked.isEmpty ? null : () => Navigator.pop(c, true),
              child: Text(picked.isEmpty ? 'Copy' : 'Copy to ${picked.length} day${picked.length == 1 ? '' : 's'}'),
            ),
          ],
        ),
      ),
    );
    if (go != true || !mounted) return false;
    final all = picked.length == others.length;
    final b = await PortalApi.post('/admin/diet-plan/meal/$id/copy',
        all ? {'allDays': true} : {'dayIds': picked.toList()});
    if (!mounted) return false;
    if (!PortalApi.ok(b)) {
      portalToast("Couldn't copy the meal", sub: PortalApi.msg(b), error: true);
      return false;
    }
    portalToast('Meal copied', sub: 'Copied to ${dpInt(dpMap(b['data'])['copiedTo']) ?? picked.length} day(s).');
    await _load();
    return true;
  }

  Future<void> _editNote() async {
    final ctrl = TextEditingController(text: '${_plan?['clientNote'] ?? ''}');
    final text = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Note for $_who', style: PT.t(17, w: FontWeight.w700)),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('She sees this at the top of her plan in the app.', style: PT.t(12.5, c: PT.sage)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 5,
              maxLength: 2000,
              style: PT.t(13.5),
              decoration: const InputDecoration(hintText: 'e.g. Drink 2 litres of water a day and keep fried food to once a week.'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancel', style: PT.t(13.5, c: PT.sage))),
          ElevatedButton(style: portalPrimary(), onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Save note')),
        ],
      ),
    );
    if (text == null || !mounted) return;
    final b = await dpSend((api, h) => api.patchData('/admin/diet-plan/${widget.planId}/note', body: {'clientNote': text}, headers: h));
    if (!mounted) return;
    if (!PortalApi.ok(b)) {
      portalToast("Couldn't save the note", sub: PortalApi.msg(b), error: true);
      return;
    }
    setState(() => _plan = {...?_plan, 'clientNote': text.isEmpty ? null : text});
    portalToast('Note saved');
  }

  // ─── Activate / cancel ────────────────────────────────────────────────

  Future<void> _activate() async {
    final sure = await portalConfirm(
      context,
      title: 'Activate this plan?',
      body: '$_who will see this plan in her app straight away.',
      yes: 'Activate plan',
    );
    if (!sure || !mounted) return;
    setState(() => _activating = true);
    final b = await PortalApi.post('/admin/diet-plan/${widget.planId}/activate', {});
    if (!mounted) return;
    setState(() => _activating = false);
    if (PortalApi.ok(b)) {
      portalToast('Plan activated', sub: 'Your client will see it now.');
      widget.onChanged?.call();
      if (mounted) _load();
    } else {
      portalToast("Couldn't activate the plan", sub: PortalApi.msg(b), error: true);
    }
  }

  Future<void> _cancel() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Cancel this plan?', style: PT.t(17, w: FontWeight.w700)),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              "She won't be able to use this plan. You can leave a reason for the record (optional).",
              style: PT.t(13, c: PT.sage, h: 1.45),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('dp_cancel_reason'),
              controller: reasonCtrl,
              maxLength: 500,
              maxLines: 3,
              style: PT.t(13.5),
              decoration: const InputDecoration(hintText: 'Reason (optional)', counterText: ''),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Keep plan', style: PT.t(13.5, c: PT.sage))),
          OutlinedButton(
            style: portalDanger(),
            onPressed: () => Navigator.pop(c, reasonCtrl.text.trim()),
            child: const Text('Cancel plan'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => _cancelling = true);
    final b = await PortalApi.post(
      '/admin/diet-plan/${widget.planId}/cancel',
      reason.isEmpty ? <String, dynamic>{} : <String, dynamic>{'reason': reason},
    );
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (PortalApi.ok(b)) {
      portalToast('Plan cancelled', sub: 'The plan has been cancelled.');
      widget.onChanged?.call();
      if (mounted) _load();
    } else {
      portalToast("Couldn't cancel the plan", sub: PortalApi.msg(b), error: true);
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────

  Widget _head(Map<String, dynamic> p) {
    final n = _who;
    final title = (n == 'Your client') ? 'Plan review' : "$n's plan";
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(children: [
        if (widget.onBack != null)
          IconButton(
            tooltip: widget.backLabel,
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: PT.ink),
          )
        else
          const SizedBox(width: 8),
        const SizedBox(width: 4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: PT.t(17, w: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('Plan #${widget.planId}', style: PT.t(12, c: PT.sage)),
          ]),
        ),
        dpStatusChip(p['status']),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : _load,
          icon: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: PT.green))
              : const Icon(Icons.refresh_rounded, color: PT.sage),
        ),
      ]),
    );
  }

  Widget _summary(Map<String, dynamic> p) {
    final summary = '${p['summary'] ?? ''}'.trim();
    final avg = dpAvgKcal({'days': _days});
    final made = portalAgo(p['createdAt']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(14), border: Border.all(color: PT.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('AI SUMMARY', style: PT.t(11, w: FontWeight.w700, c: PT.sage)),
        const SizedBox(height: 6),
        SelectableText(summary.isEmpty ? 'AI-generated personalised plan' : summary, style: PT.t(13.5, h: 1.5)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _Pill('${dpInt(p['planDays']) ?? _days.length} days'),
          _Pill('${dpInt(p['mealsPerDay']) ?? 0} meals a day'),
          if (avg > 0) _Pill('${dpKcal(avg)} kcal a day on average'),
          if (made.isNotEmpty) _Pill('Made $made'),
        ]),
      ]),
    );
  }

  Widget _dayPicker() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < _days.length; i++)
            Material(
              color: i == _dayIdx ? PT.green : Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _dayIdx = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: i == _dayIdx ? PT.green : PT.line),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Day ${dpInt(_days[i]['dayNumber']) ?? i + 1}',
                        style: PT.t(13, w: FontWeight.w700, c: i == _dayIdx ? Colors.white : PT.ink)),
                    Text('${dpKcal(_days[i]['totalCalories'])} kcal',
                        style: PT.t(11, c: i == _dayIdx ? Colors.white : PT.sage)),
                  ]),
                ),
              ),
            ),
        ],
      );

  Widget _mealRow(Map<String, dynamic> m) {
    final id = dpInt(m['id']);
    final saving = id != null && id == _savingMeal;
    final notes = '${m['notes'] ?? ''}'.trim();
    final canEdit = !_closed && !saving && id != null;
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: canEdit ? () => _edit(m) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: PT.line))),
          child: saving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: PT.green)),
                  ),
                )
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: PT.sage, borderRadius: BorderRadius.circular(20)),
                    child: Text('${m['time'] ?? ''}', style: PT.t(11.5, w: FontWeight.w700, c: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(dpMealLabel(m['mealType']).toUpperCase(), style: PT.t(10.5, w: FontWeight.w700, c: PT.sage)),
                      const SizedBox(height: 2),
                      Text('${m['foodName'] ?? ''}', style: PT.t(14, w: FontWeight.w600)),
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(notes, style: PT.t(12, c: PT.sage, h: 1.4).copyWith(fontStyle: FontStyle.italic)),
                      ],
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Text('${dpKcal(m['calories'])} kcal', style: PT.t(12.5, w: FontWeight.w600, c: PT.greenDark)),
                  if (!_closed) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.edit_outlined, size: 18, color: PT.green),
                  ],
                ]),
        ),
      ),
    );
  }

  Widget _dayPanel() {
    if (_days.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('This plan has no days yet.', style: PT.t(13, c: PT.sage)),
      );
    }
    final day = _days[_dayIdx.clamp(0, _days.length - 1)];
    final meals = _meals(day);
    return Container(
      decoration: PT.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: PT.line))),
          child: Row(children: [
            Expanded(child: Text('Day ${dpInt(day['dayNumber']) ?? _dayIdx + 1}', style: PT.t(16, w: FontWeight.w700))),
            StatusChip('${dpKcal(day['totalCalories'])} kcal'),
            if (!_closed) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _addMeal(day),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add meal'),
              ),
            ],
          ]),
        ),
        if (meals.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Text('No meals on this day.', style: PT.t(13, c: PT.sage)))
        else
          ...meals.map(_mealRow),
      ]),
    );
  }

  /// Her key health answers beside the plan, so nothing is missed.
  Widget _healthStrip() {
    final h = _health;
    String v(dynamic x) => '${x ?? ''}'.trim();
    final items = <(String, String, bool)>[];
    if (h != null) {
      final prefs = (h['dietaryPreferences'] is List ? (h['dietaryPreferences'] as List) : const [])
          .map((e) => dtHuman(e))
          .join(', ');
      items.addAll([
        ('Goal', dtHuman(h['goals']), false),
        ('Allergies', v(h['allergies']), true),
        ('Conditions', v(h['medicalConditions']), true),
        ('Diet', prefs, false),
        ('Medications', v(h['currentMedications']), false),
      ]);
    }
    final shown = items.where((e) => e.$2.isNotEmpty && e.$2 != 'None' && e.$2.toLowerCase() != 'none').toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1DDB0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.health_and_safety_outlined, size: 18, color: Color(0xFF8A5A06)),
          const SizedBox(width: 8),
          Expanded(child: Text('HER HEALTH FORM', style: PT.t(11, w: FontWeight.w700, c: const Color(0xFF8A5A06)))),
          TextButton(onPressed: _openHealthForm, child: const Text('Full form')),
        ]),
        if (h == null && !_healthMissing)
          Text('Loading…', style: PT.t(12.5, c: PT.sage))
        else if (_healthMissing)
          Text("She hasn't filled her health form yet.", style: PT.t(12.5, c: PT.sage))
        else if (shown.isEmpty)
          Text('No allergies or conditions noted.', style: PT.t(12.5, c: PT.sage))
        else
          Wrap(spacing: 18, runSpacing: 6, children: [
            for (final (label, value, warn) in shown)
              RichText(
                text: TextSpan(style: PT.t(12.5), children: [
                  TextSpan(text: '$label: ', style: PT.t(12.5, w: FontWeight.w700, c: warn ? PT.red : PT.ink)),
                  TextSpan(text: value),
                ]),
              ),
          ]),
      ]),
    );
  }

  /// The dietitian's note to the client (top of her plan in the app).
  Widget _noteCard(Map<String, dynamic> p) {
    final note = '${p['clientNote'] ?? ''}'.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: PT.line)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.sticky_note_2_outlined, size: 18, color: PT.green),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NOTE FOR ${_who.toUpperCase()}', style: PT.t(11, w: FontWeight.w700, c: PT.sage)),
            const SizedBox(height: 4),
            Text(note.isEmpty ? 'No note yet. Add tips she should follow with this plan.' : note,
                style: PT.t(13, h: 1.45, c: note.isEmpty ? PT.sage : PT.ink)),
          ]),
        ),
        if (!_closed) TextButton(onPressed: _editNote, child: Text(note.isEmpty ? 'Add note' : 'Edit')),
      ]),
    );
  }

  /// Every day side by side: spot repeats and balance at a glance.
  Widget _weekPanel() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < _days.length; i++)
          Container(
            width: 230,
            margin: const EdgeInsets.only(right: 10),
            decoration: PT.card(),
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                color: PT.wash,
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Day ${dpInt(_days[i]['dayNumber']) ?? i + 1}', style: PT.t(13.5, w: FontWeight.w700)),
                      Text('${dpKcal(_days[i]['totalCalories'])} kcal', style: PT.t(11.5, c: PT.sage)),
                    ]),
                  ),
                  if (!_closed)
                    IconButton(
                      tooltip: 'Add meal',
                      onPressed: () => _addMeal(_days[i]),
                      icon: const Icon(Icons.add_rounded, size: 18, color: PT.green),
                    ),
                ]),
              ),
              for (final m in _meals(_days[i]))
                InkWell(
                  onTap: _closed ? null : () => _edit(m),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: PT.line))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${dpMealLabel(m['mealType'])} · ${m['time'] ?? ''}'.toUpperCase(),
                          style: PT.t(9.5, w: FontWeight.w700, c: PT.sage)),
                      const SizedBox(height: 2),
                      Text('${m['foodName'] ?? ''}', style: PT.t(12.5, w: FontWeight.w600), maxLines: 3, overflow: TextOverflow.ellipsis),
                      Text('${dpKcal(m['calories'])} kcal', style: PT.t(11, c: PT.greenDark)),
                    ]),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }

  Widget _closedNote() {
    final what = _status == 'cancelled' ? 'cancelled' : 'completed';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: PT.line)),
      child: Row(children: [
        const Icon(Icons.lock_outline_rounded, size: 18, color: PT.sage),
        const SizedBox(width: 10),
        Expanded(child: Text('This plan is $what and cannot be edited.', style: PT.t(13, w: FontWeight.w600, c: PT.sage))),
      ]),
    );
  }

  Widget _actions() {
    final busy = _activating || _cancelling;
    const spin = SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: PT.green));
    final cancelBtn = OutlinedButton.icon(
      style: portalDanger(),
      onPressed: busy ? null : _cancel,
      icon: _cancelling ? spin : const Icon(Icons.close_rounded, size: 18),
      label: const Text('Cancel plan'),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: PT.line))),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          if (_status == 'draft')
            Text('Tap a meal to change, copy or remove it. Activate to send it to her.', style: PT.t(12, c: PT.sage)),
          cancelBtn,
          if (_status == 'draft')
            ElevatedButton.icon(
              style: portalPrimary(),
              onPressed: busy ? null : _activate,
              icon: _activating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: const Text('Activate plan'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_plan == null) {
      if (_loading) {
        return Container(
          decoration: PT.card(),
          child: const Center(child: CircularProgressIndicator(color: PT.green)),
        );
      }
      return Container(
        decoration: PT.card(),
        child: PortalEmpty(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't load this plan",
          sub: _error,
          action: Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
            if (widget.onBack != null)
              TextButton(onPressed: widget.onBack, child: Text(widget.backLabel, style: PT.t(13.5, c: PT.sage))),
            ElevatedButton(style: portalPrimary(), onPressed: _load, child: const Text('Try again')),
          ]),
        ),
      );
    }
    final p = _plan!;
    return Container(
      decoration: PT.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _head(p),
        const Divider(height: 1, color: PT.line),
        Expanded(
          child: Opacity(
            opacity: _closed ? 0.7 : 1,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _summary(p),
                const SizedBox(height: 12),
                _healthStrip(),
                const SizedBox(height: 12),
                _noteCard(p),
                const SizedBox(height: 16),
                if (_days.length > 1)
                  Row(children: [
                    Expanded(child: _weekView ? Text('Whole plan', style: PT.t(15, w: FontWeight.w700)) : _dayPicker()),
                    const SizedBox(width: 10),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('One day'), icon: Icon(Icons.view_day_outlined, size: 16)),
                        ButtonSegment(value: true, label: Text('Whole plan'), icon: Icon(Icons.calendar_view_week_outlined, size: 16)),
                      ],
                      selected: {_weekView},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) => setState(() => _weekView = v.first),
                    ),
                  ]),
                if (_days.length > 1) const SizedBox(height: 14),
                _weekView ? _weekPanel() : _dayPanel(),
                if (_closed) ...[
                  const SizedBox(height: 14),
                  _closedNote(),
                ],
              ],
            ),
          ),
        ),
        if (!_closed) _actions(),
      ]),
    );
  }
}

// ─── Edit one meal ───────────────────────────────────────────────────────

final RegExp _kHHMM = RegExp(r'^\d{2}:\d{2}$');

class _MealDialog extends StatefulWidget {
  const _MealDialog({required this.meal, required this.onSave, this.isNew = false, this.onDelete, this.onCopy});
  final Map<String, dynamic> meal;
  /// Nov 2026: adding a new meal (all fields are sent).
  final bool isNew;
  /// Remove / copy this meal (closes the dialog when done).
  final Future<bool> Function()? onDelete;
  final Future<bool> Function()? onCopy;

  /// Gets only the fields that changed. Returns true when saved.
  final Future<bool> Function(Map<String, dynamic> changes) onSave;

  @override
  State<_MealDialog> createState() => _MealDialogState();
}

class _MealDialogState extends State<_MealDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _food = TextEditingController(text: '${widget.meal['foodName'] ?? ''}');
  late final TextEditingController _cal =
      TextEditingController(text: widget.isNew ? '' : '${dpInt(widget.meal['calories']) ?? 0}');
  late final TextEditingController _time = TextEditingController(text: '${widget.meal['time'] ?? ''}');
  late final TextEditingController _notes = TextEditingController(text: '${widget.meal['notes'] ?? ''}');
  late final String _origType =
      dpMealTypes.containsKey('${widget.meal['mealType']}') ? '${widget.meal['mealType']}' : 'breakfast';
  late String _type = _origType;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_food, _cal, _time, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final m = widget.meal;
    final changes = <String, dynamic>{};
    final food = _food.text.trim();
    if (food != '${m['foodName'] ?? ''}') changes['foodName'] = food;
    final cal = int.tryParse(_cal.text.trim());
    if (cal != null && cal != dpInt(m['calories'])) changes['calories'] = cal;
    final time = _time.text.trim();
    if (time != '${m['time'] ?? ''}') changes['time'] = time;
    final notes = _notes.text.trim();
    if (notes != '${m['notes'] ?? ''}'.trim()) changes['notes'] = notes;
    if (_type != _origType) changes['mealType'] = _type;
    if (widget.isNew) {
      changes
        ..['foodName'] = food
        ..['calories'] = cal
        ..['time'] = time
        ..['notes'] = notes
        ..['mealType'] = _type;
    }
    if (changes.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    final ok = await widget.onSave(changes);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 12),
        child: Text(t, style: PT.t(12, w: FontWeight.w600, c: PT.sage)),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(widget.isNew ? 'Add a meal' : 'Edit meal', style: PT.t(17, w: FontWeight.w700)),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _label('Food'),
              TextFormField(
                key: const ValueKey('dp_meal_food'),
                controller: _food,
                enabled: !_saving,
                style: PT.t(13.5),
                decoration: const InputDecoration(hintText: 'e.g. Oats porridge with banana'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter the food' : null,
              ),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _label('Calories'),
                    TextFormField(
                      key: const ValueKey('dp_meal_calories'),
                      controller: _cal,
                      enabled: !_saving,
                      style: PT.t(13.5),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(hintText: '450', suffixText: 'kcal'),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null || n <= 0) return 'A number above 0';
                        return null;
                      },
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _label('Time (24 h)'),
                    TextFormField(
                      key: const ValueKey('dp_meal_time'),
                      controller: _time,
                      enabled: !_saving,
                      style: PT.t(13.5),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                        LengthLimitingTextInputFormatter(5),
                      ],
                      decoration: const InputDecoration(hintText: 'HH:MM'),
                      validator: (v) => _kHHMM.hasMatch((v ?? '').trim()) ? null : 'Use HH:MM, e.g. 08:30',
                    ),
                  ]),
                ),
              ]),
              _label('Meal'),
              DropdownButtonFormField<String>(
                key: const ValueKey('dp_meal_type'),
                value: _type,
                isExpanded: true,
                style: PT.t(13.5),
                items: dpMealTypes.entries
                    .map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: _saving ? null : (v) => setState(() => _type = v ?? _type),
              ),
              _label('Notes (optional)'),
              TextFormField(
                key: const ValueKey('dp_meal_notes'),
                controller: _notes,
                enabled: !_saving,
                style: PT.t(13.5),
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'A short tip about this choice…'),
              ),
            ]),
          ),
        ),
      ),
      actions: [
        if (!widget.isNew && widget.onDelete != null)
          TextButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    final nav = Navigator.of(context);
                    if (await widget.onDelete!()) nav.pop();
                  },
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: PT.red),
            label: Text('Remove', style: PT.t(13.5, c: PT.red)),
          ),
        if (!widget.isNew && widget.onCopy != null)
          TextButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    final nav = Navigator.of(context);
                    if (await widget.onCopy!()) nav.pop();
                  },
            icon: const Icon(Icons.copy_all_rounded, size: 18),
            label: const Text('Copy to days'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: PT.t(13.5, c: PT.sage)),
        ),
        ElevatedButton(
          style: portalPrimary(),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(widget.isNew ? 'Add meal' : 'Save changes'),
        ),
      ],
    );
  }
}
