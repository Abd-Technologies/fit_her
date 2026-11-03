import 'dart:async';

import '../../UI/free_trail/trial_summary_screen.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../UI/plans_module/all_plans.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../paid_home_v2/paid_hero.dart' show effectiveLiveClass;
import '../paid_home_v2/paid_hero_coming_up.dart';
import '../paid_home_v2/paid_hero_live_section.dart';
import 'phase_theme.dart';
import 'trial_cta_card.dart' show showTrialStartDialog;

/// Class area of the unpaid / free-trial home hero. Same real class card
/// as the paid home (UP NEXT → countdown + Get ready → Join now /
/// Cancelled) plus the Coming Up tiles — no more fake "LIVE · 34 women ·
/// Strength Training".
///
///  • Not started the trial yet: every card button is "Try free →"
///    (starts the trial).
///  • Trial running: behaves exactly like a paid user (trial join rules
///    are applied by the Join button itself).
class HeroClassSection extends StatefulWidget {
  final PhaseTheme theme;
  const HeroClassSection({super.key, required this.theme});

  @override
  State<HeroClassSection> createState() => _HeroClassSectionState();
}

class _HeroClassSectionState extends State<HeroClassSection> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Real classes for everyone (preview users included).
    final paid = Get.find<PaidHomeController>();
    if (paid.dashboard.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => paid.loadDashboard());
    }
    // Re-pick the card's class as time passes (Up next → next class).
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final dash = Get.find<PaidHomeController>().dashboard.value;
      final activated = Get.find<AuthController>().trialActivated.value;
      // Trial over, no plan: same card, button leads to her summary + offer.
      final ended = activated && Get.find<HomeController>().trialEndedUnpaid;
      if (dash == null) return const SizedBox(height: 24);
      final live = effectiveLiveClass(dash);
      final tiles = live != null
          ? dash.comingUp.where((x) => x.id != live.slotId).toList()
          : dash.comingUp;
      return Padding(
        // The tiles row already leaves 20 below it (Oct 2026: was 22 more).
        padding: const EdgeInsets.only(bottom: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            PaidHeroLiveSection(
              live: live,
              theme: widget.theme,
              previewCtaLabel: !activated
                  ? 'Try free →'
                  : ended
                      ? 'Choose a plan →'
                      : null,
              onPreviewCta: !activated
                  ? showTrialStartDialog
                  : ended
                      ? () => Get.to<dynamic>(() => const TrialSummaryScreen())
                      : null,
            ),
            PaidHeroComingUp(comingUp: tiles),
            if (activated && live == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                child: GestureDetector(
                  onTap: () => Get.to<dynamic>(() => OurPlansScreen()),
                  child: Text(
                    'Explore plans →',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.theme.accent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}
