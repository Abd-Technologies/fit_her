import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/services/cycle_engine.dart';
import '../../utils/display_name.dart';

class HeroGreetingBlock extends StatelessWidget {
  final String? firstName;
  final CycleInfo? cycleInfo;

  /// True while the cycle API call is in flight.
  /// Shows a skeleton placeholder instead of "Preview mode" so the hero
  /// never flashes an empty state during the first-frame load.
  final bool isLoading;

  const HeroGreetingBlock({
    Key? key,
    this.firstName,
    this.cycleInfo,
    this.isLoading = false,
  }) : super(key: key);

  String _timeAwareGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Maps CycleEngine phase strings to the display label + trailing emoji.
  /// Engine emits `ovulatory` (not `ovulation`) — map handles that.
  ({String label, String emoji})? _phaseDisplay(String phase) {
    switch (phase) {
      case 'follicular':
        return (label: 'Follicular Phase', emoji: '⚡');
      case 'luteal':
        return (label: 'Luteal Phase', emoji: '🌙');
      case 'menstrual':
        return (label: 'Menstrual Phase', emoji: '🩸');
      case 'ovulatory':
        return (label: 'Ovulation', emoji: '⚡');
      default:
        return null;
    }
  }

  /// Her own stated goal from onboarding ("Lose weight", "Build strength
  /// & tone", …) — already stored display-ready, no value mapping needed.
  /// Falls back to the old "Start trial" copy on the rare chance goal is
  /// somehow blank, so this chip is never left showing nothing.
  String get _goalLabel {
    final goal = Get.find<AuthController>().mainGoal.value.trim();
    return goal.isEmpty ? 'Start trial' : goal;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final double hPad = (w * 22 / 414).clamp(16.0, 24.0);
    final double phaseSize = (28 + (w - 360) / 54 * 4).clamp(28.0, 32.0);

    final name = friendlyDisplayName(firstName: firstName);
    final greeting = '${_timeAwareGreeting()}, $name';

    final phase = cycleInfo == null ? null : _phaseDisplay(cycleInfo!.phase);
    final dayText = cycleInfo == null ? '—' : 'Day ${cycleInfo!.cycleDay}';

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            greeting,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 14),
          // Phase line — skeleton while loading, real data or "Preview mode"
          // once the API responds.
          if (isLoading)
            // Skeleton pill — same height as the phase text so the layout
            // doesn't jump when data arrives.
            Container(
              width: 180,
              height: phaseSize + 2,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
            )
          else if (phase != null)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${phase.label} ',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: phaseSize,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.55),
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: phase.emoji,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: phaseSize,
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
            )
          else
            Text(
              'Preview mode',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: phaseSize,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.55),
                letterSpacing: -0.5,
                height: 1.0,
              ),
            ),
          const SizedBox(height: 14),
          // Chip row — skeleton while loading, real chips once data arrives.
          if (isLoading)
            Row(
              children: [
                _skeletonChip(60),
                const SizedBox(width: 8),
                _skeletonChip(80),
                const SizedBox(width: 8),
                _skeletonChip(50),
              ],
            )
          else
            // "Preview mode" / "Start trial" here were hardcoded — shown
            // to EVERY user regardless of whether they'd actually started
            // a trial or paid, because nothing in this row ever checked
            // real state.
            //
            // First fix used `phase == null` (real cycle data vs. no data
            // yet) as the "hasn't started" signal, since that's what the
            // phase text just above already branches on. Wrong signal
            // though — a user can log real cycle data (phase != null,
            // heading shows her actual phase) well before ever starting a
            // trial or paying, exactly Fatima's case: real "Menstrual
            // Phase" up top, but the "Try free →" button right below in
            // HeroLiveSection still shows because she genuinely hasn't
            // started a trial. Tying this row to `phase` made it
            // disappear the moment she logged her cycle, even though
            // she's still just as much in preview as before.
            //
            // The actual "has she started" signal is
            // AuthController.trialActivated — the exact same RxBool
            // HeroLiveSection already uses right below this to decide
            // between "Try free →" and "Explore more plans". Wrapped in
            // Obx so this updates immediately if she activates the trial
            // while this screen is still on-screen, not just on next
            // reload.
            Obx(() {
              final started =
                  Get.find<AuthController>().trialActivated.value;
              return Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _chip(dayText, 12, FontWeight.w700, const Color(0xFFA8F0C0).withOpacity(0.55)),
                  if (!started) ...[
                    _sep(),
                    _chip('Preview mode', 11, null, Colors.white.withOpacity(0.65)),
                    _sep(),
                    _chip('—', 11, FontWeight.w600, Colors.white.withOpacity(0.2)),
                    _sep(),
                    _chip(_goalLabel, 12, FontWeight.w700, const Color(0xFF6DC55A).withOpacity(0.7)),
                  ],
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _skeletonChip(double width) => Container(
        width: width,
        height: 12,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
        ),
      );

  Widget _sep() => Text(
        '·',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          color: Colors.white.withOpacity(0.18),
        ),
      );

  Widget _chip(String text, double size, FontWeight? weight, Color color) => Text(
        text,
        style: TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: weight, color: color),
      );
}
