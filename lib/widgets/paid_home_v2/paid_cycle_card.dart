import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../UI/auth_module/log_period_screen.dart';
import '../../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../../data/models/home_dashboard/home_dashboard_model.dart';
import '../new_home/phase_theme.dart';

/// Cycle card: today's cycle day + phase, when her next period is
/// expected, and how the prediction is made (Oct 2026). Tap → "Log your
/// period" (LogPeriodScreen, sign-up style), then home refreshes.
///
/// The hormonal engine learns her real cycle length from every new period
/// date she logs (backend helper/cycleLearning.js), so the copy says so
/// and asks her to log it when her period starts.
class PaidCycleCard extends StatelessWidget {
  final HomeDashboardModel dashboard;

  const PaidCycleCard({Key? key, required this.dashboard}) : super(key: key);

  static const _ink = Color(0xFF163220);
  static const _sage = Color(0xFF8A9A88);
  static const _deep = Color(0xFF3C9A2C);

  Future<void> _update() async {
    // Same cycle questions and look as sign-up (Oct 2026).
    await Get.to(() => const LogPeriodScreen());
    try {
      Get.find<PaidHomeController>().refreshDashboard();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cycle = dashboard.cycle;
    if (cycle == null || cycle.cycleDay == null) {
      return const SizedBox.shrink();
    }

    final phaseTheme = PhaseTheme.forPhaseString(cycle.phase);
    final phaseLabel = cycle.phaseLabel ?? phaseTheme.phaseLabel;
    final days = cycle.periodInDays;
    String? nextLine;
    if (days != null) {
      if (days <= 0) {
        nextLine = 'Period expected today';
      } else {
        final date = DateTime.now().add(Duration(days: days));
        final when = DateFormat('EEE d MMM').format(date);
        nextLine = days == 1
            ? 'Next period: around $when (tomorrow)'
            : 'Next period: around $when · in $days days';
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _update,
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD8EDD4), width: 1),
          boxShadow: [
            BoxShadow(
              color: _ink.withOpacity(0.05),
              offset: const Offset(0, 2),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🌸 Cycle',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Day ${cycle.cycleDay}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    height: 1.1,
                  ),
                ),
                Text(
                  phaseLabel,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: phaseTheme.accent,
                  ),
                ),
              ],
            ),
            if (nextLine != null) ...[
              const SizedBox(height: 4),
              Text(
                nextLine,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: _ink,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(height: 1, color: const Color(0xFFEEF3EA)),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(children: [
                // One short line (Oct 2026): the engine learns from each
                // period she logs (helper/cycleLearning.js).
                TextSpan(
                  text: cycle.cyclesLearned > 0
                      ? '✨ Learned from your last ${cycle.cyclesLearned} '
                          'cycle${cycle.cyclesLearned == 1 ? '' : 's'} · '
                      : '✨ Gets smarter with every period you log · ',
                ),
                const TextSpan(
                  text: 'Log my period ›',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _deep),
                ),
              ]),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10.5,
                height: 1.45,
                color: _sage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

