import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/cycle_theme_controller/cycle_theme_controller.dart';
import '../../data/controllers/diet_plan_user_controller/diet_plan_user_controller.dart';
import '../../utils/display_name.dart';
import '../new_home/phase_theme.dart';

/// Diet tab hero — colors follow the global CycleThemeController so
/// the phase accent stays consistent across all screens.
class V2DietHero extends StatelessWidget {
  final bool showBackButton;
  const V2DietHero({super.key, this.showBackButton = false});

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
        child: _HeroShell(theme: theme, showBackButton: showBackButton),
      );
    });
  }
}

class _HeroShell extends StatelessWidget {
  final PhaseTheme theme;
  final bool showBackButton;
  const _HeroShell({required this.theme, required this.showBackButton});

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
                    _DietStatusBlock(theme: theme),
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
          // Notification bell mirrors paid home's affordance — purely
          // decorative on this surface for now (no per-Diet badge).
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
            ),
            child: const Text('🔔', style: TextStyle(fontSize: 13)),
          ),
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
    final user = auth.logInUser;
    return friendlyDisplayName(
      firstName: user?.firstName,
      lastName: user?.lastName,
    );
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
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '·',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                theme.phaseLabel,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.55),
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
      // Wave 0 D-03 — never render "Day 13 of 7"; clamp + ended state.
      final rawToday = ctrl.todaysDayNumber!;
      final ended = ctrl.planHasEnded;
      final today =
          ended ? plan.planDays : rawToday.clamp(1, plan.planDays).toInt();
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
                    ended ? 'PLAN' : 'TODAY',
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
                    ended
                        ? 'Plan completed'
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
                    ended
                        ? 'Your ${plan.planDays}-day plan has ended'
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
