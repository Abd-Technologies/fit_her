import '../weekly_checkin/weekly_checkin_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/controllers/diet_plan_user_controller/diet_plan_user_controller.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import '../../data/controllers/meal_log_controller/meal_log_controller.dart';
import '../../data/models/diet_plan_v2/diet_plan_v2_models.dart';
import '../../data/models/diet_plan_v2/meal_log_v2.dart';
import '../../data/models/home_dashboard/home_dashboard_model.dart';
import '../../data/models/meal_log/meal_log.dart';
import '../../UI/dashboard_module/bottom_bar_screen/bottom_bar_screen.dart';
import 'log_weight_modal.dart';
import 'paid_meal_log_card.dart';
import 'set_target_weight_modal.dart';
import '../symptom_check/symptom_check_card.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../UI/profile_setup/profile_completion.dart';
import '../../UI/consultation_module/booking/book_consultation_sheet.dart';
import '../../data/controllers/consultation_controller/consultation_controller.dart';
import 'package:intl/intl.dart';
import '../../data/Repos/plan_freeze_repo/plan_freeze_repository.dart';
import '../../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../../values/constants.dart';
import '../v2/unfreeze_confirm_dialog.dart';

// Workouts + Weight + Calories all read real data from dashboard.stats
// (backend: DashboardController.buildStats()) — see each card below for
// the exact fields and null-handling.
//
// Calories shows a personalized daily TARGET (Mifflin-St Jeor BMR ×
// activity level, goal-adjusted — services/ai/utils/calorieTarget.js,
// the same calculator that drives AI diet-plan generation), not a live
// "remaining today" count — there's no calorie *consumption* tracking
// anywhere yet (meal logging only records followed/alternative/skipped,
// never food or kcal), so there's nothing to subtract from the budget.
//
// NOTE: PaidCycleCard now lives in paid_home_screen_v2.dart (paired
// with Meals/Nutrition there). Do not re-add it here — that would
// double-render the same widget.

/// Stats grid below the hero: one row of 3 equal cards
/// (Classes | Weight | Meals). Empty tiles show a prompt, never a 0.
///
/// Cycle used to render here as a full-width "Row 2", but that left the
/// no-plan case with two lonely full-width cards stacked on top of each
/// other (Cycle, then Meals). Cycle now lives in paid_home_screen_v2.dart
/// so it can be paired into a Row with whichever card belongs next to it
/// (Meals when there's no plan yet, or sit above the Nutrition+Meals
/// pair once there is) — single place decides the whole layout instead
/// of splitting the decision across two files.
///
/// Row 1 values are static placeholders for the HBL demo (see tech-debt
/// block above). Card shell mirrors the existing water/sleep visual:
/// white bg, mint border, 20-radius, soft shadow.
class PaidStatsRow extends StatelessWidget {
  final HomeDashboardModel dashboard;

  /// Oct 2026: Weight | Hormone check | Meals. When true the Classes tile
  /// moves to the row below (next to Cycle, see [PaidClassesTile]).
  final bool withHormoneCheck;

  /// Oct 2026: meals now live in "Today's insights" (PaidMealsInsightRow),
  /// so the home passes false here to avoid showing them twice.
  final bool showMeals;

  /// Classes tile next to Weight (Oct 2026: once she has joined a class
  /// this week; the health check then moves down next to Cycle).
  final bool withClasses;

  const PaidStatsRow({Key? key, required this.dashboard, this.withHormoneCheck = false, this.showMeals = true, this.withClasses = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Before her first class the Classes tile would only say "Join your
    // first class", which the hero + trial card already ask. Drop it then
    // so Weight and Meals sit side by side as 2 equal tiles; once she has
    // attended, the original 3-tile row comes back unchanged.
    final hasAttended = _classCount(dashboard).count > 0;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasAttended && !withHormoneCheck && !withClasses) ...[
            Expanded(child: _WorkoutsCard(dashboard: dashboard)),
            const SizedBox(width: 7),
          ],
          Expanded(child: _WeightCard(dashboard: dashboard)),
          if (withClasses) ...[
            const SizedBox(width: 7),
            Expanded(child: _WorkoutsCard(dashboard: dashboard)),
          ],
          if (withHormoneCheck) ...[
            const SizedBox(width: 7),
            const Expanded(child: SymptomCheckCard(where: 'home_paid', mini: true)),
          ],
          if (showMeals) ...[
            const SizedBox(width: 7),
            Expanded(child: _MealsTile(dashboard: dashboard)),
          ],
        ],
      ),
    );
  }
}

/// The Classes tile on its own (row 2, next to Cycle). Only when she has
/// joined a class this week.
class PaidClassesTile extends StatelessWidget {
  final HomeDashboardModel dashboard;
  const PaidClassesTile({super.key, required this.dashboard});

  // Free trial: always (her "0 of 3" is part of the trial). Paid: once she
  // has joined a class this week.
  static bool shows(HomeDashboardModel d) => _isTrialLive() || _classCount(d).count > 0;

  @override
  Widget build(BuildContext context) => _WorkoutsCard(dashboard: dashboard);
}

// ─── Row 1, Card 1 ───────────────────────────────────────────────────────

class _WorkoutsCard extends StatelessWidget {
  final HomeDashboardModel dashboard;
  const _WorkoutsCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    // Distinct class attendance days since Monday
    // (DashboardController.buildStats()). Always an int, never null.
    final c = _classCount(dashboard);
    final count = c.count;
    // Free trial, no class yet: same look as the tiles beside it (number,
    // small line, green link) instead of a different empty card.
    if (count == 0 && _isTrialLive()) {
      return _CardShell(
        onTap: () => Get.offAll<dynamic>(() => BottomBarScreen(index: 1)),
        child: _StatColumn(
          label: '🏋️ Classes',
          value: '0',
          valueColor: const Color(0xFF163220),
          sub: c.sub,
          caption: 'See classes ›',
          captionColor: const Color(0xFF4AA877),
        ),
      );
    }
    if (count == 0) {
      // No zero on screen: invite her to her first class instead.
      return _CardShell(
        onTap: () => Get.offAll<dynamic>(() => BottomBarScreen(index: 1)),
        child: const _EmptyStat(
          label: '🏋️ Classes',
          prompt: 'Join your first class',
          action: 'See today →',
        ),
      );
    }
    return _CardShell(
      child: _StatColumn(
        label: '🏋️ Classes',
        value: '$count',
        sub: c.sub,
      ),
    );
  }
}

/// Classes number for the Home tile. Free trial: classes in HER TRIAL
/// (same number as Profile and the trial card, "1 of 3"), not this week,
/// which could include a class from before her trial started (Oct 2026).
bool _isTrialLive() =>
    Get.isRegistered<HomeController>() && Get.find<HomeController>().trialLive.value;

({int count, String sub}) _classCount(HomeDashboardModel d) {
  if (Get.isRegistered<HomeController>()) {
    final h = Get.find<HomeController>();
    if (h.trialLive.value) {
      return (count: h.classesAttended.value, sub: 'of ${h.classGoal.value} in trial');
    }
  }
  return (count: d.stats?.workoutsThisWeek ?? 0, sub: 'this week');
}

// ─── Row 1, Card 2 ───────────────────────────────────────────────────────

/// Replaces the previous `_ProgressCard`. Displays the real week-over-week
/// weight trend from `dashboard.stats.weightDeltaKgThisWeek`. Tap-to-log
/// flow is unchanged: hands off to `SetTargetWeightModal` when no goal
/// exists, otherwise to `LogWeightModal` seeded with the current weight.
class _WeightCard extends StatelessWidget {
  final HomeDashboardModel dashboard;
  const _WeightCard({required this.dashboard});

  void _onTap(BuildContext context) {
    final goal = dashboard.goal;
    final hasGoal = goal?.targetWeightKg != null;
    if (!hasGoal) {
      SetTargetWeightModal.show(context: context, dashboard: dashboard);
    } else {
      // Log measurements (weight + body measurements), or this week's
      // check-in when it's due. Same weekly record (Oct 2026).
      WeeklyCheckinSheet.logMeasurements();
    }
  }

  // 'lose' | 'gain' | null. mainGoal === 'Lose weight' already answers
  // this on its own — SetTargetWeightModal doesn't even show a picker
  // in that case — so it takes priority over the stored column, which
  // only exists for users whose signup goal didn't say. Null means truly
  // unknown (never asked yet, e.g. no target weight set at all).
  String? _direction() {
    if (dashboard.user?.mainGoal == 'Lose weight') return 'lose';
    if (dashboard.user?.mainGoal == 'Gain weight') return 'gain';
    return dashboard.goal?.weightGoalDirection;
  }

  // Green when the change moves toward the user's stated direction,
  // amber (not alarm-red — a wellness app shouldn't punish a bad week)
  // when it moves away from it. Falls back to the card's normal green
  // when direction is unknown or the change is exactly 0 — there's
  // nothing to judge either way.
  Color _valueColor(double? delta) {
    const onTrack = Color(0xFF6DC55A);
    const offTrack = Color(0xFFD9A441);
    final direction = _direction();
    if (delta == null || delta == 0 || direction == null) return onTrack;
    final movingTowardGoal = direction == 'lose' ? delta < 0 : delta > 0;
    return movingTowardGoal ? onTrack : offTrack;
  }

  @override
  Widget build(BuildContext context) {
    // DashboardController.buildStats() only fills this in once there are
    // 2+ WeeklyCheckin rows within the last 14 days — it returns null
    // (not 0.0) when there isn't enough history yet, so a fresh user
    // isn't shown a false "no change". Sign is added explicitly since
    // Dart's toStringAsFixed doesn't prefix positive numbers.
    //
    // IMPORTANT: save_weight_log upserts ONE row per ISO week (keyed by
    // that week's Monday — userController.js's currentWeekMonday()), so
    // logging twice on the same day/week overwrites the same row rather
    // than creating a second one. A trend only appears once the user has
    // a weigh-in from two DIFFERENT weeks — the old copy here ("log 2x
    // to see trend") wrongly implied logging twice today would do it.
    // Shows her CURRENT weight, with the week-over-week change under it
    // once there are weigh-ins from two different weeks (see
    // DashboardController.buildStats()). Nothing logged yet: an "Add
    // your weight" prompt instead of a confusing 0.0.
    var current = dashboard.goal?.currentWeightKg;
    final delta = dashboard.stats?.weightDeltaKgThisWeek;
    // No weigh-in logged yet: use the weight from her profile (old
    // clients gave it at sign-up) instead of asking again.
    String? fromProfile;
    if (current == null || current <= 0) {
      try {
        final w = double.tryParse(
            (Get.find<AuthController>().logInUser?.weight ?? '').trim());
        if (w != null && w > 0) {
          current = w;
          fromProfile = 'From your profile';
        }
      } catch (_) {}
    }
    if (current == null || current <= 0) {
      return _CardShell(
        onTap: () => _onTap(context),
        child: const _EmptyStat(
          label: '⚖️ Weight',
          prompt: 'Add your weight',
          action: 'Add →',
        ),
      );
    }
    String sub = '';
    if (delta != null && delta != 0) {
      final arrow = delta < 0 ? '↓' : '↑';
      sub = '$arrow ${delta.abs().toStringAsFixed(1)} kg this week';
    }
    // Free trial: frame the number as her baseline.
    final onTrial = Get.isRegistered<HomeController>() &&
        Get.find<HomeController>().isFreeTrialUser.value;
    // Weight goal but no target yet (Oct 2026): invite her to set one.
    // Tapping the tile opens the target box (see _onTap).
    final askTarget = dashboard.goal?.targetWeightKg == null &&
        (dashboard.user?.mainGoal == 'Lose weight' ||
            dashboard.user?.mainGoal == 'Gain weight');
    return _CardShell(
      onTap: () => _onTap(context),
      child: _StatColumn(
        label: '⚖️ Weight',
        value: current.toStringAsFixed(1),
        unit: 'kg',
        valueFontSize: 20,
        sub: sub,
        valueColor: _valueColor(delta),
        caption: askTarget
            ? 'Set your target ›'
            : (onTrial ? 'Your starting point' : fromProfile),
        captionColor: askTarget ? const Color(0xFF4AA877) : null,
      ),
    );
  }
}

// ─── Row 1, Card 3 ───────────────────────────────────────────────────────

/// Meals logged today plus calories, so every tile in this row shows
/// progress (Calories used to be a lonely target number here).
///
/// Calories eaten = sum of plan calories for meals marked "followed".
/// Alternatives and skips aren't counted, since we don't know what she
/// ate instead. With no structured plan there's nothing to add up, so
/// only the target is shown.
class _MealsTile extends StatelessWidget {
  final HomeDashboardModel dashboard;
  const _MealsTile({required this.dashboard});

  static String _slotName(MealType t) {
    switch (t) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<MealLogController>()) {
      Get.put(MealLogController(
        homeRepo: Get.find(),
        sharedPreferences: Get.find(),
      ));
    }
    final ctrl = Get.find<MealLogController>();
    final pc = ProfileCompletion.to;
    return Obx(() {
    // Paid client whose dietitian still needs her form, and no meal plan
    // yet: the tile waits for the profile instead of asking to log meals.
    final planCtrl = Get.isRegistered<DietPlanUserController>()
        ? Get.find<DietPlanUserController>()
        : null;
    if (pc.dietLocked && planCtrl?.activePlan.value == null) {
      return _CardShell(
        onTap: pc.openForm,
        child: const _EmptyStat(
          label: '🔒 Meals',
          prompt: 'Meal plan locked',
          action: 'Fill your profile ›',
        ),
      );
    }
    return _CardShell(
      onTap: () => _openMealLogSheet(context),
      child: Obx(() {
        int logged;
        int total;
        int? eatenKcal;
        int? targetKcal = dashboard.stats?.dailyKcalBudget;
        final dietCtrl = Get.isRegistered<DietPlanUserController>()
            ? Get.find<DietPlanUserController>()
            : null;
        final day = dietCtrl?.todaysDay;
        if (dietCtrl?.activePlan.value != null &&
            day != null &&
            day.meals.isNotEmpty) {
          final logs = dietCtrl!.todayLogsByType;
          total = day.meals.length;
          logged = 0;
          eatenKcal = 0;
          for (final m in day.meals) {
            final log = logs[m.mealType.wire];
            if (log != null && log.status != MealLogStatusV2.pending) {
              logged++;
            }
            if (log?.status == MealLogStatusV2.followed) {
              eatenKcal = eatenKcal! + m.calories;
            }
          }
          if (day.totalCalories > 0) targetKcal = day.totalCalories;
        } else {
          total = MealType.values.length;
          logged = ctrl.todayMeals.values
              .where((m) => m.status != MealStatus.pending)
              .length;
        }

        String kcalLine;
        if (targetKcal == null) {
          kcalLine = 'logged today';
        } else if (eatenKcal != null) {
          kcalLine = '$eatenKcal of $targetKcal kcal';
        } else {
          kcalLine = '$targetKcal kcal target';
        }

        if (logged == 0) {
          return _EmptyStat(
            label: '🍽️ Meals',
            prompt: 'Log ${_slotName(currentMealForNow())}',
            sub: targetKcal != null ? '0 of $targetKcal kcal' : null,
          );
        }
        return _StatColumn(
          label: '🍽️ Meals',
          value: '$logged/$total',
          sub: kcalLine,
        );
      }),
    );
    });
  }
}

// ─── Row 2 ───────────────────────────────────────────────────────────────

/// Promoted from `_NutritionCard` so paid_home_screen_v2.dart can render
/// it directly next to PaidMealLogCard in a shared row. PaidStatsRow no
/// longer emits it in Row 2; the home screen owns its placement now.
///
/// Only ever mounted when the user has an active structured diet plan
/// (paid_home_screen_v2.dart gates this — see the Obx wrapper around
/// this row) — a "% diet plan" figure is meaningless without a real
/// plan to measure against, so this card no longer renders a fake
/// static number for plan-less users.
class PaidNutritionCard extends StatelessWidget {
  final HomeDashboardModel dashboard;
  const PaidNutritionCard({Key? key, required this.dashboard})
      : super(key: key);

  static String _slotName(MealType t) {
    switch (t) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Resolve once per build — slot only changes hour-to-hour, and the
    // accordion state is reactive via Obx below.
    final slot = currentMealForNow();
    // Defensive lookup — GetX's lazyPut bindings can fall out of the
    // registry on hot-reload when get_di.dart is edited without a full
    // hot-restart. Re-register on demand so the Nutrition card doesn't
    // bring the whole home screen down with "MealLogController not
    // found". Idempotent: if it's already there, isRegistered short-
    // circuits to the existing instance.
    if (!Get.isRegistered<MealLogController>()) {
      Get.put(MealLogController(
        homeRepo: Get.find(),
        sharedPreferences: Get.find(),
      ));
    }
    return _CardShell(
      // Tap-anywhere opens the shared meal-log sheet — same target as the
      // adjacent PaidMealSummaryCard. PaidMealLogCard is no longer
      // embedded on the home screen, so toggling the in-place accordion
      // would have no visible effect.
      onTap: () => _openMealLogSheet(context),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() {
            // Real adherence, computed from today's structured-plan
            // logs: % of today's meals marked "followed" (alternative
            // and skipped both count against adherence, pending simply
            // hasn't happened yet and is excluded from the denominator
            // used for display parity with the "X of N logged" pill
            // elsewhere — but IS counted here so a day full of unlogged
            // meals doesn't misleadingly read as 100%).
            final dietCtrl = Get.find<DietPlanUserController>();
            final day = dietCtrl.todaysDay;
            String value = '--';
            if (day != null && day.meals.isNotEmpty) {
              final logs = dietCtrl.todayLogsByType;
              final total = day.meals.length;
              final followed = day.meals.where((m) {
                final log = logs[m.mealType.wire];
                return log?.status == MealLogStatusV2.followed;
              }).length;
              value = '${((followed / total) * 100).round()}%';
            }
            return _StatColumn(
              label: '🥗 Nutrition',
              value: value,
              sub: 'diet plan',
              valueFontSize: 26,
              subFontSize: 10,
            );
          }),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Log ${_slotName(slot)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF163220),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 13,
                color: Color(0xFF163220),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact "today's meals" summary that pairs visually with
/// PaidNutritionCard in a half-width row. Tapping opens the same shared
/// meal-log sheet (`_openMealLogSheet`) — single entry point so both
/// cards behave identically.
class PaidMealSummaryCard extends StatelessWidget {
  const PaidMealSummaryCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Same defensive lookup as PaidNutritionCard — controller can fall
    // out of GetX's registry on hot-reload.
    if (!Get.isRegistered<MealLogController>()) {
      Get.put(MealLogController(
        homeRepo: Get.find(),
        sharedPreferences: Get.find(),
      ));
    }
    final ctrl = Get.find<MealLogController>();
    return _CardShell(
      onTap: () => _openMealLogSheet(context),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() {
            // Structured plan (if active) is the source of truth for the
            // real meal count — a plan can have more or fewer than the
            // legacy 3 (breakfast/lunch/dinner), so showing "1/3" for a
            // 5-meal plan would be wrong. Fall back to the legacy count
            // only when there's no active plan to read from.
            int logged;
            int total;
            final dietCtrl = Get.isRegistered<DietPlanUserController>()
                ? Get.find<DietPlanUserController>()
                : null;
            final day = dietCtrl?.todaysDay;
            if (dietCtrl?.activePlan.value != null &&
                day != null &&
                day.meals.isNotEmpty) {
              final logs = dietCtrl!.todayLogsByType;
              total = day.meals.length;
              logged = day.meals.where((m) {
                final log = logs[m.mealType.wire];
                return log != null && log.status != MealLogStatusV2.pending;
              }).length;
            } else {
              total = MealType.values.length;
              logged = ctrl.todayMeals.values
                  .where((m) => m.status != MealStatus.pending)
                  .length;
            }
            return _StatColumn(
              label: '🍽 Meals',
              value: '$logged/$total',
              sub: 'logged today',
              valueFontSize: 26,
              subFontSize: 10,
            );
          }),
          const SizedBox(height: 6),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Log meals',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF163220),
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                size: 13,
                color: Color(0xFF163220),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared "open meal log" sheet used by PaidNutritionCard +
/// PaidMealSummaryCard. Forces the embedded PaidMealLogCard into its
/// expanded state on open so the user lands directly on the meals
/// to log — they shouldn't need to tap a header to expand inside a
/// sheet that's already dedicated to logging.
void _openMealLogSheet(BuildContext context) {
  if (Get.isRegistered<MealLogController>()) {
    final ctrl = Get.find<MealLogController>();
    if (!ctrl.todayMealsExpanded.value) {
      ctrl.toggleTodayMeals();
    }
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Sheet hugs its content (no big empty area under the meals) and
    // only scrolls once the content is taller than 90% of the screen.
    builder: (sheetCtx) {
      final media = MediaQuery.of(sheetCtx);
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9FCF7),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + media.padding.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3EBDF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const PaidMealLogCard(),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// ─── Shared bits ─────────────────────────────────────────────────────────

/// Empty state for a stat tile: a short prompt in place of a 0, plus a
/// small green action or a muted sub line. Same label style as
/// [_StatColumn] so the row stays even.
class _EmptyStat extends StatelessWidget {
  final String label;
  final String prompt;
  final String? action;
  final String? sub;

  const _EmptyStat({
    required this.label,
    required this.prompt,
    this.action,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF163220),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF163220),
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        if (action != null)
          Text(
            action!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3C9A2C),
            ),
          )
        else if (sub != null)
          Text(
            sub!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF9AB09A),
            ),
          ),
      ],
    );
  }
}

/// Standard label / value / sub stack used by every card. Centralises
/// font sizing + colours so the 5 cards stay visually identical.
/// Mirrors the original `_WorkoutsCard` block in the previous version
/// of this file.
class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final double valueFontSize;
  final double subFontSize;
  final Color? valueColor;
  final String? caption;
  final Color? captionColor;
  /// Small unit right after the number ("79.0 kg").
  final String? unit;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.sub,
    this.unit,
    this.valueFontSize = 20,
    this.subFontSize = 9.5,
    this.valueColor,
    this.caption,
    this.captionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF163220),
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: value),
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: valueFontSize * 0.55,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ]),
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: FontWeight.w800,
              color: valueColor ?? const Color(0xFF6DC55A),
              height: 1.0,
            ),
          ),
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: subFontSize,
              color: const Color(0xFF9AB09A),
            ),
          ),
        ],
        if (caption != null) ...[
          const SizedBox(height: 3),
          Text(
            caption!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: captionColor != null ? FontWeight.w700 : FontWeight.w500,
              color: captionColor ?? const Color(0xFF8A9A88),
            ),
          ),
        ],
      ],
    );
  }
}

/// Shared card shell — white bg, mint border, 20 radius, soft shadow.
/// Mirrors water/sleep cards visually. Optional `onTap` for the
/// interactive Weight variant (preserves the previous _ProgressCard's
/// tap-to-log-weight behaviour).
class _CardShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const _CardShell({
    required this.child,
    this.onTap,
    // Default mirrors HTML stats-card padding (11px vert, 6px horiz).
    // Override for the wider Nutrition cell which uses .card padding.
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8EDD4), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF163220).withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: card,
    );
  }
}

/// Meals still to log today, for the "N to log / All done" count in
/// Today's insights (Oct 2026). Same counting as [PaidMealsInsightRow]:
/// her plan's meals for today (4, 5...), else breakfast/lunch/dinner.
/// 0 when meals are locked (nothing she can log yet). Read inside Obx.
/// Oct 2026 (option A): paid, before her first dietitian plan exists
/// (first call to book, booked, or plan being prepared). There's nothing
/// to "follow" yet, so meals aren't logged; Home says the plan comes
/// after her call instead.
bool mealPlanNotYet() {
  if (!Get.isRegistered<DietPlanUserController>()) return false;
  final d = Get.find<DietPlanUserController>();
  if (d.activePlan.value != null || d.isLoading.value) return false;
  final ctx = d.bookingContext.value;
  if (ctx == null) return false;
  // Server steps before her first plan: book the first call, first call
  // booked, plan being prepared (helper: booking context nextStep).
  const before = {'book_initial', 'initial_booked', 'plan_preparing'};
  return before.contains(ctx.nextStep) || ctx.planPreparing != null;
}

int mealsLeftToLog() {
  if (mealPlanNotYet()) return 0;
  if (!Get.isRegistered<MealLogController>()) {
    Get.put(MealLogController(homeRepo: Get.find(), sharedPreferences: Get.find()));
  }
  final ctrl = Get.find<MealLogController>();
  final dietCtrl = Get.isRegistered<DietPlanUserController>()
      ? Get.find<DietPlanUserController>()
      : null;
  if (ProfileCompletion.to.dietLocked && dietCtrl?.activePlan.value == null) return 0;
  final day = dietCtrl?.todaysDay;
  if (dietCtrl?.activePlan.value != null && day != null && day.meals.isNotEmpty) {
    final logs = dietCtrl!.todayLogsByType;
    var left = 0;
    for (final m in day.meals) {
      final log = logs[m.mealType.wire];
      if (log == null || log.status == MealLogStatusV2.pending) left++;
    }
    return left;
  }
  return MealType.values.where((t) {
    final m = ctrl.todayMeals[t];
    return m == null || m.status == MealStatus.pending;
  }).length;
}

/// "Meals" row inside Today's insights (Oct 2026): logged today, calories
/// and the next meal to log, with a progress bar. Tap: the meal log sheet.
/// Locked (paid client whose dietitian still needs her form, no plan yet):
/// says so and opens her form.
class PaidMealsInsightRow extends StatelessWidget {
  final HomeDashboardModel dashboard;
  const PaidMealsInsightRow({Key? key, required this.dashboard}) : super(key: key);

  static String _slotName(MealType t) {
    switch (t) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<MealLogController>()) {
      Get.put(MealLogController(
        homeRepo: Get.find(),
        sharedPreferences: Get.find(),
      ));
    }
    final ctrl = Get.find<MealLogController>();
    final pc = ProfileCompletion.to;
    return Obx(() {
      final dietCtrl = Get.isRegistered<DietPlanUserController>()
          ? Get.find<DietPlanUserController>()
          : null;
      final locked = pc.dietLocked && dietCtrl?.activePlan.value == null;
      if (!locked && mealPlanNotYet()) return const _MealPlanAfterCall();

      int logged;
      int total;
      int? eaten;
      int? target = dashboard.stats?.dailyKcalBudget;
      // Next meal to log (Oct 2026): the first NOT-yet-logged meal from
      // now on (else the first not-logged one at all), so it never says
      // "Log breakfast" once breakfast is logged.
      String? nextName;
      final nowSlot = currentMealForNow();
      final day = dietCtrl?.todaysDay;
      if (dietCtrl?.activePlan.value != null && day != null && day.meals.isNotEmpty) {
        final logs = dietCtrl!.todayLogsByType;
        total = day.meals.length;
        logged = 0;
        eaten = 0;
        final nowIdx = nowSlot == MealType.breakfast
            ? MealTypeV2.breakfast.index
            : nowSlot == MealType.lunch
                ? MealTypeV2.lunch.index
                : MealTypeV2.dinner.index;
        MealTypeV2? firstOpen;
        MealTypeV2? nextOpen;
        for (final m in day.meals) {
          final log = logs[m.mealType.wire];
          final isLogged = log != null && log.status != MealLogStatusV2.pending;
          if (isLogged) {
            logged++;
          } else {
            firstOpen ??= m.mealType;
            if (m.mealType.index >= nowIdx) nextOpen ??= m.mealType;
          }
          if (log?.status == MealLogStatusV2.followed) eaten = eaten! + m.calories;
        }
        final pick = nextOpen ?? firstOpen;
        if (pick != null) nextName = pick.label.toLowerCase();
        if (day.totalCalories > 0) target = day.totalCalories;
      } else {
        total = MealType.values.length;
        bool isLogged(MealType t) {
          final m = ctrl.todayMeals[t];
          return m != null && m.status != MealStatus.pending;
        }
        logged = MealType.values.where(isLogged).length;
        final open = MealType.values.where((t) => !isLogged(t)).toList();
        final pick = open.firstWhereOrNull((t) => t.index >= nowSlot.index) ??
            (open.isEmpty ? null : open.first);
        if (pick != null) nextName = _slotName(pick);
      }
      final done = total > 0 && logged >= total;
      final kcal = target == null
          ? null
          : (eaten != null ? '$eaten of $target kcal' : '$target kcal target');

      const ink = Color(0xFF163220);
      const soft = Color(0xFF6F8B7A);
      const green = Color(0xFF4AA877);
      const amber = Color(0xFFC8893A);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: locked ? pc.openForm : () => _openMealLogSheet(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: locked ? const Color(0xFFFAFCF9) : const Color(0xFFF7FBF5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3EEDD)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF1E3),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(locked ? '🔒' : '🍽️', style: const TextStyle(fontSize: 15)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text('Meals',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: ink)),
                        const SizedBox(width: 6),
                        if (!locked)
                          Text('$logged of $total logged',
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: soft)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (locked)
                      const Text('Meal plan locked · finish your profile',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: soft))
                    else ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : (logged / total).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: const Color(0xFFE6EFE1),
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF6DC55A)),
                        ),
                      ),
                      if (kcal != null) ...[
                        const SizedBox(height: 3),
                        Text(kcal, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: soft)),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                locked
                    ? 'Fill profile ›'
                    : done
                        ? 'All logged ✓'
                        : 'Log ${nextName ?? _slotName(nowSlot)} ›',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: done ? green : (locked ? green : amber),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}


/// Meals row before her first plan (Oct 2026, option A).
class _MealPlanAfterCall extends StatelessWidget {
  const _MealPlanAfterCall();

  Future<void> _book() async {
    final ctx = Get.find<DietPlanUserController>().bookingContext.value;
    if (ctx == null || !ctx.canBook) return;
    await BookConsultationSheet.show(
      popupVariable: 'POPUP_BOOK_INITIAL_CONSULTATION',
      dietitianId: ctx.dietitianId!,
      userId: ctx.userId!,
      userPlanId: ctx.userPlanId!,
      kind: 'initial',
    );
  }

  /// Plan paused: resume it first (with the usual confirm), then book.
  Future<void> _unfreezeThenBook() async {
    final ok = await Get.dialog<bool>(const UnfreezeConfirmDialog(resumeOn: null));
    if (ok != true) return;
    try {
      final token = Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
      final res = await Get.find<PlanFreezeRepository>().unfreeze(accessToken: token);
      final done = res.body != null && res.body['status'] == '1';
      if (!done) {
        Get.snackbar('Could not resume', res.body?['message']?.toString() ?? 'Please try again.',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      final home = Get.find<HomeController>();
      await home.refreshPlanFrozen();
      if (Get.isRegistered<PaidHomeController>()) Get.find<PaidHomeController>().silentRefresh();
      await Get.find<DietPlanUserController>().loadBookingContext(refresh: true);
      await _book();
    } catch (e) {
      Get.snackbar('Could not resume', '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF163220);
    const soft = Color(0xFF6F8B7A);
    const green = Color(0xFF3E8E36);
    final d = Get.find<DietPlanUserController>();
    // Paused plan (Oct 2026): booking is off until she resumes, so the
    // link says so and resumes the plan first instead of doing nothing.
    final frozen = Get.isRegistered<HomeController>() && Get.find<HomeController>().planFrozen.value;
    final ctx = d.bookingContext.value;
    final appt = Get.isRegistered<ConsultationController>()
        ? Get.find<ConsultationController>().upcomingAppointment.value
        : null;
    final preparing = ctx?.planPreparing != null;

    String sub;
    String? action;
    if (preparing) {
      sub = 'Your dietitian is preparing it now';
    } else if (appt != null) {
      final when = DateTime.tryParse('${appt.date}');
      sub = when != null
          ? 'Your call: ${DateFormat('EEE d MMM').format(when)}${appt.slotStart != null ? ' · ${appt.slotStart}' : ''}'
          : 'Your call is booked';
    } else if (frozen) {
      sub = 'Your plan is paused. Resume it to book your call';
      action = 'Unfreeze ›';
    } else {
      sub = 'Meal logging starts with your plan';
      if (ctx?.canBook == true) action = 'Book my call ›';
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: action == null ? null : (frozen && !preparing && appt == null ? _unfreezeThenBook : _book),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FBF5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3EEDD)),
        ),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFFDF1E3), borderRadius: BorderRadius.circular(9)),
            child: Text(preparing ? '🥗' : '🗓️', style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(preparing ? 'Your meal plan is on its way' : 'Your meal plan comes after your call',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: ink)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: soft)),
            ]),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            Text(action,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: green)),
          ],
        ]),
      ),
    );
  }
}
