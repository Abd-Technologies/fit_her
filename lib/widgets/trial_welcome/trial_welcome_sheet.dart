import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../data/Repos/cycle_repo/cycle_data_repository.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import '../../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../../data/services/cycle_engine.dart';
import '../../helper/popup_manager.dart';
import '../../values/constants.dart';
import '../anim/motion.dart';
import '../new_home/trial_cta_card.dart' show enterTrialOnboarding;
import '../../UI/auth_module/walt_through/animated_cycle_wheel.dart';

/// "Welcome, [name] 💚" sheet (Oct 2026). Shown ONCE, on the unpaid home,
/// to a woman who has just finished the sign-up questions, to invite her
/// to start the free trial.
///
/// When it appears (all must be true, else nothing is shown):
///  1. The sign-up questions screen saved `trial_welcome_pending` for THIS
///     user (so old users, logins and admin-added clients never see it),
///     less than 7 days ago.
///  2. She is a normal user (not guest / staff), not paid, and has never
///     started a trial (server check: GET /trial/me returns no journey).
///  3. The trial length came from the server just now (GET /trial/me).
///     No internet -> not shown, asked again on the next app open. It
///     never shows a fixed number.
///  4. Home is on screen with nothing on top. It does NOT wait for a
///     pop-up turn ([PopupManager.runFirstLanding]): it is part of the
///     sign-up flow. The notifications ask waits for her next open.
///
/// Once shown, it is never shown again (any button, or swiping it away).
/// If she already started or bought, the pending mark is just removed.
class TrialWelcomeSheet {
  TrialWelcomeSheet._();

  static const String kPendingKey = 'trial_welcome_pending';
  static const String _kDonePrefix = 'trial_welcome_done_';
  static const Duration _kFreshFor = Duration(days: 7);

  static bool _checking = false;

  /// Called by the sign-up questions screen once her answers are saved.
  static void markPending() {
    try {
      final prefs = Get.find<AuthController>().sharedPreferences;
      final uid = prefs.getString(Constants.userId) ?? '';
      if (uid.isEmpty) return;
      prefs.setString(kPendingKey, '$uid|${DateTime.now().toIso8601String()}');
    } catch (_) {}
  }

  static Future<void> maybeShow() async {
    if (_checking) return;
    _checking = true;
    try {
      if (!Get.isRegistered<AuthController>() ||
          !Get.isRegistered<HomeController>()) {
        return;
      }
      final auth = Get.find<AuthController>();
      final home = Get.find<HomeController>();
      final prefs = auth.sharedPreferences;

      // 1. Pending for this user, and recent.
      final raw = prefs.getString(kPendingKey);
      if (raw == null || raw.isEmpty) return;
      final uid = prefs.getString(Constants.userId) ?? '';
      final parts = raw.split('|');
      final at = parts.length > 1 ? DateTime.tryParse(parts[1]) : null;
      if (parts.first != uid ||
          at == null ||
          DateTime.now().difference(at) > _kFreshFor ||
          prefs.getBool('$_kDonePrefix$uid') == true) {
        prefs.remove(kPendingKey);
        return;
      }

      // 2. Normal, unpaid, no trial yet.
      final user = auth.logInUser;
      final token = prefs.getString(Constants.accessToken) ?? '';
      if (user == null || token.isEmpty) return;
      if (prefs.getBool(Constants.isGuest) == true ||
          auth.loginAsA.value != Constants.user) {
        return;
      }
      if (home.hasRealPlan == true ||
          auth.trialActivated.value ||
          home.trialLive.value ||
          home.isFreeTrialUser.value) {
        prefs.remove(kPendingKey);
        return;
      }

      // 3. Trial length (and "no trial yet") fresh from the server.
      // Oct 2026: the three look-ups run AT THE SAME TIME (they used to run
      // one after the other, then wait 1.5 s more), so the sheet shows
      // right after "Get Started". Cycle / class give up after 2.5 s and
      // the sheet shows without them.
      final cycleF = _cycle(token)
          .timeout(const Duration(milliseconds: 2500), onTimeout: () => null);
      final classF = _firstClass()
          .timeout(const Duration(milliseconds: 2500), onTimeout: () => null);
      final res = await home.homeRepo
          .getMyTrial(accessToken: token)
          .timeout(const Duration(seconds: 6));
      final body = res.body;
      if (res.statusCode != 200 || body is! Map || '${body['status']}' != '1') {
        return; // try again next open
      }
      final data = body['data'];
      if (data is Map && data['journey'] != null) {
        prefs.remove(kPendingKey);
        return;
      }
      final days = int.tryParse('${data is Map ? data['trialDays'] : ''}');
      if (days == null || days <= 0) return;
      home.trialDays.value = days;

      // Her answers.
      final name = user.firstName.trim().split(RegExp(r'\s+')).first;
      final goal = auth.mainGoal.value.trim();
      final conds = auth.healthConditions.value
          .toLowerCase()
          .split(',')
          .map((s) => s.trim())
          .toSet();
      // First ticked condition, in this order (PCOD counts as PCOS).
      String? condition;
      for (final c in const ['pcos', 'thyroid', 'diabetes', 'endometriosis', 'arthritis']) {
        if (conds.contains(c) || (c == 'pcos' && conds.contains('pcod'))) {
          condition = c;
          break;
        }
      }
      final cycle = await cycleF;
      final firstClass = await classF;

      // 4. Its turn (short wait: it's the first thing she should see).
      await PopupManager.runFirstLanding(
        wait: const Duration(milliseconds: 250),
        'trial_welcome',
        () async {
          await prefs.remove(kPendingKey);
          // She may have started the trial while it waited for its turn.
          if (auth.trialActivated.value || home.trialLive.value) return;
          await prefs.setBool('$_kDonePrefix$uid', true);
          await Get.bottomSheet<void>(
            _TrialWelcomeView(
              name: name,
              goal: goal,
              condition: condition,
              cycle: cycle,
              firstClass: firstClass,
              days: days,
            ),
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            barrierColor: Colors.black.withValues(alpha: 0.45),
          );
        },
      );
    } catch (e) {
      debugPrint('[trial_welcome] skipped: $e');
    } finally {
      _checking = false;
    }
  }

  /// The real next live class: the one live/next today, else the first
  /// coming up (today or tomorrow). "Today 6:00 PM · Strength with Hira".
  /// Null if there is none.
  static Future<String?> _firstClass() async {
    try {
      if (!Get.isRegistered<PaidHomeController>()) return null;
      final paid = Get.find<PaidHomeController>();
      if (paid.dashboard.value == null) await paid.loadDashboard();
      final d = paid.dashboard.value;
      if (d == null) return null;
      String? type, trainer, start;
      int day = 0;
      bool liveNow = false;
      final l = d.live;
      if (l != null && (l.start ?? '').trim().isNotEmpty) {
        type = l.classType;
        trainer = l.trainerName;
        start = l.start;
        day = l.dayOffset;
        liveNow = (l.status ?? '').toLowerCase() == 'in progress';
      } else if (d.comingUp.isNotEmpty) {
        final c = d.comingUp.first;
        type = c.classType;
        trainer = c.trainerName;
        start = c.start;
        day = c.dayOffset ?? 0;
      }
      if (start == null || start.trim().isEmpty) return null;
      if (day > 1) return null; // only today / tomorrow
      final t = start.trim().replaceFirst(RegExp(r'^0'), '');
      final when = liveNow ? 'Live now' : '${day == 0 ? 'Today' : 'Tomorrow'} $t';
      final what = (type ?? 'Live class').trim();
      final who = (trainer ?? '').trim();
      return '$when · $what${who.isEmpty ? '' : ' with ${who.split(RegExp(r'\s+')).first}'}';
    } catch (_) {
      return null;
    }
  }

  /// Her cycle day + phase from the sign-up period date. Null if she
  /// skipped it, or her period is late (a phase line would be wrong).
  static Future<_Cycle?> _cycle(String token) async {
    try {
      if (!Get.isRegistered<CycleDataRepository>()) return null;
      final res =
          await Get.find<CycleDataRepository>().getCycleData(accessToken: token);
      final body = res.body;
      if (body is! Map || '${body['status']}' != '1' || body['data'] is! Map) {
        return null;
      }
      final d = body['data'] as Map;
      final p = d['dataProvided'];
      if (!(p == 1 || p == true || p == '1') || d['lastPeriodDate'] == null) {
        return null;
      }
      final len = int.tryParse('${d['averageCycleLength'] ?? 28}') ?? 28;
      final info = CycleEngine.calculate(
        lastPeriodDate: DateTime.tryParse('${d['lastPeriodDate']}'),
        cycleLength: len,
      );
      if (info == null || info.cycleDay < 1 || info.cycleDay > len) return null;
      final reg = '${d['isRegular'] ?? ''}'.toLowerCase();
      return _Cycle(info, approximate: reg == 'no' || reg == 'not sure');
    } catch (_) {
      return null;
    }
  }
}

class _Cycle {
  _Cycle(this.info, {this.approximate = false});
  final CycleInfo info;
  final bool approximate; // her cycle is irregular / not sure
}

class _TrialWelcomeView extends StatelessWidget {
  const _TrialWelcomeView({
    required this.name,
    required this.goal,
    required this.condition,
    required this.cycle,
    required this.firstClass,
    required this.days,
  });

  final String name;
  final String goal;
  final String? condition; // pcos | thyroid | diabetes | endometriosis | arthritis
  final _Cycle? cycle;
  final String? firstClass;
  final int days;

  static const Color _green = Color(0xFF6DC55A);
  static const Color _ink = Color(0xFF163220);
  static const Color _sage = Color(0xFF6F8B7A);
  static const Color _line = Color(0xFFE3ECDD);
  static const Color _wash = Color(0xFFF2F9EE);

  static const Map<String, List<String>> _phase = {
    'menstrual': ['Period phase', 'Rest is strength this week; gentle movement helps.'],
    'follicular': ['Follicular phase', 'Your energy is rising; a good week to start.'],
    'ovulatory': ['Ovulation phase', 'Your energy is at its peak this week.'],
    'luteal': ['Luteal phase', 'Calm, steady movement suits you now.'],
  };

  /// [bold, rest] for her goal (+ first ticked condition). Approved copy,
  /// Oct 2026.
  List<String> _goalLine() {
    final g = goal.toLowerCase();
    final lose = g == 'lose weight';
    final gain = g == 'gain weight';
    final String bold;
    String rest;
    if (lose) {
      bold = 'Lose weight';
      rest = 'steadily. No crash diets; meals and movement matched to your cycle.';
    } else if (gain) {
      bold = 'Gain weight';
      rest = 'the healthy way. Real food and strength work, so you build strength, not just fat.';
    } else if (g == 'build strength & tone') {
      bold = 'Build strength & tone.';
      rest = 'Strength classes timed to the days your body is strongest.';
    } else if (g == 'improve fitness') {
      bold = 'Improve your fitness.';
      rest = 'Stamina that builds week by week, at a pace you can keep.';
    } else if (g == 'reduce stress') {
      bold = 'Feel calmer.';
      rest = 'Yoga and gentle movement for the days your body needs rest.';
    } else {
      bold = goal.isEmpty ? 'Your plan.' : '$goal.';
      rest = 'Movement and meals matched to you.';
    }
    switch (condition) {
      case 'pcos':
        return [
          lose ? 'Lose weight with PCOS.' : gain ? 'Gain weight with PCOS.' : '$bold',
          lose
              ? "It's slower with PCOS. That's hormones, not you. We plan around them."
              : gain
                  ? 'With PCOS, gaining well means steady blood sugar, not just more food. We plan for that.'
                  : 'With PCOS, your energy shifts more. Your plan follows it.',
        ];
      case 'thyroid':
        return [
          lose ? 'Lose weight with thyroid.' : gain ? 'Gain weight with thyroid.' : '$bold',
          lose
              ? "A slow thyroid makes weight loss harder. That's your body, not your effort. We plan around it."
              : gain
                  ? 'Thyroid can make gaining harder. We build up slowly and steadily.'
                  : 'Thyroid affects your energy. Your plan goes at your pace.',
        ];
      case 'diabetes':
        return [
          lose ? 'Lose weight with diabetes.' : gain ? 'Gain weight with diabetes.' : '$bold',
          lose
              ? 'Meals planned to keep your blood sugar steady while you lose.'
              : gain
                  ? 'Gaining with steady blood sugar: we plan every meal for it.'
                  : 'Meals planned to keep your blood sugar steady.',
        ];
      case 'endometriosis':
        return [lose || gain ? '$bold.' : bold, 'Gentle on painful days, stronger on good ones.'];
      case 'arthritis':
        return [lose || gain ? '$bold.' : bold, 'Low-impact movement, kind to your joints.'];
    }
    if (lose || gain) return ['$bold,', rest];
    return [bold, rest];
  }

  // Oct 2026 "wow" version: her cycle wheel (same as sign-up / login),
  // a headline about her, and her first free days, day by day.
  static const Map<String, String> _phaseMeals = {
    'menstrual': 'Iron-rich, comforting food for your period days',
    'follicular': 'Lighter meals for your high-energy days',
    'ovulatory': 'Fresh, protein-rich meals for your peak days',
    'luteal': 'Warm, filling meals that keep cravings calm',
  };

  String get _goalWords {
    final g = goal.toLowerCase();
    final base = g.contains('lose')
        ? 'lose weight'
        : g.contains('gain')
            ? 'gain weight'
            : g.contains('strength')
                ? 'build strength'
                : g.contains('fitness')
                    ? 'improve your fitness'
                    : g.contains('stress')
                        ? 'feel calmer'
                        : 'feel your best';
    const named = {'pcos': 'PCOS', 'thyroid': 'thyroid', 'diabetes': 'diabetes'};
    final c = named[condition];
    return c == null ? base : '$base with $c';
  }

  Widget _dayCard(int i, String day, String title, String sub, {bool today = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: today ? const Color(0xFFF7FCF4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: today ? _green : _line, width: today ? 1.4 : 1),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: today ? _green : _wash,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('DAY',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: today ? Colors.white : _sage)),
            Text(day,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    color: today ? Colors.white : const Color(0xFF3E8E36))),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
              Text(title,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
              if (today)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(20)),
                  child: const Text('TODAY',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
            ]),
            const SizedBox(height: 1),
            Text(sub,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, height: 1.4, color: _sage)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calm = Motion.calm(context);
    final c = cycle;
    final phaseKey = c?.info.phase;
    final ph = phaseKey == null ? null : _phase[phaseKey];
    final w = MediaQuery.sizeOf(context).width;
    final wheel = (w * 0.4).clamp(120.0, 170.0);

    // Her first free days. Real class time/trainer when there is one.
    final fc = firstClass;
    final lastDay = days < 3 ? days : 3;
    final cards = <Widget>[
      fc != null
          ? _dayCard(0, '1', 'Your first live class', '$fc · women only', today: true)
          : _dayCard(0, '1', 'Your meal plan, made for you', 'Ready right after your 1-minute setup', today: true),
      if (days >= 2)
        _dayCard(
          1,
          '2',
          ph != null ? 'Meals for your ${ph[0].toLowerCase()}' : 'Meals made for you',
          ph != null
              ? (_phaseMeals[phaseKey] ?? 'Food that matches your cycle')
              : 'Built around your goal and what you like',
        ),
      if (days >= 3)
        _dayCard(2, '$lastDay', 'Your first progress snapshot', 'Weight, energy and cycle, side by side'),
    ];

    Widget anim(Widget child, int i) => calm
        ? child
        : child
            .animate()
            .fadeIn(delay: (450 + i * 180).ms, duration: 450.ms)
            .slideY(begin: 0.2, end: 0, delay: (450 + i * 180).ms, duration: 450.ms);

    Widget sheet = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 10, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFDCE6D7), borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 8),
          // Same wheel as the sign-up / login screens.
          SizedBox(
            height: wheel * 1.15,
            child: Center(
              child: RepaintBoundary(child: AnimatedCycleWheel(size: wheel, showCaption: false)),
            ),
          ),
          if (c != null && ph != null) ...[
            const SizedBox(height: 4),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: _wash, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '🌸 Day ${c.info.cycleDay} · ${ph[0]}${c.approximate ? ' (approx.)' : ''}',
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3E8E36)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            name.isEmpty ? 'WELCOME' : 'WELCOME, ${name.toUpperCase()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Color(0xFF3E8E36)),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Your plan, built for '),
              TextSpan(
                text: ph != null ? 'your ${ph[0].toLowerCase()}' : 'you',
                style: const TextStyle(color: _green),
              ),
            ]),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 21, fontWeight: FontWeight.w800, height: 1.22, color: _ink),
          ),
          const SizedBox(height: 4),
          Text(
            'To help you $_goalWords, here are your first $days free day${days == 1 ? '' : 's'}:',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, height: 1.45, color: _sage),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < cards.length; i++) anim(cards[i], i),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in const ['💬 Community', '📈 Progress report', '🔒 Women only'])
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFF4F7F2), borderRadius: BorderRadius.circular(20)),
                  child: Text(t, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: _sage)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Get.back();
                enterTrialOnboarding();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Build my plan · 1 min →',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$days day${days == 1 ? '' : 's'} free · your meals are made right after',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: _sage),
          ),
          Center(
            child: TextButton(
              onPressed: () => Get.back(),
              child: const Text('Maybe later',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _sage)),
            ),
          ),
        ],
      ),
    );

    if (!calm) {
      sheet = sheet.animate().fadeIn(duration: Motion.fast, curve: Motion.ease);
    }
    return SafeArea(top: true, bottom: false, child: SingleChildScrollView(child: sheet));
  }

  Widget _row(String icon, String bold, String rest) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _wash,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(icon, style: const TextStyle(fontSize: 15)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    height: 1.4,
                    color: _ink,
                  ),
                  children: [
                    TextSpan(
                      text: '$bold ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: rest, style: const TextStyle(color: _sage)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
