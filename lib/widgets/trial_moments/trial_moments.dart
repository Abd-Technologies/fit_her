import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../UI/free_trail/trial_summary_screen.dart';
import '../../UI/plans_module/all_plans.dart';
import '../../data/api_provider/api_provider.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../helper/permissions.dart' show getCountryCode;
import '../../helper/popup_manager.dart';
import '../../values/constants.dart';
import '../anim/motion.dart';

/// Free-trial moments (Nov 2026), from GET /trial/moment
/// (partner_backend helper/trialMoments.js):
///   progress  Day 3    "Your energy is rising"
///   month     Day 4    "Your next month is ready"
///   lastDay   last day "N days done" + offer
///   ended     after    "Your free trial has ended"
///
/// Each is shown ONCE, wherever she sees it first:
///   1. her push (tap → [openFromPush], opens at once),
///   2. a pop-up when she opens the app ([loadAndMaybeShow], its own
///      turn in the pop-up manager, rank [PopupRank.trialMoment]),
///   3. [TrialMomentCard] on Home until she opens it.
/// Seen anywhere → POST /trial/moment/seen, so the others stop.
class TrialMomentController extends GetxController {
  static TrialMomentController ensure() => Get.isRegistered<TrialMomentController>()
      ? Get.find<TrialMomentController>()
      : Get.put(TrialMomentController(), permanent: true);

  /// The moment due now and not seen yet ({kind, seen, data}), or null.
  final moment = Rxn<Map<String, dynamic>>();
  bool _loading = false;
  bool _showing = false;
  DateTime? _lastLoad;

  ApiProvider get _api => Get.find<ApiProvider>();
  String get _token =>
      Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
  Map<String, String> get _headers => {'accessToken': _token};

  Future<Map<String, dynamic>?> _fetch({String? kind}) async {
    if (_token.isEmpty) return null;
    try {
      String country = '';
      try {
        country = await getCountryCode();
      } catch (_) {}
      final q = <String>[
        if (kind != null) 'kind=$kind',
        if (country.isNotEmpty) 'country=${Uri.encodeComponent(country)}',
      ].join('&');
      final r = await _api.getData('${Constants.trialMoment}${q.isEmpty ? '' : '?$q'}', headers: _headers);
      final body = r.body;
      if (body is Map && body['status'] == '1' && body['data'] is Map) {
        final m = (body['data'] as Map)['moment'];
        return m is Map ? Map<String, dynamic>.from(m) : null;
      }
    } catch (_) {}
    return null;
  }

  /// Home opened / came back: load today's moment and offer it as a pop-up.
  /// At most once a minute.
  Future<void> loadAndMaybeShow() async {
    if (_loading) return;
    if (_lastLoad != null && DateTime.now().difference(_lastLoad!).inSeconds < 60) return;
    _loading = true;
    try {
      final m = await _fetch();
      _lastLoad = DateTime.now();
      moment.value = (m != null && m['seen'] != true && m['data'] is Map) ? m : null;
    } finally {
      _loading = false;
    }
    final m = moment.value;
    if (m == null || _showing) return;
    _showing = true;
    try {
      await PopupManager.run(
        'trial_moment_${m['kind']}',
        rank: PopupRank.trialMoment,
        show: () => _show(m, via: 'popup'),
      );
    } finally {
      _showing = false;
    }
  }

  /// She tapped the push: open that moment right away.
  Future<void> openFromPush(String kind) async {
    final m = await _fetch(kind: kind);
    if (m == null || m['data'] is! Map) return;
    await PopupManager.runNow('trial_moment_push_$kind', () => _show(m, via: 'push'));
  }

  /// She tapped the Home card.
  Future<void> openCard() async {
    final m = moment.value;
    if (m == null) return;
    await _show(m, via: 'card');
  }

  Future<void> _show(Map<String, dynamic> m, {required String via}) async {
    final kind = '${m['kind']}';
    final data = Map<String, dynamic>.from(m['data'] as Map);
    moment.value = null; // the Home card goes away once she's seen it
    _markSeen(kind, via);
    final Widget sheet;
    switch (kind) {
      case 'progress':
        sheet = TrialProgressSheet(d: data);
        break;
      case 'month':
        sheet = TrialMonthSheet(d: data);
        break;
      case 'lastDay':
        sheet = TrialLastDaySheet(d: data);
        break;
      case 'ended':
        sheet = TrialEndedSheet(d: data);
        break;
      default:
        return;
    }
    await Get.bottomSheet<void>(sheet, isScrollControlled: true, backgroundColor: Colors.transparent);
  }

  Future<void> _markSeen(String kind, String via) async {
    try {
      await _api.postData(Constants.trialMomentSeen, headers: _headers, body: {'kind': kind, 'via': via});
    } catch (_) {}
  }
}

// ── Shared look (same as the after-class sheet) ─────────────────────────
const _ink = Color(0xFF1F2A1E);
const _soft = Color(0xFF66705F);
const _body = Color(0xFF3D4A3A);
const _deep = Color(0xFF3F6B36);
const _limeBg = Color(0xFFEEF7E6);
const _green = Color(0xFF5DBB4A);
const _dark = Color(0xFF163220);
const _line = Color(0xFFE3E8DE);

TextStyle _t(double size, {FontWeight w = FontWeight.w400, Color c = _ink, double? h}) =>
    TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: w, color: c, height: h);

int? _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
String _name(Map<String, dynamic> d) => '${d['name'] ?? ''}'.trim();
String _hours(dynamic v) {
  final n = v is num ? v.toDouble() : double.tryParse('$v');
  if (n == null) return '';
  return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFDADFD5), borderRadius: BorderRadius.circular(4)),
              ),
              ...children,
            ]),
          ),
        ),
      );
}

Widget _badge(BuildContext context, IconData icon, {Color color = _green, Color ring = _limeBg}) {
  Widget b = Container(
    width: 60,
    height: 60,
    margin: const EdgeInsets.only(top: 16, bottom: 14),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: ring, spreadRadius: 8)]),
    child: Icon(icon, color: Colors.white, size: 30),
  );
  if (!Motion.calm(context)) {
    b = b.animate().scaleXY(begin: 0.3, end: 1, duration: const Duration(milliseconds: 600), curve: Curves.easeOutBack);
  }
  return b;
}

Widget _title(String text) => Text(text, textAlign: TextAlign.center, style: _t(22, w: FontWeight.w700));
Widget _line1(String text) =>
    Padding(padding: const EdgeInsets.only(top: 4), child: Text(text, textAlign: TextAlign.center, style: _t(14, c: _body, h: 1.45)));

Widget _pill(String text, Color bg, Color fg, {IconData? icon, Color? iconColor}) => Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 15, color: iconColor ?? fg), const SizedBox(width: 6)],
        Text(text, style: _t(12.5, w: FontWeight.w600, c: fg)),
      ]),
    );

Widget _pills(List<Widget> items) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: items),
    );

Widget _streakPill(int? streak) => _pill('${streak ?? 0}-day streak', const Color(0xFFFBF1DC), const Color(0xFF8A5A12),
    icon: Icons.local_fire_department_rounded, iconColor: const Color(0xFFE0A12C));

Widget _luna(String? text) {
  if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 14),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: const Color(0xFFF5FAF1), borderRadius: BorderRadius.circular(16)),
    child: Row(children: [
      Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
        child: const Icon(Icons.nightlight_round, size: 15, color: Colors.white),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text.rich(TextSpan(children: [
          TextSpan(text: 'Luna: ', style: _t(13, w: FontWeight.w600, c: const Color(0xFF3F8A2E))),
          TextSpan(text: text, style: _t(13, c: _body, h: 1.4)),
        ])),
      ),
    ]),
  );
}

Widget _primary(String label, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _dark,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          onPressed: onTap,
          child: Text(label, style: _t(15, w: FontWeight.w600, c: Colors.white)),
        ),
      ),
    );

Widget _notNow({String label = 'Not now'}) =>
    TextButton(onPressed: () => Get.back(), child: Text(label, style: _t(13, w: FontWeight.w600, c: _soft)));

// ── Day 3: energy rising ────────────────────────────────────────────────
class TrialProgressSheet extends StatelessWidget {
  const TrialProgressSheet({super.key, required this.d});
  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final name = _name(d);
    final up = d['energyUp'] == true;
    final energy = (d['energy'] is List ? d['energy'] as List : const []).whereType<Map>().toList();
    final sleep = d['sleep'] is Map ? d['sleep'] as Map : null;
    final meals = _int(d['meals']) ?? 0;
    final next = '${d['nextTime'] ?? ''}'.trim();
    return _Sheet(children: [
      _badge(context, Icons.trending_up_rounded),
      _title(up
          ? 'Your energy is rising${name.isEmpty ? '' : ', $name'}'
          : '3 days in${name.isEmpty ? '' : ', $name'}'),
      _line1(up ? '3 days in. Your phase and your classes are working together.' : 'Here is your progress so far.'),
      if (energy.length >= 2) _EnergyLine(points: energy),
      _pills([
        if (sleep != null) _pill('Sleep up to ${_hours(sleep['latest'])} h', _limeBg, _deep),
        if (meals > 0) _pill('$meals meals from your plan', _limeBg, _deep),
        _streakPill(_int(d['streak'])),
      ]),
      _luna(d['luna'] as String?),
      if (next.isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 12), child: Text('Next class at $next, reminder on', style: _t(12, c: _soft))),
      _primary('Got it', () => Get.back()),
    ]);
  }
}

/// Her mood check-ins as a small rising line (1–5 points).
class _EnergyLine extends StatelessWidget {
  const _EnergyLine({required this.points});
  final List<Map> points;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: SizedBox(
          height: 96,
          width: double.infinity,
          child: CustomPaint(painter: _EnergyPainter(points)),
        ),
      );
}

class _EnergyPainter extends CustomPainter {
  _EnergyPainter(this.points);
  final List<Map> points;

  @override
  void paint(Canvas canvas, Size size) {
    final n = points.length;
    final dx = n == 1 ? 0.0 : (size.width - 60) / (n - 1);
    Offset at(int i) {
      final v = ((points[i]['value'] as num?) ?? 3).toDouble().clamp(1.0, 5.0).toDouble();
      final y = 14.0 + (5.0 - v) / 4.0 * (size.height - 44.0);
      return Offset(30.0 + dx * i, y);
    }

    final line = Paint()
      ..color = _green
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < n; i++) {
      final a = at(i - 1), b = at(i);
      path.cubicTo((a.dx + b.dx) / 2, a.dy, (a.dx + b.dx) / 2, b.dy, b.dx, b.dy);
    }
    canvas.drawPath(path, line);
    for (var i = 0; i < n; i++) {
      final last = i == n - 1;
      final o = at(i);
      canvas.drawCircle(o, last ? 8 : 6, Paint()..color = last ? _green : Colors.white);
      if (!last) {
        canvas.drawCircle(o, 6, Paint()
          ..color = _green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
      }
      final tp = TextPainter(
        text: TextSpan(text: '${points[i]['label'] ?? ''}', style: _t(11, w: last ? FontWeight.w600 : FontWeight.w400, c: last ? _deep : _soft)),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (o.dx - tp.width / 2).clamp(0.0, (size.width - tp.width).clamp(0.0, size.width)).toDouble();
      tp.paint(canvas, Offset(x, o.dy + 12));
    }
  }

  @override
  bool shouldRepaint(covariant _EnergyPainter old) => old.points != points;
}

// ── Day 4: your next month ──────────────────────────────────────────────
class TrialMonthSheet extends StatelessWidget {
  const TrialMonthSheet({super.key, required this.d});
  final Map<String, dynamic> d;

  static const _colors = {
    'menstrual': Color(0xFFE07A6B),
    'follicular': Color(0xFF8AD167),
    'ovulatory': Color(0xFFF2C14E),
    'luteal': Color(0xFF9C8BD9),
  };

  @override
  Widget build(BuildContext context) {
    final phases = (d['phases'] is List ? d['phases'] as List : const []).whereType<Map>().toList();
    final meals = (d['sampleMeals'] is List ? d['sampleMeals'] as List : const []).whereType<Map>().toList();
    final time = '${d['time'] ?? ''}'.trim();
    return _Sheet(children: [
      _badge(context, Icons.calendar_month_rounded),
      _title('Your next month is ready'),
      _line1('Made from this week: your goal, the classes you joined${time.isEmpty ? '' : ' and your $time time'}.'),
      if (phases.isNotEmpty) ...[
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(children: [
              for (final p in phases)
                Expanded(flex: _int(p['days']) ?? 1, child: Container(color: _colors['${p['phase']}'] ?? _line)),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final p in phases) Text('${p['label']}', style: _t(11.5, c: _soft)),
        ]),
      ],
      if (meals.isNotEmpty || time.isNotEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(border: Border.all(color: _line), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('A day from your plan (free to look)', style: _t(12, c: _soft)),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('$time class, picked for your phase', style: _t(14, w: FontWeight.w600)),
            ],
            if (meals.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(meals.map((m) => '${m['food'] ?? ''}'.trim()).where((s) => s.isNotEmpty).join(', '),
                  style: _t(13, c: _body, h: 1.4)),
            ],
          ]),
        ),
      _luna(d['luna'] as String?),
      _primary('See plans', () {
        Get.back();
        Get.to(() => OurPlansScreen());
      }),
      _notNow(),
    ]);
  }
}

// ── Last day: N days done + offer ───────────────────────────────────────
class TrialLastDaySheet extends StatelessWidget {
  const TrialLastDaySheet({super.key, required this.d});
  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final name = _name(d);
    final days = _int(d['trialDays']) ?? 5;
    final classes = _int(d['classes']) ?? 0;
    final meals = _int(d['meals']) ?? 0;
    final kcal = _int(d['kcal']);
    final sleep = d['sleep'] is Map ? d['sleep'] as Map : null;
    final offer = d['offer'] is Map ? Map<String, dynamic>.from(d['offer']) : null;
    return _Sheet(children: [
      _badge(context, Icons.emoji_events_rounded, color: const Color(0xFFF5B83D), ring: const Color(0xFFFBF1DC)),
      _title('$days days done${name.isEmpty ? '' : ', $name'}!'),
      _line1([
        if (classes > 0) '$classes ${classes == 1 ? 'class' : 'classes'}',
        if (meals > 0) '$meals meals from your plan',
      ].join(' and ').let((s) => s.isEmpty ? 'Your plan and progress are saved.' : '$s. Your plan and progress are saved.')),
      _pills([
        _streakPill(_int(d['streak'])),
        if (sleep != null) _pill('Sleep up to ${_hours(sleep['latest'])} h', _limeBg, _deep),
        if (kcal != null && kcal > 0)
          _pill('about $kcal kcal', const Color(0xFFFCE9E5), const Color(0xFF9A3B2C),
              icon: Icons.bolt_rounded, iconColor: const Color(0xFFC9563F)),
      ]),
      if (offer != null) _OfferBlock(offer: offer),
      _primary('Keep my plan', () {
        Get.back();
        Get.to(() => const TrialSummaryScreen(jumpToOffer: true));
      }),
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text('Not ready? Everything stays saved.', style: _t(12, c: _soft)),
      ),
    ]);
  }
}

class _OfferBlock extends StatelessWidget {
  const _OfferBlock({required this.offer});
  final Map<String, dynamic> offer;

  @override
  Widget build(BuildContext context) {
    final options = (offer['options'] is List ? offer['options'] as List : const []).whereType<Map>().toList();
    final expired = offer['expired'] == true;
    final ends = DateTime.tryParse('${offer['expiresAt'] ?? ''}')?.toLocal();
    final left = ends?.difference(DateTime.now());
    final cur = '${offer['currency'] ?? ''}'.trim();
    String money(dynamic v) {
      final n = v is num ? v : num.tryParse('$v');
      return n == null ? '' : '${cur.isEmpty ? '' : '$cur '}${n.round()}';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(children: [
        const Divider(height: 1, color: Color(0xFFEEF1EA)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text('Keep going', style: _t(15, w: FontWeight.w600))),
          if (!expired && left != null && !left.isNegative)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFBF1DC), borderRadius: BorderRadius.circular(14)),
              child: Text('${offer['percent']}% off, ends in ${left.inHours}h ${left.inMinutes % 60}m',
                  style: _t(12, w: FontWeight.w600, c: const Color(0xFF8A5A12))),
            ),
        ]),
        for (var i = 0; i < options.length; i++)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: i == 0 ? const Color(0xFFF5FAF1) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: i == 0 ? _green : _line, width: i == 0 ? 2 : 1),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_duration(_int(options[i]['days'])), style: _t(14, w: FontWeight.w600)),
                  if (i == 0 && options.length > 1) Text('Time to see real change', style: _t(12, c: _soft)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(money(options[i]['offerPrice']), style: _t(15, w: FontWeight.w700)),
                if (!expired && options[i]['listPrice'] != options[i]['offerPrice'])
                  Text(money(options[i]['listPrice']),
                      style: _t(11.5, c: _soft).copyWith(decoration: TextDecoration.lineThrough)),
              ]),
            ]),
          ),
      ]),
    );
  }

  static String _duration(int? days) {
    if (days == null || days <= 0) return 'Plan';
    if (days % 30 == 0) return days == 30 ? '1 month' : '${days ~/ 30} months';
    return '$days days';
  }
}

// ── After the trial ─────────────────────────────────────────────────────
class TrialEndedSheet extends StatelessWidget {
  const TrialEndedSheet({super.key, required this.d});
  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final streak = _int(d['streak']) ?? 0;
    final offer = d['offer'] is Map ? Map<String, dynamic>.from(d['offer']) : null;
    return _Sheet(children: [
      _badge(context, Icons.favorite_rounded, color: const Color(0xFF8AB87C)),
      _title('Your free trial has ended'),
      _line1('Your meal plan, progress${streak > 0 ? ' and $streak-day streak' : ''} are saved, ready when you are.'),
      if (offer != null) _OfferBlock(offer: offer),
      _primary('Keep my plan', () {
        Get.back();
        Get.to(() => const TrialSummaryScreen(jumpToOffer: true));
      }),
      _notNow(),
    ]);
  }
}

/// Home card: today's trial moment, until she opens it (pop-up or push
/// didn't reach her). Hides itself otherwise.
class TrialMomentCard extends StatelessWidget {
  const TrialMomentCard({super.key, this.padding = EdgeInsets.zero});
  final EdgeInsets padding;

  static String _text(String kind, Map d) {
    final name = '${d['name'] ?? ''}'.trim();
    switch (kind) {
      case 'progress':
        return d['energyUp'] == true ? 'Your energy is rising${name.isEmpty ? '' : ', $name'}' : 'See your first 3 days';
      case 'month':
        return 'Your next month is ready';
      case 'lastDay':
        return '${d['trialDays'] ?? 5} days done${name.isEmpty ? '' : ', $name'}!';
      case 'ended':
        return 'Your plan is saved for you';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final c = TrialMomentController.ensure();
    return Obx(() {
      final m = c.moment.value;
      if (m == null || m['data'] is! Map) return const SizedBox.shrink();
      final text = _text('${m['kind']}', m['data'] as Map);
      if (text.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: padding,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: c.openCard,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: _t(14, w: FontWeight.w600))),
                Text('Open', style: _t(13, w: FontWeight.w700, c: _deep)),
              ]),
            ),
          ),
        ),
      );
    });
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
