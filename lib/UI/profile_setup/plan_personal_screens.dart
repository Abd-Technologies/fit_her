import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../auth_module/walt_through/animated_cycle_wheel.dart';

/// Oct 2026: the "your plan just got personal" journey for paid clients
/// whose profile is incomplete (mostly old clients after the update).
///
///   PlanPersonalIntro   once per user, before the first question
///   PartOneDoneScreen   between "About you" and "Your health"
///   ProfileDoneScreen   the reward at the end
///
/// Wording follows her package: diet, workout, or both ("combined").

const _ink = Color(0xFF163220);
const _sub = Color(0xFF5F7A5D);
const _muted = Color(0xFF8A9A88);
const _green = Color(0xFF6DC55A);
const _deep = Color(0xFF3E8E36);
const _wash = Color(0xFFEAF6E4);
const _line = Color(0xFFDCE8D6);

TextStyle _t(double size, {FontWeight w = FontWeight.w400, Color c = _ink, double? h}) =>
    TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: w, color: c, height: h);

bool _hasDiet(String planType) => planType == 'diet' || planType == 'combined';
bool _hasWorkout(String planType) => planType == 'workout' || planType == 'combined';

String _team(String planType) => planType == 'combined'
    ? 'Your dietitian and trainer'
    : planType == 'workout'
        ? 'Your trainer'
        : 'Your dietitian';

String _firstName() {
  try {
    final n = (Get.find<AuthController>().logInUser?.firstName ?? '').trim();
    return n.split(' ').first;
  } catch (_) {
    return '';
  }
}

String get _uid {
  try {
    return (Get.find<AuthController>().logInUser?.id ?? '').toString();
  } catch (_) {
    return '';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// "Every day in Fit Her": what she can use daily, by package. Shared by
// the done screen and the paid "Welcome to Fit Her" pop-up.
// ═══════════════════════════════════════════════════════════════════════

List<(String, Color, String, String)> everydayFeatures(String planType) => [
      ('💡', const Color(0xFFFFF6DD), "Today's insight", 'A new tip every day for your cycle phase'),
      if (_hasDiet(planType))
        ('🥗', const Color(0xFFEAF6E4), 'Your meal plan', 'Made by your dietitian, log meals in a tap'),
      if (_hasWorkout(planType))
        ('🧘', const Color(0xFFF1ECFB), 'Live classes', 'Women-only, join any class of the day'),
      ('📈', const Color(0xFFEAF3FB), 'Weekly check-in', 'See your weight and progress change'),
      ('👭', const Color(0xFFFBEAF0), 'Community', 'Share wins and ask women like you'),
    ];

/// Compact list for small spaces (the welcome pop-up).
class EverydayInFitHer extends StatelessWidget {
  final String planType;
  const EverydayInFitHer({super.key, required this.planType});

  @override
  Widget build(BuildContext context) {
    final items = everydayFeatures(planType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EVERY DAY IN FIT HER', style: _t(10.5, w: FontWeight.w700, c: _muted).copyWith(letterSpacing: 0.8)),
        const SizedBox(height: 8),
        for (final (i, f) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: f.$2, borderRadius: BorderRadius.circular(9)),
                  child: Text(f.$1, style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.$3, style: _t(12.5, w: FontWeight.w600, h: 1.25)),
                      Text(f.$4, style: _t(10.5, c: _muted, h: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: (500 + i * 110).ms, duration: 350.ms).slideX(begin: 0.06, end: 0),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 1. Intro
// ═══════════════════════════════════════════════════════════════════════

class PlanPersonalIntro extends StatelessWidget {
  final String planType;
  final int parts;
  const PlanPersonalIntro({super.key, required this.planType, required this.parts});

  static String get _seenKey => 'plan_intro_seen_$_uid';

  /// Shown once per user (kept across logout).
  static bool seen() {
    try {
      return Get.find<AuthController>().sharedPreferences.getBool(_seenKey) ?? false;
    } catch (_) {
      return true;
    }
  }

  /// true = "Let's do it", false = "Later" / back.
  static Future<bool> show({required String planType, required int parts}) async {
    try {
      await Get.find<AuthController>().sharedPreferences.setBool(_seenKey, true);
    } catch (_) {}
    final r = await Get.to<bool>(
      () => PlanPersonalIntro(planType: planType, parts: parts),
      fullscreenDialog: true,
      transition: Transition.fadeIn,
    );
    return r == true;
  }

  List<(String, Color, String, String)> get _benefits {
    final team = _team(planType);
    return [
      if (_hasDiet(planType))
        ('🔥', const Color(0xFFFFF0E6), 'Calories set for your body', "Not an average woman's")
      else
        ('💪', const Color(0xFFFFF0E6), 'Workouts at the right intensity', 'Matched to your body and fitness'),
      (
        '🌸',
        const Color(0xFFFBEAF0),
        planType == 'combined'
            ? 'Meals and workouts that follow your cycle'
            : planType == 'workout'
                ? 'Training that follows your cycle'
                : 'Meals that follow your cycle',
        'Easier days when your body needs them'
      ),
      ('🩺', const Color(0xFFEAF3FB), '$team ${planType == 'combined' ? 'know' : 'knows'} what\'s safe for you',
          planType == 'workout' ? 'Before your next class' : 'Before your first call'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final name = _firstName();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Get.back<bool>(result: false);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF1F9EC), Colors.white],
              stops: [0, 0.46],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Get.back<bool>(result: false),
                    child: Text('Later', style: _t(13, w: FontWeight.w600, c: _muted)),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: _CycleHero(planType: planType)),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: _wash, borderRadius: BorderRadius.circular(20)),
                          child: Text('NEW IN FIT HER',
                              style: _t(10.5, w: FontWeight.w700, c: _deep).copyWith(letterSpacing: 0.8)),
                        ),
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(children: [
                            const TextSpan(text: 'Your plan just got '),
                            TextSpan(text: 'personal', style: _t(25, w: FontWeight.w800, c: _green)),
                            const TextSpan(text: ' 💚'),
                          ]),
                          style: _t(25, w: FontWeight.w800, h: 1.18),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${name.isEmpty ? '' : '$name, '}tell us a few things and your plan stops being "one size fits all".',
                          style: _t(13, c: _sub, h: 1.5),
                        ),
                        const SizedBox(height: 18),
                        for (final (i, b) in _benefits.indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BenefitRow(emoji: b.$1, bg: b.$2, title: b.$3, sub: b.$4)
                                .animate()
                                .fadeIn(delay: (250 + i * 150).ms, duration: 450.ms)
                                .slideY(begin: 0.25, end: 0, delay: (250 + i * 150).ms, duration: 450.ms),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < parts; i++)
                            Container(
                              width: 22,
                              height: 5,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: i == 0 ? _green : _line,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          const SizedBox(width: 6),
                          Text(
                            parts > 1 ? 'About 2 minutes · $parts short parts' : 'About 1 minute',
                            style: _t(11.5, c: _sub),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _PrimaryButton(label: "Let's do it", onTap: () => Get.back<bool>(result: true)),
                      const SizedBox(height: 9),
                      Text('🔒 Private to you and your Fit Her team', style: _t(10.5, c: _muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The same animated cycle wheel as the Get Started screen (Oct 2026),
/// so the update feels like part of the Fit Her she knows.
class _CycleHero extends StatelessWidget {
  final String planType;
  const _CycleHero({required this.planType});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final size = math.min(w * 0.56, 220.0);
    return SizedBox(
      height: size * 1.2,
      child: Center(
        child: RepaintBoundary(child: AnimatedCycleWheel(size: size, showCaption: false)),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String emoji;
  final Color bg;
  final String title;
  final String sub;
  const _BenefitRow({required this.emoji, required this.bg, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _t(13.5, w: FontWeight.w600, h: 1.35)),
              Text(sub, style: _t(11.5, c: _muted, h: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _PrimaryButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          disabledBackgroundColor: _green.withOpacity(0.45),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: _t(15, w: FontWeight.w600, c: Colors.white)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Shared: her numbers from Home (calories, cycle phase)
// ═══════════════════════════════════════════════════════════════════════

class _Numbers {
  final int? kcal;
  final String? phase;
  final int? cycleDay;
  const _Numbers(this.kcal, this.phase, this.cycleDay);
}

/// Reloads Home so the numbers reflect what she just saved.
Future<_Numbers> _loadNumbers() async {
  try {
    if (!Get.isRegistered<PaidHomeController>()) return const _Numbers(null, null, null);
    final h = Get.find<PaidHomeController>();
    // Home may already be reloading (it returns at once then, with the
    // OLD numbers from before she saved). Wait for it, load fresh, wait.
    Future<void> settle() async {
      for (var i = 0; i < 60 && h.isLoading.value; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }
    await settle();
    await h.loadDashboard().timeout(const Duration(seconds: 12));
    await settle();
    final d = h.dashboard.value;
    return _Numbers(d?.stats?.dailyKcalBudget, d?.cycle?.phaseLabel, d?.cycle?.cycleDay);
  } catch (_) {
    return const _Numbers(null, null, null);
  }
}

class _Fact {
  final String emoji;
  final String text;
  const _Fact(this.emoji, this.text);
}

Widget _factRow(_Fact f, int i) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Text(f.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(child: Text(f.text, style: _t(13.5, w: FontWeight.w500, h: 1.35))),
          const Icon(Icons.check_circle_rounded, color: _green, size: 20),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (150 + i * 140).ms, duration: 400.ms)
        .slideX(begin: 0.08, end: 0, delay: (150 + i * 140).ms, duration: 400.ms);

// ═══════════════════════════════════════════════════════════════════════
// 2. Part 1 done
// ═══════════════════════════════════════════════════════════════════════

class PartOneDoneScreen extends StatefulWidget {
  final String planType;
  final Future<void> Function() work;
  const PartOneDoneScreen({super.key, required this.planType, required this.work});

  /// Shows right after "About you" while [work] runs behind it.
  /// true = Continue to part 2, false = Finish later.
  static Future<bool> show({required String planType, required Future<void> Function() work}) async {
    final r = await Get.to<bool>(
      () => PartOneDoneScreen(planType: planType, work: work),
      transition: Transition.fadeIn,
    );
    return r == true;
  }

  @override
  State<PartOneDoneScreen> createState() => _PartOneDoneScreenState();
}

class _PartOneDoneScreenState extends State<PartOneDoneScreen> {
  bool _ready = false;
  _Numbers _n = const _Numbers(null, null, null);

  @override
  void initState() {
    super.initState();
    Future.wait([
      widget.work().catchError((_) {}),
      _loadNumbers().then((n) => _n = n),
    ]).whenComplete(() {
      if (mounted) setState(() => _ready = true);
    });
  }

  bool get _workoutOnly => _hasWorkout(widget.planType) && !_hasDiet(widget.planType);

  /// Her own answers, as the "why" behind the number.
  List<String> get _chips {
    final out = <String>[];
    try {
      final auth = Get.find<AuthController>();
      final age = int.tryParse(auth.editAge.text.trim());
      final kg = double.tryParse(auth.editWeight.text.trim());
      final ft = double.tryParse(auth.editHeight.text.trim());
      final goal = auth.mainGoal.value.trim();
      if (age != null) out.add('$age yrs');
      if (kg != null) out.add('${kg.round()} kg');
      if (ft != null && ft > 0) {
        final f = ft.floor();
        final inch = ((ft - f) * 12).round();
        out.add("$f' $inch\"");
      }
      if (goal.isNotEmpty) out.add(goal);
    } catch (_) {}
    return out;
  }

  /// Lose / Gain weight: why the number differs from "normal" (only
  /// when the ring shows calories).
  String? get _goalLine {
    if (_workoutOnly || _n.kcal == null) return null;
    try {
      final g = Get.find<AuthController>().mainGoal.value.toLowerCase();
      if (g.contains('lose')) return 'Includes a gentle deficit to lose weight';
      if (g.contains('gain')) return 'Includes a gentle surplus to gain weight';
    } catch (_) {}
    return null;
  }

  /// What Part 2 asks, by package.
  List<(String, Color, String)> get _next {
    switch (widget.planType) {
      case 'workout':
        return const [
          ('🩺', Color(0xFFEAF3FB), 'Health conditions & injuries'),
          ('💪', Color(0xFFFFF0E6), 'Your fitness level'),
          ('🔔', Color(0xFFF1ECFB), 'Your 2 class times'),
        ];
      case 'combined':
        return const [
          ('🩺', Color(0xFFEAF3FB), 'Allergies & health conditions'),
          ('🥗', Color(0xFFEAF6E4), 'Food you like, meals a day'),
          ('🧘', Color(0xFFF1ECFB), 'Fitness level & class times'),
        ];
      default:
        return const [
          ('🩺', Color(0xFFEAF3FB), 'Allergies & health conditions'),
          ('🥗', Color(0xFFEAF6E4), 'Food you like, meals a day'),
          ('✅', Color(0xFFFFF6DD), 'A quick review'),
        ];
    }
  }

  /// Ring centre + headline: kcal (diet / both), cycle day (workout), or
  /// a plain "saved" line when the number isn't there.
  (String headline, String? big, String? unit, String why) get _content {
    if (!_workoutOnly && _n.kcal != null) {
      final k = _n.kcal!;
      final big = k >= 1000 ? '${k ~/ 1000},${(k % 1000).toString().padLeft(3, '0')}' : '$k';
      return ('Your daily calories are set', big, 'kcal a day', 'Worked out from what you told us');
    }
    if (_n.phase != null && _n.cycleDay != null) {
      return ('Your plan now follows your cycle', 'Day ${_n.cycleDay}', '${_n.phase}',
          'From your period date');
    }
    return (
      _workoutOnly ? 'Your workouts are tuned to your body' : 'Your body numbers are saved',
      null,
      null,
      'From what you told us'
    );
  }

  Widget _steps() {
    Widget dot(bool done, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? _green : Colors.white,
              border: done ? null : Border.all(color: _line, width: 1.5),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : Text('2', style: _t(11.5, w: FontWeight.w700, c: _muted)),
          ),
          const SizedBox(width: 6),
          Text(label, style: _t(12, w: FontWeight.w600, c: done ? _ink : _muted)),
        ]);
    return Row(children: [
      dot(true, 'About you'),
      const SizedBox(width: 10),
      Expanded(
        child: Container(
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: const LinearGradient(colors: [_green, _green, _line, _line], stops: [0, 0.5, 0.5, 1]),
          ),
        ),
      ),
      const SizedBox(width: 10),
      dot(false, _workoutOnly ? 'Health & fitness' : 'Your health'),
    ]);
  }

  Widget _ring(String? big, String? unit) {
    return SizedBox(
      width: 176,
      height: 176,
      child: Stack(alignment: Alignment.center, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1.0),
          duration: const Duration(milliseconds: 1300),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => CustomPaint(size: const Size(176, 176), painter: _RingPainter(v)),
        ),
        if (big != null)
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(big, style: _t(36, w: FontWeight.w800, c: _deep, h: 1)),
            const SizedBox(height: 4),
            Text(unit ?? '', textAlign: TextAlign.center, style: _t(11.5, c: _sub)),
          ])
        else
          const Icon(Icons.check_rounded, color: _deep, size: 56),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (headline, big, unit, why) = _content;
    final chips = _chips;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _ready) Get.back<bool>(result: false);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEEF8E9), Colors.white],
              stops: [0, 0.42],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _steps(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => SingleChildScrollView(
                      child: ConstrainedBox(
                      // Fills the free space, so the block sits in the
                      // middle instead of leaving a hole above "Next".
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 22),
                          Text('PART 1 DONE', style: _t(12, w: FontWeight.w700, c: _deep).copyWith(letterSpacing: 0.8)),
                          const SizedBox(height: 4),
                          Text(_ready ? headline : 'Working out your numbers…',
                              style: _t(23, w: FontWeight.w800, h: 1.2)),
                          const SizedBox(height: 18),
                          Center(
                            child: _ready
                                ? _ring(big, unit)
                                : const SizedBox(
                                    width: 176,
                                    height: 176,
                                    child: Center(
                                      child: SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: _green),
                                      ),
                                    ),
                                  ),
                          ),
                          if (_ready) ...[
                            const SizedBox(height: 8),
                            Center(child: Text(why, textAlign: TextAlign.center, style: _t(11.5, c: _sub))),
                            if (chips.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    for (final c in chips)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: _line),
                                        ),
                                        child: Text(c, style: _t(11, w: FontWeight.w600)),
                                      ),
                                  ],
                                ),
                              ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
                            ],
                            if (_goalLine != null) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: Text(_goalLine!, textAlign: TextAlign.center, style: _t(11.5, c: _muted)),
                              ).animate().fadeIn(delay: 750.ms, duration: 400.ms),
                            ],
                          ],
                          const SizedBox(height: 18),
                        ],
                      ),
                      ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(_workoutOnly ? 'Next: your health & fitness' : 'Next: your health',
                                style: _t(12.5, w: FontWeight.w700)),
                          ),
                          Text('about 1 min', style: _t(11.5, c: _muted)),
                        ]),
                        const SizedBox(height: 6),
                        for (final (e, bg, label) in _next)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                                child: Text(e, style: const TextStyle(fontSize: 13)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(label, style: _t(12.5))),
                            ]),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PrimaryButton(
                    label: _ready ? 'Continue' : 'One moment…',
                    onTap: _ready ? () => Get.back<bool>(result: true) : null,
                  ),
                  TextButton(
                    onPressed: _ready ? () => Get.back<bool>(result: false) : null,
                    child: Text('Finish later', style: _t(13, w: FontWeight.w500, c: _muted)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Progress ring that fills in (0..1), green gradient on a pale track.
class _RingPainter extends CustomPainter {
  final double value;
  const _RingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(8);
    canvas.drawArc(r, 0, 2 * math.pi, false,
        Paint()
          ..color = const Color(0xFFE8F1E3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13);
    if (value <= 0) return;
    canvas.drawArc(
      r,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..shader = const SweepGradient(
          colors: [Color(0xFF9BD88A), Color(0xFF3E8E36)],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(r)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value;
}

// ═══════════════════════════════════════════════════════════════════════
// 3. Done
// ═══════════════════════════════════════════════════════════════════════

class ProfileDoneScreen extends StatefulWidget {
  final String planType;
  const ProfileDoneScreen({super.key, required this.planType});

  static Future<void> show({required String planType}) async {
    await Get.to<void>(
      () => ProfileDoneScreen(planType: planType),
      transition: Transition.fadeIn,
    );
  }

  @override
  State<ProfileDoneScreen> createState() => _ProfileDoneScreenState();
}

class _ProfileDoneScreenState extends State<ProfileDoneScreen> {
  _Numbers? _n;

  @override
  void initState() {
    super.initState();
    _loadNumbers().then((n) {
      if (mounted) setState(() => _n = n);
    });
  }

  List<_Fact> get _facts {
    final p = widget.planType;
    final n = _n!;
    return [
      if (_hasDiet(p) && n.kcal != null) _Fact('🔥', '${n.kcal} kcal a day, set for your body'),
      if (n.phase != null && n.cycleDay != null) _Fact('🌸', 'Today: ${n.phase} · day ${n.cycleDay}'),
      if (_hasWorkout(p)) const _Fact('💪', 'Workouts matched to your fitness'),
      _Fact('🩺', '${_team(p)} can see your health form'),
    ];
  }

  List<(String, Color, String, String)> get _features => everydayFeatures(widget.planType);

  Widget _featureRow((String, Color, String, String) f, int i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _BenefitRow(emoji: f.$1, bg: f.$2, title: f.$3, sub: f.$4),
      )
          .animate()
          .fadeIn(delay: (200 + i * 120).ms, duration: 400.ms)
          .slideY(begin: 0.2, end: 0, delay: (200 + i * 120).ms, duration: 400.ms);

  @override
  Widget build(BuildContext context) {
    final name = _firstName();
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF6E4), Colors.white],
            stops: [0, 0.5],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 18),
            child: Column(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 54))
                    .animate()
                    .scale(begin: const Offset(0.4, 0.4), end: const Offset(1, 1), duration: 500.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 14),
                Text('Your plan now knows you', textAlign: TextAlign.center, style: _t(25, w: FontWeight.w800, h: 1.2)),
                const SizedBox(height: 6),
                Text(
                  '${name.isEmpty ? 'Thank you' : 'Thank you, $name'}. Here\'s what just changed:',
                  textAlign: TextAlign.center,
                  style: _t(13, c: _sub, h: 1.5),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _n == null
                      ? const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: _green),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final (i, f) in _facts.indexed) _factRow(f, i),
                            const SizedBox(height: 14),
                            Text('EVERY DAY IN FIT HER',
                                style: _t(11, w: FontWeight.w700, c: _muted).copyWith(letterSpacing: 0.8))
                                .animate()
                                .fadeIn(delay: (250 + _facts.length * 140).ms),
                            const SizedBox(height: 10),
                            for (final (i, f) in _features.indexed)
                              _featureRow(f, _facts.length + 1 + i),
                          ],
                        ),
                ),
                _PrimaryButton(label: 'See my plan', onTap: () => Get.back<void>()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
