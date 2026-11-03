import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_session.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';
import 'plan_editor.dart';

/// Set this (then portalGo('d_generate')) to open the Generate page with a
/// client already chosen. Accepts any of:
///  - a row from /dietTimes/getClients ({id: userPlanId, User: {id, ...}})
///  - {userId, userPlanId?, name?}
///  - a user map {id: userId, firstName, lastName}
/// The page clears it back to null once used.
final ValueNotifier<Map<String, dynamic>?> generateForClient = ValueNotifier<Map<String, dynamic>?>(null);

const List<int> _kMealOptions = [3, 4, 5, 6];
const Map<int, String> _kMealHints = {
  3: 'Breakfast, Lunch, Dinner',
  4: 'Breakfast, Lunch, Snack, Dinner',
  5: 'Breakfast, Mid-morning, Lunch, Snack, Dinner',
  6: 'Breakfast, Mid-morning, Lunch, Snack, Evening snack, Dinner',
};
const List<String> _kProgress = [
  'Asking the AI for the best meals…',
  'Balancing calories and nutrition…',
  'Adding cycle-phase awareness…',
  'Double-checking allergies and preferences…',
  'Putting the days together…',
  'Almost there…',
];

/// Pick one of your clients, choose plan length and meals per day, and let
/// the AI build a draft. The draft then opens for review (same as the app's
/// GeneratePlanScreen → PlanReviewEditScreen).
class DietGeneratePage extends StatefulWidget {
  const DietGeneratePage({super.key});

  @override
  State<DietGeneratePage> createState() => _DietGeneratePageState();
}

class _DietGeneratePageState extends State<DietGeneratePage> {
  static const int _minDays = 3;
  static const int _maxDays = 14;

  final _search = TextEditingController();
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;
  String? _loadError;
  Map<String, dynamic>? _pending;

  Map<String, dynamic>? _sel;
  int _planDays = 14;
  int _mealsPerDay = 5;

  bool _generating = false;
  String? _genError;
  List<String> _genDetails = [];
  int _progressIdx = 0;
  Timer? _timer;

  int? _draftId;
  String? _draftName;

  @override
  void initState() {
    super.initState();
    _pending = generateForClient.value;
    if (_pending != null) Future.microtask(() => generateForClient.value = null);
    generateForClient.addListener(_onPreselect);
    _load();
  }

  @override
  void dispose() {
    generateForClient.removeListener(_onPreselect);
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onPreselect() {
    final m = generateForClient.value;
    if (m == null || !mounted) return;
    Future.microtask(() => generateForClient.value = null);
    if (_generating) {
      portalToast('Please wait', sub: 'A plan is being made right now.', error: true);
      return;
    }
    if (_loading) {
      _pending = m;
      return;
    }
    _applyPreselect(m);
  }

  void _applyPreselect(Map<String, dynamic> m) {
    final c = _match(m);
    if (c == null) {
      portalToast("Couldn't find that client", sub: 'Please pick her from the list.', error: true);
      return;
    }
    setState(() => _draftId = null);
    _select(c);
  }

  Map<String, dynamic>? _match(Map<String, dynamic> m) {
    final hasUser = m['User'] is Map;
    final userId = hasUser ? dpInt(dpMap(m['User'])['id']) : dpInt(m['userId'] ?? m['id']);
    final upId = hasUser ? dpInt(m['id']) : dpInt(m['userPlanId']);
    for (final c in _clients) {
      if (upId != null && dpInt(c['id']) == upId) return c;
    }
    for (final c in _clients) {
      if (userId != null && dpInt(dpMap(c['User'])['id']) == userId) return c;
    }
    if (userId != null && upId != null) {
      if (hasUser) return {'id': upId, 'User': dpMap(m['User'])};
      final name = '${m['name'] ?? ''}'.trim();
      return {
        'id': upId,
        'User': {
          'id': userId,
          'firstName': name.isNotEmpty ? name : '${m['firstName'] ?? ''}',
          'lastName': name.isNotEmpty ? '' : '${m['lastName'] ?? ''}',
          'email': '${m['email'] ?? ''}',
        },
      };
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final me = Get.find<PortalSession>().userId ?? 0;
    final b = await PortalApi.get('${Constants.getClients}/$me');
    if (!mounted) return;
    final list = dpList(dpMap(b['data'])['cliets']);
    final ok = PortalApi.ok(b);
    // The server says "No Plan assigned to you yet" when she has no clients.
    final none = !ok && PortalApi.msg(b).toLowerCase().contains('no plan assigned');
    setState(() {
      _loading = false;
      _clients = ok ? list : <Map<String, dynamic>>[];
      _loadError = (ok || none) ? null : PortalApi.msg(b, "Couldn't load your clients.");
      if (_sel != null) {
        final id = dpInt(_sel!['id']);
        final fresh = _clients.where((c) => dpInt(c['id']) == id).toList();
        if (fresh.isNotEmpty) _sel = fresh.first;
      }
    });
    final p = _pending;
    _pending = null;
    if (p != null) _applyPreselect(p);
  }

  int? _userId(Map<String, dynamic> c) => dpInt(dpMap(c['User'])['id']);

  void _select(Map<String, dynamic> c) {
    setState(() {
      _sel = c;
      _genError = null;
      _genDetails = [];
      _mealsPerDay = 5;
    });
    _prefillMeals(c);
  }

  /// Start from the meals-per-day set on her form during the consultation.
  Future<void> _prefillMeals(Map<String, dynamic> c) async {
    final uid = _userId(c);
    if (uid == null) return;
    final b = await PortalApi.get('/admin/pre-consultation/$uid');
    if (!mounted || _sel == null || _userId(_sel!) != uid || _generating) return;
    final prof = dpMap(dpMap(b['data'])['profile']);
    final n = dpInt(prof['mealsPerDay']);
    if (PortalApi.ok(b) && n != null && n >= 3 && n <= 6) setState(() => _mealsPerDay = n);
  }

  Future<void> _generate() async {
    final c = _sel;
    if (c == null) return;
    final uid = _userId(c);
    final upId = dpInt(c['id']);
    if (uid == null || upId == null) {
      portalToast("Can't make a plan for this client", sub: 'Her plan details are missing.', error: true);
      return;
    }
    final name = dpUserName(c['User']);
    setState(() {
      _generating = true;
      _genError = null;
      _genDetails = [];
      _progressIdx = 0;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      if (_progressIdx < _kProgress.length - 1) setState(() => _progressIdx++);
    });
    final b = await dpSend((api, h) => api.postData(
          '/admin/diet-plan/generate',
          body: {'userId': uid, 'userPlanId': upId, 'planDays': _planDays, 'mealsPerDay': _mealsPerDay},
          headers: h,
          timeout: const Duration(seconds: 120),
        ));
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;
    final plan = dpMap(dpMap(b['data'])['dietPlan']);
    final id = dpInt(plan['id']);
    if (PortalApi.ok(b) && id != null) {
      setState(() {
        _generating = false;
        _draftId = id;
        _draftName = name;
      });
      portalToast('Draft plan ready', sub: 'Check the meals, then activate it.');
    } else {
      final v = dpMap(dpMap(b['data'])['validation']);
      setState(() {
        _generating = false;
        _genError = PortalApi.msg(b, 'AI generation failed.');
        _genDetails = (v['errors'] is List) ? (v['errors'] as List).map((e) => '$e').toList() : <String>[];
      });
    }
  }

  // ─── Client picker ────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _clients;
    return _clients.where((c) {
      final u = dpMap(c['User']);
      final hay = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''} ${u['email'] ?? ''} ${u['phone'] ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Widget _clientTile(Map<String, dynamic> c) {
    final u = dpMap(c['User']);
    final name = dpUserName(u);
    final sel = _sel != null && dpInt(_sel!['id']) == dpInt(c['id']);
    final pipe = dpMap(c['planPipeline']);
    final owed = pipe['owed'] == true;
    final hasDraft = pipe['draftPlanId'] != null;
    return Material(
      color: sel ? const Color(0xFFEAF7E4) : Colors.white,
      child: InkWell(
        onTap: _generating ? null : () => _select(c),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: PT.line))),
          child: Row(children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: PT.wash,
              child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: PT.t(13, w: FontWeight.w700, c: PT.greenDark)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: PT.t(13.5, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${u['email'] ?? ''}', style: PT.t(11.5, c: PT.sage), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            if (hasDraft)
              const StatusChip('Has draft', color: PT.amber)
            else if (owed)
              const StatusChip('Plan owed', color: PT.red),
          ]),
        ),
      ),
    );
  }

  Widget _picker() {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator(color: PT.green));
    } else if (_loadError != null) {
      body = PortalEmpty(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load your clients",
        sub: _loadError,
        action: ElevatedButton(style: portalPrimary(), onPressed: _load, child: const Text('Try again')),
      );
    } else if (_clients.isEmpty) {
      body = const PortalEmpty(icon: Icons.people_outline_rounded, title: 'No clients yet', sub: 'Clients assigned to you show here.');
    } else {
      final list = _filtered;
      body = list.isEmpty
          ? Center(child: Text('No client matches your search.', style: PT.t(13, c: PT.sage)))
          : ListView(children: list.map(_clientTile).toList());
    }
    return Container(
      decoration: PT.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
          child: Row(children: [
            Expanded(child: Text('1. Choose a client', style: PT.t(14.5, w: FontWeight.w700))),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading || _generating ? null : _load,
              icon: const Icon(Icons.refresh_rounded, color: PT.sage),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            key: const ValueKey('dp_gen_search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: PT.t(13.5),
            decoration: const InputDecoration(
              hintText: 'Search by name or email',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
          ),
        ),
        const Divider(height: 1, color: PT.line),
        Expanded(child: body),
      ]),
    );
  }

  // ─── Settings + generate ──────────────────────────────────────────────

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: PT.t(13, w: FontWeight.w700, c: PT.sage)),
          const SizedBox(height: 8),
          child,
        ]),
      );

  Widget _mealChip(int n) {
    final sel = _mealsPerDay == n;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: sel ? PT.green : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _generating ? null : () => setState(() => _mealsPerDay = n),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? PT.green : PT.line),
              ),
              child: Text('$n', style: PT.t(15, w: FontWeight.w700, c: sel ? Colors.white : PT.ink)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _generateBlock() {
    if (_generating) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(14), border: Border.all(color: PT.line)),
        child: Column(children: [
          const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: PT.green)),
          const SizedBox(height: 12),
          Text('Making the plan…', style: PT.t(15, w: FontWeight.w700)),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(_kProgress[_progressIdx],
                key: ValueKey(_progressIdx), textAlign: TextAlign.center, style: PT.t(13, c: PT.sage)),
          ),
          const SizedBox(height: 10),
          Text(
            'This can take up to 2 minutes. Please keep this page open. '
            'If you leave, the draft will still appear in Drafts when it is ready.',
            textAlign: TextAlign.center,
            style: PT.t(11.5, c: PT.sage, h: 1.4),
          ),
        ]),
      );
    }
    final btn = ElevatedButton.icon(
      style: portalPrimary(),
      onPressed: _sel == null ? null : _generate,
      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
      label: Text(_genError == null ? 'Generate with AI' : 'Try again'),
    );
    if (_genError == null) return btn;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PT.red.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEBC6C6)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.error_outline_rounded, size: 18, color: PT.red),
            const SizedBox(width: 8),
            Expanded(child: Text(_genError!, style: PT.t(13, w: FontWeight.w600, c: PT.red))),
          ]),
          for (final d in _genDetails)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 4),
              child: Text('• $d', style: PT.t(12, c: PT.red)),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      btn,
    ]);
  }

  Widget _settings() {
    final c = _sel;
    final pipe = c == null ? <String, dynamic>{} : dpMap(c['planPipeline']);
    final noForm = pipe.isNotEmpty && pipe['hasForm'] != true;
    final hasDraft = pipe['draftPlanId'] != null;
    return Container(
      decoration: PT.card(),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('2. Plan settings', style: PT.t(14.5, w: FontWeight.w700)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(14), border: Border.all(color: PT.line)),
          child: Row(children: [
            const Icon(Icons.person_outline_rounded, color: PT.green),
            const SizedBox(width: 10),
            Expanded(
              child: c == null
                  ? Text('Pick a client first.', style: PT.t(13.5, c: PT.sage))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('CLIENT', style: PT.t(10.5, w: FontWeight.w700, c: PT.sage)),
                      Text(dpUserName(c['User']), style: PT.t(15, w: FontWeight.w700)),
                    ]),
            ),
          ]),
        ),
        if (noForm) ...[
          const SizedBox(height: 10),
          Text("She hasn't filled her form. Fill it with her before generating.",
              style: PT.t(12.5, c: PT.amber, h: 1.4)),
        ],
        if (hasDraft) ...[
          const SizedBox(height: 10),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
            Text('She already has a draft waiting.', style: PT.t(12.5, c: PT.amber)),
            TextButton(
              onPressed: _generating
                  ? null
                  : () => setState(() {
                        _draftId = dpInt(pipe['draftPlanId']);
                        _draftName = dpUserName(c!['User']);
                      }),
              child: const Text('Open the draft'),
            ),
          ]),
        ],
        _section(
          'Plan length',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$_planDays days', style: PT.t(22, w: FontWeight.w800)),
            Slider(
              min: _minDays.toDouble(),
              max: _maxDays.toDouble(),
              divisions: _maxDays - _minDays,
              value: _planDays.toDouble(),
              activeColor: PT.green,
              inactiveColor: PT.line,
              label: '$_planDays days',
              onChanged: _generating ? null : (v) => setState(() => _planDays = v.round()),
            ),
            Text('14 days lasts until her Day-15 check-in.', style: PT.t(12, c: PT.sage)),
          ]),
        ),
        _section(
          'Meals per day',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: _kMealOptions.map(_mealChip).toList()),
            const SizedBox(height: 10),
            Text(_kMealHints[_mealsPerDay] ?? '', style: PT.t(12.5, c: PT.sage, h: 1.4)),
          ]),
        ),
        const SizedBox(height: 22),
        _generateBlock(),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_draftId != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader(
          title: 'Review the new plan',
          sub: 'Check each day, tap a meal to change it, then activate it to send it to your client.',
        ),
        Expanded(
          child: DietPlanEditor(
            key: ValueKey('dp_gen_$_draftId'),
            planId: _draftId!,
            clientName: _draftName,
            backLabel: 'Back to Generate',
            onBack: () => setState(() => _draftId = null),
            onChanged: _load,
          ),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(
        title: 'Generate a plan',
        sub: 'Choose a client, set the plan length and meals per day, and the AI makes a draft '
            'from her consultation form. You check it before she sees anything.',
      ),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          if (box.maxWidth >= 820) {
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(width: 360, child: _picker()),
              const SizedBox(width: 16),
              Expanded(child: _settings()),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 4, child: _picker()),
            const SizedBox(height: 12),
            Expanded(flex: 6, child: _settings()),
          ]);
        }),
      ),
    ]);
  }
}
