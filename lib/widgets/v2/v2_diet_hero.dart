import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/cycle_theme_controller/cycle_theme_controller.dart';
import '../../data/controllers/diet_plan_user_controller/diet_plan_user_controller.dart';
import '../new_home/phase_theme.dart';
import '../../data/models/diet_plan_v2/diet_plan_v2_models.dart';
import '../../data/models/diet_plan_v2/meal_log_v2.dart';

/// Diet tab hero — colors follow the global CycleThemeController so
/// the phase accent stays consistent across all screens.
class V2DietHero extends StatelessWidget {
  final bool showBackButton;
  /// Paid clients (Oct 2026): show the "today" card (calorie ring, date,
  /// meals, day picker) instead of the TODAY block.
  final bool todayCard;
  const V2DietHero({super.key, this.showBackButton = false, this.todayCard = false});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final theme = Get.find<CycleThemeController>().theme.value;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: _HeroShell(theme: theme, showBackButton: showBackButton, todayCard: todayCard),
      );
    });
  }
}

class _HeroShell extends StatelessWidget {
  final PhaseTheme theme;
  final bool showBackButton;
  final bool todayCard;
  const _HeroShell({required this.theme, required this.showBackButton, this.todayCard = false});

  /// Phase-tinted radial-gradient overlay alpha. Mirrors PaidHero's
  /// `_gradAlpha` choice — follicular is gentler, others are punchier.
  double _gradAlpha(CyclePhase phase) =>
      phase == CyclePhase.follicular ? 0.40 : 0.50;

  Color _gradTint(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.follicular:
        return const Color(0xFF46823C);
      case CyclePhase.ovulatory:
        return const Color(0xFF146E5A);
      case CyclePhase.luteal:
        return const Color(0xFF6E460F);
      case CyclePhase.menstrual:
        return const Color(0xFF6E1414);
    }
  }

  @override
  Widget build(BuildContext context) {
    // We keep the hero phase-aware so it stays in family with paid home,
    // but Diet flow only knows follicular for now. Reading the value
    // back from the theme rather than hardcoding so phase tinting works
    // immediately when we wire phase data through.
    final phase = theme == PhaseTheme.follicular
        ? CyclePhase.follicular
        : theme == PhaseTheme.ovulatory
            ? CyclePhase.ovulatory
            : theme == PhaseTheme.luteal
                ? CyclePhase.luteal
                : CyclePhase.menstrual;
    const radius = BorderRadius.only(
      bottomLeft: Radius.circular(36),
      bottomRight: Radius.circular(36),
    );
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
              // 1. Phase-tinted radial gradient — fades from top-right.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(1.1, -1.05),
                        radius: 1.3,
                        colors: [
                          _gradTint(phase).withOpacity(_gradAlpha(phase)),
                          _gradTint(phase).withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.55],
                      ),
                    ),
                  ),
                ),
              ),
              // 2. Decorative ring at top-right.
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
              // 3. Content.
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TopBar(theme: theme, showBackButton: showBackButton),
                    _Greeting(theme: theme, phase: phase),
                    _Divider(theme: theme),
                    todayCard ? _TodayCard(theme: theme) : _DietStatusBlock(theme: theme),
                    SizedBox(height: 18.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final PhaseTheme theme;
  final bool showBackButton;
  const _TopBar({required this.theme, required this.showBackButton});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Oct 2026: no back button and no bell → no empty bar; just clear the
    // phone's status bar and let "NUTRITION" start right below it.
    if (!showBackButton) return SizedBox(height: mq.padding.top + 4);
    final topInset = mq.padding.top + 14;
    return Padding(
      padding: EdgeInsets.fromLTRB(8.w, topInset, 22.w, 0),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              onPressed: () => Get.back<dynamic>(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            )
          else
            SizedBox(width: 14.w),
          const Spacer(),
          // Oct 2026: the decorative bell was removed (it did nothing).
          // Same height kept so the hero doesn't shift.
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final PhaseTheme theme;
  final CyclePhase phase;
  const _Greeting({required this.theme, required this.phase});

  String _firstName() {
    if (!Get.isRegistered<AuthController>()) return 'there';
    final auth = Get.find<AuthController>();
    // `LoginModel.firstName` is non-nullable; only `logInUser` itself
    // can be null pre-login. The chain short-circuits cleanly.
    final n = auth.logInUser?.firstName.trim();
    return (n == null || n.isEmpty) ? 'there' : n;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22.w, 14.h, 22.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NUTRITION',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: theme.accent.withOpacity(0.85),
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Hi ${_firstName()}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
              height: 1.1,
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Text(theme.emoji, style: const TextStyle(fontSize: 14)),
              SizedBox(width: 6.w),
              Text(
                theme.energyLabel,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.92),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '·',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white.withOpacity(0.55),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                theme.phaseLabel,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final PhaseTheme theme;
  const _Divider({required this.theme});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(horizontal: 22.w),
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
}

/// Diet-specific status block in the hero — the data the user actually
/// cares about: which day, how many remaining, today's calorie target.
/// Wrapped in Obx so the hero stays in lockstep with controller state.
class _DietStatusBlock extends StatelessWidget {
  final PhaseTheme theme;
  const _DietStatusBlock({required this.theme});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<DietPlanUserController>()) {
      return _emptyState();
    }
    final ctrl = Get.find<DietPlanUserController>();
    return Obx(() {
      final plan = ctrl.activePlan.value;
      if (plan == null || ctrl.todaysDayNumber == null) {
        return _emptyState();
      }
      final today = ctrl.todaysDayNumber!;
      final remaining = ctrl.daysRemainingInPlan ?? 0;
      final dayMeal = ctrl.todaysDay;
      final kcal = dayMeal?.totalCalories;
      return Padding(
        padding: EdgeInsets.fromLTRB(22.w, 14.h, 22.w, 0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TODAY',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.55),
                      letterSpacing: 0.84,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    // Never "Day 22 of 7": past the last day it just
                    // says the plan has ended.
                    today > plan.planDays
                        ? 'Plan ended'
                        : 'Day $today of ${plan.planDays}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    today > plan.planDays
                        ? 'See your next step below'
                        : remaining == 0
                        ? 'Last day of plan'
                        : remaining == 1
                            ? 'Ends tomorrow'
                            : '$remaining days left',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.65),
                    ),
                  ),
                ],
              ),
            ),
            if (kcal != null && kcal > 0)
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: theme.accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.accent.withOpacity(0.32),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$kcal',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'kcal target',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.accent.withOpacity(0.9),
                        letterSpacing: 0.6,
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

  Widget _emptyState() {
    return Padding(
      padding: EdgeInsets.fromLTRB(22.w, 14.h, 22.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'TODAY',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.55),
              letterSpacing: 0.84,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Your diet plan',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Paid clients (Oct 2026): ONE "today" card in the hero with the calorie
/// ring (eaten of the day's target), the date, meals done, "Day X of Y"
/// and the day picker, in her phase colours. Replaces the hero's TODAY
/// block, and the day strip + green day summary card under the hero.
/// Shows the day she picked (today by default).
class _TodayCard extends StatelessWidget {
  final PhaseTheme theme;
  const _TodayCard({required this.theme});

  static const _weekday = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<DietPlanUserController>()) {
      return _emptyState();
    }
    final ctrl = Get.find<DietPlanUserController>();
    return Obx(() {
      final plan = ctrl.activePlan.value;
      final today = ctrl.todaysDayNumber;
      if (plan == null || today == null) {
        return _emptyState();
      }
      // Oct 2026: past the last day her plan repeats (ctrl.isRepeating)
      // until her next plan comes; otherwise it just says it ended.
      final repeating = ctrl.isRepeating;
      if (today > plan.planDays && !repeating) {
        // Never "Day 22 of 7": past the last day it just says so.
        return _emptyState(title: 'Plan ended', sub: 'See your next step below');
      }
      final dayNumber = ctrl.effectiveDayNumber;
      final shownDay = repeating ? (ctrl.repeatDayNumber ?? 1) : dayNumber;
      final day = ctrl.selectedDay ?? ctrl.todaysDay;
      final meals = day?.meals ?? const <DietPlanMealV2>[];
      final future = ctrl.isViewingFuture;
      var done = 0;
      var eaten = 0;
      for (final m in meals) {
        final s = ctrl.getLogForMeal(dayNumber, m.mealType.wire)?.status;
        if (s == MealLogStatusV2.followed || s == MealLogStatusV2.alternative) {
          done++;
          eaten += m.calories;
        } else if (s == MealLogStatusV2.skipped) {
          done++;
        }
      }
      final target = day?.totalCalories ?? 0;
      final progress = (future || target <= 0) ? 0.0 : (eaten / target).clamp(0.0, 1.0);
      final date = ctrl.dateForDay(dayNumber);
      final dateLine = date == null
          ? 'Day $dayNumber'
          : '${_weekday[(date.weekday - 1).clamp(0, 6)]}, ${date.day} ${_monthShort[(date.month - 1).clamp(0, 11)]}';
      final tag = ctrl.isViewingPast ? 'Past day' : (future ? 'Coming up' : null);

      return Padding(
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              // Calorie ring: eaten of the day's target.
              SizedBox(
                width: 82.w,
                height: 82.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 82.w,
                      height: 82.w,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.white.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          future ? '$target' : '$eaten',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          future ? 'kcal planned' : 'of $target\nkcal',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.5.sp,
                            color: Colors.white.withOpacity(0.65),
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            dateLine,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (tag != null) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.65),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '$done of ${meals.length}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        const TextSpan(text: ' meals   Day '),
                        TextSpan(
                          text: '$shownDay of ${plan.planDays}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        if (repeating) const TextSpan(text: ' · again'),
                      ]),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5.sp,
                        color: Colors.white.withOpacity(0.65),
                      ),
                    ),
                    if (plan.planDays > 1 && !repeating) ...[
                      SizedBox(height: 8.h),
                      _DayPicker(
                        theme: theme,
                        planDays: plan.planDays,
                        selected: dayNumber,
                        today: today,
                        labelFor: (n) {
                          final d = ctrl.dateForDay(n);
                          return d == null ? 'Day' : _weekdayShort[(d.weekday - 1).clamp(0, 6)];
                        },
                        onSelect: (n) => n == today ? ctrl.selectToday() : ctrl.selectDay(n),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _emptyState({String title = 'Your diet plan', String? sub}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22.w, 14.h, 22.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (sub != null) ...[
            SizedBox(height: 2.h),
            Text(
              sub,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.65),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Day picker inside the today card. Up to 4 days: equal pills. Longer
/// plans: a scrolling row that opens on the picked day.
class _DayPicker extends StatefulWidget {
  final PhaseTheme theme;
  final int planDays;
  final int selected;
  final int today;
  final String Function(int dayNumber) labelFor;
  final ValueChanged<int> onSelect;
  const _DayPicker({
    required this.theme,
    required this.planDays,
    required this.selected,
    required this.today,
    required this.labelFor,
    required this.onSelect,
  });

  @override
  State<_DayPicker> createState() => _DayPickerState();
}

class _DayPickerState extends State<_DayPicker> {
  final ScrollController _scroll = ScrollController();
  static const double _pillW = 46;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _show(widget.selected, animate: false));
  }

  @override
  void didUpdateWidget(covariant _DayPicker old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _show(widget.selected);
  }

  void _show(int day, {bool animate = true}) {
    if (!_scroll.hasClients) return;
    final target = ((day - 1) * (_pillW.w + 4.w)) - 40.w;
    final to = target.clamp(0.0, _scroll.position.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(to, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(to);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _pill(int n, {double? width}) {
    final on = n == widget.selected;
    return GestureDetector(
      onTap: () => widget.onSelect(n),
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(vertical: 6.h),
        decoration: BoxDecoration(
          color: on ? widget.theme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.labelFor(n),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
                color: on ? widget.theme.heroBackground : Colors.white.withOpacity(0.65),
              ),
            ),
            Text(
              '$n',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: on ? widget.theme.heroBackground : Colors.white,
              ),
            ),
            // Small dot under today when another day is picked.
            Container(
              width: 4,
              height: 4,
              margin: EdgeInsets.only(top: 2.h),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: n == widget.today && !on ? widget.theme.accent : Colors.transparent,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
    );
    if (widget.planDays <= 4) {
      return Container(
        padding: EdgeInsets.all(3.w),
        decoration: box,
        child: Row(
          children: [
            for (var n = 1; n <= widget.planDays; n++) Expanded(child: _pill(n)),
          ],
        ),
      );
    }
    return Container(
      height: 60.h,
      padding: EdgeInsets.all(3.w),
      decoration: box,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        itemCount: widget.planDays,
        separatorBuilder: (_, __) => SizedBox(width: 4.w),
        itemBuilder: (_, i) => _pill(i + 1, width: _pillW.w),
      ),
    );
  }
}
