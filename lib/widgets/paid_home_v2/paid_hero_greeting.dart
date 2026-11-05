import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../UI/auth_module/sign_up_screen/goal_screen.dart';
import '../../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../../data/models/home_dashboard/home_dashboard_model.dart';
import '../new_home/phase_theme.dart';
import '../../UI/profile_setup/profile_completion.dart';
import '../../UI/profile_setup/profile_completion_widgets.dart';

/// H-01 greeting block: time-aware greeting + split-weight phase title
/// + dynamic chip row. Separators only appear between visible chips.
class PaidHeroGreeting extends StatelessWidget {
  final HomeDashboardModel dashboard;
  final PhaseTheme theme;
  final CyclePhase phase;

  const PaidHeroGreeting({
    Key? key,
    required this.dashboard,
    required this.theme,
    required this.phase,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = (dashboard.user?.firstName ?? '').trim();
    // Display-only: capitalise the first letter of each word.
    final resolvedName = name.isEmpty ? 'there' : _titleCase(name);
    final greeting = '${_timeAwareGreeting()}, $resolvedName 🌿';

    // No period date yet: never guess a phase (it used to say
    // "Follicular Phase, Peak energy" for everyone without data).
    final noCycle = dashboard.cycle?.cycleDay == null;
    final phaseLabel = noCycle
        ? 'Your day'
        : (dashboard.cycle?.phaseLabel ?? theme.phaseLabel);
    final emoji = noCycle ? '🌿' : theme.emoji;

    final chipColors = _chipColors(phase);
    final chips = <Widget>[];

    // Day chip — hidden entirely when cycleDay is null.
    final cycleDay = dashboard.cycle?.cycleDay;
    if (cycleDay != null) {
      chips.add(
        _chip('Day $cycleDay', 12, FontWeight.w700, chipColors.day),
      );
    }

    // Energy chip — theme-derived, so only with a real cycle phase.
    if (!noCycle) {
      chips.add(
        _chip(theme.energyLabel, 11, FontWeight.w500,
            Colors.white.withOpacity(0.82)),
      );
    }

    // Streak chip — hidden at 0 (Day 1 redesign); shown from 1 day.
    final streak = dashboard.goal?.streakDays;
    if (streak != null && streak >= 1) {
      chips.add(
        _chip('$streak🔥', 11, FontWeight.w600, chipColors.streak),
      );
    }

    // Goal chip — the SIGNUP goal category (User.mainGoal, e.g. "Lose
    // weight"), not the dietitian/weight-tracking delta. Shows "Set
    // goal →" (tappable) when the user never picked one; otherwise shows
    // their chosen goal, also tappable to change it.
    chips.add(_goalChip(context, dashboard.user?.mainGoal, theme.accent));

    // Interleave '·' separators only between visible chips.
    final interleaved = <Widget>[];
    for (int i = 0; i < chips.length; i++) {
      interleaved.add(chips[i]);
      if (i < chips.length - 1) interleaved.add(_separator());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            greeting,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              // Oct 2026: brighter again ("make it brighter").
              color: Colors.white.withOpacity(0.92),
            ),
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$phaseLabel ',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.96),
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
                TextSpan(
                  text: emoji,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: interleaved,
          ),
          // Paid client with no period date: ask for it right here.
          if (noCycle)
            Obx(() => ProfileCompletion.to.periodLocked
                ? const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: HeroPeriodCard(),
                  )
                : const SizedBox.shrink()),
        ],
      ),
    );
  }

  static String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  String _timeAwareGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _separator() => Text(
        '·',
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withOpacity(0.45),
        ),
      );

  Widget _chip(String text, double size, FontWeight? weight, Color color) =>
      Text(
        text,
        style: TextStyle(fontSize: size, fontWeight: weight, color: color),
      );

  Widget _goalChip(BuildContext context, String? mainGoal, Color accent) {
    final hasGoal = mainGoal != null && mainGoal.trim().isNotEmpty;
    return GestureDetector(
      onTap: () => _onGoalTap(context, hasGoal ? mainGoal : null),
      child: Text(
        hasGoal ? mainGoal! : 'Set goal →',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }

  /// Opens the same goal picker GoalScreen uses at signup, pre-filled
  /// with the current choice if any. Saves via
  /// PaidHomeController.saveMainGoal (POST /users/profile/main_goal) and
  /// pops back to the home screen — this is a direct in-place edit, not
  /// a re-entry into the multi-step signup questionnaire.
  Future<void> _onGoalTap(BuildContext context, String? currentGoal) async {
    await Get.to(() => GoalScreen(
          currentStep: 1,
          totalSteps: 1,
          initialGoal: currentGoal,
          showBackButton: true,
          onNext: (selected) {
            Get.back();
            Get.find<PaidHomeController>().saveMainGoal(selected);
          },
        ));
  }
}

// Per-phase chip tint palette, traced exactly to H-01..H-04 in the HTML
// reference. Lives here (not PhaseTheme) because these colors are chip-row
// specific, don't apply elsewhere, and PhaseTheme is frozen.
({Color day, Color streak}) _chipColors(CyclePhase phase) {
  switch (phase) {
    case CyclePhase.follicular:
      return (day: const Color(0xFFA8F0C0), streak: const Color(0xFFFAC775));
    case CyclePhase.ovulatory:
      return (day: const Color(0xFF9FE1CB), streak: const Color(0xFFFAC775));
    case CyclePhase.luteal:
      return (day: const Color(0xFFFDE4A0), streak: const Color(0xFFFAC775));
    case CyclePhase.menstrual:
      // Softer than gold during the period (H-04 intent), but still readable:
      // 25% white was nearly invisible on the dark red card (Nov 2026).
      return (
        day: const Color(0xFFFFB8B8),
        streak: Color.fromRGBO(255, 255, 255, 0.6),
      );
  }
}
