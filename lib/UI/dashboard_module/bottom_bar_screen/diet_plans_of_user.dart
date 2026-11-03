import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../widgets/v2/plan_expiry_banner.dart';
import '../../../widgets/v2/plan_frozen_banner.dart';

import '../../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../../data/controllers/diet_plan_user_controller/diet_plan_user_controller.dart';
import '../../consultation_module/booking/upcoming_consultation_card.dart';
import '../../../widgets/v2/v2_diet_hero.dart';
import '../../../widgets/paid_home_v2/talk_to_expert_card.dart';
import '../../../widgets/v2/v2_today_meals_section.dart';
import '../../profile_setup/profile_completion.dart';
import '../../profile_setup/profile_completion_widgets.dart';

/// User's Diet bottom-nav tab.
///
/// Phase F.1 hard-switched this surface from the legacy assigned-plans
/// list to the structured-plan "today's meals" view. Phase H upgrades
/// the visual shell to mirror the paid-home v2 layout: edge-to-edge
/// dark phase-themed `V2DietHero` at the top, cream body below with
/// the existing meal-section content.
///
/// The class name + constructor signature stay stable so
/// `bottom_bar_screen.dart` doesn't need to know about the swap.
class DietPlansOfUser extends StatelessWidget {
  // Kept for source compatibility with the existing call site at
  // bottom_bar_screen.dart:69. When mounted as a bottom-nav tab the
  // back button is hidden; when pushed (legacy entry points) it shows.
  final bool showBackButton;

  const DietPlansOfUser({super.key, this.showBackButton = true});

  static const Color _kCream = Color(0xFFEAF7E4);
  static const Color _kAccent = Color(0xFF6DC55A);

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<DietPlanUserController>();
    final consultCtrl = Get.find<ConsultationController>();
    // Fired on every build rather than tucked into a StatefulWidget's
    // initState on purpose: this tab rebuilds whenever the bottom-nav
    // switches to it, which is exactly when we want a fresh read — the
    // dietitian may have confirmed/canceled since the user last looked.
    // loadUpcomingAppointment() always refetches (no caching), unlike
    // loadBookingContext().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      consultCtrl.loadUpcomingAppointment();
      ProfileCompletion.to.reload();
    });
    final pc = ProfileCompletion.to;
    // Hero paints edge-to-edge under the system status bar (matches
    // paid_home_screen_v2.dart). No outer SafeArea — the hero handles
    // its own top padding via MediaQuery.padding.top inside _TopBar.
    return Scaffold(
      backgroundColor: _kCream,
      body: RefreshIndicator(
        color: _kAccent,
        onRefresh: () async {
          await Future.wait([
            ctrl.loadActivePlan(refresh: true),
            consultCtrl.loadUpcomingAppointment(),
            pc.reload(force: true),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // All clients, paid and trial (Oct 2026): "today" card in the
              // hero; the plan ending card, day strip and day summary card
              // are left out.
              V2DietHero(showBackButton: showBackButton, todayCard: true),
              // Plan paused: says so, with Unfreeze (hides itself otherwise).
              const PlanFrozenBanner(),
              // Package ending / ended: renew heads-up while her meals still
              // show (meal plan stays visible). Hidden when the meal plan
              // itself is complete: that card already offers the next step.
              Obx(() => ctrl.planHasEnded ? const SizedBox.shrink() : const PlanExpiryBanner()),
              // Old paid client whose dietitian still needs her health
              // form / food answers. No plan yet: the tab waits for the
              // profile. Plan already made: it stays, with a small ask.
              Obx(() {
                final locked = pc.dietLocked;
                final hasPlan = ctrl.activePlan.value != null;
                if (locked && !hasPlan && !ctrl.isLoading.value) {
                  return const DietLockedView();
                }
                return Column(
                  children: [
                    if (locked && hasPlan) const DietFinishProfileStrip(),
                    const UpcomingConsultationCard(),
                    // Oct 2026: paid client, no call booked → book her
                    // consultation here too (hides itself otherwise: trial,
                    // already booked, or nothing she can book).
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: TalkToExpertCard(forDietTab: true),
                    ),
                    // Nov 2026: her dietitian's note for this plan.
                    Obx(() {
                      final note = ctrl.activePlan.value?.clientNote;
                      if (note == null || note.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F8EE),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFD8EDD4)),
                          ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.sticky_note_2_outlined, size: 20, color: Color(0xFF3E8E4A)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('From your dietitian',
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF3E8E4A))),
                                const SizedBox(height: 4),
                                Text(note,
                                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, height: 1.45, color: Color(0xFF1A3A22))),
                              ]),
                            ),
                          ]),
                        ),
                      );
                    }),
                    const V2TodayMealsSection(compact: true),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
