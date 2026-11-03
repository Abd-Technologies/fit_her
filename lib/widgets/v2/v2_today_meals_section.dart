import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../UI/consultation_module/booking/book_consultation_sheet.dart';
import '../../UI/diet_screen/user_v2/day7_review_screen.dart';
import '../../UI/plans_module/all_plans.dart';
import '../../UI/consultation_module/popups/booking_locked_sheet.dart';
import '../../UI/dashboard_module/bottom_bar_screen/Help_Screen.dart';
import '../../UI/support/report_issue_screen.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import '../../data/Repos/diet_plan_v2/diet_plan_user_repository.dart' show BookingContextV2;
import '../weekly_checkin/weekly_checkin_sheet.dart';
import '../toasts.dart';
import '../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../data/controllers/day7_review_controller/day7_review_controller.dart';
import '../../data/controllers/diet_plan_user_controller/diet_plan_user_controller.dart';
import '../../data/models/diet_plan_v2/diet_plan_v2_models.dart';
import '../../data/models/diet_plan_v2/meal_log_v2.dart';
import 'v2_bottom_sheet.dart';
import 'v2_buttons.dart';
import 'v2_day_strip.dart';
import 'v2_plan_timeline_banner.dart';
import 'v2_plan_preparing_card.dart';

const Color _kCream = Color(0xFFEAF7E4);
const Color _kHeroDark = Color(0xFF163220);
const Color _kSage = Color(0xFF9AB09A);
const Color _kBodyMuted = Color(0xFF6F8B7A);
const Color _kAccent = Color(0xFF6DC55A);
const Color _kCardBorder = Color(0xFFD8EDD4);
const Color _kDanger = Color(0xFFE07B7B);
// Phase F.2 — "alternative" status indicator. Phase tint reused from
// luteal so the colour vocabulary is consistent with paid_home_v2.
const Color _kAlternative = Color(0xFFFAC775);

/// Shared follow-up booking flow used by Phase G.2's timeline banner
/// and Phase F.3's "Plan Completed" empty state. Lazy-loads the
/// booking context first (the banner can fire from the active-plan
/// path where context isn't auto-fetched), then routes:
///   • bookingContext.canBook → BookConsultationSheet (kind: followup)
///   • else → OurPlansScreen (silent fallback — no error snackbar)
/// Dead-end audit (Oct 2026): a PAID client whose dietitian isn't assigned
/// yet must not be sent to the "buy a plan" screen. Tell her what happens
/// next and give her a way to reach us.
bool _paidWithoutDietitian(BookingContextV2? ctx) =>
    ctx != null &&
    ctx.userPlanId != null &&
    ctx.dietitianId == null &&
    !ctx.planEnded &&
    ctx.nextStep != 'renew' &&
    !_isTrial();

bool _isTrial() =>
    Get.isRegistered<HomeController>() &&
    Get.find<HomeController>().isFreeTrialUser.value;

void _showNoDietitianYet() {
  CustomToast.warnToast(
    "We're assigning your dietitian",
    sub: "You'll get a message as soon as she's ready, then you can book your call.",
    action: 'Contact us',
    onAction: () => Get.to<dynamic>(() => const ReportIssueScreen()),
  );
}

Future<void> _bookFollowUpFromContext(String popupVariable) async {
  final ctrl = Get.find<DietPlanUserController>();
  // Always fresh: the right next step changes as she checks in / books.
  await ctrl.loadBookingContext(refresh: true);
  final ctx = ctrl.bookingContext.value;
  final step = ctx?.nextStep ?? (ctx != null && ctx.canBook ? 'book_followup' : 'explore_plans');
  switch (step) {
    case 'book_initial':
    case 'book_followup':
      if (ctx != null && ctx.canBook) {
        await BookConsultationSheet.show(
          popupVariable: popupVariable,
          dietitianId: ctx.dietitianId!,
          userId: ctx.userId!,
          userPlanId: ctx.userPlanId!,
          kind: step == 'book_initial' ? 'initial' : 'followup',
        );
      } else if (_paidWithoutDietitian(ctx)) {
        _showNoDietitianYet();
      } else {
        Get.to<dynamic>(() => OurPlansScreen());
      }
      break;
    case 'day15_checkin':
      // Day 15 progress is now the halfway weekly check-in (Oct 2026).
      // Always opens (it used to do nothing when the plan id was missing).
      await WeeklyCheckinSheet.open();
      await ctrl.loadBookingContext(refresh: true);
      break;
    case 'locked':
      await BookingLockedSheet.show();
      break;
    case 'followup_booked':
      CustomToast.successToast(
          msg: 'Your follow-up is booked. See it on your Diet tab.');
      break;
    case 'initial_booked':
      CustomToast.successToast(
          msg: 'Your consultation is booked. See it on your Diet tab.');
      break;
    case 'plan_preparing':
      CustomToast.successToast(
          msg: 'Your dietitian is preparing your plan. We will let you know when it is ready.');
      break;
    default: // renew, explore_plans
      Get.to<dynamic>(() => OurPlansScreen());
  }
}

/// Button label for the next step (banner + plan-ended card).
String _nextStepCta(String? step) {
  switch (step) {
    case 'book_initial':
      return 'Book consultation';
    case 'day15_checkin':
      return 'Do my check-in';
    case 'locked':
      return 'Contact us';
    case 'followup_booked':
      return 'Follow-up booked';
    case 'initial_booked':
      return 'Consultation booked';
    case 'plan_preparing':
      return 'Plan on its way';
    case 'renew':
      return 'Renew my plan';
    case 'explore_plans':
      return 'Explore plans';
    default:
      return 'Book follow-up';
  }
}

Future<void> _onTimelineBookFollowUp(DietPlanUserController _) async {
  // Distinct popup variable so analytics can tell where the booking
  // came from (banner vs end-of-plan empty state).
  await _bookFollowUpFromContext('POPUP_PLAN_ENDING_SOON');
}

/// Public entry point for the V2 meal log sheet. Used by both this
/// file (Diet tab meal cards on today) and `PaidMealLogCard` on the
/// paid home so both surfaces share the exact same Phase F.2 logging
/// flow (3 buttons + alternative-text reveal + optimistic update +
/// revert on failure).
///
/// The actual body lives in this file as `_MealLogSheetBody`; this
/// helper just wraps the bottom-sheet show-call so callers don't need
/// to know the private widget exists.
Future<void> showV2MealLogSheet({required DietPlanMealV2 meal}) {
  return V2BottomSheet.show<void>(
    title: meal.mealType.label,
    child: _MealLogSheetBody(meal: meal),
  );
}

/// Phase G.3 — Day 7 check-in trigger banner. Self-contained: hides
/// itself when the controller says ineligible (no active plan, today
/// < 7, or already submitted/dismissed for this cycle).
///
/// Visual: white card, 4px accent-green left rail, mint border on the
/// other three sides, small caps "QUICK CHECK-IN" header, 1-line
/// prompt, full-width V2PrimaryButton + dismiss X.
///
/// Public (Phase H follow-up) so paid_home_screen_v2.dart can mount
/// the same banner at the top of the cream body — both surfaces share
/// the same Day7ReviewController, so submitting/dismissing from either
/// flips eligibility on both instantly.
class V2Day7TriggerBanner extends StatelessWidget {
  const V2Day7TriggerBanner({super.key});

  void _openCheckIn(DietPlanUserController dietCtrl) {
    final plan = dietCtrl.activePlan.value;
    final userPlanId = plan?.userPlanId;
    if (userPlanId == null) return;
    Get.to<dynamic>(() => Day7ReviewScreen(
          userPlanId: userPlanId,
          cycle: Get.find<Day7ReviewController>().currentCycle,
        ));
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<Day7ReviewController>()) {
      return const SizedBox.shrink();
    }
    final ctrl = Get.find<Day7ReviewController>();
    final dietCtrl = Get.find<DietPlanUserController>();
    return Obx(() {
      if (!ctrl.isEligible.value) return const SizedBox.shrink();
      if (dietCtrl.activePlan.value == null) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: const Border(
              left: BorderSide(color: _kAccent, width: 4),
              top: BorderSide(color: _kCardBorder),
              right: BorderSide(color: _kCardBorder),
              bottom: BorderSide(color: _kCardBorder),
            ),
            boxShadow: [
              BoxShadow(
                color: _kHeroDark.withOpacity(0.05),
                offset: const Offset(0, 2),
                blurRadius: 10,
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(14.w, 12.h, 6.w, 14.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'QUICK CHECK-IN',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        color: _kAccent,
                        letterSpacing: 0.84,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: ctrl.dismiss,
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: _kSage),
                    tooltip: 'Dismiss',
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(0, 2.h, 8.w, 12.h),
                child: Text(
                  'How is your plan going? Share a quick update with '
                  'your dietitian.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: _kHeroDark,
                    height: 1.4,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: V2PrimaryButton(
                  label: 'Take 2 minutes',
                  leadingIcon: Icons.rate_review_outlined,
                  onPressed: () => _openCheckIn(dietCtrl),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Phase F.1 — "today's meals" surface for the user. Renders 4 states
/// off `DietPlanUserController`: loading, error, no-active-plan
/// (Option B empty state), plan-ended, and the loaded list of meal
/// cards sorted by time.
///
/// Lives as a `Section` widget so callers (the diet bottom-nav tab,
/// future home embeds) wrap it in their own scaffold + scroll. The
/// section provides padding internally so it can be dropped into a
/// SingleChildScrollView or directly into a Scaffold body.
class V2TodayMealsSection extends StatelessWidget {
  /// Paid clients on the Diet tab (Oct 2026): the hero's "today" card
  /// already shows the day picker and the day summary, so the "plan
  /// ending" card, the day strip and the day summary card are left out
  /// here. Meal cards are unchanged.
  final bool compact;
  const V2TodayMealsSection({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<DietPlanUserController>();
    return Obx(() {
      if (ctrl.isLoading.value && ctrl.activePlan.value == null) {
        return const _LoadingState();
      }
      if (ctrl.errorMessage.value != null && ctrl.activePlan.value == null) {
        return _ErrorState(
          message: ctrl.errorMessage.value!,
          onRetry: () => ctrl.loadActivePlan(refresh: true),
        );
      }
      final plan = ctrl.activePlan.value;
      if (plan == null) {
        // Phase F.3 — lazily fetch booking context so the CTA can open
        // BookConsultationSheet with real IDs. Idempotent on the
        // controller side; safe to schedule on every empty-state paint.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ctrl.loadBookingContext();
        });
        return const _NoPlanState();
      }
      if (ctrl.planHasEnded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ctrl.loadBookingContext();
        });
        // Oct 2026: paid package still running → keep showing her plan
        // (repeat) with her next step on top, never an empty Diet tab.
        if (!ctrl.isRepeating) return _PlanEndedState(plan: plan);
      }
      final today = ctrl.todaysDay;
      if (today == null) {
        // Dead-end audit (Oct 2026): plan starts later (activated for a
        // future day) or today's day is missing — this used to say "Your
        // plan is complete!". Say when it starts / that it's coming.
        return _PlanStartsState(plan: plan);
      }
      // Phase G.1 — _LoadedState now drives day selection itself.
      return _LoadedState(plan: plan, compact: compact);
    });
  }
}

// ─── States ───────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220.h,
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: _Card(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kDanger.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.error_outline, color: _kDanger, size: 24.w),
            ),
            SizedBox(height: 12.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: _kHeroDark,
              ),
            ),
            SizedBox(height: 14.h),
            SizedBox(
              width: 160.w,
              child: V2SecondaryButton(label: 'Retry', onPressed: onRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPlanState extends StatelessWidget {
  const _NoPlanState();

  /// Phase F.3 — open BookConsultationSheet when we have real IDs from
  /// the booking-context endpoint; otherwise fall back to the paywall.
  /// `kind: 'initial'` because the user has no active plan and likely
  /// has never had one (no userPlanId means brand-new user → paywall).
  Future<void> _onBookConsultation() async {
    final ctrl = Get.find<DietPlanUserController>();
    final ctx = ctrl.bookingContext.value;
    if (ctx != null && ctx.canBook) {
      await BookConsultationSheet.show(
        popupVariable: 'POPUP_NO_PLAN_YET',
        dietitianId: ctx.dietitianId!,
        userId: ctx.userId!,
        userPlanId: ctx.userPlanId!,
        kind: 'initial',
      );
      return;
    }
    if (_paidWithoutDietitian(ctx)) {
      _showNoDietitianYet();
      return;
    }
    // Brand-new user (no UserPlan yet) — they need to buy a plan
    // before a dietitian gets assigned, so route to the paywall.
    Get.to<dynamic>(() => OurPlansScreen());
  }

  /// Trial with no plan (her free AI plan didn't get made): make it now.
  Future<void> _onCreateTrialPlan() async {
    final home = Get.find<HomeController>();
    final ok = await home.submitTrialQuickIntake();
    if (ok) {
      await Get.find<DietPlanUserController>().loadActivePlan(refresh: true);
      if (home.trialPlanPending.value) {
        CustomToast.successToast(
            msg: "Still preparing your plan. We'll send you a notification when it's ready.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reactive off ConsultationController — the same signal
    // UpcomingConsultationCard (the card right above this one) uses to
    // show "CONSULTATION BOOKED". When a booking already exists, this
    // card would otherwise say "book a consultation" directly under a
    // card that says one is already booked — confusing, and duplicate
    // work if tapped. Swap to "plan's on its way" copy instead, and
    // drop the CTA (Reschedule/Cancel already live on the card above;
    // no second action needed here).
    final consultCtrl = Get.find<ConsultationController>();
    final planCtrl = Get.find<DietPlanUserController>();
    return Obx(() {
      // Consultation done, plan not delivered yet: tell her it's being
      // prepared (and when), instead of asking her to book again.
      final preparing = planCtrl.bookingContext.value?.planPreparing;
      if (preparing != null) {
        return V2PlanPreparingCard(info: preparing);
      }
      final appt = consultCtrl.upcomingAppointment.value;
      final hasPendingBooking = appt != null;
      // Trial with no plan: her free plan, not a consultation (Oct 2026).
      final trial = !hasPendingBooking && _isTrial();
      final home = Get.isRegistered<HomeController>() ? Get.find<HomeController>() : null;
      final creating = home?.trialQuickIntakeLoad.value == true;
      // AI took longer than 6 s: being made in the background (Oct 2026).
      final trialPreparing = trial && home?.trialPlanPending.value == true;

      // Paid, no plan yet (Oct 2026): her journey in 5 steps, instead of a
      // paragraph + "Talk to support". Booked: step 1 done, step 2 next.
      if (!trial) {
        return _JourneyCard(
          booked: hasPendingBooking,
          canBook: !hasPendingBooking && home?.planFrozen.value != true,
          onBook: _onBookConsultation,
        );
      }

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: _Card(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(hasPendingBooking ? '🗓️' : '🥗',
                    style: TextStyle(fontSize: 48.sp)),
              ),
              SizedBox(height: 14.h),
              Center(
                child: Text(
                  hasPendingBooking
                      ? 'PLAN ON THE WAY'
                      : trial
                          ? 'YOUR FREE PLAN'
                          : 'NO PLAN YET',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: _kSage,
                    letterSpacing: 0.84,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                hasPendingBooking
                    ? 'Your consultation is booked'
                    : trialPreparing
                        ? 'Your plan is being prepared ✨'
                        : trial
                            ? "Your free meal plan isn't ready yet"
                            : "Your dietitian hasn't shared a plan yet",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: _kHeroDark,
                  letterSpacing: -0.2,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                hasPendingBooking
                    ? 'Once your consultation is done, your dietitian will '
                        'build a personalized AI-powered meal plan around '
                        'your goals, cycle, and preferences — it will show '
                        'up right here.'
                    : trialPreparing
                        ? "It will be shared with you soon. We'll send you a "
                            "notification as soon as it's ready."
                        : trial
                        ? "Let's make it now. It takes a few seconds and is "
                            'built around your goals and cycle.'
                        : 'Book a consultation with your dietitian to get a '
                            'personalized AI-powered meal plan tailored to your '
                            'goals, cycle, and preferences.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.sp,
                  color: _kBodyMuted,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 18.h),
              if (trial)
                V2PrimaryButton(
                  label: creating
                      ? 'Making your plan…'
                      : (trialPreparing ? 'Check again' : 'Create my free plan'),
                  leadingIcon: Icons.auto_awesome_rounded,
                  onPressed: creating ? null : _onCreateTrialPlan,
                )
              else if (!hasPendingBooking && home?.planFrozen.value != true)
                V2PrimaryButton(
                  label: 'Book a Consultation',
                  leadingIcon: Icons.event_note_rounded,
                  onPressed: _onBookConsultation,
                ),
            ],
          ),
        ),
      );
    });
  }
}

/// "No plan yet" for paid clients: the dietitian journey as 5 steps,
/// the current one highlighted, and one button.
class _JourneyCard extends StatelessWidget {
  final bool booked;
  final bool canBook;
  final VoidCallback onBook;
  const _JourneyCard({required this.booked, required this.canBook, required this.onBook});

  static const _green = Color(0xFF6DC55A);
  static const _deep = Color(0xFF3E8E36);
  static const _line = Color(0xFFDCE8D6);
  static const _wash = Color(0xFFEAF6E4);

  static const _steps = [
    ('Book your call', 'A video call with your dietitian'),
    ('Your plan is ready', 'Within 2 working days of your call'),
    ('Day 7 check-in', 'Tell us how week 1 went, we tune it'),
    ('Day 15 check-in', "Halfway: weight, energy, what's working"),
    ('Follow-up call', 'Your dietitian plans your next 15 days'),
  ];

  TextStyle _t(double size, {FontWeight w = FontWeight.w400, Color c = _kHeroDark, double? h}) =>
      TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: w, color: c, height: h);

  Widget _step(int i) {
    final done = booked && i == 0;
    final now = booked ? i == 1 : i == 0;
    final last = i == _steps.length - 1;
    final (title, sub) = _steps[i];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32.w,
            child: Column(children: [
              Container(
                width: 30.w,
                height: 30.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done || now ? _green : Colors.white,
                  border: done || now ? null : Border.all(color: _line, width: 1.5),
                  boxShadow: now
                      ? [BoxShadow(color: _green.withOpacity(0.25), blurRadius: 0, spreadRadius: 5)]
                      : null,
                ),
                child: done
                    ? Icon(Icons.check_rounded, size: 16.sp, color: Colors.white)
                    : Text('${i + 1}',
                        style: _t(13.sp, w: FontWeight.w700, c: now ? Colors.white : _kSage)),
              ),
              if (!last)
                Expanded(child: Container(width: 2, margin: EdgeInsets.symmetric(vertical: 3.h), color: _line)),
            ]),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14.h, top: 3.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6.w,
                    children: [
                      Text(title, style: _t(14.sp, w: FontWeight.w700, c: now ? _deep : _kHeroDark, h: 1.3)),
                      if (now)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.h),
                          decoration: BoxDecoration(color: _wash, borderRadius: BorderRadius.circular(20)),
                          child: Text(booked ? 'NEXT' : 'YOU ARE HERE',
                              style: _t(9.5.sp, w: FontWeight.w800, c: _deep)),
                        ),
                    ],
                  ),
                  Text(done ? 'Booked ✓' : sub, style: _t(12.sp, c: _kBodyMuted, h: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: _Card(
        padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 18.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 48.w,
                height: 48.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _wash, borderRadius: BorderRadius.circular(14)),
                child: Text(booked ? '🗓️' : '🥗', style: TextStyle(fontSize: 24.sp)),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(booked ? 'PLAN ON THE WAY' : 'NO PLAN YET',
                      style: _t(10.5.sp, w: FontWeight.w800, c: _deep).copyWith(letterSpacing: 0.8)),
                  SizedBox(height: 2.h),
                  Text(booked ? 'Your call is booked' : 'Your plan starts with one call',
                      style: _t(17.sp, w: FontWeight.w800, h: 1.25)),
                ]),
              ),
            ]),
            SizedBox(height: 12.h),
            Text(
              booked ? 'After your call, here\'s what happens:' : "Here's your journey with your dietitian:",
              style: _t(13.sp, c: _kBodyMuted, h: 1.5),
            ),
            SizedBox(height: 14.h),
            for (var i = 0; i < _steps.length; i++) _step(i),
            if (canBook) ...[
              SizedBox(height: 18.h),
              V2PrimaryButton(
                label: 'Book my call',
                leadingIcon: Icons.event_note_rounded,
                onPressed: onBook,
              ),
              SizedBox(height: 8.h),
              Center(
                child: Text('Pick a time that suits you · takes 1 minute',
                    style: _t(11.5.sp, c: _kSage)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Plan exists but today isn't one of its days yet (activated for a later
/// day, or that day is missing). Dead-end audit Oct 2026: this used to
/// show "Your plan is complete!".
class _PlanStartsState extends StatelessWidget {
  final DietPlanV2 plan;
  const _PlanStartsState({required this.plan});

  static const _weekday = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final start = plan.activatedAt?.toLocal();
    final now = DateTime.now();
    final future = start != null &&
        DateTime(start.year, start.month, start.day)
            .isAfter(DateTime(now.year, now.month, now.day));
    final when = future
        ? '${_weekday[start.weekday - 1]}, ${start.day} ${_month[start.month - 1]}'
        : null;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: _Card(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Text('🗓️', style: TextStyle(fontSize: 48.sp))),
            SizedBox(height: 14.h),
            Text(
              when != null ? 'Your plan starts on $when' : 'Your plan is on its way',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: _kHeroDark,
                height: 1.3,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              "Your meals for each day will show here from that day. "
              'Pull down to refresh.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                color: _kBodyMuted,
                height: 1.5,
              ),
            ),
            SizedBox(height: 14.h),
            Center(
              child: V2GhostButton(
                label: 'Talk to support',
                onPressed: () => Get.to<dynamic>(() => HelpScreen()),
                fullWidth: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanEndedState extends StatefulWidget {
  final DietPlanV2 plan;
  const _PlanEndedState({required this.plan});

  @override
  State<_PlanEndedState> createState() => _PlanEndedStateState();
}

/// Plan finished. What she sees next depends on where she is in her
/// package (server's bookingContext.nextStep), so the button always
/// leads somewhere that works: check-in before the follow-up, book the
/// follow-up, renew, or (trial) explore plans.
class _PlanEndedStateState extends State<_PlanEndedState> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Get.find<DietPlanUserController>().loadBookingContext(refresh: true);
      }
    });
  }

  ({String title, String body}) _copy(String? step) {
    final days = widget.plan.planDays;
    switch (step) {
      case 'explore_plans':
        return (
          title: 'Your free plan has ended',
          body: 'Choose a plan to get a dietitian who builds your meals '
              'around you.',
        );
      case 'renew':
        return (
          title: 'Your plan is complete!',
          body: "You've had both consultations on this package. Renew to "
              'keep going with your dietitian.',
        );
      case 'locked':
        return (
          title: 'Your $days-day plan is complete!',
          body: 'Our team will book your next session with you.',
        );
      case 'book_initial':
        return (
          title: 'Your $days-day plan is complete!',
          body: 'Book your consultation so your dietitian can make your '
              'personal plan.',
        );
      case 'day15_checkin':
        return (
          title: 'Your $days-day plan is complete!',
          body: 'Your next plan comes after a quick check-in. Tell us how '
              "it went, then book your follow-up.",
        );
      case 'plan_preparing':
        return (
          title: 'Your $days-day plan is complete!',
          body: 'Your dietitian is preparing your own plan. It will show '
              'here as soon as it is ready.',
        );
      case 'initial_booked':
        return (
          title: 'Your $days-day plan is complete!',
          body: 'Your consultation is booked. Your dietitian makes your '
              'own plan after it.',
        );
      case 'followup_booked':
        return (
          title: 'Your $days-day plan is complete!',
          body: 'Your follow-up is booked. Your next plan will be ready '
              'within 2 working days of the session.',
        );
      default:
        return (
          title: 'Your $days-day plan is complete!',
          body: 'Time to check in with your dietitian for your next plan.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<DietPlanUserController>();
    return Obx(() {
      final step = ctrl.bookingContext.value?.nextStep;
      final copy = _copy(step);
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: _Card(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Text('🎉', style: TextStyle(fontSize: 48.sp))),
              SizedBox(height: 14.h),
              Center(
                child: Text(
                  'PLAN COMPLETED',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: _kAccent,
                    letterSpacing: 0.84,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                copy.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: _kHeroDark,
                  letterSpacing: -0.2,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                copy.body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.sp,
                  color: _kBodyMuted,
                  height: 1.5,
                ),
              ),
              if (step != 'followup_booked') ...[
                SizedBox(height: 18.h),
                V2PrimaryButton(
                  label: _nextStepCta(step),
                  leadingIcon: Icons.event_repeat_rounded,
                  onPressed: () => _bookFollowUpFromContext('POPUP_PLAN_ENDED'),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _LoadedState extends StatelessWidget {
  final DietPlanV2 plan;
  final bool compact;
  const _LoadedState({required this.plan, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<DietPlanUserController>();
    return Obx(() {
      final day = ctrl.selectedDay;
      // Defensive — selectedDayNumber points outside plan.days. Falls
      // back to today; if today is also missing, the empty-state path
      // already short-circuited above so we never get here.
      final renderDay = day ?? ctrl.todaysDay;
      if (renderDay == null) return const SizedBox.shrink();

      final showStrip = plan.planDays > 1 && !compact;
      final viewState = ctrl.isViewingFuture
          ? _ViewState.future
          : ctrl.isViewingPast
              ? _ViewState.past
              : _ViewState.today;

      // Sort meals by time so the column reads breakfast → dinner. Server
      // already orders them, but the client guards against future edits
      // landing out of order.
      final meals = [...renderDay.meals]
        ..sort((a, b) => a.time.compareTo(b.time));

      return Padding(
        padding: EdgeInsets.fromLTRB(0, 12.h, 0, 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Phase G.3 — Day 7 check-in trigger. Sits above the timeline
            // banner so it's the first thing the user sees after the
            // app bar. Hidden once submitted or dismissed for the cycle.
            // Day 7 check-in banner removed (Oct 2026): week 1 of the
            // weekly check-in (Home card) asks the Day 7 questions now.
            // Phase G.2 — plan progress + ending-soon CTA. Renders
            // nothing when the plan is already ended (F.1's Plan
            // Completed empty state takes over up the tree) — extra
            // guard kept here so future refactors can drop the
            // banner anywhere without re-adding the check.
            // The top hero already shows "Day X of Y" and days left, so
            // the big "Your plan" card only appears when it has something
            // new to say: the plan is ending soon (with its follow-up CTA).
            if (!compact && !ctrl.isPlanEnded && ctrl.isPlanEndingSoon)
              Builder(builder: (_) {
                // Banner label depends on her next step; load it once.
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => ctrl.loadBookingContext());
                return const SizedBox.shrink();
              }),
            if (!compact && !ctrl.isPlanEnded && ctrl.isPlanEndingSoon)
              V2PlanTimelineBanner(
                plan: plan,
                todaysDayNumber: ctrl.todaysDayNumber,
                daysRemaining: ctrl.daysRemainingInPlan ?? 0,
                progressPercent: ctrl.planProgressPercent,
                endingSoon: ctrl.isPlanEndingSoon,
                onBookFollowUp: ctrl.isPlanEndingSoon
                    ? () => _onTimelineBookFollowUp(ctrl)
                    : null,
                ctaLabel: _nextStepCta(ctrl.bookingContext.value?.nextStep),
              ),
            if (showStrip)
              Stack(
                children: [
                  V2DayStrip(
                    plan: plan,
                    selectedDayNumber: ctrl.effectiveDayNumber,
                    todayDayNumber: ctrl.todaysDayNumber,
                    onDaySelected: ctrl.selectDay,
                    controller: ctrl,
                  ),
                  if (!ctrl.isViewingToday)
                    Positioned(
                      right: 16.w,
                      top: 12.h,
                      child: _TodayJumpChip(onTap: ctrl.selectToday),
                    ),
                ],
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!compact) ...[
                    _DayHeader(
                      plan: plan,
                      day: renderDay,
                      viewState: viewState,
                      date: ctrl.dateForDay(renderDay.dayNumber),
                      meals: meals,
                    ),
                    SizedBox(height: 14.h),
                  ],
                  // Oct 2026: next step on top — while repeating her ended
                  // plan, or in the last 2 days of a plan.
                  _NextStepStrip(
                    repeating: ctrl.isRepeating,
                    daysLeft: ctrl.daysRemainingInPlan,
                  ),
                  // Oct 2026: AI plan with no dietitian (free trial / before
                  // her consultation) = a GENERAL plan, not a personal one.
                  if (plan.dietitianId == null) ...[
                    const _GeneralPlanNote(),
                    SizedBox(height: 12.h),
                  ],
                  _MealTimeline(
                    key: ValueKey('meals-${renderDay.dayNumber}'),
                    meals: meals,
                    // Repeating: logs belong to TODAY's date, not the
                    // original day's date.
                    dayNumber: ctrl.isRepeating
                        ? (ctrl.todaysDayNumber ?? renderDay.dayNumber)
                        : renderDay.dayNumber,
                    viewState: viewState,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Phase G.1 — discrimates rendering for the day being viewed.
enum _ViewState { today, past, future }

/// Floating "Today" jump chip that overlays the day strip when the
/// user has navigated away from today.
class _TodayJumpChip extends StatelessWidget {
  final VoidCallback onTap;
  const _TodayJumpChip({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: _kAccent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: _kAccent.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.today_rounded, size: 14.w, color: Colors.white),
              SizedBox(width: 5.w),
              Text(
                'Today',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Day summary (redesigned) ─────────────────────────────────────────
// A calorie ring for the day plus "meals done" at a glance, instead of a
// single uppercase label line. Same data as before, nothing new fetched.
class _DayHeader extends StatelessWidget {
  final DietPlanV2 plan;
  final DietPlanDayV2 day;
  final _ViewState viewState;
  final DateTime? date;
  final List<DietPlanMealV2> meals;

  const _DayHeader({
    required this.plan,
    required this.day,
    required this.viewState,
    required this.date,
    required this.meals,
  });

  static const _weekday = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  static const _monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _dateLine() {
    if (date == null) return 'Day ${day.dayNumber} of ${plan.planDays}';
    final wd = _weekday[(date!.weekday - 1).clamp(0, 6)];
    final mo = _monthShort[(date!.month - 1).clamp(0, 11)];
    return '$wd, ${date!.day} $mo';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<DietPlanUserController>();
    return Obx(() {
      var done = 0;
      var eaten = 0;
      for (final m in meals) {
        final s = ctrl.getLogForMeal(day.dayNumber, m.mealType.wire)?.status;
        if (s == MealLogStatusV2.followed || s == MealLogStatusV2.alternative) {
          done++;
          eaten += m.calories;
        } else if (s == MealLogStatusV2.skipped) {
          done++;
        }
      }
      final total = day.totalCalories <= 0 ? 1 : day.totalCalories;
      final progress = viewState == _ViewState.future
          ? 0.0
          : (eaten / total).clamp(0.0, 1.0);

      final String tag;
      final Color tagColor;
      switch (viewState) {
        case _ViewState.today:
          tag = 'TODAY';
          tagColor = _kAccent;
          break;
        case _ViewState.past:
          tag = 'PAST DAY';
          tagColor = _kBodyMuted;
          break;
        case _ViewState.future:
          tag = 'COMING UP';
          tagColor = _kSage;
          break;
      }

      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kHeroDark, Color(0xFF24502F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 74.w,
              height: 74.w,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 74.w,
                    height: 74.w,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white.withOpacity(0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(_kAccent),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$done/${meals.length}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'meals',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.sp,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: tagColor.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w800,
                            color: viewState == _ViewState.today
                                ? _kAccent
                                : Colors.white.withOpacity(0.8),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Day ${day.dayNumber} of ${plan.planDays}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    _dateLine(),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: viewState == _ViewState.future ? '' : '$eaten ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _kAccent,
                          ),
                        ),
                        TextSpan(
                          text: viewState == _ViewState.future
                              ? '${day.totalCalories} kcal planned'
                              : 'of ${day.totalCalories} kcal',
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5.sp,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ─── Meal row (redesigned) ────────────────────────────────────────────
// Timeline layout: time on the left joined by a line, a card on the
// right with a meal emoji, food, the AI's tip and a clear status/action.
// Tap behaviour is unchanged (today: log sheet, past: read-only, future:
// preview).
String _mealEmoji(MealTypeV2 t) {
  switch (t) {
    case MealTypeV2.breakfast:
      return '🍳';
    case MealTypeV2.midMorning:
      return '🍎';
    case MealTypeV2.lunch:
      return '🍛';
    case MealTypeV2.afternoonSnack:
      return '🥜';
    case MealTypeV2.eveningSnack:
      return '🫖';
    case MealTypeV2.dinner:
      return '🍲';
  }
}

String _prettyTime(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return hhmm;
  final h = int.tryParse(parts[0]);
  final m = parts[1].padLeft(2, '0').substring(0, 2);
  if (h == null) return hhmm;
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m $suffix';
}

/// Next-step strip above the meals (Oct 2026).
///   repeating: her plan ended, package still running — "keep following
///              your plan" + what's next (check-in / book / booked / renew).
///   daysLeft <= 1 (last 2 days of a plan): "Your plan ends …" + next step.
/// Hidden otherwise, and for a free trial (it has its own prompts).
class _NextStepStrip extends StatefulWidget {
  final bool repeating;
  final int? daysLeft;
  const _NextStepStrip({required this.repeating, required this.daysLeft});

  @override
  State<_NextStepStrip> createState() => _NextStepStripState();
}

class _NextStepStripState extends State<_NextStepStrip> {
  static const _weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  bool get _ending => !widget.repeating && widget.daysLeft != null && widget.daysLeft! <= 1;

  @override
  void initState() {
    super.initState();
    if (widget.repeating || _ending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Get.find<DietPlanUserController>().loadBookingContext();
      });
    }
  }

  static String _d(DateTime d) => '${_weekday[d.weekday - 1]} ${d.day} ${_month[d.month - 1]}';

  /// True while `UpcomingConsultationCard` (same tab, above this strip) is
  /// visible with a booking prompt of its own: an upcoming session, or a
  /// missed / canceled / expired one with "Pick a new time".
  static bool _consultationCardShowsBooking() {
    if (!Get.isRegistered<ConsultationController>()) return false;
    final appt = Get.find<ConsultationController>().upcomingAppointment.value;
    if (appt == null) return false;
    return appt.status != 'completed';
  }

  Widget _stripCard(String title, String body, String? cta, dynamic ctx) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Container(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
        decoration: BoxDecoration(
          color: _kCream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, fontWeight: FontWeight.w700, color: _kHeroDark)),
            SizedBox(height: 2.h),
            Text(body,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp, height: 1.45, color: _kBodyMuted)),
            if (cta != null) ...[
              SizedBox(height: 8.h),
              V2PrimaryButton(
                label: cta,
                fullWidth: false,
                onPressed: () => _bookFollowUpFromContext(
                    widget.repeating ? 'POPUP_PLAN_ENDED' : 'POPUP_PLAN_ENDING_SOON'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.repeating && !_ending) return const SizedBox.shrink();
    final ctrl = Get.find<DietPlanUserController>();
    return Obx(() {
      final ctx = ctrl.bookingContext.value;
      final step = ctx?.nextStep;
      if (ctx == null || step == null || step == 'explore_plans') return const SizedBox.shrink();
      // Don't ask her to book twice (Oct 2026). When the consultation card
      // above already shows her session — booked, or missed / canceled /
      // expired with its own "Pick a new time" — this strip's "Book
      // consultation" / "Book follow-up" is the same ask a second time.
      // The card is hidden only when there is no current appointment or
      // it is completed; in both of those cases the strip still shows.
      if ((step == 'book_initial' || step == 'book_followup') && _consultationCardShowsBooking()) {
        return const SizedBox.shrink();
      }
      final ends = ctx.packageEndsOn;
      final now = DateTime.now();
      final endsSoon = ends != null && ends.difference(now).inDays < 5;
      final opens = ctx.halfwayOpensOn;
      final notOpenYet = step == 'day15_checkin' && opens != null && opens.isAfter(now);

      // Starter plan (made without a dietitian: free trial, or a paid
      // client before her first consultation). Its end is NOT her package
      // ending, so never "Do my check-in" / "book your follow-up" here.
      final starter = ctrl.activePlan.value?.dietitianId == null;
      final title = widget.repeating
          ? 'Keep going with your plan 🔁'
          : starter
              ? (widget.daysLeft == 0 ? 'Your starter plan ends today' : 'Your starter plan ends tomorrow')
              : (widget.daysLeft == 0 ? 'Your plan ends today' : 'Your plan ends tomorrow');
      String body;
      String? cta;
      if (starter && !widget.repeating) {
        if (step == 'book_initial') {
          body = 'Book your consultation so your dietitian can make your own plan.';
          cta = 'Book consultation';
        } else {
          body = step == 'initial_booked'
              ? 'Your own plan comes after your consultation. See your booking above.'
              : step == 'plan_preparing'
                  ? 'Your dietitian is preparing your own plan. It shows here when it is ready.'
                  : 'Your dietitian shares your own plan after your consultation.';
        }
        return _stripCard(title, body, cta, ctx);
      }
      switch (step) {
        case 'initial_booked':
          body = 'Your consultation is booked. Your own plan comes after it.';
          break;
        case 'plan_preparing':
          body = 'Your dietitian is preparing your own plan.';
          break;
        case 'day15_checkin':
          body = notOpenYet
              ? 'Your check-in opens on ${_d(opens)}. Then you can book your follow-up for your next plan.'
              : 'Do your check-in, then book your follow-up for your next plan.';
          cta = notOpenYet ? null : 'Do my check-in';
          break;
        case 'book_followup':
          body = 'Book your follow-up to get your next plan.';
          cta = 'Book follow-up';
          break;
        case 'book_initial':
          body = 'Book your consultation to get your own plan.';
          cta = 'Book consultation';
          break;
        case 'followup_booked':
          body = 'Your follow-up is booked. Your new plan comes after it.';
          break;
        case 'locked':
          body = 'Contact us to book your next session.';
          cta = 'Contact us';
          break;
        case 'renew':
          if (endsSoon) {
            body = 'Your package ends on ${_d(ends)}. Renew to keep going with your dietitian.';
            cta = 'Renew my plan';
          } else {
            body = ends != null
                ? "You've had both consultations. Keep following your plan until your package ends on ${_d(ends)}."
                : "You've had both consultations. Keep following your plan.";
          }
          break;
        default:
          body = 'Keep following your plan until your next one comes.';
      }
      if (widget.repeating && step != 'renew') {
        body = 'Your ${ctrl.activePlan.value?.planDays ?? ''}-day plan starts again from Day 1 until your next plan. $body';
      }
      // Plan paused: no booking / check-in button (Oct 2026).
      if (Get.isRegistered<HomeController>() && Get.find<HomeController>().planFrozen.value) {
        cta = null;
      }
      return _stripCard(title, body, cta, ctx);
    });
  }
}

/// Shown above the meals when the plan was made by AI without a dietitian
/// (free trial, or a paid client before her consultation). Oct 2026.
class _GeneralPlanNote extends StatelessWidget {
  const _GeneralPlanNote();

  @override
  Widget build(BuildContext context) {
    final trial = _isTrial();
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1DFB8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18.w, color: const Color(0xFF8A5A06)),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your starter plan 🌱',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5C3D05),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  // Short and friendly (Oct 2026): general plan, not personal;
                  // health-condition caution in one line.
                  'A general plan to get you started. '
                  '${trial ? 'Choose a plan for one made just for you.' : 'Your dietitian will make one just for you after your call.'}'
                  ' Health condition? Check with your doctor first.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.sp,
                    height: 1.45,
                    color: const Color(0xFF8A5A06),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Meal list (Oct 2026): only one meal card is open at a time.
/// Today: the meal for the current time in her time zone is open (the
/// last meal whose time has come; before breakfast, the first meal) and
/// it moves on by itself as the day goes. Other days: the first meal.
/// Tapping a closed card opens it and closes the others.
class _MealTimeline extends StatefulWidget {
  final List<DietPlanMealV2> meals;
  final int dayNumber;
  final _ViewState viewState;
  const _MealTimeline({
    super.key,
    required this.meals,
    required this.dayNumber,
    required this.viewState,
  });

  @override
  State<_MealTimeline> createState() => _MealTimelineState();
}

class _MealTimelineState extends State<_MealTimeline> {
  /// The card she tapped open; null = follow the clock.
  int? _picked;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Re-check once a minute so the open card follows the clock.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _picked == null && widget.viewState == _ViewState.today) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant _MealTimeline old) {
    super.didUpdateWidget(old);
    if (old.viewState != widget.viewState) _picked = null;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static int? _minutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1].padLeft(2, '0').substring(0, 2));
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  int _nowMinutes() {
    DateTime now;
    try {
      final zone = Get.find<DietPlanUserController>().auth.userTimeZone;
      now = tz.TZDateTime.now(tz.getLocation(zone));
    } catch (_) {
      now = DateTime.now();
    }
    return now.hour * 60 + now.minute;
  }

  int _clockIndex() {
    if (widget.viewState != _ViewState.today) return 0;
    final now = _nowMinutes();
    var idx = 0;
    for (var i = 0; i < widget.meals.length; i++) {
      final t = _minutes(widget.meals[i].time);
      if (t != null && t <= now) idx = i;
    }
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final open = _picked ?? _clockIndex();
    final meals = widget.meals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < meals.length; i++)
          _MealCard(
            meal: meals[i],
            dayNumber: widget.dayNumber,
            viewState: widget.viewState,
            isFirst: i == 0,
            isLast: i == meals.length - 1,
            expanded: i == open,
            onExpand: () => setState(() => _picked = i),
          ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final DietPlanMealV2 meal;
  final int dayNumber;
  final _ViewState viewState;
  final bool isFirst;
  final bool isLast;
  /// Open = full card (tip + log button). Closed = type, kcal and name;
  /// tapping a closed card opens it instead of the log sheet.
  final bool expanded;
  final VoidCallback? onExpand;

  const _MealCard({
    required this.meal,
    required this.dayNumber,
    required this.viewState,
    this.isFirst = false,
    this.isLast = false,
    this.expanded = true,
    this.onExpand,
  });

  void _openSheet(DietPlanUserController ctrl) {
    switch (viewState) {
      case _ViewState.today:
        showV2MealLogSheet(meal: meal);
        break;
      case _ViewState.past:
        final log = ctrl.getLogForMeal(dayNumber, meal.mealType.wire);
        V2BottomSheet.show<void>(
          title: meal.mealType.label,
          child: _PastMealSheetBody(
            meal: meal,
            log: log,
            date: ctrl.dateForDay(dayNumber),
          ),
        );
        break;
      case _ViewState.future:
        V2BottomSheet.show<void>(
          title: meal.mealType.label,
          child: _FutureMealSheetBody(
            meal: meal,
            date: ctrl.dateForDay(dayNumber),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<DietPlanUserController>();
    return Obx(() {
      // Read the log on every day (even future ones) so this Obx always
      // listens to something — GetX throws if an Obx reads nothing.
      final logged = ctrl.getLogForMeal(dayNumber, meal.mealType.wire)?.status;
      final status = viewState == _ViewState.future
          ? MealLogStatusV2.pending
          : (logged ?? MealLogStatusV2.pending);
      final dotColor = _statusColor(status);
      final tip = (meal.notes ?? '').trim();

      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Time + timeline rail
            SizedBox(
              width: 58.w,
              child: Column(
                children: [
                  SizedBox(height: 16.h),
                  Text(
                    _prettyTime(meal.time),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w700,
                      color: _kBodyMuted,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    width: 14.w,
                    height: 14.w,
                    decoration: BoxDecoration(
                      color: status == MealLogStatusV2.pending
                          ? Colors.white
                          : dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: status == MealLogStatusV2.pending
                            ? _kSage
                            : dotColor,
                        width: 2.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isLast ? Colors.transparent : _kCardBorder,
                    ),
                  ),
                ],
              ),
            ),
            // Meal card
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: expanded || onExpand == null
                        ? () => _openSheet(ctrl)
                        : onExpand,
                    borderRadius: BorderRadius.circular(20),
                    child: _Card(
                      padding: EdgeInsets.all(14.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40.w,
                                height: 40.w,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _kCream,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(_mealEmoji(meal.mealType),
                                    style: TextStyle(fontSize: 20.sp)),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  meal.mealType.label,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: _kBodyMuted,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 9.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: _kCream,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '🔥 ${meal.calories} kcal',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: _kHeroDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            meal.foodName,
                            maxLines: expanded ? null : 1,
                            overflow: expanded ? null : TextOverflow.ellipsis,
                            // Oct 2026: 14 semi-bold (was 15 bold, too heavy).
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: status == MealLogStatusV2.skipped
                                  ? _kSage
                                  : _kHeroDark,
                              decoration: status == MealLogStatusV2.skipped
                                  ? TextDecoration.lineThrough
                                  : null,
                              height: 1.35,
                            ),
                          ),
                          if (expanded && tip.isNotEmpty) ...[
                            SizedBox(height: 8.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4FAF1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '💡 $tip',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11.5.sp,
                                  color: _kBodyMuted,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                          if (expanded) ...[
                            SizedBox(height: 10.h),
                            _actionRow(status),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Color _statusColor(MealLogStatusV2 s) {
    switch (s) {
      case MealLogStatusV2.followed:
        return _kAccent;
      case MealLogStatusV2.alternative:
        return _kAlternative;
      case MealLogStatusV2.skipped:
        return _kDanger;
      case MealLogStatusV2.pending:
        return _kSage;
    }
  }

  Widget _actionRow(MealLogStatusV2 status) {
    if (viewState == _ViewState.future) {
      return _pill(Icons.lock_outline_rounded, 'Unlocks on its day', _kSage,
          filled: false);
    }
    switch (status) {
      case MealLogStatusV2.followed:
        return _pill(Icons.check_rounded, 'Ate as planned', _kAccent);
      case MealLogStatusV2.alternative:
        return _pill(Icons.swap_horiz_rounded, 'Had something else',
            const Color(0xFFC98A2C));
      case MealLogStatusV2.skipped:
        return _pill(Icons.close_rounded, 'Skipped', _kDanger);
      case MealLogStatusV2.pending:
        return viewState == _ViewState.today
            ? _pill(Icons.add_rounded, 'Log this meal', _kAccent,
                filled: false)
            : _pill(Icons.remove_rounded, 'Not logged', _kSage, filled: false);
    }
  }

  Widget _pill(IconData icon, String text, Color color, {bool filled = true}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.14) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(filled ? 0.0 : 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.w, color: color),
          SizedBox(width: 5.w),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Phase F.2 — meal logging sheet body. Renders the meal info on top,
/// a status banner + "Change" link if the meal's already been logged,
/// and three big buttons (Ate as planned / Had something else /
/// Skipped) otherwise. The "had something else" path reveals a
/// TextField for the alternative meal name.
class _MealLogSheetBody extends StatefulWidget {
  final DietPlanMealV2 meal;
  const _MealLogSheetBody({required this.meal});

  @override
  State<_MealLogSheetBody> createState() => _MealLogSheetBodyState();
}

class _MealLogSheetBodyState extends State<_MealLogSheetBody> {
  late final DietPlanUserController _ctrl;
  late final TextEditingController _altCtrl;

  /// Local view state — when the user taps "I had something else" we
  /// reveal the text field instead of immediately firing. When the
  /// user taps "Change" on a logged meal we drop back to the picker.
  bool _showAlternativeForm = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<DietPlanUserController>();
    final existing =
        _ctrl.todayLogsByType[widget.meal.mealType.wire];
    _altCtrl = TextEditingController(
      text: existing?.alternativeText ?? '',
    );
  }

  @override
  void dispose() {
    _altCtrl.dispose();
    super.dispose();
  }

  Future<void> _log(MealLogStatusV2 status, {String? alternativeText}) async {
    // Close the sheet immediately — controller does the optimistic
    // update + error revert. The user sees the status flip on the card
    // before the network even returns.
    Get.back<dynamic>();
    await _ctrl.logMeal(
      mealTypeWire: widget.meal.mealType.wire,
      status: status,
      alternativeText: alternativeText,
      dietPlanMealId: widget.meal.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final log = _ctrl.todayLogsByType[widget.meal.mealType.wire];
      final isLogged =
          log != null && log.status != MealLogStatusV2.pending;
      final showPicker = !isLogged || _editing;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _mealHeader(),
          SizedBox(height: 18.h),
          if (isLogged && !_editing) _loggedBanner(log),
          if (showPicker) ...[
            if (_showAlternativeForm)
              _alternativeForm()
            else
              _picker(),
          ],
          SizedBox(height: 8.h),
          Center(
            child: V2GhostButton(
              label: 'Cancel',
              onPressed: () => Get.back<dynamic>(),
              fullWidth: false,
            ),
          ),
          SizedBox(height: 4.h),
        ],
      );
    });
  }

  Widget _mealHeader() {
    final meal = widget.meal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: _kSage,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                // Same 12-hour time as the meal list (4:30 PM, not 16:30).
                _prettyTime(meal.time),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              '${meal.calories} kcal',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: _kBodyMuted,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        // Sheet sizes (Oct 2026): name 16 (was 18, bigger than the
        // buttons below it), note 12.5 (was 13).
        Text(
          meal.foodName,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: _kHeroDark,
            height: 1.3,
          ),
        ),
        if ((meal.notes ?? '').trim().isNotEmpty) ...[
          SizedBox(height: 8.h),
          Text(
            meal.notes!.trim(),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5.sp,
              color: _kBodyMuted,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _loggedBanner(MealLogV2 log) {
    final (Color bg, IconData icon, String label) = switch (log.status) {
      MealLogStatusV2.followed => (
          _kAccent,
          Icons.check_rounded,
          'You ate this as planned'
        ),
      MealLogStatusV2.alternative => (
          _kAlternative,
          Icons.swap_horiz_rounded,
          'You had something else'
        ),
      MealLogStatusV2.skipped => (
          _kDanger,
          Icons.close_rounded,
          'You skipped this meal'
        ),
      MealLogStatusV2.pending => (
          _kSage,
          Icons.radio_button_unchecked,
          'Pending'
        ),
    };
    final altText = (log.alternativeText ?? '').trim();
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bg.withOpacity(0.32), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: bg, size: 18.w),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: _kHeroDark,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  _editing = true;
                  _showAlternativeForm = false;
                }),
                child: Text(
                  'Change',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: _kAccent,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          if (log.status == MealLogStatusV2.alternative &&
              altText.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.only(left: 28.w),
              child: Text(
                '↳ $altText',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.sp,
                  fontStyle: FontStyle.italic,
                  color: _kBodyMuted,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _picker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        V2PrimaryButton(
          label: 'Ate as planned',
          leadingIcon: Icons.check_rounded,
          onPressed: () => _log(MealLogStatusV2.followed),
        ),
        SizedBox(height: 10.h),
        _LogChoiceButton(
          label: 'I had something else',
          icon: Icons.swap_horiz_rounded,
          accent: _kAlternative,
          onPressed: () => setState(() => _showAlternativeForm = true),
        ),
        SizedBox(height: 10.h),
        _LogChoiceButton(
          label: 'Skipped this meal',
          icon: Icons.close_rounded,
          accent: _kDanger,
          onPressed: () => _log(MealLogStatusV2.skipped),
        ),
      ],
    );
  }

  Widget _alternativeForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'WHAT DID YOU EAT?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
            color: _kSage,
            letterSpacing: 0.84,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: _altCtrl,
          maxLength: 255,
          autofocus: true,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14.sp,
            color: _kHeroDark,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. Paratha and yogurt',
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.sp,
              color: _kBodyMuted,
            ),
            filled: true,
            fillColor: _kCream,
            counterText: '',
            contentPadding:
                EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kCardBorder, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kCardBorder, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kAccent, width: 1.4),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: V2SecondaryButton(
                label: 'Back',
                onPressed: () =>
                    setState(() => _showAlternativeForm = false),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              flex: 2,
              child: V2PrimaryButton(
                label: 'Save',
                onPressed: () {
                  final text = _altCtrl.text.trim();
                  _log(
                    MealLogStatusV2.alternative,
                    alternativeText: text.isEmpty ? null : text,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Outline-style choice button with a coloured icon — used for the two
/// non-primary log options ("I had something else", "Skipped this
/// meal"). Differentiates them from the dominant green "Ate as planned"
/// CTA without giving them equal visual weight.
class _LogChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onPressed;
  const _LogChoiceButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          padding: EdgeInsets.symmetric(horizontal: 18.w),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: accent.withOpacity(0.32), width: 1.2),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 20.w),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: _kHeroDark,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: accent, size: 22.w),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phase G.1 — sage outlined circle with a small lock icon. Used on
/// future-day meal cards to make "you can't log this yet" obvious at a
/// glance, paralleling the pending/followed/etc. status indicators
/// without sneaking into MealLogStatusV2 (which is a backend-mirrored
/// enum we don't want to grow).
/// Read-only meal sheet for past days. Shows the logged status (or a
/// pending pill if the user never logged it) plus a clear hint that
/// the row can't be edited.
class _PastMealSheetBody extends StatelessWidget {
  final DietPlanMealV2 meal;
  final MealLogV2? log;
  final DateTime? date;
  const _PastMealSheetBody({
    required this.meal,
    required this.log,
    required this.date,
  });

  String _formatDate() {
    if (date == null) return 'a previous day';
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final w = wd[(date!.weekday - 1).clamp(0, 6)];
    final m = mo[(date!.month - 1).clamp(0, 11)];
    return '$w, $m ${date!.day}';
  }

  @override
  Widget build(BuildContext context) {
    final status = log?.status ?? MealLogStatusV2.pending;
    final altText = (log?.alternativeText ?? '').trim();
    final (Color bg, IconData icon, String label) = switch (status) {
      MealLogStatusV2.followed => (
          _kAccent,
          Icons.check_rounded,
          'Logged as eaten'
        ),
      MealLogStatusV2.alternative => (
          _kAlternative,
          Icons.swap_horiz_rounded,
          'Logged as alternative'
        ),
      MealLogStatusV2.skipped => (
          _kDanger,
          Icons.close_rounded,
          'Logged as skipped'
        ),
      MealLogStatusV2.pending => (
          _kSage,
          Icons.radio_button_unchecked,
          'Not logged'
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _MealMeta(meal: meal),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: bg.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: bg.withOpacity(0.32), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: bg, size: 18.w),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  '$label · ${_formatDate()}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: _kHeroDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (status == MealLogStatusV2.alternative && altText.isNotEmpty) ...[
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.only(left: 12.w),
            child: Text(
              '↳ $altText',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.sp,
                fontStyle: FontStyle.italic,
                color: _kBodyMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
        SizedBox(height: 14.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: _kCream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kCardBorder, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.history_rounded, size: 16.w, color: _kSage),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  "Past meals can't be edited.",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.sp,
                    color: _kBodyMuted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 6.h),
      ],
    );
  }
}

/// Future-day meal sheet — meal info + a "logging unlocks on {date}"
/// hint. No log buttons.
class _FutureMealSheetBody extends StatelessWidget {
  final DietPlanMealV2 meal;
  final DateTime? date;
  const _FutureMealSheetBody({required this.meal, required this.date});

  String _formatDate() {
    if (date == null) return 'this day';
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final w = wd[(date!.weekday - 1).clamp(0, 6)];
    final m = mo[(date!.month - 1).clamp(0, 11)];
    return '$w, $m ${date!.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _MealMeta(meal: meal),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: _kCream,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kCardBorder, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 18.w, color: _kSage),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'Logging available on ${_formatDate()}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: _kBodyMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        Text(
          "You can preview upcoming meals and prep ahead. Come back on "
          'the day to log what you ate.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.sp,
            color: _kBodyMuted,
            height: 1.5,
          ),
        ),
        SizedBox(height: 6.h),
      ],
    );
  }
}

/// Meal meta shared by both read-only sheets — time pill + food name +
/// kcal + notes. Mirrors the top of `_MealLogSheetBody._mealHeader`.
class _MealMeta extends StatelessWidget {
  final DietPlanMealV2 meal;
  const _MealMeta({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: _kSage,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                // Same 12-hour time as the meal list (4:30 PM, not 16:30).
                _prettyTime(meal.time),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              '${meal.calories} kcal',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: _kBodyMuted,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        // Sheet sizes (Oct 2026): name 16 (was 18, bigger than the
        // buttons below it), note 12.5 (was 13).
        Text(
          meal.foodName,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: _kHeroDark,
            height: 1.3,
          ),
        ),
        if ((meal.notes ?? '').trim().isNotEmpty) ...[
          SizedBox(height: 8.h),
          Text(
            meal.notes!.trim(),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5.sp,
              color: _kBodyMuted,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Local card shell (mirrors v2 pattern) ────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _Card({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _kHeroDark.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }
}
