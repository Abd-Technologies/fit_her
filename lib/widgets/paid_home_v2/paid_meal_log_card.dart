import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/controllers/diet_plan_user_controller/diet_plan_user_controller.dart';
import '../../data/controllers/meal_log_controller/meal_log_controller.dart';
import '../../data/models/diet_plan_v2/diet_plan_v2_models.dart';
import '../../data/models/diet_plan_v2/meal_log_v2.dart';
import '../../data/models/meal_log/meal_log.dart';
import '../../UI/consultation_module/meal_log/meal_log_options_sheet.dart';
import '../../UI/consultation_module/meal_log/meal_edit_history_screen.dart';
import '../v2/meal_status_chip.dart';
import '../v2/v2_today_meals_section.dart' show showV2MealLogSheet;

const Color _kCardBorder = Color(0xFFD8EDD4);
const Color _kRowBorder = Color(0xFFD8EDD4);
const Color _kRowBg = Color(0xFFF5FDF2);
const Color _kCurrentBg = Color(0xFFE8F8E0);
const Color _kAccent = Color(0xFF6DC55A);
const Color _kHeroDark = Color(0xFF163220);
const Color _kTextPrimary = Color(0xFF163220);
const Color _kTextMuted = Color(0xFF6F8B7A);
const Color _kSage = Color(0xFF9AB09A);
// Phase H — structured rendering uses the same status colours as the
// Diet tab's V2TodayMealsSection so the user sees consistent meal-
// status iconography across both surfaces.
const Color _kAlternative = Color(0xFFFAC775);
const Color _kDanger = Color(0xFFE07B7B);

/// Home tile (Section 6.1) — collapsible "Today's meals" card. Tapping
/// the header (or the Nutrition stat card on the same screen) toggles
/// the accordion: the chevron rotates → to ↓, the meal rows slide open,
/// and the page scrolls the card into view. Tapping a row inside opens
/// [MealLogOptionsSheet]; the calendar icon opens
/// [MealEditHistoryScreen] (7-day editable window enforced server-side).
class PaidMealLogCard extends StatefulWidget {
  const PaidMealLogCard({Key? key}) : super(key: key);

  @override
  State<PaidMealLogCard> createState() => _PaidMealLogCardState();
}

class _PaidMealLogCardState extends State<PaidMealLogCard> {
  late final MealLogController _ctrl;
  final GlobalKey _cardKey = GlobalKey();
  Worker? _expandWatcher;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<MealLogController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.loadToday();
      // Phase H — kick the structured plan controller too. If the user
      // hasn't opened the Diet tab yet, `activePlan` is still null and
      // the structured branch in build() falls back to legacy. This
      // load is idempotent — the controller guards against duplicate
      // in-flight fetches.
      if (Get.isRegistered<DietPlanUserController>()) {
        Get.find<DietPlanUserController>().loadActivePlan();
      }
    });
    // When something else (the Nutrition stat card) flips the expand
    // state, scroll this card into view so the slide-open animation is
    // visible — otherwise the user taps the arrow above and watches
    // nothing change because the card is below the fold.
    _expandWatcher = ever<bool>(_ctrl.todayMealsExpanded, (expanded) {
      if (!expanded || !mounted) return;
      // Defer one frame so AnimatedSize starts before we measure scroll.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _cardKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            alignment: 0.05,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _expandWatcher?.dispose();
    super.dispose();
  }

  Future<void> _openOptions(MealLog meal) async {
    if (!meal.editable) return;
    await MealLogOptionsSheet.show(meal: meal);
  }

  void _openHistory() {
    Get.to<dynamic>(() => const MealEditHistoryScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _cardKey,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
      child: Obx(() {
        // Phase H — branch on whether the user has an active structured
        // plan. If she does, the home card mirrors the Diet tab's
        // today data (real food names + times + V2 log sheet). If not,
        // we fall back to the legacy 3-row breakfast/lunch/dinner view
        // so users still on the legacy PDF flow see something sensible.
        final dietCtrl = _findDietPlanCtrl();
        final structuredDay = dietCtrl?.todaysDay;
        final useStructured =
            dietCtrl != null && dietCtrl.activePlan.value != null && structuredDay != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            useStructured
                ? _buildHeaderStructured(dietCtrl, structuredDay)
                : _buildHeader(),
            Obx(() {
              final expanded = _ctrl.todayMealsExpanded.value;
              return AnimatedSize(
                duration: const Duration(milliseconds: 280),
                alignment: Alignment.topCenter,
                curve: Curves.easeInOutCubic,
                child: expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: useStructured
                            ? _buildBodyStructured(dietCtrl, structuredDay)
                            : _buildBody(currentMealForNow()),
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              );
            }),
          ],
        );
      }),
    );
  }

  /// Phase H — structured-plan header. Pulls "X of N logged" from
  /// DietPlanUserController.todayLogsByType by counting non-pending
  /// entries against today's actual meal count (could be 3, 4, 5, or 6
  /// depending on plan template).
  Widget _buildHeaderStructured(
      DietPlanUserController dietCtrl, DietPlanDayV2 day) {
    return Obx(() {
      final logs = dietCtrl.todayLogsByType;
      final total = day.meals.length;
      final logged = day.meals
          .where((m) {
            final log = logs[m.mealType.wire];
            return log != null && log.status != MealLogStatusV2.pending;
          })
          .length;
      final expanded = _ctrl.todayMealsExpanded.value;
      return InkWell(
        onTap: _ctrl.toggleTodayMeals,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "TODAY'S MEALS",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kSage,
                        letterSpacing: 0.7,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Log what you ate',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kTextPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              _ProgressPill(logged: logged, total: total),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openHistory,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _kRowBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kRowBorder),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: _kAccent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: _kSage,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Phase H — structured-plan body. One row per meal in today's plan,
  /// sorted by time. Tap → V2 log sheet (same flow as Diet tab).
  Widget _buildBodyStructured(
      DietPlanUserController dietCtrl, DietPlanDayV2 day) {
    final meals = [...day.meals]..sort((a, b) => a.time.compareTo(b.time));
    return Obx(() {
      final logs = dietCtrl.todayLogsByType;
      return Column(
        children: [
          for (final m in meals)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StructuredMealRow(
                meal: m,
                status: logs[m.mealType.wire]?.status ??
                    MealLogStatusV2.pending,
                onTap: () => showV2MealLogSheet(meal: m),
              ),
            ),
        ],
      );
    });
  }

  DietPlanUserController? _findDietPlanCtrl() {
    if (!Get.isRegistered<DietPlanUserController>()) return null;
    return Get.find<DietPlanUserController>();
  }

  Widget _buildHeader() {
    return Obx(() {
      final logged = _ctrl.todayMeals.values
          .where((m) => m.status != MealStatus.pending)
          .length;
      final total = MealType.values.length;
      final expanded = _ctrl.todayMealsExpanded.value;
      return InkWell(
        onTap: _ctrl.toggleTodayMeals,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "TODAY'S MEALS",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kSage,
                        letterSpacing: 0.7,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Log what you ate',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kTextPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              _ProgressPill(logged: logged, total: total),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openHistory,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _kRowBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kRowBorder),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: _kAccent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: _kSage,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildBody(MealType currentSlot) {
    return Obx(() {
      if (_ctrl.loading.value && _ctrl.todayMeals.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
              ),
            ),
          ),
        );
      }
      return Column(
        children: MealType.values.map((t) {
          final meal = _ctrl.todayMeals[t] ??
              MealLog(
                date: '',
                mealType: t,
                status: MealStatus.pending,
              );
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MealRow(
              meal: meal,
              isCurrent: t == currentSlot,
              onTap: () => _openOptions(meal),
            ),
          );
        }).toList(),
      );
    });
  }
}

class _ProgressPill extends StatelessWidget {
  final int logged;
  final int total;
  const _ProgressPill({required this.logged, required this.total});

  @override
  Widget build(BuildContext context) {
    final isComplete = logged >= total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (isComplete ? _kAccent : _kSage).withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (isComplete ? _kAccent : _kSage).withOpacity(0.32),
        ),
      ),
      child: Text(
        '$logged of $total logged',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isComplete ? _kAccent : _kSage,
        ),
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  final MealLog meal;
  final bool isCurrent;
  final VoidCallback onTap;

  const _MealRow({
    required this.meal,
    required this.isCurrent,
    required this.onTap,
  });

  static String _label(MealType t) {
    switch (t) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
    }
  }

  static String _timeHint(MealType t) {
    switch (t) {
      case MealType.breakfast:
        return 'Morning · until 11:00';
      case MealType.lunch:
        return 'Midday · until 17:00';
      case MealType.dinner:
        return 'Evening · anytime tonight';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = isCurrent ? _kCurrentBg : _kRowBg;
    final borderColor = isCurrent ? _kAccent : _kRowBorder;
    final borderWidth = isCurrent ? 1.4 : 1.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: _kAccent.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          _label(meal.mealType),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kTextPrimary,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: _kAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'NOW',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _timeHint(meal.mealType),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _kTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              MealStatusChip(status: meal.status),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: _kSage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phase H — paid-home row that mirrors the Diet tab's `_MealCard`
/// content. Time pill + meal-type label + actual food name + status
/// indicator on the right. Tappable; onTap opens the V2 log sheet so
/// the row → log flow matches the Diet tab exactly.
class _StructuredMealRow extends StatelessWidget {
  final DietPlanMealV2 meal;
  final MealLogStatusV2 status;
  final VoidCallback onTap;

  const _StructuredMealRow({
    required this.meal,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: _kRowBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kRowBorder, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kSage,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _mealTime12h(meal.time),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      meal.mealType.label.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _kSage,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meal.foodName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusDot(status: status),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact 24×24 status indicator. Same colour vocabulary as the Diet
/// tab's per-meal indicator (followed/alternative/skipped), sized down
/// for the home card's denser row.
class _StatusDot extends StatelessWidget {
  final MealLogStatusV2 status;
  const _StatusDot({required this.status});
  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MealLogStatusV2.pending:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _kSage, width: 1.4),
          ),
        );
      case MealLogStatusV2.followed:
        return _filled(_kAccent, Icons.check_rounded);
      case MealLogStatusV2.alternative:
        return _filled(_kAlternative, Icons.swap_horiz_rounded);
      case MealLogStatusV2.skipped:
        return _filled(_kDanger, Icons.close_rounded);
    }
  }

  Widget _filled(Color bg, IconData icon) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 14),
    );
  }
}

/// "13:30" -> "1:30 PM" (same as the Diet tab's meal cards).
String _mealTime12h(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return hhmm;
  final h = int.tryParse(parts[0]);
  if (h == null) return hhmm;
  final m = parts[1].padLeft(2, '0').substring(0, 2);
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m $suffix';
}
