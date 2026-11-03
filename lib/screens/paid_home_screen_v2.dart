import '../widgets/weekly_checkin/weekly_checkin_card.dart';
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../widgets/paid_home_v2/consultation_home_banner.dart';
import '../UI/consultation_module/booking/upcoming_consultation_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../UI/consultation_module/popup_orchestrator.dart';
import '../UI/dashboard_module/bottom_bar_screen/bottom_bar_screen.dart';
import '../data/controllers/home_controller/home_controller.dart';
import '../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../data/models/home_dashboard/home_dashboard_model.dart';
import '../utils/app_clock.dart';
import '../widgets/anim/motion.dart';
import '../widgets/anim/skeleton.dart';
import '../widgets/class_feedback/class_feedback_card.dart';
import '../widgets/paid_home_v2/paid_cycle_card.dart';
import '../widgets/paid_home_v2/paid_footer.dart';
import '../widgets/paid_home_v2/paid_hero.dart';
import '../widgets/paid_home_v2/paid_insight_card.dart';
import '../widgets/paid_home_v2/paid_stats_row.dart'
    show PaidStatsRow, PaidClassesTile;
import '../widgets/paid_home_v2/today_insights_box.dart';
import '../widgets/paid_home_v2/talk_to_expert_card.dart';
import '../widgets/v2/plan_expiry_banner.dart';
import '../widgets/v2/plan_frozen_banner.dart';
import '../widgets/v2/v2_plan_preparing_card.dart';
import '../widgets/v2/v2_trial_banner.dart';
import '../main.dart' show routeObserver;
import '../UI/profile_setup/profile_setup_gate.dart';
import '../UI/profile_setup/profile_completion.dart';
import '../UI/profile_setup/profile_completion_widgets.dart';
import '../widgets/plan_welcome/plan_welcome_moment.dart';
import '../helper/popup_manager.dart';
import '../widgets/trial_moments/trial_moments.dart';

/// The three genuinely daily inputs on this screen, in the order they
/// appear top-to-bottom (Mood, then Water/Sleep side by side — Water
/// wins ties over Sleep simply because it's the left/first card of that
/// row). Workouts and Calories are deliberately excluded: Workouts is
/// derived from class attendance (nothing to manually log) and Calories
/// is a computed target, not a daily entry.
enum _DailyItem { mood, water, sleep, none }

/// Which of the three daily items still needs logging today, derived
/// purely from the current dashboard — no separate "just logged"
/// tracking needed. Because every log action already triggers a
/// dashboard refresh on success, this naturally advances mood -> water
/// -> sleep the instant each one is saved, and clears once all three
/// are done.
_DailyItem _nextDailyItem(HomeDashboardModel dashboard) {
  final moodDone = dashboard.todayCheckin?.moodLevel != null;
  if (!moodDone) return _DailyItem.mood;
  final waterDone = (dashboard.hydration?.consumedMl ?? 0) > 0;
  if (!waterDone) return _DailyItem.water;
  final sleepDone = dashboard.sleep?.hoursToday != null;
  if (!sleepDone) return _DailyItem.sleep;
  return _DailyItem.none;
}

/// PaidHomeScreenV2 — phase-themed dashboard for paid users behind the
/// `useNewPaidHome` feature flag. Phase B2.3 ships only the hero section
/// (top bar + greeting + LIVE + coming up). The cream body below is a
/// placeholder that will be filled in subsequent phases (insight, mood,
/// water, sleep, stats, cycle/nutrition, footer).
class PaidHomeScreenV2 extends StatefulWidget {
  const PaidHomeScreenV2({super.key});

  @override
  State<PaidHomeScreenV2> createState() => _PaidHomeScreenV2State();
}

class _PaidHomeScreenV2State extends State<PaidHomeScreenV2>
    with WidgetsBindingObserver, RouteAware {
  final PaidHomeController _controller = Get.find<PaidHomeController>();

  // Bumped whenever this screen becomes visible again after a pushed
  // screen (Profile, most relevantly) is popped -- see didPopNext()
  // below. Threaded into PaidHero/PlanFrozenBanner/PlanExpiryBanner as
  // part of their Key so a bump forces Flutter to dispose and recreate
  // them, re-running their initState() freeze/expiry-status fetch.
  // Those widgets intentionally manage their own state independently
  // (self-contained fetch-on-mount pattern used throughout this screen)
  // rather than reading from _controller's dashboard, so simply calling
  // _controller.refreshDashboard() on return would NOT have picked up a
  // freeze/unfreeze done on Profile -- only remounting them does.
  int _refreshGen = 0;

  // First-load entrance: true once the skeleton has been shown, so the
  // real cards fade/slide in one after another the first time data
  // arrives. Never reset, so the wrappers stay in the tree and pull-to-
  // refresh / rebuilds don't replay the animation (an Animate widget
  // only plays once, when it is first mounted).
  bool _playEntry = false;

  Widget _enter(Widget child, int index, {double dy = 0.12}) =>
      _playEntry ? child.fhEnter(context, index: index, dy: dy) : child;

  // Guided scroll: after she logs her feeling the screen glides down to
  // water and sleep; once those are done it glides on to the stats row.
  // Only once per step per day, never while she is scrolling herself.
  final GlobalKey _waterSleepKey = GlobalKey();
  final GlobalKey _statsKey = GlobalKey();
  _DailyItem? _lastNextUp;
  static final Set<String> _guidedToday = {};

  void _maybeGuideScroll(_DailyItem nextUp) {
    final prev = _lastNextUp;
    _lastNextUp = nextUp;
    if (prev == null || prev == nextUp) return;

    GlobalKey? target;
    String? step;
    if (prev == _DailyItem.mood) {
      target = _waterSleepKey;
      step = 'afterFeeling';
    } else if ((prev == _DailyItem.water || prev == _DailyItem.sleep) &&
        nextUp == _DailyItem.none) {
      target = _statsKey;
      step = 'afterSleep';
    }
    if (target == null || step == null) return;

    final day = DateTime.now().toIso8601String().substring(0, 10);
    if (!_guidedToday.add('$day:$step')) return;

    final key = target;
    // A short pause so she sees her tap land (and the tip appear) first.
    Future.delayed(const Duration(milliseconds: 500), () {
      final ctx = key.currentContext;
      if (!mounted || ctx == null) return;
      final scrollable = Scrollable.maybeOf(ctx);
      if (scrollable != null &&
          scrollable.position.isScrollingNotifier.value) {
        return;
      }
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
        // Only moves if the card is below the screen, and only as far as
        // needed to show all of it.
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  // Step 4-style sync layers — same pattern as the workout schedule.
  // Heartbeat keeps live/comingUp data fresh when the realtime socket
  // is offline; foreground + reconnect triggers cover the long-tail
  // cases (resume from background, network drop). _lastContactAt
  // drives the "Reconnecting…" banner.
  Timer? _heartbeatTimer;
  Worker? _opensWorker;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  DateTime? _lastContactAt;
  // Guard against overlapping heartbeats. The 30s timer + foreground
  // resume + connectivity-reconnect triggers can all fire in tight
  // succession on flaky networks; without this, multiple concurrent
  // dashboard fetches stack up and a later one's success can mask an
  // earlier failure.
  bool _heartbeatInFlight = false;

  static const Duration _kHeartbeatInterval = Duration(seconds: 30);
  static const Duration _kStaleAfter = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.dashboard.value == null) {
        _controller.loadDashboard().then((_) {
          if (mounted) setState(() => _lastContactAt = AppClock.now());
          ProfileCompletion.to.reload(force: true);
        });
      } else {
        _lastContactAt = AppClock.now();
        ProfileCompletion.to.reload(force: true);
      }
    });

    _heartbeatTimer = Timer.periodic(_kHeartbeatInterval, (_) => _heartbeat());

    // Old clients: finish the health form and pick class reminder times
    // (skippable 3 times, then compulsory). Small delay so home shows first.
    // One-time "Welcome to Fit Her" right after a paid plan is activated
    // (self-checks: paid, not trial, plan started <= 3 days ago, once per
    // plan). The health-form gate waits until she has closed it.
    final Future<void> welcome = Future<void>.delayed(
        const Duration(milliseconds: 1200), () async {
      if (mounted) await PlanWelcomeMoment.maybeShow();
    });
    Future.delayed(const Duration(seconds: 3), () async {
      await welcome;
      if (mounted) ProfileSetupGate.checkAndShow();
    });
    // Free-trial moment of the day (Day 3 / 4 / last day), once.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) TrialMomentController.ensure().loadAndMaybeShow();
    });
    // Nov 2026: rate the consultation she just had (pop-up, once).
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) SessionRatingPopup.maybeShow();
    });
    // Pop-up manager: a new app open is a new turn. Ask again for the
    // ones that lost their turn (each still checks its own rules).
    _opensWorker = ever(PopupManager.opens, (_) async {
      if (!mounted) return;
      await PlanWelcomeMoment.maybeShow();
      if (mounted) ProfileSetupGate.checkAndShow();
      if (mounted) TrialMomentController.ensure().loadAndMaybeShow();
      if (mounted) SessionRatingPopup.maybeShow();
    });

    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _opensWorker?.dispose();
    _connectivitySub?.cancel();
    super.dispose();
  }

  // RouteAware -- fires when a screen pushed on top of this one (e.g.
  // Get.to(() => ProfileScreenUser()) from the hero top bar, or from
  // PlanFrozenBanner's own "Manage" button) is popped and this Home
  // screen is visible again. This is specifically what Shaista asked
  // for: freezing/unfreezing on Profile and coming back to Home should
  // show the correct paused/active state right away, not only after a
  // full app restart or the next 30s heartbeat tick.
  @override
  void didPopNext() {
    _heartbeat(reason: 'route-return');
    ProfileCompletion.to.reload();
    if (mounted) setState(() => _refreshGen++);
  }

  Future<void> _heartbeat({String reason = 'tick'}) async {
    if (!mounted || _heartbeatInFlight) return;
    _heartbeatInFlight = true;
    try {
      debugPrint('[PaidHomeV2] heartbeat ($reason)');
      final ok = await _controller.silentRefresh();
      if (!mounted || !ok) return;
      setState(() => _lastContactAt = AppClock.now());
    } finally {
      _heartbeatInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _heartbeat(reason: 'resumed');
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final reachable = results.any((r) => r != ConnectivityResult.none);
    if (reachable) _heartbeat(reason: 'reconnect');
  }

  bool get _isStale {
    if (_lastContactAt == null) return false;
    return AppClock.now().difference(_lastContactAt!) > _kStaleAfter;
  }

  @override
  Widget build(BuildContext context) {
    // Status-bar styling — single mechanism: AnnotatedRegion. The hero
    // (PaidHero) has a flat top and paints from y=0 (Scaffold body has no
    // implicit SafeArea); PaidHeroTopBar already pads its content by
    // `MediaQuery.padding.top + 14` so bell + avatar clear the system
    // chrome. With edgeToEdge enabled in main.dart, a transparent
    // statusBarColor lets the hero's actual phase colour show through
    // the OS bar — no fake-tint scrim, no imperative SystemChrome push,
    // no possibility of a stale "mint band" from splash sticking around.
    return Obx(() {
      // Even though the per-phase colour is no longer wired into the
      // status bar, we still rebuild on dashboard changes so AnnotatedRegion
      // refreshes if anything else (icon brightness, etc.) ever needs to.
      _controller.dashboard.value;

      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          // Transparent so the hero's dark phase colour paints the strip.
          statusBarColor: Colors.transparent,
          // Android: light icons render white on dark hero.
          statusBarIconBrightness: Brightness.light,
          // iOS: `Brightness.dark` reads as "the surface is dark" — system
          // renders status-bar content in white. Platform-inverted naming.
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          // Cream body bg matches the H-01 reference scroll area below the
          // hero. Unchanged.
          backgroundColor: const Color(0xFFEAF7E4),
          // Phase 2D wiring (consultation flow):
          //   • PendingPopupOrchestrator watches dashboard.pendingPopups
          //     and dispatches the right sheet by variable name.
          body: PendingPopupOrchestrator(
            // Inactivity popup's "View today's classes" CTA — switch the
            // bottom-bar to the Workout tab so the user lands on their
            // schedule. WorkPlansOfUser → tap into the plan → today's class.
            onOpenWorkoutSchedule: () =>
                Get.offAll<dynamic>(() => BottomBarScreen(index: 1)),
            child: _bodyStack(),
          ),
        ),
      );
    });
  }


  Widget _bodyStack() {
    return Stack(
      children: [
        _buildBody(),
        // Reconnecting banner — overlay so it stays pinned at
        // the top of the screen instead of scrolling away with
        // the hero. SafeArea so it clears the status bar.
        if (_isStale)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _buildReconnectingBanner(),
            ),
          ),
      ],
    );
  }

  // Slim amber pill shown when no successful heartbeat in [_kStaleAfter].
  // Same styling intent as the workout schedule banner so users see
  // consistent reconnecting feedback wherever they are in the app.
  Widget _buildReconnectingBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      color: const Color(0xFFFAC775),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12.w,
            height: 12.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            'Reconnecting…',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      // Also covers the very first frame, before loadDashboard() has
      // flipped isLoading on (any failure always sets errorMessage).
      if (_controller.dashboard.value == null &&
          (_controller.isLoading.value ||
              _controller.errorMessage.value.isEmpty)) {
        _playEntry = true;
        return const _PaidHomeSkeleton();
      }
      final dashboard = _controller.dashboard.value;
      if (dashboard == null) {
        return Center(
          child: Text(
            _controller.errorMessage.value.isEmpty
                ? 'No data'
                : _controller.errorMessage.value,
            style: const TextStyle(color: Colors.black54),
          ),
        );
      }
      final hasCycle = dashboard.cycle?.cycleDay != null;
      // Day 1 of the free trial: hold back the hormone check (it shows
      // from Day 2, and always for paid). Same day maths as
      // V2TrialBanner; reading the Rx values here keeps it reactive.
      final home = Get.isRegistered<HomeController>()
          ? Get.find<HomeController>()
          : null;
      final trialStart = home?.trialStartedAt.value;
      final isTrialDay1 = home != null &&
          home.trialLive.value &&
          trialStart != null &&
          DateTime.now().difference(trialStart).inHours < 24;
      final nextUp = _nextDailyItem(dashboard);
      _maybeGuideScroll(nextUp);
      return RefreshIndicator(
          onRefresh: _controller.refreshDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _enter(
                  PaidHero(
                    key: ValueKey('hero_$_refreshGen'),
                    dashboard: dashboard,
                  ),
                  0,
                  // Fade only: the hero paints under the status bar.
                  dy: 0,
                ),
                // Renewal heads-up — same "self-hides, own margin" sibling
                // pattern as V2Day7TriggerBanner right below. Sits above it
                // so a lapsing/expired plan is the first thing a user sees
                // under the hero, ahead of the day-7 check-in nudge.
                // Her consultation (Nov 2026): today / starting / live /
                // late / rate / canceled. Self-hides when nothing's due.
                const ConsultationHomeBanner(),
                // Free trial: "Day 2 of 3" + Upgrade. Self-hides for paid.
                const V2TrialBanner(),
                // Today's trial moment, until she opens it (self-hides).
                const TrialMomentCard(padding: EdgeInsets.fromLTRB(16, 10, 16, 0)),
                PlanExpiryBanner(key: ValueKey('expiry_$_refreshGen')),
                // "Your plan is being prepared, expected by ..." between
                // consultation and delivery. Self-hides otherwise.
                V2PlanPreparingBanner(key: ValueKey('preparing_$_refreshGen')),
                // Frozen-plan heads-up -- item #1 of the frozen-plan
                // architecture pass. Sits right below the renewal banner;
                // in practice the two never show at once (a frozen plan's
                // expireDate was already pushed out at freeze time), but
                // each self-hides independently so there's no ordering
                // dependency between them.
                PlanFrozenBanner(
                  key: ValueKey('frozen_$_refreshGen'),
                  // Unfreezing right here (no navigation involved) needs
                  // the same PaidHero remount that didPopNext() triggers
                  // for the "unfroze on Profile, came back" path -- see
                  // PlanFrozenBanner.onUnfrozen's doc comment.
                  onUnfrozen: () {
                    if (mounted) setState(() => _refreshGen++);
                  },
                ),
                // Cream scroll body. Insight card is the first section;
                // everything below the `SizedBox` is a placeholder that
                // future phases fill in (mood, water/sleep, stats, etc.).
                // Phase H — Day 7 check-in trigger. Mounted as a
                // sibling of the cream-body Padding (not inside it)
                // because V2Day7TriggerBanner already has its own
                // 16w margin — putting it inside the 16-padded inner
                // Column would double-pad. Self-hides when ineligible,
                // so this slot only contributes layout on Day 7+.
                // Day 7 check-in banner removed (Oct 2026): the weekly
                // check-in card below asks the Day 7 questions in week 1.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Old paid client who skipped her profile: "reminders
                      // for all classes" note + "Finish your profile"
                      // checklist. Hides itself when nothing is missing.
                      const ProfileCompletionSection(),
                      // Book a call with her dietitian (hides itself when
                      // she has no dietitian or a call is already booked).
                      // "How was your class?" (only after a class ended).
                      _enter(const ClassFeedbackCard(), 1),
                      // Weekly measurements (hidden once done this week).
                      _enter(const WeeklyCheckinCard(), 1),
                      _enter(TalkToExpertCard(key: ValueKey('expert_$_refreshGen')), 1),
                      // Luna's tip follows her cycle phase: without her
                      // period date it waits for the profile.
                      _enter(
                        Obx(() {
                          // Read the observable FIRST, before `hasCycle`.
                          // `!hasCycle && periodLocked` short-circuits when
                          // she has cycle data, so Obx saw no observable
                          // and GetX threw "improper use of GetX".
                          final locked = ProfileCompletion.to.periodLocked;
                          return !hasCycle && locked
                              ? ProfileLockedCard(
                                  title: 'Luna · your daily tip',
                                  body: 'Tips for food and workouts that match your phase.',
                                  action: 'Add your period date to unlock',
                                onTap: ProfileCompletion.to.openPeriod,
                                )
                              : PaidInsightCard(dashboard: dashboard);
                        }),
                        2,
                      ),
                      const SizedBox(height: 8),
                      // "Today's insights" box: feeling, water and sleep.
                      // Inputs stay open until all three are logged, then
                      // it folds into three tiles. The soft glow still
                      // points at the next unfilled input.
                      _enter(
                        TodayInsightsBox(
                          dashboard: dashboard,
                          glowMood: nextUp == _DailyItem.mood,
                          glowWater: nextUp == _DailyItem.water,
                          glowSleep: nextUp == _DailyItem.sleep,
                          waterSleepKey: _waterSleepKey,
                        ),
                        3,
                      ),
                      const SizedBox(height: 8),
                      _enter(
                        KeyedSubtree(
                          key: _statsKey,
                          // Weight | Hormone check | Meals (Oct 2026).
                          child: PaidStatsRow(
                            dashboard: dashboard,
                            // Weight | Classes once she has joined a class
                            // this week (the health check moves next to
                            // Cycle); otherwise Weight | Health checks.
                            withClasses: PaidClassesTile.shows(dashboard),
                            withHormoneCheck: true,
                            // Meals are in Today's insights now.
                            showMeals: false,
                          ),
                        ),
                        4,
                      ),
                      const SizedBox(height: 8),
                      // Row 2: Cycle, with the health check beside it once
                      // she has joined a class this week (Classes then sits
                      // next to Weight in the row above, Oct 2026).
                      // Row 2: Cycle on its own (Weight · Classes · Health
                      // check share row 1, Oct 2026).
                      if (hasCycle)
                        _enter(PaidCycleCard(dashboard: dashboard), 5)
                      else if (!isTrialDay1)
                        _enter(
                          Obx(() {
                            // No period date: locked Cycle tile.
                            if (!ProfileCompletion.to.periodLocked) return const SizedBox.shrink();
                            return ProfileLockedCard(
                              title: 'Cycle',
                              body: 'See your phase and when your next period comes.',
                              action: 'Add your period date',
                              onTap: ProfileCompletion.to.openPeriod,
                            );
                          }),
                          5,
                        ),
                      if (isTrialDay1)
                        _enter(
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
                            child: const Text(
                              'More tools unlock from Day 2: Hormone check, weekly progress',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.5,
                                color: Color(0xFF8A9A88),
                              ),
                            ),
                          ),
                          5,
                        ),
                      const SizedBox(height: 8),
                      _enter(PaidFooter(dashboard: dashboard), 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
    });
  }
}

/// First-load placeholder for the paid home: grey shapes laid out like the
/// real hero (top bar, greeting, live card, coming-up tiles) and the first
/// cards below, with a soft moving shine (still when reduce-motion is on).
class _PaidHomeSkeleton extends StatelessWidget {
  const _PaidHomeSkeleton();

  static const Color _heroBg = Color(0xFF163220);
  static const Color _dark = FhSkeleton.onDark;

  Widget _frac(double f, double h, {double top = 0, Color color = FhSkeleton.light, double radius = 6}) {
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: f,
        child: FhSkeleton(height: h, color: color, radius: radius),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(12)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8EDD4)),
      ),
      child: child,
    );
  }

  Widget _hero(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _heroBg,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: FhSkeletonShine(
        color: Colors.white.withOpacity(0.13),
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, top + 14, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar: bell + avatar.
              Row(
                children: const [
                  FhSkeleton.circle(size: 30, color: _dark),
                  Spacer(),
                  FhSkeleton.circle(size: 30, color: _dark),
                ],
              ),
              const SizedBox(height: 18),
              // Greeting.
              const FhSkeleton(width: 140, height: 10, color: _dark),
              const SizedBox(height: 14),
              const FhSkeleton(width: 240, height: 30, radius: 8, color: _dark),
              const SizedBox(height: 16),
              const FhSkeleton(width: 210, height: 11, color: _dark),
              const SizedBox(height: 18),
              Container(height: 1, color: Colors.white.withOpacity(0.06)),
              const SizedBox(height: 14),
              // Live class card.
              const FhSkeleton(width: 56, height: 15, radius: 20, color: _dark),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        FhSkeleton(width: 180, height: 21, color: _dark),
                        SizedBox(height: 6),
                        FhSkeleton(width: 150, height: 12, color: _dark),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  const FhSkeleton(width: 104, height: 44, radius: 16, color: _dark),
                ],
              ),
              const SizedBox(height: 18),
              // Coming-up tiles.
              Row(
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 7),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _frac(0.85, 10, color: _dark),
                            _frac(0.6, 9, top: 7, color: _dark),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: FhSkeletonShine(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Expert card.
            _card(
              child: Row(
                children: [
                  const FhSkeleton(width: 42, height: 42, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _frac(0.7, 12),
                        _frac(0.85, 10, top: 6),
                        _frac(0.5, 9, top: 6),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const FhSkeleton(width: 66, height: 40, radius: 14),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Insight card.
            _card(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _frac(0.4, 12),
                  _frac(0.8, 15, top: 12),
                  _frac(1, 10, top: 8),
                  _frac(0.9, 10, top: 6),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Today's insights box.
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _frac(0.45, 13),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 9, 8, 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE3EFE0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _frac(0.7, 10),
                                _frac(0.6, 15, top: 8),
                                _frac(0.8, 8, top: 6),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Stats row.
            Row(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  Expanded(
                    child: _card(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
                      child: Column(
                        children: const [
                          FractionallySizedBox(widthFactor: 0.7, child: FhSkeleton(height: 9)),
                          SizedBox(height: 6),
                          FractionallySizedBox(widthFactor: 0.5, child: FhSkeleton(height: 20)),
                          SizedBox(height: 5),
                          FractionallySizedBox(widthFactor: 0.6, child: FhSkeleton(height: 8)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Not scrollable on purpose: it is only on screen for a moment.
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _hero(context),
          _body(),
        ],
      ),
    );
  }
}
