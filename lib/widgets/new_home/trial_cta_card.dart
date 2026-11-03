import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../UI/free_trail/trial_onboarding_screen.dart';
import '../../UI/free_trail/trial_summary_screen.dart';
import '../../UI/plans_module/all_plans.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import '../anim/motion.dart';

/// Navigation mode for [enterTrialOnboarding] -- lets each call site keep
/// its own back-stack behavior (push vs. replace vs. clear-to-root)
/// without duplicating the activation + routing logic itself.
enum TrialNav { push, replace, replaceAll }

/// Canonical "the trial was just started server-side" entry point. Every
/// trial-start call site in the app (home hero, workout tab, login,
/// Google sign-in, signup, deep links, slot booking) should call this
/// right after its own backend call succeeds, instead of hand-rolling its
/// own "if started: Get.to(TrialJourneyScreen)" -- that duplication is
/// exactly how those paths drifted out of sync with the main funnel and
/// ended up skipping the diet quick-intake + AI plan step entirely, while
/// also never flipping AuthController.trialActivated (so the home screen
/// kept showing everything as locked even though the trial was live).
///
/// Sequence this enforces: mark the trial activated locally (unlocks
/// every 🔒 on the home screen immediately) -> pre-diet quick-intake form
/// (TrialQuickIntakeScreen), which generates + auto-activates the AI
/// starter plan -> from there, the existing workout/live-class
/// onboarding (TrialMealPlanScreen's "Live classes" hand-off into
/// TrialJourneyScreen). If the user already has a diet plan (e.g. a
/// second trial-start trigger fires after the first already ran),
/// HomeController.submitTrialQuickIntake treats the backend's "already
/// got a plan" response as success, so this still lands them safely on
/// the meal plan instead of erroring.
void enterTrialOnboarding([TrialNav nav = TrialNav.push]) {
  // The trial is NOT switched on here any more. TrialOnboardingScreen
  // only starts it (server trial + AI plan + the local trialActivated
  // flag) once she has filled the form and confirmed her answers. If she
  // leaves halfway, the home screen keeps offering "Start free trial"
  // and brings her back here, with her answers saved.
  switch (nav) {
    case TrialNav.push:
      Get.to<void>(() => const TrialOnboardingScreen());
      break;
    case TrialNav.replace:
      Get.off<void>(() => const TrialOnboardingScreen());
      break;
    case TrialNav.replaceAll:
      Get.offAll<void>(() => const TrialOnboardingScreen());
      break;
  }
}

/// Shows the trial-start confirmation dialog.
/// Shared by [TrialCtaCard] and [HeroLiveSection] so either entry-point
/// triggers the same flow: confirm → POST /trial/start ->
/// [enterTrialOnboarding] (Trial-to-Plan funnel Step 3) — its own "Skip
/// for now" still reaches TrialJourneyScreen for the live-class booking.
void showTrialStartDialog() {
  // The "Your trial is activated" popup was removed: tapping Start free
  // trial goes straight to the trial onboarding (first-day preview).
  // The trial clock still starts at the end of onboarding, after she
  // confirms her form. Name kept so every existing call site still works.
  enterTrialOnboarding();
}

/// Conversion banner shown on the unpaid home + unpaid progress preview.
///
/// Two states (driven by [AuthController.trialActivated]):
///   • idle      → "3 days free · then PKR 3500/month" + "Start 3-day free
///                 trial →". Tapping the button shows a confirmation dialog;
///                 on confirm it calls [HomeController.startTrial] (creates
///                 a TrialJourney row on the backend) then navigates to
///                 TrialQuickIntakeScreen. The local
///                 [AuthController.trialActivated] flag is also set so the
///                 card shows "activated" if the user navigates back to
///                 this screen later.
///   • activated → "Trial active · 3 days remaining" + "Explore more plans
///                 →" which routes to `OurPlansScreen`.
class TrialCtaCard extends StatelessWidget {
  const TrialCtaCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final home = Get.find<HomeController>();
    return Obx(() {
      final active = auth.trialActivated.value;
      if (!active) return const _IdleCard();
      // Compute real days remaining from the TrialJourney startedAt timestamp
      // so the chip stays accurate instead of always showing "3 days".
      // Falls back to null when the journey hasn't loaded yet (shows "Trial active").
      int? daysLeft;
      final rawStart = home.trialJourney?['startedAt'];
      if (rawStart != null) {
        final startedAt = DateTime.tryParse(rawStart.toString());
        if (startedAt != null) {
          final endsAt = startedAt.add(const Duration(days: 3));
          final hours = endsAt.difference(DateTime.now()).inHours;
          daysLeft = hours > 0 ? (hours / 24).ceil() : 0;
        }
      }
      return _ActivatedCard(daysLeft: daysLeft);
    });
  }
}

/// Shows a compact "this feature is locked" popup, specific to whichever
/// feature the user tapped (Water tracking, FitHer AI insight, Mood
/// logging, etc). "Start free trial →" hands off into the same
/// [showTrialStartDialog] flow used everywhere else, so there's one
/// consistent trial-start confirmation across the whole app -- this is
/// just a feature-specific teaser in front of it.
void showLockedFeatureDialog(String feature) {
  const accent = Color(0xFF6DC55A);
  Get.dialog<void>(
    Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Text('🔒', style: TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '$feature is locked',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF163220),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start your ${Get.find<HomeController>().trialDays.value}-day free trial to unlock $feature and everything '
              'else on your dashboard.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF6F8B7A),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Get.back<void>();
                showTrialStartDialog();
              },
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Start free trial →',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Get.back<void>(),
                child: const Text(
                  'Maybe later',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9AB09A),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: true,
  );
}

// ─── Idle (pre-activation) — original "Start 3-day free trial" copy. ───
class _IdleCard extends StatelessWidget {
  const _IdleCard();

  static const _accent = Color(0xFF6DC55A);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF163220), Color(0xFF1A3A28)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withOpacity(0.32), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF163220).withOpacity(0.18),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.22),
                  border:
                      Border.all(color: _accent.withOpacity(0.4), width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.work_outline,
                  color: _accent,
                  size: 14,
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  '${Get.find<HomeController>().trialDays.value} days free · then PKR 3500/month',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Unlock phase-matched live classes, AI insights, and your hormonal dashboard.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          _CtaBreath(
            color: _accent,
            radius: BorderRadius.circular(12),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onStartTrial(context),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Start ${Get.find<HomeController>().trialDays.value}-day free trial →',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Cancel anytime · No card charged today',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.white.withOpacity(0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onStartTrial(BuildContext context) => showTrialStartDialog();
}

/// Animation pass (#6): the main "Start free trial" button breathes
/// softly — scale 1.0 <-> 1.03 with a glow, ~1.8 s per loop, starting a
/// moment after the card appears. Reduce motion: a still button.
class _CtaBreath extends StatelessWidget {
  const _CtaBreath({required this.child, required this.color, required this.radius});
  final Widget child;
  final Color color;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    if (Motion.calm(context)) return child;
    return child
        .animate(
          delay: const Duration(milliseconds: 900),
          onPlay: (controller) => controller.repeat(reverse: true),
        )
        .custom(
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          builder: (context, v, child) => Transform.scale(
            scale: 1.0 + 0.03 * v,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.10 + 0.30 * v),
                    blurRadius: 8 + 12 * v,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
  }
}

// ─── Small info row used inside the trial-start confirmation dialog. ────
class _TrialInfoRow extends StatelessWidget {
  const _TrialInfoRow({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              height: 1.45,
              color: Color(0xFF3D5E46),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Activated — "Explore more plans" CTA into OurPlansScreen. ────────
class _ActivatedCard extends StatelessWidget {
  /// Real days left computed from [TrialJourney.startedAt].
  /// Null means the journey data hasn't loaded yet — shows "Trial active"
  /// without a day count rather than a stale "3 days remaining".
  final int? daysLeft;

  const _ActivatedCard({this.daysLeft});

  static const _accent = Color(0xFF6DC55A);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF163220), Color(0xFF1A3A28)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withOpacity(0.32), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF163220).withOpacity(0.18),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.22),
                  border:
                      Border.all(color: _accent.withOpacity(0.4), width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('✨',
                    style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  daysLeft == null
                      ? 'Trial active'
                      : daysLeft! > 0
                          ? 'Trial active · $daysLeft day${daysLeft == 1 ? '' : 's'} remaining'
                          : 'Trial ended · choose a plan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            // Bug fix: this used to say "You're enjoying full access" even
            // once the trial had ended — directly contradicting the
            // headline right above it ("Trial ended · choose a plan").
            // Now it matches whichever state the headline is showing.
            (daysLeft != null && daysLeft! <= 0)
                ? "Your free trial has ended. Pick a plan to get back to your insights, classes, and dashboard."
                : "You're enjoying full access. Pick a plan to keep your insights, classes, and dashboard after the trial ends.",
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Trial ended: her summary + offer (in her country's price).
            onTap: () => daysLeft == 0
                ? Get.to<dynamic>(() => const TrialSummaryScreen())
                : Get.to<dynamic>(() => OurPlansScreen()),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                daysLeft == 0 ? 'See my trial summary & offer →' : 'Explore more plans →',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Cancel anytime · No card charged today',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.white.withOpacity(0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
