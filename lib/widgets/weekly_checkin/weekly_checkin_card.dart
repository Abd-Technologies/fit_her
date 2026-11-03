import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../anim/motion.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import 'weekly_checkin_sheet.dart';

/// Paid home: the one weekly check-in card (Oct 2026). Shows only while a
/// check-in is due, with the label for her week (Week 1 / Weekly /
/// Halfway / End of plan). Opens WeeklyCheckinSheet. Never pops up by
/// itself.
class WeeklyCheckinCard extends StatefulWidget {
  const WeeklyCheckinCard({super.key});

  @override
  State<WeeklyCheckinCard> createState() => _WeeklyCheckinCardState();
}

class _WeeklyCheckinCardState extends State<WeeklyCheckinCard> {
  static const _ink = Color(0xFF1A3A22);
  static const _sage = Color(0xFF7A8C78);
  static const _accent = Color(0xFF6DC55A);
  static const _wash = Color(0xFFF6FBF3);
  static const _line = Color(0xFFEFF4EC);

  bool _done = true;

  // Animation pass (#10):
  //  - a small nudge (chevron wiggle + soft halo on the icon) the first
  //    time the card shows in this app session;
  //  - after she saves, a green tick pops in, then the card folds away
  //    smoothly instead of vanishing.
  static bool _nudgedThisSession = false;
  bool _playNudge = false;
  bool _justDone = false;
  bool _collapsing = false;

  // The server decides if a check-in is due and which one (week 1,
  // weekly, halfway, end of plan): helper/weeklyCheckin.js. Every 7 days
  // from her first shared diet plan (plan start for workout only).
  WeeklyCheckinState? _state;

  @override
  void initState() {
    super.initState();
    _done = true; // hidden until we know she has one due
    _decide();
  }

  Future<void> _decide() async {
    if (Get.isRegistered<HomeController>() && Get.find<HomeController>().isFreeTrialUser.value) return;
    final state = await WeeklyCheckinSheet.loadState();
    if (state == null || !state.due || !mounted) return;
    setState(() {
      _state = state;
      _done = false;
      if (!_nudgedThisSession) {
        _nudgedThisSession = true;
        _playNudge = true;
      }
    });
    // Never opens by itself: the card on Home and the Sunday 7 pm push
    // bring her in.
  }

  Future<void> _open() async {
    final saved = await WeeklyCheckinSheet.open();
    if (saved && mounted) _finish();
  }

  /// Saved: tick, short pause, then fold the card away (reduce motion:
  /// hide straight away, like before).
  void _finish() {
    if (_justDone) return;
    if (Motion.calm(context)) {
      setState(() => _done = true);
      return;
    }
    setState(() => _justDone = true);
    Future.delayed(const Duration(milliseconds: 750), () {
      if (mounted) setState(() => _collapsing = true);
    });
  }

  static const _nudgeDelay = Duration(milliseconds: 600);

  Widget _iconBox(bool calm) {
    Widget box = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: _wash, borderRadius: BorderRadius.circular(12)),
      child: _justDone
          ? (calm
              ? const Icon(Icons.check_rounded, color: _accent, size: 22)
              : const Icon(Icons.check_rounded, color: _accent, size: 22)
                  .animate()
                  .fadeIn(duration: Motion.fast)
                  .scaleXY(begin: 0.3, end: 1, duration: const Duration(milliseconds: 380), curve: Curves.easeOutBack))
          : const Icon(Icons.straighten_outlined, color: _accent, size: 20),
    );
    if (_playNudge && !calm) {
      // Soft green halo that spreads out once and fades.
      box = box.animate(delay: _nudgeDelay).custom(
            duration: Motion.slow,
            curve: Curves.easeOut,
            builder: (context, v, child) => DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.45 * (1 - v)),
                    spreadRadius: 8 * v,
                  ),
                ],
              ),
              child: child,
            ),
          );
    }
    return box;
  }

  Widget _chevron(bool calm) {
    const icon = Icon(Icons.chevron_right_rounded, color: _accent);
    if (!_playNudge || calm) return icon;
    // One small sideways wiggle that settles (damped sine).
    return icon.animate(delay: _nudgeDelay).custom(
          duration: Motion.slow,
          builder: (context, v, child) => Transform.translate(
            offset: Offset(math.sin(v * math.pi * 4) * 5 * (1 - v), 0),
            child: child,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();
    final calm = Motion.calm(context);
    final card = GestureDetector(
      onTap: _justDone ? null : _open,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
          boxShadow: [BoxShadow(color: _ink.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          _iconBox(calm),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!_justDone && _state != null) ...[
                Text(_state!.cardEyebrow.toUpperCase(),
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: _accent, letterSpacing: 0.6)),
                const SizedBox(height: 2),
              ],
              Text(_justDone ? 'Check-in saved' : (_state?.cardTitle ?? 'Weekly check-in'),
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 2),
              Text(
                  _justDone
                      ? 'Nice work. See you next week.'
                      : (_state?.cardSubtitle ?? 'Log your weight and measurements to see your progress.'),
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: _sage, height: 1.35)),
            ]),
          ),
          _chevron(calm),
        ]),
      ),
    );
    // Folds up (height + fade, 400 ms) once _collapsing flips, then the
    // card is removed for good.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: _collapsing ? 0 : 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      onEnd: () {
        if (_collapsing && mounted) setState(() => _done = true);
      },
      builder: (context, t, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: t,
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        ),
      ),
      child: card,
    );
  }
}
