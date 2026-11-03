import '../widgets/payment_hold/payment_hold_banner.dart';
import '../widgets/symptom_check/symptom_check_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../data/Repos/cycle_repo/cycle_data_repository.dart';
import '../data/controllers/auth_controller/auth_controller.dart';
import '../data/controllers/cycle_theme_controller/cycle_theme_controller.dart';
import '../data/controllers/home_controller/home_controller.dart';
import '../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../data/controllers/workout_controller/work_out_controller.dart';
import '../data/services/cycle_engine.dart';
import '../UI/dashboard_module/bottom_bar_screen/workout_plans_of_user.dart';
import '../utils/slot_input_builder.dart';
import '../values/constants.dart';
import '../widgets/anim/motion.dart';
import '../widgets/new_home/community_footer.dart';
import '../widgets/new_home/feel_selector_card.dart';
import '../widgets/new_home/hero_coming_up_row.dart' show UpcomingSlot;
import '../widgets/new_home/home_hero.dart';
import '../widgets/new_home/locked_insight_card.dart';
import '../widgets/new_home/locked_stats_grid.dart';
import '../widgets/new_home/reengagement_cta_card.dart';
import '../widgets/v2/trial_recap_card.dart';
import '../widgets/trial_welcome/trial_welcome_sheet.dart';
import '../helper/popup_manager.dart';
import '../widgets/class_feedback/class_feedback_card.dart';
import '../widgets/paid_home_v2/paid_feel_selector.dart';
import '../widgets/paid_home_v2/paid_sleep_card.dart';
import '../widgets/paid_home_v2/paid_water_card.dart';
import '../widgets/trial_moments/trial_moments.dart';

/// Unpaid (free-trial / pre-purchase) home screen.
/// Mounted by home_screen.dart for every unpaid user (logInUser.status == false).
///
/// Data sources:
///   firstName       — AuthController.logInUser.firstName
///   cycleInfo       — CycleDataRepository.getCycleData(), cached per mount.
///   upcomingSlots   — populated for active trial users via
///                     WorkOutController.getDietPlanDetailsFunc('0').
///   dashboard       — PaidHomeController.loadDashboard(), loaded for trial
///                     users so feel/water/sleep widgets become interactive.
class UnpaidHomeScreenV2 extends StatefulWidget {
  const UnpaidHomeScreenV2({super.key});

  @override
  State<UnpaidHomeScreenV2> createState() => _UnpaidHomeScreenV2State();
}

class _UnpaidHomeScreenV2State extends State<UnpaidHomeScreenV2> {
  final AuthController _auth = Get.find();
  final WorkOutController _workOutController = Get.find();
  final PaidHomeController _paidController = Get.find<PaidHomeController>();

  late Future<CycleInfo?> _cycleFuture;
  Worker? _trialWorker;
  Worker? _opensWorker;

  // Animation pass (#6): the cards rise in one after another the first
  // time this screen opens. After that (rebuilds, pull-to-refresh, a card
  // swapping from locked to unlocked) nothing replays.
  bool _entranceDone = false;

  Widget _enter(String id, int index, Widget child) =>
      _EnterOnce(key: ValueKey('unpaid_enter_$id'), index: index, play: !_entranceDone, child: child);

  @override
  void initState() {
    super.initState();
    _cycleFuture = _fetchCycleInfo();
    Future.delayed(const Duration(milliseconds: 1500), () => _entranceDone = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Real class card for everyone — pre-trial users see it with "Try free".
      _paidController.loadDashboard();
      if (_auth.trialActivated.value) _fetchTrialSlots();
      // Once, right after sign-up (see TrialWelcomeSheet for the rules).
      TrialWelcomeSheet.maybeShow();
      // Trial over, not upgraded: "Your free trial has ended", once.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) TrialMomentController.ensure().loadAndMaybeShow();
      });
    });
    // Lost its turn earlier: ask again when the app is opened again.
    _opensWorker = ever(PopupManager.opens, (_) {
      TrialWelcomeSheet.maybeShow();
      TrialMomentController.ensure().loadAndMaybeShow();
    });

    _trialWorker = ever(_auth.trialActivated, (bool active) {
      if (active && mounted) {
        _fetchTrialSlots();
        _paidController.loadDashboard();
      }
    });
  }

  @override
  void dispose() {
    _trialWorker?.dispose();
    _opensWorker?.dispose();
    super.dispose();
  }

  void _fetchTrialSlots() {
    _workOutController.getDietPlanDetailsFunc('0');
  }

  Future<void> _onRefresh() async {
    final fresh = _fetchCycleInfo();
    setState(() { _cycleFuture = fresh; });
    _paidController.loadDashboard();
    if (_auth.trialActivated.value) _fetchTrialSlots();
    // Also re-check user plans in case an admin approved payment
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().getUserHomeFunc(forceRefresh: true);
    }
    await fresh;
  }

  List<UpcomingSlot> _buildUpcomingSlots() {
    // ignore: unused_local_variable
    final _ = _workOutController.workOutPlanDetailsLoad.value;
    final plan = _workOutController.getUserWorkoutPlanDetailsPlan;
    if (plan == null) return [];

    final now = DateTime.now();
    final todayName = DateFormat('EEEE').format(now);
    final tomorrowDate = now.add(const Duration(days: 1));
    final tomorrowName = DateFormat('EEEE').format(tomorrowDate);

    final results = <UpcomingSlot>[];
    for (final daySlot in plan.trainerSlots) {
      final int dayOffset;
      final DateTime anchorDate;
      if (daySlot.day == todayName) {
        dayOffset = 0;
        anchorDate = now;
      } else if (daySlot.day == tomorrowName) {
        dayOffset = 1;
        anchorDate = tomorrowDate;
      } else {
        continue;
      }

      for (final slot in daySlot.slots) {
        final start = parseSlotWallClock(slot.start, anchorDate);
        final end = parseSlotWallClock(slot.end, anchorDate);
        if (start == null || end == null) continue;
        if (end.isBefore(now)) continue;
        results.add(UpcomingSlot(slot, start, end, dayOffset: dayOffset));
      }
    }

    results.sort((a, b) {
      final dayDiff = a.dayOffset.compareTo(b.dayOffset);
      return dayDiff != 0 ? dayDiff : a.startLocal.compareTo(b.startLocal);
    });
    return results.take(3).toList();
  }

  Future<CycleInfo?> _fetchCycleInfo() async {
    try {
      final repo = Get.find<CycleDataRepository>();
      final token = _auth.sharedPreferences.getString(Constants.accessToken) ?? '';
      final response = await repo.getCycleData(accessToken: token);
      final body = response.body;
      if (body == null || body['status'] != '1' || body['data'] == null) return null;
      final data = body['data'];
      final provided = data['dataProvided'];
      final hasProvided = provided == 1 || provided == true || provided == '1';
      final last = data['lastPeriodDate'];
      if (!hasProvided || last == null) return null;
      final info = CycleEngine.calculate(
        lastPeriodDate: DateTime.parse(last.toString()),
        cycleLength: data['averageCycleLength'] ?? 28,
      );
      try { Get.find<CycleThemeController>().setPhase(info?.phase); } catch (_) {}
      return info;
    } catch (_) {
      return null;
    }
  }

  String _firstName() {
    final n = _auth.logInUser?.firstName.trim();
    return (n == null || n.isEmpty) ? '' : n;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FCF7),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          color: const Color(0xFF6DC55A),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero: upcoming slots + workout tap navigation ──
                Obx(() {
                  final trialActive = _auth.trialActivated.value;
                  final slots = trialActive
                      ? _buildUpcomingSlots()
                      : const <UpcomingSlot>[];
                  return FutureBuilder<CycleInfo?>(
                    future: _cycleFuture,
                    builder: (_, snap) => HomeHero(
                      firstName: _firstName(),
                      cycleInfo: snap.data,
                      isLoading: snap.connectionState == ConnectionState.waiting,
                      upcomingSlots: slots,
                      // Tapping a slot tile navigates to the workout schedule.
                      onWorkoutTap: trialActive
                          ? () => Get.to(() => WorkPlansOfUser(showBackButton: true))
                          : null,
                    ),
                  );
                }),

                // ── Feel / insight / water+sleep / CTA ──
                // When trial is active AND the paid dashboard has loaded,
                // replace the locked-UI widgets with fully interactive paid ones
                // so the user can log mood, water, and sleep exactly as on the
                // paid home screen.
                Obx(() {
                  final trialActive = _auth.trialActivated.value;
                  final dash = _paidController.dashboard.value;
                  final showPaid = trialActive && dash != null;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Plan paused: payment not confirmed (send proof).
                        const PaymentHoldBanner(),
                        // Trial over, not upgraded: what she did each day
                        // + Keep going (hides itself otherwise).
                        const TrialRecapCard(padding: EdgeInsets.only(bottom: 12)),
                        // Today's trial moment, until she opens it (self-hides).
                        const TrialMomentCard(padding: EdgeInsets.only(bottom: 12)),
                        // "How was your class?" (only after a class ended).
                        const ClassFeedbackCard(),
                        // Mood selector
                        _enter(
                          'feel',
                          0,
                          showPaid
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    PaidFeelSelector(dashboard: dash),
                                    const SizedBox(height: 8),
                                  ],
                                )
                              : const FeelSelectorCard(),
                        ),

                        // AI insight teaser (always locked — not a paid feature)
                        _enter('insight', 1, const LockedInsightCard()),

                        // Water + Sleep — IntrinsicHeight forces both cards
                        // to the same height regardless of content differences.
                        _enter(
                          'stats',
                          2,
                          showPaid
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(child: PaidWaterCard(dashboard: dash)),
                                        const SizedBox(width: 8),
                                        Expanded(child: PaidSleepCard(dashboard: dash)),
                                      ],
                                    ),
                                  ),
                                )
                              : const LockedStatsGrid(),
                        ),

                        // "Check my symptoms" (PCOS, thyroid…) / her last result.
                        _enter('symptom', 3, const SymptomCheckCard(where: 'home_unpaid')),

                        _enter('cta', 4, const ReengagementCtaCard()),
                        _enter('footer', 5, const CommunityFooter()),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades + slides a home card in once, when it is first built while the
/// screen's first-open entrance is still running. Whether it plays is
/// decided once (initState), so later rebuilds never change the widget
/// tree (no remount, no lost state) and never replay the animation.
class _EnterOnce extends StatefulWidget {
  const _EnterOnce({super.key, required this.index, required this.play, required this.child});
  final int index;
  final bool play;
  final Widget child;

  @override
  State<_EnterOnce> createState() => _EnterOnceState();
}

class _EnterOnceState extends State<_EnterOnce> {
  late final bool _play = widget.play;
  bool? _calm;

  @override
  Widget build(BuildContext context) {
    _calm ??= Motion.calm(context);
    if (!_play || _calm!) return widget.child;
    final delay = Duration(milliseconds: 60 + widget.index * 70);
    return widget.child
        .animate()
        .fadeIn(delay: delay, duration: Motion.normal, curve: Motion.ease)
        .slideY(begin: 0.12, end: 0, delay: delay, duration: Motion.normal, curve: Motion.ease);
  }
}
