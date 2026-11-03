import 'package:flutter/material.dart' show TextButton, Text;
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../Repos/diet_plan_v2/diet_plan_admin_repository.dart'
    show DietPlanApiException;
import '../../Repos/diet_plan_v2/diet_plan_user_repository.dart';
import '../../models/diet_plan_v2/diet_plan_v2_models.dart';
import '../../models/diet_plan_v2/meal_log_v2.dart';
import '../../../values/constants.dart';
import '../auth_controller/auth_controller.dart';

/// User-side counterpart to DietPlanAdminController. Owns the active
/// plan + computes "today's day" so the home-screen meal cards can be
/// dumb (just render whatever this controller hands them).
class DietPlanUserController extends GetxController {
  final DietPlanUserRepository repo;
  final AuthController auth;

  DietPlanUserController({required this.repo, required this.auth});

  /// Backend's `/users/diet-plan/me/active` returns null when the user
  /// has no active structured plan — that's a normal lifecycle state,
  /// not an error.
  final Rxn<DietPlanV2> activePlan = Rxn<DietPlanV2>();
  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxnString errorMessage = RxnString();
  DateTime? _lastPlanFetch;
  static const Duration _planTtl = Duration(minutes: 5);

  // ─── Phase F.3 — booking-context state ─────────────────────────────────

  /// Cached IDs the empty-state CTA needs to open BookConsultationSheet.
  /// Loaded lazily on first need (V2TodayMealsSection's empty-state
  /// path) — there's no point fetching it on every paid-user load.
  final Rxn<BookingContextV2> bookingContext = Rxn<BookingContextV2>();
  final RxBool isBookingContextLoading = false.obs;

  /// Idempotent — returns immediately if already loaded or in flight,
  /// unless [refresh] is true (the "plan is being prepared" card passes
  /// that so its countdown and delayed state stay current).
  Future<void> loadBookingContext({bool refresh = false}) async {
    if (bookingContext.value != null && !refresh) return;
    if (isBookingContextLoading.value) return;
    isBookingContextLoading.value = true;
    try {
      bookingContext.value =
          await repo.getBookingContext(accessToken: _token);
    } catch (_) {
      // Silent — empty-state CTA falls back to OurPlansScreen if context
      // is null, which is the right behaviour for transport errors too.
    } finally {
      isBookingContextLoading.value = false;
    }
  }

  // ─── Phase F.2 — meal logging state ────────────────────────────────────

  /// Today's logs keyed by mealType wire string. Seeds pending entries
  /// for every meal in `todaysDay` so the UI can render a status
  /// indicator without null-checking everywhere.
  final RxMap<String, MealLogV2> todayLogsByType =
      <String, MealLogV2>{}.obs;

  // ─── Phase G.1 — day-strip navigation state ────────────────────────────

  /// `null` = "viewing today"; a `1..planDays` value = browsing a specific
  /// day. The Diet tab's day strip writes to this; meal cards + the
  /// section subtitle read [effectiveDayNumber] which folds the null
  /// case back to today.
  final RxnInt selectedDayNumber = RxnInt();

  /// All MealLogs the user has loaded across past days, keyed by
  /// `"yyyy-MM-dd:meal_type_wire"`. Populated lazily — only past days
  /// the user actually navigates to get fetched. `todayLogsByType` is
  /// kept in parallel for backward compat with F.2 callers.
  final RxMap<String, MealLogV2> logsByDateAndType =
      <String, MealLogV2>{}.obs;

  final RxBool isLoadingHistoricalLogs = false.obs;

  /// Set of date keys we've already fetched (success or empty). Avoids
  /// re-firing the network call on every chip tap once a past day has
  /// been viewed once.
  final Set<String> _fetchedDateKeys = <String>{};

  static String _dateKey(MealLogV2 log) =>
      '${log.date}:${log.mealTypeWire}';

  String _todayDate() {
    // Same zone-aware logic as todaysDayNumber so the meal-log
    // endpoint queries the user's calendar day rather than the device's.
    final tzName = auth.userTimeZone;
    DateTime now;
    try {
      now = tz.TZDateTime.now(tz.getLocation(tzName));
    } catch (_) {
      now = DateTime.now();
    }
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  String get _token =>
      auth.sharedPreferences.getString(Constants.accessToken) ?? '';

  @override
  void onInit() {
    super.onInit();
    loadActivePlan();
  }

  Future<void> loadActivePlan({bool refresh = false}) async {
    final now = DateTime.now();
    final isFresh = _lastPlanFetch != null &&
        now.difference(_lastPlanFetch!) < _planTtl;

    if (!refresh && activePlan.value != null && isFresh) {
      return;
    }

    if (refresh) {
      isRefreshing.value = true;
    } else {
      isLoading.value = true;
    }
    errorMessage.value = null;
    try {
      // Fire both calls in parallel — they're independent. A logs
      // failure shouldn't block the plan render (Phase F.2 spec wants
      // status indicators on first paint, but pending placeholders are
      // fine fallbacks).
      final results = await Future.wait([
        repo.getMyActivePlan(accessToken: _token),
        _safeFetchLogs(),
      ]);
      activePlan.value = results[0] as DietPlanV2?;
      _seedLogsFromFetch(results[1] as List<MealLogV2>);
      _lastPlanFetch = DateTime.now();
    } on DietPlanApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value =
          'Network error — check your connection and try again';
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  /// Wrapped fetch that swallows errors — logs are best-effort. The
  /// plan-render path can't fail just because the logs endpoint did.
  Future<List<MealLogV2>> _safeFetchLogs() async {
    try {
      return await repo.getMealLogsForDate(
        accessToken: _token,
        dateYYYYMMDD: _todayDate(),
      );
    } catch (_) {
      return const [];
    }
  }

  /// Build the keyed map. Pending placeholders for every mealType in
  /// today's day get seeded first; real fetched logs overwrite them.
  /// Also mirrors entries into [logsByDateAndType] (Phase G.1) so the
  /// day strip can read today's logs through the same composite-key
  /// API it uses for past days — one source of truth.
  void _seedLogsFromFetch(List<MealLogV2> fetched) {
    final next = <String, MealLogV2>{};
    final today = _todayDate();
    final day = todaysDay;
    if (day != null) {
      for (final m in day.meals) {
        next[m.mealType.wire] = MealLogV2.pending(
          date: today,
          mealTypeWire: m.mealType.wire,
          dietPlanMealId: m.id,
        );
      }
    }
    for (final log in fetched) {
      next[log.mealTypeWire] = log;
    }
    todayLogsByType.assignAll(next);
    // Mirror today's entries into the composite-keyed map.
    next.forEach((typeWire, log) {
      logsByDateAndType['$today:$typeWire'] = log;
    });
    _fetchedDateKeys.add(today);
  }

  /// Optimistic upsert. Updates the keyed map immediately, fires the
  /// backend POST, reverts the map on failure so the UI returns to
  /// the previous status. Returns true on success, false on failure.
  /// On failure also fires a snackbar with a Retry action.
  Future<bool> logMeal({
    required String mealTypeWire,
    required MealLogStatusV2 status,
    String? alternativeText,
    String? reasonCode,
    int? dietPlanMealId,
  }) async {
    // Phase G.1 — server-side endpoint already enforces the 7-day edit
    // window; this client-side guard short-circuits the optimistic
    // update entirely so a stray tap on a past/future card can't even
    // produce a flicker. The day strip's per-state UI shouldn't fire
    // logMeal at all, but defensive nonetheless.
    if (!isViewingToday) {
      Get.snackbar(
        "Can't log this meal",
        "You can only log today's meals.",
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final today = _todayDate();
    final previous = todayLogsByType[mealTypeWire];

    // Optimistic write — preserve the FK so revert can restore it too.
    final optimistic = (previous ?? MealLogV2.pending(
          date: today,
          mealTypeWire: mealTypeWire,
          dietPlanMealId: dietPlanMealId,
        ))
        .copyWith(
      status: status,
      alternativeText: status == MealLogStatusV2.alternative
          ? alternativeText
          : null,
      clearAlternativeText: status != MealLogStatusV2.alternative,
      reasonCode: reasonCode,
      dietPlanMealId: dietPlanMealId,
    );
    todayLogsByType[mealTypeWire] = optimistic;
    logsByDateAndType['$today:$mealTypeWire'] = optimistic;

    try {
      final saved = await repo.upsertMealLog(
        accessToken: _token,
        dateYYYYMMDD: today,
        mealTypeWire: mealTypeWire,
        status: status,
        alternativeText: alternativeText,
        reasonCode: reasonCode,
        dietPlanMealId: dietPlanMealId,
      );
      // Server response is canonical (carries the row id, server-set
      // timestamps). Splice it in so subsequent edits use the real row.
      todayLogsByType[mealTypeWire] = saved;
      logsByDateAndType['$today:$mealTypeWire'] = saved;
      return true;
    } on DietPlanApiException catch (e) {
      _revertWithSnackbar(
        mealTypeWire: mealTypeWire,
        previous: previous,
        message: e.message,
        retry: () => logMeal(
          mealTypeWire: mealTypeWire,
          status: status,
          alternativeText: alternativeText,
          reasonCode: reasonCode,
          dietPlanMealId: dietPlanMealId,
        ),
      );
      return false;
    } catch (_) {
      _revertWithSnackbar(
        mealTypeWire: mealTypeWire,
        previous: previous,
        message: 'Network error — try again',
        retry: () => logMeal(
          mealTypeWire: mealTypeWire,
          status: status,
          alternativeText: alternativeText,
          reasonCode: reasonCode,
          dietPlanMealId: dietPlanMealId,
        ),
      );
      return false;
    }
  }

  void _revertWithSnackbar({
    required String mealTypeWire,
    required MealLogV2? previous,
    required String message,
    required Future<bool> Function() retry,
  }) {
    final today = _todayDate();
    final compositeKey = '$today:$mealTypeWire';
    if (previous == null) {
      todayLogsByType.remove(mealTypeWire);
      logsByDateAndType.remove(compositeKey);
    } else {
      todayLogsByType[mealTypeWire] = previous;
      logsByDateAndType[compositeKey] = previous;
    }
    Get.snackbar(
      "Couldn't save",
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
      mainButton: TextButton(
        onPressed: () {
          Get.closeCurrentSnackbar();
          retry();
        },
        child: const Text('Retry'),
      ),
    );
  }

  /// Day-number for "today" relative to the active plan's
  /// `activatedAt`, computed in the **user's** IANA zone (Phase F.3).
  ///
  ///   1..planDays  → that day's data should render
  ///   > planDays   → plan ended; the screen shows the completed-state
  ///   null         → no plan / not yet activated
  ///
  /// Falls back to device-local arithmetic when the IANA zone name is
  /// unknown to the bundled tz database — protects against a typo or
  /// a brand-new zone that hasn't been added yet. Asia/Karachi is the
  /// usual case so this fallback rarely fires.
  int? get todaysDayNumber {
    final plan = activePlan.value;
    if (plan == null) return null;
    final activatedAt = plan.activatedAt;
    if (activatedAt == null) return null;

    final tzName = auth.userTimeZone;
    DateTime today;
    DateTime startMidnight;
    try {
      final loc = tz.getLocation(tzName);
      final nowInZone = tz.TZDateTime.now(loc);
      final startInZone = tz.TZDateTime.from(activatedAt, loc);
      today = DateTime(nowInZone.year, nowInZone.month, nowInZone.day);
      startMidnight =
          DateTime(startInZone.year, startInZone.month, startInZone.day);
    } catch (_) {
      // Bad/missing zone — fall back to the device's clock.
      final now = DateTime.now();
      today = DateTime(now.year, now.month, now.day);
      final start = activatedAt.toLocal();
      startMidnight = DateTime(start.year, start.month, start.day);
    }
    final diff = today.difference(startMidnight).inDays;
    if (diff < 0) return null; // future-activated; treat as not started
    return diff + 1; // 1-indexed
  }

  /// Convenience wrapper around [todaysDayNumber] — returns the matching
  /// [DietPlanDayV2] or null when the plan has ended (today number
  /// exceeds `planDays`).
  /// Oct 2026: her plan has ended but her paid package hasn't, and her next
  /// plan isn't here yet → the Diet tab keeps showing her plan again from
  /// Day 1 ("keep following your plan"), never an empty tab. Not for a
  /// free trial (nextStep explore_plans) or an ended package.
  bool get isRepeating {
    final plan = activePlan.value;
    final ctx = bookingContext.value;
    if (plan == null || plan.planDays <= 0 || !planHasEnded || ctx == null) return false;
    if (ctx.planEnded) return false;
    if (ctx.nextStep == null || ctx.nextStep == 'explore_plans') return false;
    final ends = ctx.packageEndsOn;
    if (ends != null && ends.isBefore(DateTime.now())) return false;
    return true;
  }

  /// Plan day shown today while repeating (1..planDays).
  int? get repeatDayNumber {
    final plan = activePlan.value;
    final n = todaysDayNumber;
    if (plan == null || n == null || plan.planDays <= 0) return null;
    return ((n - 1) % plan.planDays) + 1;
  }

  DietPlanDayV2? _planDay(int n) {
    final plan = activePlan.value;
    if (plan == null) return null;
    for (final d in plan.days) {
      if (d.dayNumber == n) return d;
    }
    return null;
  }

  DietPlanDayV2? get todaysDay {
    final plan = activePlan.value;
    final n = todaysDayNumber;
    if (plan == null || n == null) return null;
    if (n > plan.planDays) {
      return isRepeating ? _planDay(repeatDayNumber!) : null;
    }
    DietPlanDayV2? match;
    for (final d in plan.days) {
      if (d.dayNumber == n) {
        match = d;
        break;
      }
    }
    return match;
  }

  /// True when the plan exists but `todaysDayNumber > planDays` — used
  /// by the screen to render the "Plan completed" state instead of
  /// silently showing nothing.
  bool get planHasEnded {
    final plan = activePlan.value;
    final n = todaysDayNumber;
    if (plan == null || n == null) return false;
    return n > plan.planDays;
  }

  // ─── Phase G.2 — plan timeline / banner helpers ────────────────────────
  // All derived; no extra state. Re-evaluated on every Obx tick that
  // already watches activePlan, so the banner stays in lockstep with
  // plan-load and refresh events.

  DateTime? get planStartDate => dateForDay(1);

  DateTime? get planEndDate {
    final plan = activePlan.value;
    if (plan == null) return null;
    return dateForDay(plan.planDays);
  }

  /// Days between today and the last day of the plan (inclusive of
  /// today). Day 1 of 7 → 6. Day 7 of 7 → 0. Past Day 7 → 0 (the banner
  /// is hidden in that case anyway via [isPlanEnded]).
  ///
  /// Returns null when there's no plan or no `activatedAt` to anchor
  /// against (the banner stays hidden, F.1's empty state takes over).
  int? get daysRemainingInPlan {
    final plan = activePlan.value;
    final today = todaysDayNumber;
    if (plan == null || today == null) return null;
    final raw = plan.planDays - today;
    return raw < 0 ? 0 : raw;
  }

  /// "Last 2 days" window — today is Day N or Day N-1.
  bool get isPlanEndingSoon {
    final n = daysRemainingInPlan;
    return n != null && n <= 1 && !planHasEnded;
  }

  /// Same intent as [planHasEnded]; aliased per the Phase G.2 spec.
  bool get isPlanEnded => planHasEnded;

  /// Progress through the plan as a 0..1 fraction. Day 1 → 0; Day N
  /// (last day) → (N-1)/N. Rounding choice: we count completed *whole
  /// days* before today, so Day 4 of 7 reads as ~43% (3/7), which is
  /// what the dietitian's review-screen progress bar shows on the
  /// other side.
  double get planProgressPercent {
    final plan = activePlan.value;
    final today = todaysDayNumber;
    if (plan == null || today == null || plan.planDays <= 0) return 0;
    final raw = (today - 1) / plan.planDays;
    return raw.clamp(0.0, 1.0);
  }

  // ─── Phase G.1 — day-navigation getters + methods ──────────────────────

  /// Day number the screen is currently rendering — folds the "viewing
  /// today" sentinel (selectedDayNumber == null) back to today's
  /// number. Falls back to 1 if today's number is also null (plan
  /// activated in the future / not yet started).
  int get effectiveDayNumber {
    final sel = selectedDayNumber.value;
    if (sel != null) return sel;
    return todaysDayNumber ?? 1;
  }

  /// The [DietPlanDayV2] matching [effectiveDayNumber]. Null when the
  /// plan has no such day (e.g. effectiveDayNumber > planDays).
  DietPlanDayV2? get selectedDay {
    final plan = activePlan.value;
    if (plan == null) return null;
    if (isRepeating) return todaysDay; // today only while repeating
    final n = effectiveDayNumber;
    for (final d in plan.days) {
      if (d.dayNumber == n) return d;
    }
    return null;
  }

  bool get isViewingToday {
    final t = todaysDayNumber;
    return t == null || effectiveDayNumber == t;
  }

  bool get isViewingPast {
    final t = todaysDayNumber;
    return t != null && effectiveDayNumber < t;
  }

  bool get isViewingFuture {
    final t = todaysDayNumber;
    return t != null && effectiveDayNumber > t;
  }

  /// Calendar date (in the user's IANA zone) of [effectiveDayNumber].
  /// Computed off `activatedAt + (dayNumber - 1) days`. Returns null
  /// when there's no plan or no activatedAt.
  DateTime? get selectedDayDate {
    final plan = activePlan.value;
    final activatedAt = plan?.activatedAt;
    if (plan == null || activatedAt == null) return null;
    return _dayDate(plan, effectiveDayNumber);
  }

  String? get selectedDayDateKey {
    final d = selectedDayDate;
    if (d == null) return null;
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$dd';
  }

  /// User-facing helper for the day strip + section subtitle. Same
  /// `activatedAt + (n-1) days in user TZ` math used everywhere; lives
  /// here so callers don't have to know about timezone fallbacks.
  DateTime? dateForDay(int dayNumber) {
    final plan = activePlan.value;
    if (plan == null) return null;
    return _dayDate(plan, dayNumber);
  }

  String? dateKeyForDay(int dayNumber) {
    final d = dateForDay(dayNumber);
    if (d == null) return null;
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$dd';
  }

  DateTime? _dayDate(DietPlanV2 plan, int dayNumber) {
    final activatedAt = plan.activatedAt;
    if (activatedAt == null) return null;
    final tzName = auth.userTimeZone;
    DateTime startMidnight;
    try {
      final loc = tz.getLocation(tzName);
      final startInZone = tz.TZDateTime.from(activatedAt, loc);
      startMidnight =
          DateTime(startInZone.year, startInZone.month, startInZone.day);
    } catch (_) {
      final start = activatedAt.toLocal();
      startMidnight = DateTime(start.year, start.month, start.day);
    }
    return startMidnight.add(Duration(days: dayNumber - 1));
  }

  /// Day strip → controller. Lazy-fetches the past-day logs the first
  /// time the user opens that day.
  void selectDay(int dayNumber) {
    selectedDayNumber.value = dayNumber;
    final t = todaysDayNumber;
    if (t != null && dayNumber < t) {
      _ensureLogsLoadedForDay(dayNumber);
    }
  }

  /// "Today" jump button → restore the default sentinel.
  void selectToday() {
    selectedDayNumber.value = null;
  }

  /// Idempotent: only fires the network call the first time we visit a
  /// past day. Errors are swallowed — the meal cards just stay in
  /// pending state on failure, which reads as "no logs found" and is
  /// the same UX as "user didn't log this day".
  Future<void> _ensureLogsLoadedForDay(int dayNumber) async {
    final dateKey = dateKeyForDay(dayNumber);
    if (dateKey == null) return;
    if (_fetchedDateKeys.contains(dateKey)) return;

    isLoadingHistoricalLogs.value = true;
    try {
      final logs = await repo.getMealLogsForDate(
        accessToken: _token,
        dateYYYYMMDD: dateKey,
      );
      for (final log in logs) {
        logsByDateAndType[_dateKey(log)] = log;
      }
      _fetchedDateKeys.add(dateKey);
    } catch (_) {
      // Silent — cards render "pending" placeholders for missing logs.
    } finally {
      isLoadingHistoricalLogs.value = false;
    }
  }

  /// Composite-key lookup for the day strip's per-cell status.
  /// Falls back to [todayLogsByType] for today so the F.2 fast-path
  /// still works while the old map is being phased out.
  MealLogV2? getLogForMeal(int dayNumber, String mealTypeWire) {
    final dateKey = dateKeyForDay(dayNumber);
    if (dateKey != null) {
      final hit = logsByDateAndType['$dateKey:$mealTypeWire'];
      if (hit != null) return hit;
    }
    final t = todaysDayNumber;
    if (t != null && dayNumber == t) {
      return todayLogsByType[mealTypeWire];
    }
    return null;
  }
}
