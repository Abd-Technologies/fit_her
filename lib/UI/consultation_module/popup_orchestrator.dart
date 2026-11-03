import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../data/controllers/diet_plan_user_controller/diet_plan_user_controller.dart';
import '../../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../../data/models/consultation/pending_popup.dart';
import '../../helper/popup_manager.dart';
import '../plans_module/all_plans.dart';
import 'booking/book_consultation_sheet.dart';
import 'popups/book_initial_reminder_sheet.dart';
import 'popups/class_cancelled_sheet.dart';
import 'popups/consultation_cancelled_sheet.dart';
import 'popups/daily_log_reminder_sheet.dart';
import 'popups/day7_review_sheet.dart';
import 'popups/early_checkin_sheet.dart';
import 'popups/inactivity_reminder_sheet.dart';
import 'popups/medical_concern_sheet.dart';
import 'popups/photo_privacy_notice_sheet.dart';
import 'popups/plan_delayed_sheet.dart';
import '../pre_consultation/pre_consultation_form_screen.dart';
import 'popups/progress_submission_sheet.dart';
import 'popups/renew_plan_sheet.dart';

/// Watches `paidHomeController.dashboard.value.pendingPopups` and fires
/// the highest-priority popup that hasn't already been shown in this
/// app session. Sits at the root of paid-user surfaces; when a popup
/// closes, refetches the dashboard so the next eligible popup (if any)
/// surfaces on the next reactive tick.
///
/// Best-effort: when a popup needs context the orchestrator can't
/// derive (e.g. dietitianId for a booking), it dismisses silently and
/// moves on. Building each sheet's surface lookup is the consumer
/// screen's responsibility — paid_home_screen_v2 hooks the right
/// callbacks below.
class PendingPopupOrchestrator extends StatefulWidget {
  final Widget child;

  /// Hooks for routing popups that lead to other screens. The home
  /// screen wires these to its own navigation logic so the orchestrator
  /// stays decoupled from app navigation.
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenFaq;
  final VoidCallback? onOpenWorkoutSchedule;
  final VoidCallback? onOpenRenewalPlans;
  final VoidCallback? onOpenDailyCheckin;

  const PendingPopupOrchestrator({
    Key? key,
    required this.child,
    this.onOpenChat,
    this.onOpenFaq,
    this.onOpenWorkoutSchedule,
    this.onOpenRenewalPlans,
    this.onOpenDailyCheckin,
  }) : super(key: key);

  @override
  State<PendingPopupOrchestrator> createState() =>
      _PendingPopupOrchestratorState();
}

/// Push tap ("popupReminder"): open that pop-up. Waits up to 15 s for
/// the paid Home to be on screen (cold start).
Future<void> openPendingPopupFromPush(String variable) async {
  if (variable.isEmpty) return;
  for (var i = 0;
      i < 30 && _PendingPopupOrchestratorState._active == null;
      i++) {
    await Future.delayed(const Duration(milliseconds: 500));
  }
  await _PendingPopupOrchestratorState._active?._openFromPush(variable);
}

class _PendingPopupOrchestratorState extends State<PendingPopupOrchestrator> {
  Worker? _worker;
  bool _showing = false;

  // The Home that is on screen, for pushes that open a pop-up.
  static _PendingPopupOrchestratorState? _active;

  // Persisted-across-sessions cooldown so a popup that fired once doesn't
  // refire every time the user lands on Home. Server still owns long-term
  // eligibility (dismissCount caps, completedAt, etc.); this is a local
  // floor on cadence so the UI doesn't become a popup carousel.
  static const String _kShownPrefix = 'popup_shown_';
  static const Duration _defaultCooldown = Duration(hours: 24);

  // Per-popup overrides for cases where the default 24h is wrong:
  //   - Reminders that should nag faster get a shorter window
  //   - Non-urgent nudges that already have server-side cadence get a longer one
  // Server-side gates still apply on top of whatever's left here.
  //
  // POPUP_BOOK_INITIAL_REMINDER: product direction is "resurface on
  // every dashboard reload while unbooked" (popupEligibility.js's
  // evalBookInitialReminder no longer enforces its own 2-day gate
  // either) — but this can NOT be Duration.zero. `_markShown` fires the
  // instant the sheet opens, and `_maybeShowNext` calls
  // `paid.refreshDashboard()` right after every dispatch, which retriggers
  // the `ever()` worker immediately. With a zero cooldown that second
  // evaluation sees the exact same still-eligible row (tapping "Book now"
  // only navigates now — see book_initial_reminder_sheet.dart, it
  // deliberately no longer completes/dismisses/snoozes) and reshows the
  // same popup on the spot, on top of whatever screen the user just
  // navigated to — an instant show → refresh → show loop, not "shows
  // again next time you reload". A short floor absorbs that immediate
  // re-evaluation while still resurfacing well within any realistic
  // "reload" (reopening the app, coming back to Home after a bit).
  static const Map<String, Duration> _perPopupCooldown = {
    'POPUP_CONSULTANT_NO_SHOW': Duration(minutes: 15),
    'POPUP_PLAN_DELAYED': Duration(hours: 12),
    'POPUP_BOOK_INITIAL_REMINDER': Duration(minutes: 5),
    'POPUP_INACTIVITY_REMINDER': Duration(days: 3),
    'POPUP_RENEW_PLAN': Duration(days: 7),
    'POPUP_DAILY_LOG_REMINDER': Duration(hours: 20),
    // Health form: shows on the first open, then at most every 3 days.
    // The "Finish your profile" card on home covers the days between.
    'POPUP_PRE_CONSULTATION_FORM': Duration(days: 3),
    // Urgent "consultation cancelled": once. The server retires it after 48 h.
    'POPUP_CONSULTATION_CANCELLED': Duration(days: 2),
  };

  // In-memory cache mirroring SharedPreferences. Key = variable[+cycle],
  // value = epoch millis when the popup was last shown on this device.
  final Map<String, int> _shownAt = {};
  bool _shownLoaded = false;

  Future<void> _loadShown() async {
    if (_shownLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_kShownPrefix)) continue;
      final ts = prefs.getInt(key);
      if (ts == null) continue;
      _shownAt[key.substring(_kShownPrefix.length)] = ts;
    }
    _shownLoaded = true;
  }

  // Cycle-aware key so Day7/Day15/Day30 popups don't block each other and
  // a new cycle of the same popup type can re-fire after the previous one
  // expired its cooldown.
  String _composeKey(PendingPopup p) {
    final cycle = (p.metadata?['cycle'] ?? '').toString();
    return cycle.isEmpty ? p.variable : '${p.variable}_$cycle';
  }

  bool _wasRecentlyShown(PendingPopup p) {
    final key = _composeKey(p);
    final ts = _shownAt[key];
    if (ts == null) return false;
    final cooldown = _perPopupCooldown[p.variable] ?? _defaultCooldown;
    final shownAt = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateTime.now().difference(shownAt) < cooldown;
  }

  Future<void> _markShown(PendingPopup p) async {
    final key = _composeKey(p);
    final ts = DateTime.now().millisecondsSinceEpoch;
    _shownAt[key] = ts;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_kShownPrefix$key', ts);
  }

  @override
  void initState() {
    super.initState();
    _active = this;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadShown();
      final paid = Get.find<PaidHomeController>();
      // Fire on every dashboard change. ever() de-duplicates per-tick;
      // _showing guards against re-entry while a sheet is already up.
      _worker = ever(paid.dashboard, (_) => _maybeShowNext());
      // First tick — if dashboard is already loaded.
      _maybeShowNext();
    });
  }

  @override
  void dispose() {
    if (_active == this) _active = null;
    _worker?.dispose();
    super.dispose();
  }

  /// Opens one queued pop-up because she tapped its push (Day 7/15/30,
  /// follow-up, renew...). Her own tap: no phone cooldown, no daily limit
  /// (PopupManager.runNow). If it's already done, nothing opens.
  Future<void> _openFromPush(String variable) async {
    final paid = Get.find<PaidHomeController>();
    try {
      await paid.refreshDashboard();
    } catch (_) {}
    final list = paid.dashboard.value?.pendingPopups ?? const <PendingPopup>[];
    final p = list.firstWhereOrNull((e) => e.variable == variable);
    if (p == null) return;
    await PopupManager.runNow('push_$variable', () async {
      await _markShown(p);
      try {
        await _dispatch(p);
      } catch (_) {}
    });
  }

  Future<void> _maybeShowNext() async {
    if (_showing) return;
    await _loadShown();
    final paid = Get.find<PaidHomeController>();
    final dashboard = paid.dashboard.value;
    if (dashboard == null) return;
    final list = dashboard.pendingPopups;
    if (list.isEmpty) return;

    // First popup not within its per-popup cooldown, in the planned
    // order (PopupRank). The server list is already in almost the same
    // order; sorting here keeps both in step.
    final ordered = [...list]..sort((a, b) => _rankOf(a).compareTo(_rankOf(b)));
    final next = ordered.firstWhereOrNull(
      (p) => !_wasRecentlyShown(p),
    );
    if (next == null) return;

    // Pop-up manager decides if it may open now. If not, nothing is
    // marked and it is asked again on a later app open.
    _showing = true;
    bool shown = false;
    try {
      shown = await PopupManager.run(
        'server_${next.variable}',
        rank: _rankOf(next),
        urgent: _urgent.contains(next.variable),
        show: () async {
          await _markShown(next);
          try {
            await _dispatch(next);
          } catch (_) {
            // Swallow; orchestrator is best-effort.
          }
        },
      );
    } finally {
      _showing = false;
    }
    if (!shown) return;

    // Refresh the dashboard so the next eligible popup (or the empty
    // state) shows up on the next reactive tick.
    try {
      await paid.refreshDashboard();
    } catch (_) {}
  }

  /// Urgent: skip the manager's limits (only wait for the open pop-up).
  static const Set<String> _urgent = {
    'POPUP_CLASS_CANCELLED',
    'POPUP_CONSULTATION_CANCELLED',
  };

  /// Planned order (see PopupRank). Last day of the diet check-in moves up.
  int _rankOf(PendingPopup p) {
    switch (p.variable) {
      case 'POPUP_CLASS_CANCELLED':
      case 'POPUP_CONSULTATION_CANCELLED':
        return 0;
      case 'POPUP_PRE_CONSULTATION_FORM':
        return PopupRank.healthForm;
      case 'POPUP_BOOK_INITIAL_CONSULTATION':
      case 'POPUP_BOOK_INITIAL_REMINDER':
        return PopupRank.bookSession;
      case 'POPUP_DAY7_REVIEW':
      case 'POPUP_DAY15_PROGRESS':
      case 'POPUP_DAY30_PROGRESS':
        return PopupRank.progress;
      case 'POPUP_BOOK_FOLLOWUP_CONSULTATION':
        return PopupRank.followUp;
      case 'POPUP_EARLY_CHECKIN':
        return p.metadata?['lastDay'] == true
            ? PopupRank.lastDay
            : PopupRank.dietCheckin;
      case 'POPUP_RENEW_PLAN':
        return PopupRank.renew;
      default:
        return PopupRank.other;
    }
  }

  // Loads booking-context IDs (dietitianId/userId/userPlanId) and opens
  // the actual working booking flow, BookConsultationSheet — mirrors
  // v2_today_meals_section.dart's `_bookFollowUpFromContext`.
  //
  // This replaces routing to `DietScreen` (lib/UI/diet_screen/
  // diet_module.dart), which the "Book now" / booking popups used to
  // open. That screen shows a spinner and NEVER resolves: it only
  // renders once `HomeController.getUsersBasedOnUserTypeLoad` flips
  // true, and that only happens inside `getUsersBasedOnUserType(...)`
  // — a method nothing in the app actually calls. It's leftover/legacy
  // code, not a working "existing Consultation entry" as an earlier
  // pass through this file assumed. BookConsultationSheet (the
  // dietitian calendar picker) is the flow that's actually wired up
  // end-to-end and already used elsewhere in the app.
  Future<void> _openBookingSheet({
    required String popupVariable,
    required String kind, // 'initial' | 'followup'
  }) async {
    final dietCtrl = Get.find<DietPlanUserController>();
    await dietCtrl.loadBookingContext();
    final ctx = dietCtrl.bookingContext.value;
    if (ctx != null && ctx.canBook) {
      await BookConsultationSheet.show(
        popupVariable: popupVariable,
        dietitianId: ctx.dietitianId!,
        userId: ctx.userId!,
        userPlanId: ctx.userPlanId!,
        kind: kind,
      );
    } else {
      // No dietitian/plan context yet (shouldn't normally happen — the
      // evaluators that fire these popups already confirmed an active
      // diet/combined plan — but fail safe rather than strand the user
      // on a dead screen).
      Get.to<dynamic>(() => OurPlansScreen());
    }
  }

  Future<void> _dispatch(PendingPopup p) async {
    final ctrl = Get.find<ConsultationController>();
    final meta = p.metadata ?? const {};

    int? _readInt(String key) {
      final v = meta[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    String? _readStr(String key) {
      final v = meta[key];
      return v is String ? v : null;
    }

    switch (p.variable) {
      case 'POPUP_DAILY_LOG_REMINDER':
        await DailyLogReminderSheet.show(
          onLogNow: widget.onOpenDailyCheckin ?? () {},
        );
        break;

      case 'POPUP_EARLY_CHECKIN':
        await EarlyCheckinSheet.show(
          onOpenChat: widget.onOpenChat ?? () {},
          onOpenFaq: widget.onOpenFaq ?? () {},
          firstPlan: meta['firstPlan'] != false,
        );
        break;

      case 'POPUP_CLASS_CANCELLED':
        await ClassCancelledSheet.show(
          classTime: _readStr('classTime'),
          classType: _readStr('classType'),
          nextClass: _readStr('nextClass'),
          onViewClasses: widget.onOpenWorkoutSchedule ?? () {},
        );
        break;

      case 'POPUP_CONSULTATION_CANCELLED':
        final kind = _readStr('kind') == 'followup' ? 'followup' : 'initial';
        await ConsultationCancelledSheet.show(
          reason: _readStr('reason') ?? 'dietitian_cancelled',
          bonusDays: _readInt('bonusDays') ?? 0,
          locked: meta['locked'] == true,
          onPickNewTime: () => _openBookingSheet(
            popupVariable: kind == 'followup'
                ? 'POPUP_BOOK_FOLLOWUP_CONSULTATION'
                : 'POPUP_BOOK_INITIAL_CONSULTATION',
            kind: kind,
          ),
        );
        break;

      case 'POPUP_INACTIVITY_REMINDER':
        await InactivityReminderSheet.show(
          onViewClasses: widget.onOpenWorkoutSchedule ?? () {},
        );
        break;

      case 'POPUP_PLAN_DELAYED':
        await PlanDelayedSheet.show();
        break;

      case 'POPUP_CONSULTANT_NO_SHOW':
        // No longer shown as a blocking popup here — an appointment the
        // consultant hasn't joined isn't something that should interrupt
        // whatever screen the user happens to be on, and it was popping
        // up repeatedly for stale/leftover appointments with no way to
        // self-resolve. It's now surfaced inline, in context, on the Diet
        // tab's UpcomingConsultationCard ("Check status" notice), which
        // (the old report sheet has been removed; the server now decides). Just
        // acknowledge server-side so this queue entry doesn't keep
        // resurfacing here.
        await ctrl.dismissPopup(p.variable);
        break;

      case 'POPUP_RENEW_PLAN':
        await RenewPlanSheet.show(
          ended: p.metadata?['ended'] == true,
          // No screen passed a handler, so the button did nothing:
          // open the plans screen by default.
          onViewPlans: widget.onOpenRenewalPlans ?? () => Get.to(() => OurPlansScreen()),
        );
        break;

      case 'POPUP_PHOTO_PRIVACY_NOTICE':
        await PhotoPrivacyNoticeSheet.show();
        break;

      case 'POPUP_MEDICAL_CONCERN':
        // User-driven; orchestrator only ever sees this if the eligibility
        // helper opportunistically queues it (rare). Show it.
        await MedicalConcernSheet.show();
        break;

      case 'POPUP_BOOK_INITIAL_REMINDER':
        await BookInitialReminderSheet.show(
          // "Book now" opens the real booking flow via booking-context
          // + BookConsultationSheet (see _openBookingSheet above). It
          // does NOT complete this popup itself — BookConsultationSheet
          // completes POPUP_BOOK_INITIAL_CONSULTATION once a slot is
          // actually booked, and the backend's evalBookInitialReminder
          // independently retires this reminder once a real Appointment
          // exists. So backing out of the booking sheet without booking
          // correctly leaves the reminder eligible to resurface.
          onBookNow: () => _openBookingSheet(
            popupVariable: 'POPUP_BOOK_INITIAL_CONSULTATION',
            kind: 'initial',
          ),
        );
        break;

      case 'POPUP_BOOK_INITIAL_CONSULTATION':
      case 'POPUP_BOOK_FOLLOWUP_CONSULTATION':
        // Booking success (not opening the sheet) is what should retire
        // these — BookConsultationSheet calls completePopup itself once
        // a slot is actually booked. Don't complete on open: that would
        // let a user who backs out without booking evade the popup for
        // the rest of the session, the same class of bug just fixed on
        // the initial reminder.
        await _openBookingSheet(
          popupVariable: p.variable,
          kind: p.variable == 'POPUP_BOOK_INITIAL_CONSULTATION'
              ? 'initial'
              : 'followup',
        );
        break;

      case 'POPUP_PRE_CONSULTATION_FORM':
        // One pre-consultation form (full screen, signup style). Only the
        // missing questions. What needs her answers stays locked on home
        // and in the Diet tab until she fills it.
        final planType = _readStr('planType') ?? 'diet';
        // Oct 2026: never forced. "Later" works every time; only booking
        // the dietitian needs the answers (checked at booking).
        await PreConsultationFormScreen.open(planType: planType);
        break;

      case 'POPUP_DAY7_REVIEW':
        final userPlanId = _readInt('userPlanId');
        final cycle = _readInt('cycle') ?? 1;
        final planType = _readStr('planType') ?? 'diet';
        if (userPlanId == null) {
          await ctrl.dismissPopup(p.variable);
          break;
        }
        await Day7ReviewSheet.show(
          planType: planType,
          userPlanId: userPlanId,
          cycle: cycle,
        );
        break;

      case 'POPUP_DAY15_PROGRESS':
      case 'POPUP_DAY30_PROGRESS':
        final userPlanId = _readInt('userPlanId');
        final cycle = p.variable == 'POPUP_DAY15_PROGRESS' ? 15 : 30;
        final planType = _readStr('planType') ?? 'diet';
        if (userPlanId == null) {
          await ctrl.dismissPopup(p.variable);
          break;
        }
        await ProgressSubmissionSheet.show(
          planType: planType,
          userPlanId: userPlanId,
          cycle: cycle,
        );
        break;

      default:
        // Unknown variable — eligibility helper added a popup we don't
        // know how to render. Dismiss server-side so it doesn't keep
        // returning, then move on.
        await ctrl.dismissPopup(p.variable);
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
