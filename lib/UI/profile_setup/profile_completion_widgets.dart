import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'profile_completion.dart';
import '../../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../../widgets/paid_home_v2/set_target_weight_modal.dart';

const _ink = Color(0xFF163220);
const _sub = Color(0xFF5F7A5D);
const _muted = Color(0xFF8A9A88);
const _green = Color(0xFF6DC55A);
const _deep = Color(0xFF3E8E36);
const _line = Color(0xFFD8EDD4);

TextStyle _t(double size, {FontWeight w = FontWeight.w400, Color c = _ink, double? h}) =>
    TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: w, color: c, height: h);

/// Top of the home body for an old paid client: the "reminders for all
/// classes" note, then the "Finish your profile" checklist. Each hides
/// itself when not needed.
class ProfileCompletionSection extends StatelessWidget {
  const ProfileCompletionSection({super.key});

  @override
  Widget build(BuildContext context) {
    final pc = ProfileCompletion.to;
    return Obx(() {
      final note = pc.showAllClassesNote;
      final card = pc.showCard;
      final complete = pc.showComplete.value && !card;
      if (!note && !card && !complete) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (note) const AllClassesNote(),
            if (note && card) const SizedBox(height: 10),
            if (card) const FinishProfileCard(),
            if (complete) const ProfileCompleteCard(),
          ],
        ),
      );
    });
  }
}

/// "Reminders for all classes": she hasn't picked her 2 class times.
class AllClassesNote extends StatelessWidget {
  const AllClassesNote({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ProfileCompletion.to.openClassTimes,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔔', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Reminders for all classes. ', style: _t(12, w: FontWeight.w600)),
                  TextSpan(
                    text: "You haven't picked your class times yet, so we'll remind you of every class. ",
                    style: _t(12, c: _sub, h: 1.45),
                  ),
                  TextSpan(text: 'Pick my times', style: _t(12, w: FontWeight.w600, c: _deep)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item {
  final String label;
  final bool done;
  final String? time;
  final VoidCallback? onTap;
  // Optional (target weight): shown, but not counted in "N of M" and
  // never locks anything.
  final bool optional;
  const _Item(this.label, this.done, {this.time, this.onTap, this.optional = false});
}

/// "Profile complete 🎉": shown once when the last item is done, for
/// 3 seconds from when she sees it, then it fades and folds away.
class ProfileCompleteCard extends StatefulWidget {
  const ProfileCompleteCard({super.key});

  @override
  State<ProfileCompleteCard> createState() => _ProfileCompleteCardState();
}

class _ProfileCompleteCardState extends State<ProfileCompleteCard> {
  bool _closing = false; // fading out
  bool _gone = false; // folding away

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), _close);
  }

  void _close() {
    if (!mounted || _closing) return;
    setState(() => _closing = true);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _gone = true);
      Future.delayed(const Duration(milliseconds: 350), ProfileCompletion.to.dismissComplete);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      child: AnimatedOpacity(
        opacity: _closing ? 0 : 1,
        duration: const Duration(milliseconds: 350),
        child: _gone ? const SizedBox(width: double.infinity) : _card(),
      ),
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6E4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCFE7C6), width: 1.5),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile complete', style: _t(14.5, w: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Your plan now uses everything you told us.', style: _t(12, c: _sub, h: 1.4)),
              ],
            ),
          ),
          IconButton(
            onPressed: _close,
            icon: const Icon(Icons.close_rounded, size: 18, color: _muted),
          ),
        ],
      ),
    );
  }
}

/// "Finish your profile · 2 min" checklist (approved preview, Oct 2026).
/// Done rows fold into "3 done ✓" (tap to see them); only the next 1–2
/// open rows show.
class FinishProfileCard extends StatefulWidget {
  const FinishProfileCard({super.key});

  @override
  State<FinishProfileCard> createState() => _FinishProfileCardState();
}

class _FinishProfileCardState extends State<FinishProfileCard> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final pc = ProfileCompletion.to;
    return Obx(() {
      final items = <_Item>[
        _Item('About you', !pc.aboutNeeded, time: '1 min', onTap: pc.openAbout),
        if (pc.hasWorkout)
          _Item(
            pc.pickedOwnTimes.value ? 'Class reminders: your times' : 'Class reminders: all classes',
            true,
            onTap: pc.openClassTimes,
          ),
        _Item(
          pc.hasDiet ? 'Health form for your dietitian' : 'Health form for your trainer',
          !pc.healthNeeded,
          time: '90 sec',
          onTap: pc.openForm,
        ),
        if (pc.hasDiet)
          _Item('Food likes & allergies', !pc.foodNeeded, time: '30 sec', onTap: pc.openForm),
        // Target weight (Oct 2026): only for a Lose / Gain weight goal.
        if (_targetApplies())
          _Item(
            '🎯 Target weight',
            _targetSet(),
            time: 'optional',
            optional: true,
            onTap: () {
              final d = Get.find<PaidHomeController>().dashboard.value;
              if (d != null) SetTargetWeightModal.show(context: context, dashboard: d);
            },
          ),
      ];
      final counted = items.where((i) => !i.optional);
      final done = counted.where((i) => i.done).length;
      final total = counted.length;
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCFE7C6), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Oct 2026: same story as the intro screen, so after "Later"
            // she recognises it and continues.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NEW IN FIT HER',
                          style: _t(10, w: FontWeight.w700, c: _deep).copyWith(letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Text('Your plan just got personal 💚', style: _t(15, w: FontWeight.w700)),
                      Text('Finish your profile · 2 min', style: _t(12, c: _muted)),
                    ],
                  ),
                ),
                Text('$done of $total', style: _t(12, c: _muted)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 7,
                backgroundColor: const Color(0xFFE5EFDF),
                valueColor: const AlwaysStoppedAnimation<Color>(_green),
              ),
            ),
            const SizedBox(height: 6),
            ..._rows(items),
            const SizedBox(height: 10),
            // No "Not now" (Oct 2026): the card stays until she's done.
            SizedBox(
              width: double.infinity,
              child: _button('Continue', filled: true, onTap: pc.openNext),
            ),
          ],
        ),
      );
    });
  }

  /// Folded list: "N done ✓", then the next 2 open rows, then "+N more".
  List<Widget> _rows(List<_Item> items) {
    final done = items.where((i) => i.done).toList();
    final open = items.where((i) => !i.done).toList();
    final next = open.take(2).toList();
    final more = open.length - next.length;
    return [
      if (done.isNotEmpty)
        InkWell(
          onTap: () => setState(() => _showDone = !_showDone),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 21,
                  height: 21,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: _green),
                  child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text('${done.length} done', style: _t(13, c: _sub, h: 1.3))),
                Icon(_showDone ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 18, color: _muted),
              ],
            ),
          ),
        ),
      if (_showDone)
        for (final i in done)
          Padding(padding: const EdgeInsets.only(left: 12), child: _row(i)),
      for (final i in next) _row(i),
      if (more > 0)
        Padding(
          padding: const EdgeInsets.only(left: 31, top: 2),
          child: Text('+$more more after these', style: _t(11.5, c: _muted)),
        ),
    ];
  }

  static bool _targetApplies() {
    if (!Get.isRegistered<PaidHomeController>()) return false;
    final d = Get.find<PaidHomeController>().dashboard.value;
    final g = d?.user?.mainGoal;
    return d != null && (g == 'Lose weight' || g == 'Gain weight');
  }

  static bool _targetSet() {
    final d = Get.isRegistered<PaidHomeController>()
        ? Get.find<PaidHomeController>().dashboard.value
        : null;
    return d?.goal?.targetWeightKg != null;
  }

  Widget _row(_Item i) => InkWell(
        onTap: i.done && i.label.startsWith('Class') ? i.onTap : (i.done ? null : i.onTap),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i.done ? _green : Colors.transparent,
                  border: i.done ? null : Border.all(color: const Color(0xFFD2DDCD), width: 1.5),
                ),
                child: i.done ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(i.label, style: _t(13, h: 1.3))),
              if (!i.done && i.time != null) Text(i.time!, style: _t(11, c: _muted)),
            ],
          ),
        ),
      );

  Widget _button(String text, {required bool filled, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: filled ? _green : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: filled ? null : Border.all(color: const Color(0xFFE1EADC)),
          ),
          child: Text(
            text,
            style: _t(13, w: filled ? FontWeight.w600 : FontWeight.w500, c: filled ? Colors.white : _muted),
          ),
        ),
      );
}

/// A card that waits for an answer from her profile, e.g. the Luna tip
/// until she adds her period date.
class ProfileLockedCard extends StatelessWidget {
  final String title;
  final String body;
  final String action;
  final bool compact;

  /// What the tap opens; default: her health form.
  final VoidCallback? onTap;

  const ProfileLockedCard({
    super.key,
    required this.title,
    required this.body,
    required this.action,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? ProfileCompletion.to.openForm,
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 13),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFCF9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD3DECF), width: 1.5),
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🔒 $title', style: _t(11, c: _muted)),
                  const SizedBox(height: 4),
                  Text(body, style: _t(13, w: FontWeight.w600, c: const Color(0xFF4B604F))),
                  const SizedBox(height: 6),
                  Text('$action ›', style: _t(12, w: FontWeight.w600, c: _deep)),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF3EB),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.lock_outline_rounded, size: 18, color: _muted),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: _t(13.5, w: FontWeight.w600, c: const Color(0xFF4B604F))),
                        const SizedBox(height: 2),
                        Text(body, style: _t(12, c: _sub, h: 1.45)),
                        const SizedBox(height: 6),
                        Text('$action ›', style: _t(12, w: FontWeight.w600, c: _deep)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Dashed-look green card in the dark hero: "Add your period date".
class HeroPeriodCard extends StatelessWidget {
  const HeroPeriodCard({super.key});

  @override
  Widget build(BuildContext context) {
    final pc = ProfileCompletion.to;
    return GestureDetector(
      // Life stage unknown: health form; else the sign-up style period page.
      onTap: pc.missing.contains('lifeStage') ? pc.openForm : pc.openPeriod,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: _green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _green.withOpacity(0.85), width: 1.5),
        ),
        child: Row(
          children: [
            const Text('🌸', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Add your period date to see your phase and energy for today',
                style: _t(12.5, c: Colors.white.withOpacity(0.9), h: 1.4),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(12)),
              child: Text('Add', style: _t(12.5, w: FontWeight.w600, c: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diet tab when her meal plan can't be made yet: a blurred plan behind
/// one card that lists what her dietitian still needs.
class DietLockedView extends StatelessWidget {
  const DietLockedView({super.key});

  @override
  Widget build(BuildContext context) {
    final pc = ProfileCompletion.to;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      child: Stack(
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Opacity(
              opacity: 0.45,
              child: Column(
                children: [
                  for (final m in const ['🍳 Breakfast', '🥗 Lunch', '🍎 Snack', '🍲 Dinner', '💧 Water'])
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _line),
                      ),
                      child: Row(
                        children: [
                          Text(m, style: _t(13)),
                          const Spacer(),
                          Container(width: 70, height: 8, decoration: BoxDecoration(color: const Color(0xFFE5EFDF), borderRadius: BorderRadius.circular(4))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Obx(() {
              final missing = <String>[
                if (pc.healthNeeded) 'Health form for your dietitian',
                if (pc.foodNeeded) 'Food likes & allergies',
              ];
              final times = <String>[
                if (pc.healthNeeded) '90 sec',
                if (pc.foodNeeded) '30 sec',
              ];
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE6EFE1)),
                  boxShadow: [BoxShadow(color: _ink.withOpacity(0.10), blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(color: const Color(0xFFEEF6EA), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.lock_outline_rounded, color: _deep, size: 26),
                    ),
                    const SizedBox(height: 10),
                    Text('Your meal plan is waiting', style: _t(17, w: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      missing.length == 1
                          ? 'Your dietitian makes your plan from your answers. She still needs this from you:'
                          : 'Your dietitian makes your plan from your answers. She still needs these ${missing.length} things from you:',
                      textAlign: TextAlign.center,
                      style: _t(12.5, c: _sub, h: 1.5),
                    ),
                    const SizedBox(height: 10),
                    for (var k = 0; k < missing.length; k++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 21,
                              height: 21,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFD2DDCD), width: 1.5),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(missing[k], style: _t(13))),
                            Text(times[k], style: _t(11, c: _muted)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: pc.openForm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(14)),
                          alignment: Alignment.center,
                          child: Text('Fill my profile · 2 min', style: _t(14, w: FontWeight.w600, c: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('Your classes and reminders keep working as normal.', style: _t(11.5, c: _muted)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Small strip on the Diet tab when she already has a meal plan but the
/// form is still open: her plan stays, we just ask.
class DietFinishProfileStrip extends StatelessWidget {
  const DietFinishProfileStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: ProfileCompletion.to.openForm,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCFE7C6), width: 1.5),
          ),
          child: Row(
            children: [
              const Text('📝', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Finish your profile so your dietitian can keep your plan right for you.',
                  style: _t(12, c: _sub, h: 1.4),
                ),
              ),
              const SizedBox(width: 8),
              Text('Finish ›', style: _t(12, w: FontWeight.w600, c: _deep)),
            ],
          ),
        ),
      ),
    );
  }
}
