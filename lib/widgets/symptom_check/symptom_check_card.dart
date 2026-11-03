import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/api_provider/api_provider.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../helper/analytics_helper.dart';
import '../../UI/auth_module/pcos/endometriosis_config.dart';
import '../../UI/auth_module/pcos/generic_screening_intro.dart';
import '../../UI/auth_module/pcos/menopause_config.dart';
import '../../UI/auth_module/pcos/pcos_config.dart';
import '../../UI/auth_module/pcos/postpartum_config.dart';
import '../../UI/auth_module/pcos/screening_data.dart';
import '../../UI/auth_module/pcos/thyroid_config.dart';
import '../../UI/plans_module/all_plans.dart';
import '../../values/constants.dart';
import '../class_reminder/class_reminder_flow.dart';
import 'health_checks_screen.dart';

/// Home "Hormone check" (PCOS / thyroid / … test) — next to the cycle card.
///
/// 1. She doesn't have the condition on file:
///      Not taken → "Could it be PCOS?" · Free · 2 minutes
///      Signs found → no plan: "Get my PCOS plan" (plans)
///                    workout only: "Add a PCOS meal plan" (combined plans)
///                    diet / combined: "Tell my dietitian" (push to her dietitian)
///      Low → "Looking good" · Retake in a month
/// 2. She already has it (health form / earlier result) → TRACKING:
///      "Track my PCOS signs · Check this month"
///      after 2 checks → "Signs down 8 → 5 💚" / "Signs up 5 → 8"
///      (signs up + diet plan → her dietitian is told automatically)
///
/// Results are saved on our server only (HealthScreenings), never sent to
/// Mixpanel. Not a diagnosis.

const _ink = Color(0xFF1F2A1E);
const _soft = Color(0xFF66705F);
const _deep = Color(0xFF4C6A4B);
const _green = Color(0xFF6DC55A);
const _limeBg = Color(0xFFEEF7E6);
const _line = Color(0xFFE3E8DF);
const _amber = Color(0xFFB7791F);
const _amberBg = Color(0xFFFDF3DF);
const _red = Color(0xFFC2412D);
const _redBg = Color(0xFFFCEBE7);

TextStyle _t(double s, {FontWeight w = FontWeight.w400, Color c = _ink, double? h}) =>
    TextStyle(fontFamily: 'Poppins', fontSize: s, fontWeight: w, color: c, height: h);

final Map<String, ScreeningConfig> _configs = {
  'PCOS': pcosConfig,
  'Thyroid': thyroidConfig,
  'Menopause': menopauseConfig,
  'Postpartum': postpartumConfig,
  'Endometriosis': endometriosisConfig,
};

class SymptomCheckCard extends StatefulWidget {
  const SymptomCheckCard({super.key, this.where = 'home', this.compact = false, this.mini = false});

  /// Stat-tile size (middle of the paid home's first row, Oct 2026): same
  /// look and font sizes as the Weight and Meals tiles beside it.
  final bool mini;
  final String where;

  /// Small tile (same size/style as the cycle card) for the row
  /// [Cycle | Hormone check]. Tapping a result opens the full card in a sheet.
  final bool compact;

  @override
  State<SymptomCheckCard> createState() => _SymptomCheckCardState();
}

class _SymptomCheckCardState extends State<SymptomCheckCard> {
  Map<String, dynamic>? _latest; // latest result (any condition, highest risk first)
  String? _planType; // diet / workout / combined / null
  String? _known; // condition she already has → tracking mode
  List<Map<String, dynamic>> _history = []; // last 2 checks of _known, newest first
  bool _due = true; // tracking: check due this month
  int _doneCount = 0; // different checks she has taken (any result)
  bool _loaded = false;
  bool _sending = false;

  bool get _tracking => _known != null;
  bool get _hasDiet => _planType == 'diet' || _planType == 'combined';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _token => Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';

  Future<void> _load() async {
    try {
      if (_token.isEmpty) return;
      final r = await Get.find<ApiProvider>()
          .getData('${Constants.getHealthScreening}/summary', headers: {'accessToken': _token});
      final body = r.body;
      if (body is Map && body['status'] == '1' && body['data'] is Map) {
        final data = body['data'] as Map;
        final results = data['results'];
        final tracking = data['tracking'] is Map ? data['tracking'] as Map : const {};
        if (mounted) {
          setState(() {
            _doneCount = results is List ? results.length : 0;
            _latest = results is List && results.isNotEmpty && results.first is Map
                ? Map<String, dynamic>.from(results.first as Map)
                : null;
            _planType = data['planType']?.toString();
            _known = tracking['known']?.toString();
            _history = tracking['history'] is List
                ? (tracking['history'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
                : [];
            _due = tracking['dueThisMonth'] != false;
            _loaded = true;
          });
        }
      }
    } catch (_) {}
  }

  // ── actions ─────────────────────────────────────────────────────────
  Future<void> _start({String? condition}) async {
    final c = _configs[condition ?? _known ?? 'PCOS'] ?? pcosConfig;
    AnalyticsHelper.track('symptom_check_opened', {
      'from': widget.where,
      'screening': c.conditionType,
      'mode': _tracking ? 'tracking' : 'check',
    });
    await Get.to(() => GenericScreeningIntro(config: c));
    if (mounted) _load();
  }

  void _openPlans(String cond) {
    final workoutOnly = _planType == 'workout';
    AnalyticsHelper.offerTapped('symptom_check', offer: workoutOnly ? 'add_meal_plan' : 'plans');
    Get.to(() => OurPlansScreen(
          onlyCategoryId: workoutOnly ? 3 : null,
          headline: workoutOnly
              ? 'Add a $cond-friendly meal plan to your classes. Your dietitian builds it around your check.'
              : 'A $cond-friendly diet plan, made by your dietitian around your check.',
        ));
  }

  Future<void> _tellDietitian(String cond) async {
    if (_sending) return;
    setState(() => _sending = true);
    AnalyticsHelper.track('symptom_check_dietitian_told', {'from': widget.where});
    try {
      final r = await Get.find<ApiProvider>().postData(
        '${Constants.getHealthScreening}/notify-dietitian',
        body: {'conditionType': cond},
        headers: {'accessToken': _token},
      );
      final ok = r.body is Map && r.body['status'] == '1';
      ClassReminderFlow.showReminderToast(
        ok ? 'Sent to your dietitian ✓' : "Couldn't send",
        ok
            ? 'She will look at your $cond check before your next plan.'
            : (r.body is Map ? '${r.body['message']}' : 'Please try again.'),
        error: !ok,
        icon: Icons.favorite_rounded,
      );
      if (ok) await _load();
    } catch (_) {
      ClassReminderFlow.showReminderToast("Couldn't send", 'Please check your internet and try again.', error: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  String _date(dynamic iso) {
    final d = iso is DateTime ? iso : DateTime.tryParse('$iso')?.toLocal();
    if (d == null) return '';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]}';
  }

  /// Tracking trend: -1 signs down, 0 same, 1 up, null = fewer than 2 checks.
  int? get _trend {
    if (_history.length < 2) return null;
    final now = (_history[0]['riskScore'] as num?) ?? 0;
    final before = (_history[1]['riskScore'] as num?) ?? 0;
    return now < before ? -1 : (now > before ? 1 : 0);
  }

  // ── build ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (widget.compact || widget.mini) return _compactTile();
    if (!_loaded) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: _tracking ? _trackingBody() : (_latest == null ? _notTaken() : _result(_latest!)),
    );
  }

  // Compact tile (next to the cycle card)
  Widget _compactTile() {
    String head = 'Could it be PCOS?';
    Color headColor = const Color(0xFF163220);
    String line2 = 'Free · 2 minutes ›';
    VoidCallback? onTap = () => _start();

    if (_tracking) {
      final k = _known!;
      final t = _trend;
      if (_history.isEmpty || (_due && t == null)) {
        head = 'Track my $k signs';
        line2 = 'Check this month ›';
      } else if (t == null) {
        head = '$k signs tracked';
        line2 = 'Next check ${_date(DateTime.parse('${_history[0]['takenAt']}').add(const Duration(days: 30)))} ›';
        headColor = _deep;
      } else {
        final a = _history[1]['riskScore'];
        final b = _history[0]['riskScore'];
        head = t < 0 ? 'Signs down $a → $b 💚' : (t > 0 ? 'Signs up $a → $b' : 'Signs steady');
        headColor = t < 0 ? _deep : (t > 0 ? _amber : _deep);
        line2 = _due ? 'Check this month ›' : 'See details ›';
      }
      onTap = () => _openSheet();
      if (_history.isEmpty || _due) onTap = () => _start(condition: k);
      if (_history.isNotEmpty && !_due) onTap = _openSheet;
    } else if (_latest != null) {
      final risk = '${_latest!['riskLevel'] ?? ''}';
      final cond = '${_latest!['conditionType'] ?? 'PCOS'}';
      final concern = risk == 'high' || risk == 'moderate';
      head = concern ? 'Signs of $cond' : 'Looking good';
      headColor = risk == 'high' ? _red : (risk == 'moderate' ? _amber : _deep);
      line2 = concern ? 'See my next step ›' : 'Checked ${_date(_latest!['takenAt'])} ›';
      onTap = _openSheet;
    }

    if (widget.mini) {
      // Same 3 lines as the Weight / Meals tiles: label, value, small line.
      // Oct 2026: one door to ALL checks (PCOS, thyroid, endometriosis,
      // menopause, after birth). She picks; never a condition by itself.
      const label = '🔍 Health checks';
      final done = _doneCount;
      final dueOne = _tracking && _due;
      final String value = dueOne ? '1 due' : (done == 0 ? 'PCOS check' : '$done done');
      final String sub = done == 0 && !dueOne ? 'Free · 2 min ›' : 'See all ›';
      final Color valueColor = dueOne ? _amber : const Color(0xFF6DC55A);
      onTap = () async {
        await Get.to(() => HealthChecksScreen(where: widget.where));
        if (mounted) _load();
      };
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _loaded ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD8EDD4), width: 1),
            boxShadow: [
              BoxShadow(color: const Color(0xFF163220).withOpacity(0.05), offset: const Offset(0, 2), blurRadius: 10),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF163220)),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    maxLines: 1,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w800, color: valueColor, height: 1.1)),
              ),
              const SizedBox(height: 3),
              Text(sub,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF3C9A2C))),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _loaded ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD8EDD4), width: 1),
          boxShadow: [
            BoxShadow(color: const Color(0xFF163220).withOpacity(0.05), offset: const Offset(0, 2), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔍 HORMONE CHECK',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF9AB09A), letterSpacing: 0.6),
            ),
            const SizedBox(height: 6),
            Text(head,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: headColor, height: 1.2)),
            const Spacer(),
            const SizedBox(height: 4),
            Text(line2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _green)),
          ],
        ),
      ),
    );
  }

  void _openSheet() {
    if (!_tracking && _latest == null) return;
    Get.bottomSheet(
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: const Color(0xFFDADFD5), borderRadius: BorderRadius.circular(4)),
            ),
            _tracking ? _trackingBody(inSheet: true) : _result(_latest!, inSheet: true),
          ]),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _icon() => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(10)),
        child: const Center(child: Text('🔍', style: TextStyle(fontSize: 15))),
      );

  Widget _button(String text, VoidCallback? onTap, {bool primary = true}) => SizedBox(
        height: 40,
        width: double.infinity,
        child: primary
            ? ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  disabledBackgroundColor: _limeBg,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(text, style: _t(12.5, w: FontWeight.w600, c: onTap == null ? _deep : Colors.white)),
              )
            : OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(text, style: _t(12.5, w: FontWeight.w600, c: _deep)),
              ),
      );

  Widget _disclaimer() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('This is not a medical diagnosis. Talk to your doctor if you are worried.',
            style: _t(9.5, c: const Color(0xFF9AB09A))),
      );

  Widget _badge(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: _t(10, w: FontWeight.w600, c: fg)),
      );

  // Not taken yet
  Widget _notTaken() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _start(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _icon(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Could it be PCOS?', style: _t(13.5, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Irregular periods, weight gain, acne? Take the free 2-minute check.',
                  style: _t(11.5, c: _soft, h: 1.4)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: _soft, size: 20),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: ['Irregular periods', 'Fatigue', 'Weight gain', 'Hair growth', 'Acne']
              .map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: _limeBg, borderRadius: BorderRadius.circular(20)),
                    child: Text(t, style: _t(10, w: FontWeight.w500, c: _deep)),
                  ))
              .toList(),
        ),
      ]),
    );
  }

  // One result (she didn't have the condition on file)
  Widget _result(Map<String, dynamic> l, {bool inSheet = false}) {
    final cond = '${l['conditionType'] ?? 'PCOS'}';
    final risk = '${l['riskLevel'] ?? 'low'}';
    final concern = risk == 'high' || risk == 'moderate';
    final told = l['dietitianNotifiedAt'] != null;
    Color fg = _deep, bg = _limeBg;
    String label = 'Low signs';
    if (risk == 'high') {
      fg = _red;
      bg = _redBg;
      label = 'High signs';
    } else if (risk == 'moderate') {
      fg = _amber;
      bg = _amberBg;
      label = 'Moderate signs';
    }
    final message = !concern
        ? 'No strong signs right now. Check again if things change.'
        : (_hasDiet
            ? 'Your dietitian can adjust your plan around $cond.'
            : (_planType == 'workout'
                ? 'Add a $cond-friendly meal plan to your classes. It can help you feel better.'
                : 'A $cond-friendly diet plan can help you feel better.'));
    void close() {
      if (inSheet) Get.back();
    }

    Widget main;
    if (!concern) {
      main = _button('Retake in a month', () {
        close();
        _start(condition: cond);
      }, primary: false);
    } else {
      final primary = _hasDiet
          ? _button(told ? 'Sent to your dietitian ✓' : (_sending ? 'Sending…' : 'Tell my dietitian'),
              told || _sending ? null : () {
                close();
                _tellDietitian(cond);
              })
          : _button(_planType == 'workout' ? 'Add a $cond meal plan' : 'Get my $cond plan', () {
              close();
              _openPlans(cond);
            });
      main = Row(children: [
        Expanded(flex: 3, child: primary),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _button('Retake', () {
            close();
            _start(condition: cond);
          }, primary: false),
        ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _icon(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(concern ? 'Signs of $cond found' : 'Looking good', style: _t(13.5, w: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: [
              _badge(label, fg, bg),
              const SizedBox(width: 6),
              Text('$cond check · ${_date(l['takenAt'])}', style: _t(10.5, c: _soft)),
            ]),
            const SizedBox(height: 6),
            Text(message, style: _t(11.5, c: _soft, h: 1.4)),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      main,
      _disclaimer(),
    ]);
  }

  // Tracking: she already has the condition
  Widget _trackingBody({bool inSheet = false}) {
    final k = _known!;
    final t = _trend;
    final last = _history.isNotEmpty ? _history[0] : null;
    final told = last != null && last['dietitianNotifiedAt'] != null;
    String title;
    String message;
    Color fg = _deep, bg = _limeBg;
    String? badge;
    if (last == null) {
      title = 'Track my $k signs';
      message = 'A 2-minute check once a month shows how your signs change with your plan.';
    } else if (t == null) {
      title = 'Your $k signs';
      badge = 'Score ${last['riskScore']}';
      message = _due
          ? 'Time for this month\'s check. Next time we\'ll show if your signs went down.'
          : 'Check again next month to see if your signs went down.';
    } else {
      final a = _history[1]['riskScore'];
      final b = last['riskScore'];
      if (t < 0) {
        title = 'Signs down $a → $b 💚';
        badge = 'Improving';
        message = 'Your plan is working. Keep going!';
      } else if (t > 0) {
        title = 'Signs up $a → $b';
        badge = 'Higher';
        fg = _amber;
        bg = _amberBg;
        message = _hasDiet
            ? (told ? 'Your dietitian has been told and will adjust your plan.' : 'Let your dietitian know so she can adjust your plan.')
            : 'A $k-friendly meal plan can help bring them down.';
      } else {
        title = 'Signs steady';
        badge = 'Same';
        message = 'No change since last month. Keep following your plan.';
      }
    }
    void close() {
      if (inSheet) Get.back();
    }

    final buttons = <Widget>[];
    if (last == null || _due) {
      buttons.add(Expanded(
        flex: 3,
        child: _button(last == null ? 'Start tracking' : 'Check this month', () {
          close();
          _start(condition: k);
        }),
      ));
    }
    if (t != null && t > 0) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 8));
      buttons.add(Expanded(
        flex: 3,
        child: _hasDiet
            ? _button(told ? 'Dietitian told ✓' : 'Tell my dietitian', told || _sending ? null : () {
                close();
                _tellDietitian(k);
              }, primary: buttons.isEmpty)
            : _button(_planType == 'workout' ? 'Add a $k meal plan' : 'Get my $k plan', () {
                close();
                _openPlans(k);
              }, primary: buttons.isEmpty),
      ));
    }
    if (buttons.isEmpty) {
      buttons.add(Expanded(
        child: _button('Check again', () {
          close();
          _start(condition: k);
        }, primary: false),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _icon(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: _t(13.5, w: FontWeight.w700)),
            if (badge != null || last != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                if (badge != null) ...[_badge(badge, fg, bg), const SizedBox(width: 6)],
                if (last != null) Text('Last check ${_date(last['takenAt'])}', style: _t(10.5, c: _soft)),
              ]),
            ],
            const SizedBox(height: 6),
            Text(message, style: _t(11.5, c: _soft, h: 1.4)),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: buttons),
      _disclaimer(),
    ]);
  }
}
