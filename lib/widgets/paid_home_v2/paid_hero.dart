import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/Repos/plan_freeze_repo/plan_freeze_repository.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import '../../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../../data/models/home_dashboard/home_dashboard_model.dart';
import '../../helper/class_join_memory.dart';
import '../../utils/app_clock.dart';
import '../../utils/slot_input_builder.dart' show parseSlotWallClock;
import '../../values/constants.dart';
import '../new_home/phase_theme.dart';
import 'paid_hero_coming_up.dart';
import 'paid_hero_greeting.dart';
import 'paid_hero_live_section.dart';
import 'paid_hero_top_bar.dart';

/// Dark phase-themed hero for PaidHomeScreenV2.
/// Layered per HTML reference:
///   background: <phase bg> + radial-gradient overlay
///   + 220×220 faint accent ring at top:-70 right:-50
///   border-radius: 0 0 36px 36px (bottom-only, flat top — hero paints
///   edge-to-edge under the status bar).
class PaidHero extends StatefulWidget {
  final HomeDashboardModel dashboard;

  const PaidHero({Key? key, required this.dashboard}) : super(key: key);

  @override
  State<PaidHero> createState() => _PaidHeroState();
}

class _PaidHeroState extends State<PaidHero> {
  // Frozen-plan awareness (architecture item #2) -- one shared fetch for
  // the hero's frozen-sensitive children (the "Join" pill on a live
  // class, and hiding the coming-up tiles), same self-contained
  // GET-on-mount pattern as PlanFrozenBanner/PlanExpiryBanner elsewhere
  // on this screen. The actual "your plan is paused" messaging + the
  // Unfreeze action live solely on PlanFrozenBanner now (this hero used
  // to duplicate both -- reverted after Shaista flagged the redundancy).
  // Defaults to not-frozen until the call resolves, so nothing
  // dims/disables during the brief loading window -- an active plan
  // never flashes as paused.
  Map<String, dynamic>? _freezeStatus;
  // Until this card's own check comes back, use the last known answer
  // (HomeController.planFrozen). Coming back to Home rebuilds this card;
  // starting from "not frozen" flashed the class section for a second
  // before hiding it (Oct 2026).
  bool get _isFrozen {
    final s = _freezeStatus;
    if (s != null) return s['isFrozen'] == true;
    return Get.isRegistered<HomeController>() &&
        Get.find<HomeController>().planFrozen.value;
  }

  // Re-checks every 30s so a class moves into the big card on time even
  // when the dashboard was loaded earlier (see _effectiveLive).
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _fetchFreezeStatus();
    // Repaint every 20 s so a class moves into the big card on time.
    // Checking the server for "has the trainer started?" is done by
    // PaidHomeController's class watcher (every 20 s from 15 min before).
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // Same lead time as the server's PRE_START_LEAD_MINUTES.
  static const int _kBigCardLeadMinutes = 30;

  // The server only puts a class in `live` if it's within 30 min when the
  // dashboard is fetched. If the screen was loaded earlier, the class is
  // still sitting in Coming Up as a small "Starts in 7m" tile. Promote
  // today's next class to the big card once it's within 30 min.
  LiveClass? _effectiveLive(HomeDashboardModel d) => effectiveLiveClass(d);

  Future<void> _fetchFreezeStatus() async {
    try {
      final auth = Get.find<AuthController>();
      final token =
          auth.sharedPreferences.getString(Constants.accessToken) ?? '';
      final repo = Get.find<PlanFreezeRepository>();
      final res = await repo.getStatus(accessToken: token);
      if (res.body != null &&
          res.body['status'] == '1' &&
          res.body['data'] is Map) {
        final data = Map<String, dynamic>.from(res.body['data']);
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().planFrozen.value = data['isFrozen'] == true;
        }
        if (mounted) {
          setState(() {
            _freezeStatus = data;
          });
        }
      }
    } catch (_) {
      // Best-effort and silent -- a status hiccup leaves the hero exactly
      // as it behaved before this existed (nothing dimmed/disabled).
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = widget.dashboard;
    final promotedLive = _effectiveLive(dashboard);
    final phase = parseCyclePhase(dashboard.cycle?.phase);
    final theme = PhaseTheme.forPhase(phase);

    const radius = BorderRadius.only(
      bottomLeft: Radius.circular(36),
      bottomRight: Radius.circular(36),
    );

    final initial = _resolveInitial(dashboard);
    final gradTint = _gradTint(phase);
    final gradAlpha = _gradAlpha(phase);

    return Container(
      decoration: BoxDecoration(
        color: theme.heroBackground,
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Stack(
            children: [
              // 1. Radial-gradient overlay (phase-specific middle-tone fading
              // to transparent). Alpha-only fade so the base bg shows through.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(1.1, -1.05),
                        radius: 1.3,
                        colors: [
                          gradTint.withOpacity(gradAlpha),
                          gradTint.withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.55],
                      ),
                    ),
                  ),
                ),
              ),
              // 2. Decorative ring — clipped by the hero's ClipRRect on
              // the bottom corners, escapes freely at the top.
              Positioned(
                top: -70,
                right: -50,
                child: IgnorePointer(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.accent.withOpacity(0.07),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
              // 3. Content — the only non-positioned child, so the Stack
              // sizes to its height. `SizedBox(width: double.infinity)`
              // guards against the loose-constraint collapse pattern.
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PaidHeroTopBar(theme: theme, initial: initial),
                    PaidHeroGreeting(
                      dashboard: dashboard,
                      theme: theme,
                      phase: phase,
                    ),
                    // Plan paused: no class times at all (Oct 2026). She
                    // only logs and sees insights until she resumes.
                    if (!_isFrozen) ...[
                      _buildDivider(theme),
                      PaidHeroLiveSection(
                        live: promotedLive,
                        theme: theme,
                        isFrozen: _isFrozen,
                      ),
                      PaidHeroComingUp(
                        comingUp: dashboard.live == null && promotedLive != null
                            ? dashboard.comingUp
                                .where((x) => x.id != promotedLive.slotId)
                                .toList()
                            : dashboard.comingUp,
                        isFrozen: _isFrozen,
                      ),
                    ] else
                      const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(PhaseTheme theme) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            theme.accent.withOpacity(0.18),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  String _resolveInitial(HomeDashboardModel dashboard) {
    final explicit = dashboard.user?.initial;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final first = dashboard.user?.firstName;
    if (first != null && first.isNotEmpty) return first[0].toUpperCase();
    return 'U';
  }
}

/// Per-phase middle-tone for the radial-gradient overlay. Traced to
/// `new screens/Home_All43_Variants.html` lines 228-248.
/// Not added to [PhaseTheme] because it only matters for this single
/// visual effect and PhaseTheme is frozen for Phase B.
Color _gradTint(CyclePhase phase) {
  switch (phase) {
    case CyclePhase.follicular:
      return const Color(0xFF46823C); // rgba(70,130,60,·)
    case CyclePhase.ovulatory:
      return const Color(0xFF146E5A); // rgba(20,110,90,·)
    case CyclePhase.luteal:
      return const Color(0xFF6E460F); // rgba(110,70,15,·)
    case CyclePhase.menstrual:
      return const Color(0xFF6E1414); // rgba(110,20,20,·)
  }
}

/// Per-phase overlay alpha. Follicular uses .4; the other three use .5 per
/// HTML. Small variance matters — too much green saturates the top-right.
double _gradAlpha(CyclePhase phase) {
  return phase == CyclePhase.follicular ? 0.40 : 0.50;
}

/// The class shown in the big hero card (shared by paid and preview
/// homes): server `live`, else the next class that hasn't ended yet.
LiveClass? effectiveLiveClass(HomeDashboardModel d) {
  final live = d.live;
  if (live != null && !_trialJoinOver(live)) return live;
  // Skip a class that was cancelled (auto or by the trainer) or ended
  // early, so the next class can take the big card. Also skip the live
  // class once a trial user's join time is over: the next class shows
  // straight away instead of an empty card until the next refresh.
  final open = d.comingUp.where((x) {
    final st = (x.status ?? '').trim();
    return st != 'Cancelled' && st != 'Completed' && x.id != live?.slotId;
  }).toList();
  // The next class that hasn't ended yet always takes the big card:
  // calm "UP NEXT" until 30 min before, then the countdown (the card
  // decides). After the last class it's tomorrow's first class.
  final now = AppClock.now();
  ComingUpClass? c;
  var offset = 0;
  for (final x in open) {
    final off = x.dayOffset ?? 0;
    final day = DateTime(now.year, now.month, now.day).add(Duration(days: off));
    final start = parseSlotWallClock(x.start, day);
    if (start == null) continue;
    final end = parseSlotWallClock(x.end, day);
    final over = end != null ? !now.isBefore(end) : now.isAfter(start);
    if (over) continue;
    c = x;
    offset = off;
    break;
  }
  if (c == null) return null;
  return LiveClass(
    slotId: c.id,
    classType: c.classType,
    trainerName: c.trainerName,
    durationMinutes: c.durationMinutes,
    status: c.status,
    trainerLink: c.trainerLink,
    level: c.level,
    start: c.start,
    end: c.end,
    dayOffset: offset,
  );
}


/// Trial user, class started more than her join window ago, and she
/// hasn't joined it: she can't join any more.
bool _trialJoinOver(LiveClass l) {
  if (!Get.isRegistered<HomeController>()) return false;
  final home = Get.find<HomeController>();
  if (!home.isFreeTrialUser.value) return false;
  if (l.joinedToday || ClassJoinMemory.joinedToday(l.slotId)) return false;
  final now = AppClock.now();
  final day = DateTime(now.year, now.month, now.day).add(Duration(days: l.dayOffset));
  final start = parseSlotWallClock(l.start, day);
  if (start == null) return false;
  return now.isAfter(start.add(Duration(minutes: home.joinWindowMinutes.value)));
}
